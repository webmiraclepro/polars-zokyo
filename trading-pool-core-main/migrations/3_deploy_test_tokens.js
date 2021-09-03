const fs = require("fs");
const path = require("path");
const { toWei } = web3.utils;

// smart contracts
const TToken = artifacts.require('TToken');

// tBlack params
const tBlackName = "TEST_BLACK";
const tBlackSymbol = "TEST_BLACK";
const tBlackSupply = toWei('1000');  // 1000 tokens

// tWhite params
const tWhiteName = "TEST_WHITE";
const tWhiteSymbol = "TEST_WHITE";
const tWhiteSupply = toWei('1000');  // 1000 tokens

module.exports = async function (deployer, network, accounts) {
    if (network === 'development' || network === 'coverage') {
        return; // skip migrations if use test network
    }

    // get the current deployer address
    const curDeployer = accounts[0];

    // deploy tBlack
    await deployer.deploy(TToken, tBlackName, tBlackSymbol, 18);
    let tBlack = await TToken.deployed();
    console.log("tBlack address: ", tBlack.address);

    // deploy tWhite
    await deployer.deploy(TToken, tWhiteName, tWhiteSymbol, 18);
    let tWhite = await TToken.deployed();
    console.log("tWhite address: ", tWhite.address);

    // mint tBlack and tWhite to deployer
    await tBlack.mint(
        curDeployer,
        tBlackSupply
    );
    await tWhite.mint(
        curDeployer,
        tWhiteSupply
    );
    console.log("Minted tWhite and tBlack to deployer address");

    // write addresses and ABI to files
    const contractsAddresses = {
        tBlack: tBlack.address,
        tWhite: tWhite.address
    };

    const contractsAbi = {
        token: tBlack.abi
    };

    const deployDirectory = `${__dirname}/../deployed`;
    if (!fs.existsSync(deployDirectory)) {
        fs.mkdirSync(deployDirectory);
    }

    fs.writeFileSync(path.join(deployDirectory, `${network}_test_tokens_addresses.json`), JSON.stringify(contractsAddresses, null, 2));
    fs.writeFileSync(path.join(deployDirectory, `${network}_test_tokens_abi.json`), JSON.stringify(contractsAbi, null, 2));
};
