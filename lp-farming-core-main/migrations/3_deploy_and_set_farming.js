const fs = require("fs");
const path = require("path");

const {
    BN,
    ether
} = require("@openzeppelin/test-helpers");

// smart contracts
const FarmingPool = artifacts.require("FarmingPool.sol");
const Reservoir = artifacts.require("Reservoir.sol");
const IERC20 = artifacts.require("IERC20.sol");

// farming params
const rewardTokenAddress = "0xB1fC2cDD72FECCeCadB852632c0FBa00ac4F81AB"; // rinkeby
const defaultRewardPerSecond = new BN("8680555555555555"); // 250,000*0.3% per day (250,000 * 0.3% / 86400)
const startFarmingTimestamp = Math.floor(Date.now() / 1000); // from now
const initialReservoirSupply = ether("250000"); // 250,000 tokens

// LP tokens
const tradingPoolAddress = "0x41A456c3D300c75eec3BA5e235baBf76Bb22A379"; // rinkeby: trading pool (bPool) address
const secondaryPoolAddress = "0xfD6DE20e0B51ebD2f435b9925222f4a5cc78a701"; // rinkeby: secondary pool address
const tradingPoolAllocPoint = ether("0.6"); // 60%
const secondaryPoolAllocPoint = ether("0.4"); // 40%

module.exports = async function (deployer, network, accounts) {
    if (network === "test") return; // skip migrations if use test network

    // get RewardToken from address
    let rewardToken = await IERC20.at(rewardTokenAddress);

    // FarmingPool deployment
    console.log("FarmingPool deployment");
    await deployer.deploy(FarmingPool,
        rewardToken.address,
        defaultRewardPerSecond,
        startFarmingTimestamp,
        [tradingPoolAllocPoint, secondaryPoolAllocPoint],
        [tradingPoolAddress, secondaryPoolAddress]
    );
    let farmingPool = await FarmingPool.deployed();
    console.log("farmingPool address: ", farmingPool.address);

    // Reservoir deployment
    console.log("Reservoir deployment");
    await deployer.deploy(Reservoir,
        rewardToken.address,
        farmingPool.address
    );
    let reservoir = await Reservoir.deployed();
    console.log("reservoir address: ", reservoir.address);

    // transfer RewardTokens to Reservoir
    console.log("transfer RewardTokens to Reservoir");
    await rewardToken.transfer(
        reservoir.address,
        initialReservoirSupply
    );

    // initialize Reservoir address in FarmingPool
    console.log("initialize Reservoir address in FarmingPool");
    await farmingPool.initializeTokenReservoir(
        reservoir.address
    );

    // write addresses and ABI to files
    console.log("write addresses and ABI to files");
    const contractsAddresses = {
        farmingPool: farmingPool.address,
        reservoir: reservoir.address,
        rewardToken: rewardToken.address,
        tradingPool: tradingPoolAddress,
        secondaryPool: secondaryPoolAddress
    };

    const contractsAbi = {
        farmingPool: farmingPool.abi,
        reservoir: reservoir.abi
    };

    const deployDirectory = `${__dirname}/../deployed`;
    if (!fs.existsSync(deployDirectory)) {
        fs.mkdirSync(deployDirectory);
    }

    fs.writeFileSync(path.join(deployDirectory, `${network}_farming_addresses.json`), JSON.stringify(contractsAddresses, null, 2));
    fs.writeFileSync(path.join(deployDirectory, `${network}_farming_abi.json`), JSON.stringify(contractsAbi, null, 2));
};
