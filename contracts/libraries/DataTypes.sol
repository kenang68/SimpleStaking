// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.6;

library DataTypes {

  struct ReserveData {
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
  }
}
