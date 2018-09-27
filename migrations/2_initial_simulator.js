var EthereumSimulator = artifacts.require("./BitcoinNetworkSimulator.sol");

module.exports = function(deployer) {
    deployer.deploy(BitcoinNetworkSimulator);
};
