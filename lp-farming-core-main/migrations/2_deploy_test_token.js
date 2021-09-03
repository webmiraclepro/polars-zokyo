const {
    ether
} = require("@openzeppelin/test-helpers");

// smart contracts
const ERC20Mock = artifacts.require("ERC20Mock.sol");

// test token params
const tTokenName = "TEST_REWARD_TOKEN";
const tTokenSymbol = "TEST_REWARD_TOKEN";
const tTokenSupply = ether("300000"); // 300,000 tokens

module.exports = async function (deployer, network, accounts) {
    if (network === "test") return; // skip migrations if use test network

    // get the current deployer address
    const curDeployer = accounts[0];

    // deploy test token
    await deployer.deploy(ERC20Mock, tTokenName, tTokenSymbol, curDeployer, tTokenSupply);
    let tToken = await ERC20Mock.deployed();
    console.log("tToken address: ", tToken.address);
};
