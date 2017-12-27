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
      network_id: "42"
    }
  }
};
