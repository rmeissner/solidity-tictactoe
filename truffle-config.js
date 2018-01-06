var HDWalletProvider = require("truffle-hdwallet-provider");
var Secrets = require("./secrets");

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    kovan: {
      provider: new HDWalletProvider(Secrets.mnemonic, "https://kovan.infura.io/"),
      network_id: "42",
      gasPrice: 4000000000
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
