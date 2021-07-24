// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Errors} from "./libraries/Errors.sol";
import {WadRayMath} from "./libraries/WadRayMath.sol";
import {ReserveLogic} from "./libraries/ReserveLogic.sol";
import {IStakingPool} from "./interfaces/IStakingPool.sol";
import {IAToken} from "./interfaces/IAToken.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {MathUtils} from "./libraries/MathUtils.sol";

contract StakingPool is IStakingPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    using ReserveLogic for DataTypes.ReserveData;

    mapping(address => DataTypes.ReserveData) internal reserves_;

    uint256 public liquidityIndex;
    address public governanceAccount;
    address public aTokenAddress;

    constructor() {
        governanceAccount = msg.sender;
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "StakingPool: sender not authorized");
        _;
    }

    /**
     * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * @param asset The address of the underlying asset to deposit
     * @param amount The amount to be deposited
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     **/
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override {
        require(amount != 0, "StakingPool: revert Error - deposit request for 0 amount");
        DataTypes.ReserveData storage reserve = reserves_[asset];

        aTokenAddress = reserve.aTokenAddress;
        liquidityIndex = reserve.liquidityIndex;

        uint256 previousLiquidityIndex = reserve.liquidityIndex;
        uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;
        uint256 currentLiquidityRate = reserve.currentLiquidityRate;
        uint256 newLiquidityIndex = previousLiquidityIndex;

        //only cumulating if there is any income being produced
        if (currentLiquidityRate > 0) {
            uint256 cumulatedLiquidityInterest =
                MathUtils.calculateLinearInterest(currentLiquidityRate, lastUpdatedTimestamp);
            newLiquidityIndex = cumulatedLiquidityInterest.rayMul(previousLiquidityIndex);
            require(newLiquidityIndex <= type(uint128).max, Errors.RL_LIQUIDITY_INDEX_OVERFLOW);

            reserve.liquidityIndex = uint128(newLiquidityIndex);
        }
        reserve.lastUpdateTimestamp = uint40(block.timestamp);

        IERC20(asset).safeTransferFrom(msg.sender, aTokenAddress, amount);
        bool isFirstDeposit =
            IAToken(aTokenAddress).mint(onBehalfOf, amount, liquidityIndex);

        bool notFirstDeposit = true;
        if (isFirstDeposit) {
            notFirstDeposit = false;
        }

        emit Deposit(asset, msg.sender, onBehalfOf, amount);
        amount = 0;
    }

    /**
     * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * @param asset The address of the underlying asset to withdraw
     * @param amountToWithdraw The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to Address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     **/
    function withdraw(
        address asset,
        uint256 amountToWithdraw,
        address to
    ) external override returns (uint256) {
        DataTypes.ReserveData storage reserve = reserves_[asset];

        aTokenAddress = reserve.aTokenAddress;
        liquidityIndex = reserve.liquidityIndex;

        uint256 userBalance = IAToken(aTokenAddress).scaledBalanceOf(msg.sender);

        uint256 amount = amountToWithdraw;

        if (amountToWithdraw == type(uint256).max) {
            amount = userBalance;
        }

        require(amountToWithdraw != 0, "StakingPool: revert Error - withdraw request for 0 amount");
        require(
            amountToWithdraw <= userBalance,
            "Error - withdraw request more than balance"
        );

        uint256 previousLiquidityIndex = reserve.liquidityIndex;
        uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;
        uint256 currentLiquidityRate = reserve.currentLiquidityRate;
        uint256 newLiquidityIndex = previousLiquidityIndex;

        //only cumulating if there is any income being produced
        if (currentLiquidityRate > 0) {
            uint256 cumulatedLiquidityInterest =
                MathUtils.calculateLinearInterest(currentLiquidityRate, lastUpdatedTimestamp);
            newLiquidityIndex = cumulatedLiquidityInterest.rayMul(previousLiquidityIndex);
            require(newLiquidityIndex <= type(uint128).max, Errors.RL_LIQUIDITY_INDEX_OVERFLOW);

            reserve.liquidityIndex = uint128(newLiquidityIndex);
        }
        reserve.lastUpdateTimestamp = uint40(block.timestamp);

        IAToken(aTokenAddress).burn(msg.sender, to, amount, liquidityIndex);

        emit Withdraw(asset, msg.sender, to, amount);

        return amount;
    }

    /**
     * @dev Returns the state of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        override
        returns (DataTypes.ReserveData memory)
    {
        return reserves_[asset];
    }

    /**
     * @dev Returns the normalized income per unit of asset
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(address asset)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return reserves_[asset].getNormalizedIncome();
    }

    /**
     * @dev Initializes a reserve, activating it, assigning an aToken
     * @param asset The address of the underlying asset of the reserve
     * @param atokenAddress The address of the aToken that will be assigned to the reserve
     **/
    function initReserve(
        address asset,
        address atokenAddress
    ) external override {
        DataTypes.ReserveData storage reserve = reserves_[asset];
        require(Address.isContract(asset), Errors.SP_NOT_CONTRACT);
        require(reserve.aTokenAddress == address(0), Errors.RL_RESERVE_ALREADY_INITIALIZED);

        reserve.liquidityIndex = uint128(WadRayMath.ray());
        reserve.aTokenAddress = atokenAddress;
        uint256 calculation = WadRayMath.ray().div(5);
        reserve.currentLiquidityRate = uint128(calculation); // 20% per year for LiquidityRate
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function setGovernanceAccount(address newGovernanceAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newGovernanceAccount != address(0),
            "StakingPool: new governance account is the zero address"
        );

        governanceAccount = newGovernanceAccount;
    }
}