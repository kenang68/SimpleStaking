// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const network = hre.network.name;
  const accounts = await hre.ethers.getSigners();
  console.log("Deployer address: ", accounts[0].address);

  const MintableERC20 = await hre.ethers.getContractFactory("MintableERC20");
  const StakingPool = await hre.ethers.getContractFactory("StakingPool");
  const ATokenMock = await hre.ethers.getContractFactory("ATokenMock");
 
  let aTokenAddress;
  let mintableERC20Address;

  const mintableERC20 = await MintableERC20.deploy("Dai Mock", "Dai Mock", 18);
  await mintableERC20.deployed();
  mintableERC20Address = mintableERC20.address;

  const aTokenMock = await ATokenMock.deploy("AToken", "AToken", 18, mintableERC20Address);
  await aTokenMock.deployed();
  aTokenAddress = aTokenMock.address;

  const stakingPool = await StakingPool.deploy();
  await stakingPool.deployed();
  stakingPoolAddress = stakingPool.address;

  console.log("MintableERC20 deployed to:", mintableERC20Address);
  console.log("StakingPool Address deployed to:", stakingPoolAddress);
  console.log("AToken Address deployed to:", aTokenAddress);

  // Post-Deployment
  // to initialize the StakingPool address of ATokenMock contract
  await aTokenMock.setStakingPoolAddress(stakingPoolAddress);
  // to initialize the Reserve Data of underlyingAssetMock
  stakingPool.initReserve(mintableERC20Address, aTokenMock.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
