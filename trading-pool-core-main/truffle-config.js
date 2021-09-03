const HDWalletProvider = require('@truffle/hdwallet-provider');
const web3 = require('web3');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({
  path: path.resolve(__dirname, '.env'),
});

function getProvider(rpc) {
  return function() {
    const provider = new web3.providers.WebsocketProvider(rpc);
    return new HDWalletProvider(process.env.DEPLOYMENT_KEY, provider);
  };
}

module.exports = {
    networks: {
        development: {
            host: 'localhost', // Localhost (default: none)
            port: 8545, // Standard Ethereum port (default: none)
            network_id: '*', // Any network (default: none)
            gas: 10000000,
        },
        coverage: {
            host: 'localhost',
            network_id: '*',
            port: 8555,
            gas: 0xfffffffffff,
            gasPrice: 0x01,
        },
        kovan: {
            gasPrice: 1e9, // 1 gwei
            gasLimit: 8 * 1e6, // 8,000,000
            provider: getProvider(`wss://kovan.infura.io/ws/v3/${ process.env.INFURA_PROJECT_ID }`),
            websockets: true,
            skipDryRun: true,
            network_id: '42'
        },
        rinkeby: {
            gasPrice: 1e9, // 1 gwei
            gasLimit: 8 * 1e6, // 8,000,000
            provider: getProvider(`wss://rinkeby.infura.io/ws/v3/${ process.env.INFURA_PROJECT_ID }`),
            websockets: true,
            skipDryRun: true,
            network_id: '4'
        },
        mainnet: {
            gasPrice: 100 * 1e9, // 100 gwei
            gasLimit: 8 * 1e6, // 8,000,000
            provider: getProvider(`wss://mainnet.infura.io/ws/v3/${ process.env.INFURA_PROJECT_ID }`),
            websockets: true,
            skipDryRun: false,
            network_id: '1'
        },
    },
    // Configure your compilers
    compilers: {
        solc: {
            version: '0.7.4',
            settings: { // See the solidity docs for advice about optimization and evmVersion
                optimizer: {
                    enabled: true,
                    runs: 200,
                },
                evmVersion: 'istanbul',
            },
        },
    },
    plugins: [
        'truffle-contract-size',
        'truffle-plugin-verify'
    ],
    api_keys: {
        etherscan: process.env.ETHERSCAN_API_KEY
    }
};
