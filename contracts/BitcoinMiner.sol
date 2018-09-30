pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/introspection/SupportsInterfaceWithLookup.sol";
import "./BitcoinChainData.sol";

contract BitcoinMiner is SupportsInterfaceWithLookup, BitcoinChainData, Ownable {
    struct Utxo {
        bytes32 txHash;
        uint256 index;
        uint256 value;
        address pubKey;
    }
    // 给矿工的区块奖励
    uint256 public constant BLOCK_REWARD = 50 * (10 ** 8);
    // 账户地址 => 其所有可用 Output 数组
    mapping(address => Utxo[]) internal allUtxos;
    // keccak256(abi.encodePacked(input.previousTxHash, input.index)) => 由 input.previousTxHash 和 input.index 所指定的 Output 在 allUtxos[output.scriptPubKey] 数组中的索引
    mapping(bytes32 => uint256) internal outputsIndexInUtxoArray;
    // 交易池
    Transaction[] internal transactionPool;
    // 是否正在记账
    bool internal isCurrentMiner;
    // 网络模拟器
    address internal networkSimulator;
    // 用于输出中间数据的事件
    event LogBlockData(
        bytes32 _previousHash,
        bytes32 _merkleRoot,
        uint256 _number,
        uint256 _timeStamp
    );
    event LogTransactionData(
        uint256 _inCounter,
        bytes _inputsData,
        uint256 _outCounter,
        bytes _outputsData
    );
    event LogInputData(bytes32 _previousTxHash, uint256 _index);
    event LogOutputData(uint256 _value, address _scriptPubKey);

    /**
     * @dev 创建矿工合约，需要以太坊协议模拟器合约已创建
     * @notice 创建时需要存入一定量的资金
     */
    constructor() public payable {
        require(msg.value > 0, "You need to transfer value for miner contract.");
        // 注册所有必要的接口
        _registerInterface(bytes4(keccak256("storeTransactionToPool(bytes)")));
        _registerInterface(bytes4(keccak256("createBlock()")));
        _registerInterface(bytes4(keccak256("applyBlock(bytes)")));
    }

    function memcpy(uint dest, uint src, uint len) private pure {
        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    modifier onlySimulator() {
        require(
            msg.sender == address(networkSimulator),
            "Only accept calling from Network Simulator."
        );
        _;
    }

    function register(address _addr) external onlyOwner {
        networkSimulator = _addr;
        uint256 _value = address(this).balance / 2;
        require(
            NetworkSimulator(networkSimulator).registerMiner.value(_value)(),
            "Failed to register miner."
        );
    }

    function unregister() external onlyOwner {
        require(
            NetworkSimulator(networkSimulator).unregisterMiner(),
            "Failed to unregister miner."
        );
    }

    /**
     * @dev 任意外部地址均可调用，创建交易并广播到网络中
     * @notice 函数应该检查 msg.sender 的 UTXO 是否足够发起交易
     * @param _target 转账目标地址
     * @param _value 转账数额
     */
    function sendBitcoin(address _target, uint256 _value) external {
        require(_value <= getBalance(msg.sender), "Balance not enough.");
        bytes memory inputsData = new bytes(0);
        bytes memory outputsData = new bytes(0);
        uint256 inputCount;
        uint256 outputCount;
        uint256 blv = _value;
        uint256 utxoCount = allUtxos[msg.sender].length;
        Input memory input = Input({previousTxHash: 0x0, index: 0});
        Output memory output = Output({value: _value, scriptPubKey: _target});
        outputsData = appendBytesToBytes(
            outputsData, abi.encode(output.value, output.scriptPubKey)
        );
        outputCount++;
        for (uint i = 0; i < utxoCount; i++) {
            input.previousTxHash = allUtxos[msg.sender][i].txHash;
            input.index = allUtxos[msg.sender][i].index;
            inputsData = appendBytesToBytes(
                inputsData, abi.encode(input.previousTxHash, input.index)
            );
            inputCount++;
            if (blv < allUtxos[msg.sender][i].value) {
                output.value = allUtxos[msg.sender][i].value - blv;
                output.scriptPubKey = msg.sender;
                outputsData = appendBytesToBytes(
                    outputsData, abi.encode(output.value, output.scriptPubKey)
                );
                outputCount++;
                break;
            } else if (blv == allUtxos[msg.sender][i].value) {
                break;
            } else {
                blv = blv - allUtxos[msg.sender][i].value;
            }
        }
        Transaction memory newTx = Transaction({
            inCounter: inputCount, inputsData: inputsData,
            outCounter: outputCount, outputsData: outputsData
        });
        transactionPool.push(newTx);
        bytes memory txData = abi.encode(
            newTx.inCounter, newTx.inputsData, newTx.outCounter, newTx.outputsData
        );
        NetworkSimulator(networkSimulator).broadcastTransaction(txData);
    }

    /**
     * @dev 获取指定地址的 UTXO 总额
     * @param _addr 指定的地址
     * @return 指定地址的 UTXO 总额
     */
    function getBalance(address _addr) public view returns (uint256) {
        uint256 blv;
        uint256 utxoCount = allUtxos[_addr].length;
        for (uint i = 0; i < utxoCount; i++) {
            blv = blv.add(allUtxos[_addr][i].value);
        }
        return blv;
    }

    function appendBytesToBytes(
        bytes memory _oriBytes, bytes memory _tailBytes
    )
        internal pure returns (bytes)
    {
        uint256 oriLen = _oriBytes.length;
        uint256 tailLen = _tailBytes.length;
        bytes memory newData = new bytes(oriLen + tailLen);
        uint destPtr;
        uint srcPtr;
        assembly {
            destPtr := add(newData, 32)
            srcPtr := add(_oriBytes, 32)
        }
        memcpy(destPtr, srcPtr, oriLen);
        destPtr = destPtr + oriLen;
        assembly {
            srcPtr := add(_tailBytes, 32)
        }
        memcpy(destPtr, srcPtr, tailLen);
        return newData;
    }

    /**
     * @dev 基于当前的 tx pool 数据创建新区块
     * @return 序列化（ABI 编码）后的区块数据
     * @notice 
     */
    function createBlock() external onlySimulator returns (bytes) {
        // 计算前一个区块的哈希
        bytes32 preBlockHash;
        if (allBlocks.length == 0) {
            preBlockHash = keccak256(new bytes(0));
        } else {
            preBlockHash = keccak256(allBlocks[allBlocks.length - 1].btcBlockData);
        }
        // 生成区块体数据
        Transaction memory tx0 = initCoinbaseTx(tx0);
        emit LogTransactionData(tx0.inCounter, tx0.inputsData, tx0.outCounter, tx0.outputsData);
        bytes memory tx0Data = abi.encode(
            tx0.inCounter, tx0.inputsData, tx0.outCounter, tx0.outputsData
        );
        allTxes[keccak256(tx0Data)] = tx0;
        updateUtxoByTransaction(tx0);
        bytes32 mrkRoot;
        uint256 txCounter;
        bytes memory txesData;
        if (transactionPool.length == 0) {
            mrkRoot = keccak256(abi.encodePacked(keccak256(tx0Data), keccak256(tx0Data)));
            txesData = abi.encode(tx0Data);
            txCounter = 1;
        } else {
            Transaction memory tx1 = transactionPool[0];
            emit LogTransactionData(tx1.inCounter, tx1.inputsData, tx1.outCounter, tx1.outputsData);
            bytes memory tx1Data = abi.encode(
                tx1.inCounter, tx1.inputsData, tx1.outCounter, tx1.outputsData
            );
            allTxes[keccak256(tx1Data)] = tx1;
            updateUtxoByTransaction(tx1);
            mrkRoot = keccak256(abi.encodePacked(keccak256(tx0Data), keccak256(tx1Data)));
            txesData = abi.encode(tx0Data, tx1Data);
            txCounter = 2;
            delete transactionPool;
        }
        // 生成区块头数据
        BlockHeader memory header = BlockHeader({
            previousHash: preBlockHash,
            merkleRoot: mrkRoot,
            number: allBlocks.length,
            timeStamp: block.timestamp
        });
        emit LogBlockData(
            header.previousHash, header.merkleRoot, header.number, header.timeStamp
        );
        bytes memory headerData = abi.encode(
            header.previousHash, header.merkleRoot, header.number, header.timeStamp
        );
        bytes memory blockData = abi.encode(headerData, txCounter, txesData);
        // 生成区块数据
        BtcBlock memory newBlock = BtcBlock({btcBlockData: blockData});
        allBlocks.push(newBlock);
        return blockData;
    }

    /**
     * @dev 创建一个 Coinbase 交易
     * @param _cbTx Coinbase 交易内存变量
     * @return Coinbase 交易内存变量
     * @notice 
     */
    function initCoinbaseTx(Transaction memory _cbTx) internal view returns (Transaction) {
        // 设定 Coinbase 交易的 output
        Output memory out = Output({value: BLOCK_REWARD, scriptPubKey: owner});
        // 设定交易数据
        _cbTx.inCounter = 0;
        _cbTx.inputsData = new bytes(0);
        _cbTx.outCounter = 1;
        _cbTx.outputsData = abi.encode(out.value, out.scriptPubKey);
        return _cbTx;
    }

    /**
     * @dev 基于交易数据更新 UTXO 数据
     * @param _tx 给定的交易数据
     * @notice 
     */
    function updateUtxoByTransaction(Transaction memory _tx) internal {
        Input memory tmpInput;
        for (uint i = 0; i < _tx.inCounter; i++) {
            tmpInput = initTxInputFromBytes(tmpInput, _tx.inputsData, i);
            emit LogInputData(tmpInput.previousTxHash, tmpInput.index);
            removeOutputFromUtxo(tmpInput.previousTxHash, tmpInput.index);
        }
        bytes memory txData = abi.encode(
            _tx.inCounter, _tx.inputsData, _tx.outCounter, _tx.outputsData
        );
        bytes32 txHash = keccak256(txData);
        Output memory tmpOutput;
        bytes32 tmpKey;
        Utxo memory tmpUtxo;
        for (uint j = 0; j < _tx.outCounter; j++) {
            tmpOutput = initTxOutputFromBytes(tmpOutput, _tx.outputsData, j);
            emit LogOutputData(tmpOutput.value, tmpOutput.scriptPubKey);
            tmpKey = keccak256(abi.encodePacked(txHash, j));
            outputsIndexInUtxoArray[tmpKey] = allUtxos[tmpOutput.scriptPubKey].length;
            tmpUtxo = Utxo({
                txHash: txHash, index: j, value: tmpOutput.value, pubKey: tmpOutput.scriptPubKey
            });
            allUtxos[tmpOutput.scriptPubKey].push(tmpUtxo);
        }
    }

    /**
     * @dev 从 UTXO 数据中删除给定的 Output（即删除已在 Input 中使用的 Output）
     * @param _txHash 给定的交易哈希
     * @param _index 给定的 Ouput 索引
     * @notice 
     */
    function removeOutputFromUtxo(bytes32 _txHash, uint256 _index) internal {
        Transaction memory tarTx = allTxes[_txHash];
        Output memory tarOutput = initTxOutputFromBytes(tarOutput, tarTx.outputsData, _index);
        bytes32 tarKey = keccak256(abi.encodePacked(_txHash, _index));
        uint256 tarIndex = outputsIndexInUtxoArray[tarKey];
        Utxo[] storage addrUtxos = allUtxos[tarOutput.scriptPubKey];
        uint256 lastUtxoIndex = addrUtxos.length - 1;
        Utxo storage lastUtxo = addrUtxos[lastUtxoIndex];
        addrUtxos[tarIndex].txHash = lastUtxo.txHash;
        addrUtxos[tarIndex].index = lastUtxo.index;
        addrUtxos[tarIndex].value = lastUtxo.value;
        addrUtxos[tarIndex].pubKey = lastUtxo.pubKey;
        delete addrUtxos[lastUtxoIndex];
        addrUtxos.length--;
        outputsIndexInUtxoArray[tarKey] = 0;
    }

    /**
     * @dev 将序列化（ABI 编码）的交易数据反编码为交易数据
     * @param _txData 交易数据 struct
     * @param _txBytes 交易数据的序列化（ABI 编码）数据
     * @return 交易数据 struct
     * @notice 
     */
    function initTransactionFromBytes(
        Transaction memory _txData, bytes memory _txBytes
    ) 
        internal pure returns (Transaction)
    {
        uint256 inCounter;
        uint256 outCounter;
        uint256 dataLength;
        uint256 oriDataPtr;
        assembly {
            inCounter := mload(add(_txBytes, 32))
            outCounter := mload(add(add(_txBytes, 32), 64))
            let offset := mload(add(add(_txBytes, 32), 32))
            dataLength := mload(add(add(_txBytes, 32), offset))
            oriDataPtr := add(add(add(_txBytes, 32), offset), 32)
        }
        bytes memory inputsData = new bytes(dataLength);
        uint256 destDataPtr;
        assembly {
            destDataPtr := add(inputsData, 32)
        }
        memcpy(destDataPtr, oriDataPtr, dataLength);
        assembly {
            let offset := mload(add(add(_txBytes, 32), 96))
            dataLength := mload(add(add(_txBytes, 32), offset))
            oriDataPtr := add(add(add(_txBytes, 32), offset), 32)
        }
        bytes memory outputsData = new bytes(dataLength);
        assembly {
            destDataPtr := add(outputsData, 32)
        }
        memcpy(destDataPtr, oriDataPtr, dataLength);
        _txData.inCounter = inCounter;
        _txData.inputsData = inputsData;
        _txData.outCounter = outCounter;
        _txData.outputsData = outputsData;
        return _txData;
    }

    /**
     * @dev 从序列化（ABI 编码）的 inputs 数据中反编码出指定的 Input 数据
     * @param _inData Input 数据 struct
     * @param _inputsBytes 交易数据中的 inputsData 数据
     * @param _inputIndex 指定的 Input 数据索引
     * @return Input 数据 struct
     * @notice 
     */
    function initTxInputFromBytes(
        Input memory _inData, bytes memory _inputsBytes, uint256 _inputIndex
    ) 
        internal pure returns (Input)
    {
        bytes32 txHash;
        uint256 index;
        assembly {
            let offset := add(add(_inputsBytes, 32), mul(64, _inputIndex))
            txHash := mload(offset)
            index := mload(add(offset, 32))
        }
        _inData.previousTxHash = txHash;
        _inData.index = index;
        return _inData;
    }

    /**
     * @dev 从序列化（ABI 编码）的 outputs 数据中反编码出指定的 Output 数据
     * @param _outData Output 数据 struct
     * @param _outputsBytes 交易数据中的 outputsData 数据
     * @param _outputIndex 指定的 output 数据索引
     * @return Output 数据 struct
     * @notice 
     */
    function initTxOutputFromBytes(
        Output memory _outData, bytes memory _outputsBytes, uint256 _outputIndex
    ) 
        internal pure returns (Output)
    {
        uint256 outValue;
        address scriptPubKey;
        assembly {
            let offset := add(add(_outputsBytes, 32), mul(64, _outputIndex))
            outValue := mload(offset)
            scriptPubKey := mload(add(offset, 32))
        }
        _outData.value = outValue;
        _outData.scriptPubKey = scriptPubKey;
        return _outData;
    }

    /**
     * @dev 接收交易数据并将其加入自己的 tx pool
     * @param _txData 序列化（ABI 编码）后的交易数据
     * @notice 
     */
    function storeTransactionToPool(bytes _txData) external onlySimulator returns (bool) {
        Transaction memory curTx = initTransactionFromBytes(curTx, _txData);
        transactionPool.push(curTx);
    }

    /**
     * @dev 从序列化（ABI 编码）的区块数据中反编码出区块信息并保存到合约中
     * @param _blockData 序列化的区块数据
     * @notice 
     */
    function applyBlock(bytes _blockData) external onlySimulator {
        // 从 calldata 中将数据复制到内存中
        uint256 len = _blockData.length;
        bytes memory newBlockData = new bytes(len);
        uint i;
        for (i = 0; i < len; i++) {
            newBlockData[i] = _blockData[i];
        }
        // 从输入的字节数据恢复区块头数据
        BlockHeader memory newHeader = initBlockHeaderFromBlockData(
            newHeader, newBlockData
        );
        emit LogBlockData(
            newHeader.previousHash, newHeader.merkleRoot, newHeader.number, newHeader.timeStamp
        );
        // 恢复 txCounter 数据
        uint256 txCounter;
        assembly {
            txCounter := mload(add(newBlockData, 64))
        }
        // 恢复所有交易数据
        Transaction memory newTx;
        bytes memory newTxData;
        for (i = 0; i < txCounter; i++) {
            newTx = initTransactionFromBlockData(newTx, newBlockData, i);
            emit LogTransactionData(
                newTx.inCounter, newTx.inputsData, newTx.outCounter, newTx.outputsData
            );
            newTxData = abi.encode(
                newTx.inCounter, newTx.inputsData, newTx.outCounter, newTx.outputsData
            );
            allTxes[keccak256(newTxData)] = newTx;
            updateUtxoByTransaction(newTx);
        }
        // 保存区块数据
        BtcBlock memory newBlock = BtcBlock({btcBlockData: newBlockData});
        allBlocks.push(newBlock);
    }

    function initBlockHeaderFromBlockData(
        BlockHeader memory _header, bytes memory _blockData
    ) 
        internal pure returns (BlockHeader) 
    {
        assembly {
            let offset := mload(add(_blockData, 32))
            let pos := add(add(add(_blockData, 32), offset), 32)
            for {let i := 0} lt(i, 4) {i := add(i, 1)} {
                mstore(add(_header, mul(32, i)), mload(add(pos, mul(32, i))))
            }
        }
        return _header;
    }

    function initTransactionFromBlockData(
        Transaction memory _blockTx, bytes memory _blockData, uint256 _index
    ) 
        internal pure returns (Transaction) 
    {
        uint256 offset;
        uint256 txesDataPtr;
        uint256 dataLength;
        uint256 oriTxDataPtr;
        // 计算交易数据的开始位置和长度
        assembly {
            offset := mload(add(add(_blockData, 32), 64))
            txesDataPtr := add(add(add(_blockData, 32), offset), 32)
            offset := mload(add(txesDataPtr, mul(32, _index)))
            dataLength := mload(add(txesDataPtr, offset))
            oriTxDataPtr := add(add(txesDataPtr, offset), 32)
        }
        // 复制给定的交易数据到一个新的内存数组
        bytes memory txData = new bytes(dataLength);
        uint256 txDataPtr;
        assembly {
            txDataPtr := add(txData, 32)
        }
        memcpy(txDataPtr, oriTxDataPtr, dataLength);
        // 用序列化的交易数据初始化交易结构
        return initTransactionFromBytes(_blockTx, txData);
    }

}

interface NetworkSimulator {
    function registerMiner() external payable returns (bool);
    function unregisterMiner() external returns (bool);
    function broadcastTransaction(bytes) external;
}