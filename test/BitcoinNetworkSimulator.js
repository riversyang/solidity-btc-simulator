var BitcoinNetworkSimulator = artifacts.require("../contracts/BitcoinNetworkSimulator");
var Miner1 = artifacts.require("../contracts/Miner1");
var Miner2 = artifacts.require("../contracts/Miner2");
var Miner3 = artifacts.require("../contracts/Miner3");
var testdata = require('../data/BitcoinNetworkSimulator.json');
var send = require('./TimeTravel.js');

contract('BitcoinNetworkSimulator', function(accounts) {
    var simulatorInstance = BitcoinNetworkSimulator.deployed();
    var minerInstance1;
    Miner1.deployed().then(miner1 => {
        const events1 = miner1.allEvents({fromBlock: 0, toBlock: "latest"});
        events1.watch(function(error, result) {
            if (!error) {
                console.log("Miner1 event " + result.event + " detected: ");
                if (result.event == "LogTransactionData") {
                    console.log("   _inCounter: " + result.args._inCounter.toNumber());
                    console.log("   _inputsData: " + result.args._inputsData);
                    console.log("   _outCounter: " + result.args._outCounter.toNumber());
                    console.log("   _outputsData: " + result.args._outputsData);
                } else if (result.event == "LogBlockData") {
                    console.log("   _previousHash: " + result.args._previousHash);
                    console.log("   _merkleRoot: " + result.args._merkleRoot);
                    console.log("   _number: " + result.args._number.toNumber());
                    console.log("   _timeStamp: " + result.args._timeStamp.toNumber());
                } else if (result.event == "LogInputData") {
                    console.log("   _previousTxHash: " + result.args._previousTxHash);
                    console.log("   _index: " + result.args._index.toNumber());
                } else if (result.event == "LogOutputData") {
                    console.log("   _value: " + result.args._value.toNumber());
                    console.log("   _scriptPubKey: " + result.args._scriptPubKey);
                } else {
                    console.log(result);
                }
            } else {
                console.log("Error occurred while watching events.");
            }
        });
        minerInstance1 = miner1;
    });
    var minerInstance2;
    Miner2.deployed().then(miner2 => {
        const events2 = miner2.allEvents({fromBlock: 0, toBlock: "latest"});
        events2.watch(function(error, result) {
            if (!error) {
                console.log("Miner2 event " + result.event + " detected: ");
                if (result.event == "LogTransactionData") {
                    console.log("   _inCounter: " + result.args._inCounter.toNumber());
                    console.log("   _inputsData: " + result.args._inputsData);
                    console.log("   _outCounter: " + result.args._outCounter.toNumber());
                    console.log("   _outputsData: " + result.args._outputsData);
                } else if (result.event == "LogBlockData") {
                    console.log("   _previousHash: " + result.args._previousHash);
                    console.log("   _merkleRoot: " + result.args._merkleRoot);
                    console.log("   _number: " + result.args._number.toNumber());
                    console.log("   _timeStamp: " + result.args._timeStamp.toNumber());
                } else if (result.event == "LogInputData") {
                    console.log("   _previousTxHash: " + result.args._previousTxHash);
                    console.log("   _index: " + result.args._index.toNumber());
                } else if (result.event == "LogOutputData") {
                    console.log("   _value: " + result.args._value.toNumber());
                    console.log("   _scriptPubKey: " + result.args._scriptPubKey);
                } else {
                    console.log(result);
                }
            } else {
                console.log("Error occurred while watching events.");
            }
        });
        minerInstance2 = miner2;
    });
    var minerInstance3;
    Miner3.deployed().then(miner3 => {
        const events3 = miner3.allEvents({fromBlock: 0, toBlock: "latest"});
        events3.watch(function(error, result) {
            if (!error) {
                console.log("Miner3 event " + result.event + " detected: ");
                if (result.event == "LogTransactionData") {
                    console.log("   _inCounter: " + result.args._inCounter.toNumber());
                    console.log("   _inputsData: " + result.args._inputsData);
                    console.log("   _outCounter: " + result.args._outCounter.toNumber());
                    console.log("   _outputsData: " + result.args._outputsData);
                } else if (result.event == "LogBlockData") {
                    console.log("   _previousHash: " + result.args._previousHash);
                    console.log("   _merkleRoot: " + result.args._merkleRoot);
                    console.log("   _number: " + result.args._number.toNumber());
                    console.log("   _timeStamp: " + result.args._timeStamp.toNumber());
                } else if (result.event == "LogInputData") {
                    console.log("   _previousTxHash: " + result.args._previousTxHash);
                    console.log("   _index: " + result.args._index.toNumber());
                } else if (result.event == "LogOutputData") {
                    console.log("   _value: " + result.args._value.toNumber());
                    console.log("   _scriptPubKey: " + result.args._scriptPubKey);
                } else {
                    console.log(result);
                }
            } else {
                console.log("Error occurred while watching events.");
            }
        });
        minerInstance3 = miner3;
    });

    it("Passes testcase 0 ", async function() {
        let simulator = await simulatorInstance;
        let miner1 = await minerInstance1;
        let miner2 = await minerInstance2;
        let miner3 = await minerInstance3;
        await miner1.register(simulator.contract.address, {from: accounts[1]});
        await miner2.register(simulator.contract.address, {from: accounts[2]});
        await miner3.register(simulator.contract.address, {from: accounts[3]});

        console.log("Simulator: " + simulator.contract.address);
        console.log("Miner1: " + miner1.contract.address);
        console.log("Miner2: " + miner2.contract.address);
        console.log("Miner3: " + miner3.contract.address);

        let result;
        result = await simulator.curMiner.call();
        console.log("Current Miner: " + result);
        assert.equal(result, miner1.contract.address);
        result = await simulator.totalStake.call();
        console.log("Total stake: " + result.toNumber());
        assert.equal(result, 30000000);

        let result1;
        let result2;
        let result3;
        result1 = await miner1.getBalance.call(accounts[1]);
        result2 = await miner2.getBalance.call(accounts[1]);
        result3 = await miner3.getBalance.call(accounts[1]);
        assert.equal(result1.toNumber(), result2.toNumber());
        assert.equal(result2.toNumber(), result3.toNumber());
        console.log("Account[1] balance: " + result3.toNumber());
        result1 = await miner1.getBalance.call(accounts[2]);
        result2 = await miner2.getBalance.call(accounts[2]);
        result3 = await miner3.getBalance.call(accounts[2]);
        assert.equal(result1.toNumber(), result2.toNumber());
        assert.equal(result2.toNumber(), result3.toNumber());
        console.log("Account[2] balance: " + result2.toNumber());
        result1 = await miner1.getBalance.call(accounts[3]);
        result2 = await miner2.getBalance.call(accounts[3]);
        result3 = await miner3.getBalance.call(accounts[3]);
        assert.equal(result1.toNumber(), result2.toNumber());
        assert.equal(result2.toNumber(), result3.toNumber());
        console.log("Account[3] balance: " + result1.toNumber());

        await send('evm_mine');
    });

    it("Passes testcase 1 ", async function() {
        let simulator = await simulatorInstance;
        let miner1 = await minerInstance1;
        let miner2 = await minerInstance2;
        let miner3 = await minerInstance3;

        await simulator.generateNewBlock();

        let result1;
        let result2;
        let result3;
        result1 = await miner1.getBalance.call(accounts[1]);
        result2 = await miner2.getBalance.call(accounts[1]);
        result3 = await miner3.getBalance.call(accounts[1]);
        assert.equal(result1.toNumber(), result2.toNumber());
        assert.equal(result2.toNumber(), result3.toNumber());
        console.log("Account[1] balance: " + result3.toNumber());
        result1 = await miner1.getBalance.call(accounts[2]);
        result2 = await miner2.getBalance.call(accounts[2]);
        result3 = await miner3.getBalance.call(accounts[2]);
        assert.equal(result1.toNumber(), result2.toNumber());
        assert.equal(result2.toNumber(), result3.toNumber());
        console.log("Account[2] balance: " + result2.toNumber());
        result1 = await miner1.getBalance.call(accounts[3]);
        result2 = await miner2.getBalance.call(accounts[3]);
        result3 = await miner3.getBalance.call(accounts[3]);
        assert.equal(result1.toNumber(), result2.toNumber());
        assert.equal(result2.toNumber(), result3.toNumber());
        console.log("Account[3] balance: " + result1.toNumber());

        await send('evm_mine');
    });

    testdata.vectors.forEach(function(v, i) {
        it("Passes test vector " + i, async function() {
    //         let simulator = await simulatorInstance;
    //         let miner1 = await minerInstance1;
    //         let miner2 = await minerInstance2;
    //         let miner3 = await minerInstance3;
    //         let result = await simulator.processTransaction(
    //             v.input[0], v.input[1], accounts[v.to], v.input[3], v.input[4], {from: accounts[v.from]}
    //         );
    //         let result1;
    //         let result2;
    //         let result3;
    //         result1 = await miner1.getBalance.call(accounts[1]);
    //         result2 = await miner2.getBalance.call(accounts[1]);
    //         result3 = await miner3.getBalance.call(accounts[1]);
    //         assert.equal(result1.toNumber(), result2.toNumber());
    //         assert.equal(result2.toNumber(), result3.toNumber());
    //         console.log("Account[1] balance: " + result3.toNumber());
    //         result1 = await miner1.getBalance.call(accounts[2]);
    //         result2 = await miner2.getBalance.call(accounts[2]);
    //         result3 = await miner3.getBalance.call(accounts[2]);
    //         assert.equal(result1.toNumber(), result2.toNumber());
    //         assert.equal(result2.toNumber(), result3.toNumber());
    //         console.log("Account[2] balance: " + result2.toNumber());
    //         result1 = await miner1.getBalance.call(accounts[3]);
    //         result2 = await miner2.getBalance.call(accounts[3]);
    //         result3 = await miner3.getBalance.call(accounts[3]);
    //         assert.equal(result1.toNumber(), result2.toNumber());
    //         assert.equal(result2.toNumber(), result3.toNumber());
    //         console.log("Account[3] balance: " + result1.toNumber());
    //         result = await simulator.curMiner.call();
    //         console.log("Current Miner: " + result);
        });
    });

    after(async function() {
        console.log("Test finished.")
    });

});
