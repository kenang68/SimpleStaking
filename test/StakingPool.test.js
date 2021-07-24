//const web3 = require('web3');
const assert = require("assert");
const { expectEvent, expectRevert } = require("@openzeppelin/test-helpers");
const expectedBlockTime = 1000;
const BN = web3.utils.BN;
const sleep = (milliseconds) => {
  return new Promise(resolve => setTimeout(resolve, milliseconds))
}

function ether(ether) {
  return new BN(web3.utils.toWei(ether, "ether"));
}

describe("StakingPool", () => {
  let accounts;
  let defaultGovernanceAccount;
  let defaultUserWalletAddress;
  let mintableERC20;
  let stakingPool;
  let aTokenMock;
  let decimal;

  before(async () => {
    accounts = await web3.eth.getAccounts();
    defaultGovernanceAccount = accounts[0];
    defaultUserWalletAddress = accounts[5];
  });

  beforeEach(async () => {
    decimal = 18;
    const MintableERC20 = artifacts.require("MintableERC20");
    mintableERC20 = await MintableERC20.new("Dai Mock", "Dai Mock", 18);
    const ATokenMock = artifacts.require("ATokenMock");
    aTokenMock = await ATokenMock.new("AToken", "AToken", decimal, mintableERC20.address);
    const StakingPool = artifacts.require("StakingPool");
    stakingPool = await StakingPool.new();
  });

  it("should be initialized correctly", async () => {
    const governanceAccount = await stakingPool.governanceAccount();
    const expectGovernanceAccount = defaultGovernanceAccount;

    assert.strictEqual(
      governanceAccount,
      expectGovernanceAccount,
      `Governance account is ${governanceAccount} instead of treasury pool creator address ${expectGovernanceAccount}`
    );
  });

  it("should allow to deposit", async () => {

    // to initialize the ReserveData of AToken
    await stakingPool.initReserve(
      mintableERC20.address,
      aTokenMock.address
    );
    // to initialize the StakingPool address of AToken contract
    await aTokenMock.setStakingPoolAddress(stakingPool.address);
    
    const depositAmount = ether("9.9");
    await assert.doesNotReject(async () => await depositUnderlyingToken(depositAmount, defaultUserWalletAddress));
  });

  it("should not allow to deposit 0", async () => {
    await expectRevert(depositUnderlyingToken(ether("0"), defaultUserWalletAddress), "StakingPool: revert Error - deposit request for 0 amount");
  });

  it("should allow to redeem", async () => {

    // to initialize the ReserveData of AToken
    await stakingPool.initReserve(
      mintableERC20.address,
      aTokenMock.address
    );
    // to initialize the StakingPool address of AToken contract
    await aTokenMock.setStakingPoolAddress(stakingPool.address);

    let depositAmount = ether("9.9");
    await depositUnderlyingToken(depositAmount, defaultUserWalletAddress);

    depositAmount = ether("9.9");

    await assert.doesNotReject(
      async () => await stakingPool.withdraw(mintableERC20.address, depositAmount, defaultUserWalletAddress, { from: defaultUserWalletAddress })
    );
  });

  it("should not allow to redeem 0", async () => {
    //console.log("should not allow to redeem 0");

    // to initialize the ReserveData of AToken
    await stakingPool.initReserve(
      mintableERC20.address,
      aTokenMock.address
    );

    // to initialize the StakingPool address of AToken contract
    await aTokenMock.setStakingPoolAddress(stakingPool.address);

    const depositAmount = ether("9.9");

    await depositUnderlyingToken(depositAmount, defaultUserWalletAddress);

    await expectRevert(
      stakingPool.withdraw(mintableERC20.address, ether("0"), defaultUserWalletAddress),
      "StakingPool: revert Error - withdraw request for 0 amount"
    );
  });

  it("should only allow governance account to change governance account", async () => {
    const nonGovernanceAccount = accounts[6];

    await expectRevert(
      stakingPool.setGovernanceAccount(nonGovernanceAccount, { from: nonGovernanceAccount }),
      "StakingPool: sender not authorized"
    );
    await assert.doesNotReject(
      async () =>
        await stakingPool.setGovernanceAccount(defaultGovernanceAccount, { from: defaultGovernanceAccount })
    );
    await sleep(expectedBlockTime);
  });

  async function depositUnderlyingToken(amount, userWalletAddress) {
    await mintableERC20.mint(userWalletAddress, amount, { from: defaultGovernanceAccount });
    await mintableERC20.approve(stakingPool.address, amount, { from: userWalletAddress });
    return await stakingPool.deposit(mintableERC20.address, amount, userWalletAddress, { from: userWalletAddress });
  }
});