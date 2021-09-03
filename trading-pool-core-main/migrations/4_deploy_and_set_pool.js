const fs = require("fs");
const path = require("path");
const { toWei } = web3.utils;

// smart contracts
const TToken = artifacts.require('TToken');
const BPool = artifacts.require('BPool');
const BFactory = artifacts.require('BFactory');

// addresses
const factoryAddress = "0x1487D59b4936BF2ADc80825250568C12dfE61861"; // rinkeby
const blackAddress = "0x34FdAb678F43bB0115785fe59964646B48264140"; // rinkeby
const whiteAddress = "0xC27F0aAA2B6fD1fce8E846ebdccCA846750C8ADA"; // rinkeby
const wethAddress = "0xDf032Bc4B9dC2782Bb09352007D4C57B75160B15"; // rinkeby
// const wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // mainnet

// pool init liquidity
const blackTokenAmount = toWei('1'); // 1 token
const whiteTokenAmount = toWei('1'); // 1 token
const wethTokenAmount = toWei('0.0017'); // 0.0017 eth

// pool fee
const liuqudityFee = toWei('0.0015'); // 0.15%
const governanceFee = toWei('0.0009'); // 0.09%
const collateralizationFee = toWei('0.0006'); // 0.06%

// governance and collateralization wallets
const governanceWallet = "0xC7797a6d8181AB3CC8a9975F6A79d91815e9CB8d"; // rinkeby
const collateralizationWallet = "0xC7797a6d8181AB3CC8a9975F6A79d91815e9CB8d"; // rinkeby


module.exports = async function (deployer, network, accounts) {
    if (network === 'development' || network === 'coverage') {
        return; // skip migrations if use test network
    }

    // get the current deployer address
    const curDeployer = accounts[0];

    let factory = await BFactory.at(factoryAddress);
    let blackToken = await TToken.at(blackAddress);
    let whiteToken = await TToken.at(whiteAddress);
    let wethToken = await TToken.at(wethAddress);

    // deploy pool
    let poolAddress = await factory.newBPool.call();
    await factory.newBPool();
    let pool = await BPool.at(poolAddress);
    console.log("pool address: ", pool.address);

    // approve and deposit tokens to pool
    console.log("approve and deposit tokens to pool");
    await blackToken.approve(pool.address, blackTokenAmount);
    await pool.bind(blackToken.address, blackTokenAmount, toWei('1'));

    await whiteToken.approve(pool.address, whiteTokenAmount);
    await pool.bind(whiteToken.address, whiteTokenAmount, toWei('1'));

    await wethToken.approve(pool.address, wethTokenAmount);
    await pool.bind(wethToken.address, wethTokenAmount, toWei('1'));

    // set fee
    await pool.setLiquidityProvidersFee(liuqudityFee);
    await pool.setGovernanceFee(governanceFee);
    await pool.setCollateralizationFee(collateralizationFee);

    // set governance and collateralization wallets
    console.log("set governance and collateralization wallets");
    await pool.setGovernanceWallet(governanceWallet);
    await pool.setCollateralizationWallet(collateralizationWallet);

    // finalize
    console.log("finalize pool");
    await pool.finalize();

    // write addresses and ABI to files
    console.log("write addresses and ABI to files");
    const contractsAddresses = {
        pool: pool.address,
        factory: factory.address,
        blackToken: blackToken.address,
        whiteToken: whiteToken.address,
        weth: wethToken.address,
        governanceWallet: governanceWallet,
        collateralizationWallet: collateralizationWallet
    };

    const contractsAbi = {
        pool: pool.abi,
        factory: factory.abi
    };

    const deployDirectory = `${__dirname}/../deployed`;
    if (!fs.existsSync(deployDirectory)) {
        fs.mkdirSync(deployDirectory);
    }

    fs.writeFileSync(path.join(deployDirectory, `${network}_pool_addresses.json`), JSON.stringify(contractsAddresses, null, 2));
    fs.writeFileSync(path.join(deployDirectory, `${network}_pool_abi.json`), JSON.stringify(contractsAbi, null, 2));
};
