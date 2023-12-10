require("@nomicfoundation/hardhat-toolbox");
const tdly = require('@tenderly/hardhat-tenderly');
tdly.setup({ automaticVerifications: true });
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: 'goerli',
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    hardhat: {

    },
    goerli: {
      name: "goerli",
      id: 5,
      url: "https://goerli.infura.io/v3/8313bffd310749cf9c827885d3aba888",
      accounts: ["PRIVATE_KEY"]
    },
  },
  plugins: [
    "hardhat-cache-plugin",

  ],
  tenderly: {
    project: 'project',
    username: 'xubowenshizi'
  }
}
