var Miner1 = artifacts.require("./Miner1.sol");
var Miner2 = artifacts.require("./Miner2.sol");
var Miner3 = artifacts.require("./Miner3.sol");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(Miner1, {from: accounts[1], value: 20000000});
    deployer.deploy(Miner2, {from: accounts[2], value: 20000000});
    deployer.deploy(Miner3, {from: accounts[3], value: 20000000});
};
