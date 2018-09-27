pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./openzeppelin-solidity/contracts/introspection/SupportsInterfaceWithLookup.sol";
import "./BitcoinChainData.sol";

contract BitcoinMiner is SupportsInterfaceWithLookup, BitcoinChainData, Ownable {
    // 客户端交易数据
    struct ClientTx {
        address from;
        address to;
        uint256 value;
    }
    // 给矿工的区块奖励
    uint256 public constant BLOCK_REWARD = 100000000;
    // txHash => 交易数据
    mapping(bytes32 => Transaction) internal allTxs;
    // 账户地址 => 其所有可用 Output 数组
    mapping(address => Output[]) internal allOutputs;
    // 交易池
    ClientTx[] internal clientTxPool;
    // 是否正在记账
    bool internal isCurrentMiner;
    // 网络模拟器
    address internal networkSimulator;

    event LogBlockReceived(
        bytes32 _previousHash,
        bytes32 _merkleRoot,
        uint256 _number,
        uint256 _timeStamp
    );

    event LogTransactionData(
        bytes32 indexed _txHash,
        address indexed _from,
        uint256 _nonce,
        uint256 _gasLimit,
        uint256 _gasPrice,
        address _to,
        uint256 _value,
        bytes _data
    );

    event LogMyData(bytes _data, uint256 _length);

    /**
     * @dev 创建矿工合约，需要以太坊协议模拟器合约已创建
     * @notice 创建时需要存入一定量的资金
     */
    constructor() public payable {
        require(msg.value > 0, "You need to transfer value for miner contract.");
        // 注册所有必要的接口
        _registerInterface(bytes4(keccak256("applyTransaction(bytes)")));
        _registerInterface(bytes4(keccak256("createBlock()")));
        _registerInterface(bytes4(keccak256("applyBlock(bytes)")));
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

    }

    /**
     * @dev 获取指定地址的 UTXO 总额
     * @param _addr 指定的地址
     * @return 指定地址的 UTXO 总额
     */
    function getBalance(address _addr) external returns (uint256) {

    }

    /**
     * @dev 接收交易数据并将其加入自己的 tx pool
     * @param _txData 序列化（ABI 编码）后的交易数据
     * @notice 
     */
    function applyTransaction(bytes _txData) external onlySimulator returns (bool) {
        // 需要创世区块创建之后才能开始处理交易
        require(chainData.blocks.length > 0, "Need to create genesis block first.");
        // 交易的 gasLimit 需要小于区块的 gasLimit
        require(_gasLimit <= BLOCK_GAS_LIMIT, "Transaction gas limit reached.");
        // 交易的实际 gas 消耗需要小于交易自己指定的 gasLimit
        require(_data.length <= _gasLimit, "Too many transaction data.");
        // 交易发送者账户的余额需要大于交易实际要消耗的 gas * gasPrice
        require(uint256(_data.length).mul(_gasPrice) <= getBalance(_from), "Balance not enough.");

        if (gasUsed + _data.length > BLOCK_GAS_LIMIT) {
            return false;
        } else {
            uint256 _nonce = addNonce(_from);
            Transaction memory transaction = Transaction({
                from: _from, nonce: _nonce, gasLimit: _gasLimit, gasPrice: _gasPrice, to: _to,
                value: _value, data: _data
            });
            transactionsPool.push(transaction);
            gasUsed += _data.length;
            return true;
        }
    }

    function emitLogTransaction(bytes32 _txHash) internal {
        uint256 txIndex = chainData.transactions[_txHash];
        require(txIndex > 0);
        Transaction storage curTx = chainData.blocks[txIndex].txData;
        emit LogTransactionData(_txHash, curTx.from, curTx.nonce, curTx.gasLimit, curTx.gasPrice, curTx.to, curTx.value, curTx.data);
    }

    /**
     * @dev 基于当前的 tx pool 数据创建新区块
     * @return 序列化（ABI 编码）后的区块数据
     * @notice 
     */
    function createBlock() external onlySimulator returns (bytes) {
        // 执行交易池中的所有交易
        require(transactionsPool.length > 0, "Need to add transaction before finalize block.");
        // 创建区块数据
        Transaction memory transaction = Transaction({
            from: transactionsPool[0].from,
            nonce: transactionsPool[0].nonce,
            gasLimit: transactionsPool[0].gasLimit,
            gasPrice: transactionsPool[0].gasPrice,
            to: transactionsPool[0].to,
            value: transactionsPool[0].value,
            data: transactionsPool[0].data
        });
        BlockHeader memory bHeader = initBlockHeader(bHeader, transaction.data.length);
        Block memory newBlock = Block({header: bHeader, txData: transaction});
        chainData.blocks.push(newBlock);
        // 更改 from 和 to 的余额
        addBalance(transaction.to, transaction.value);
        subBalance(transaction.from, transaction.value);
         // 产生区块日志
        // emit LogBlockReceived(
        //     bHeader.parentHash, 
        //     bHeader.beneficiary, 
        //     bHeader.stateRoot,
        //     bHeader.transactionsRoot,
        //     bHeader.difficulty,
        //     bHeader.number,
        //     bHeader.gasLimit,
        //     bHeader.gasUsed,
        //     bHeader.timeStamp,
        //     bHeader.extraData
        // );
        // 产生日志
        bytes32 txHash = getLatestTransactionHash();
        chainData.transactions[txHash] = chainData.blocks.length - 1;
        emitLogTransaction(txHash);
        // 清除交易池
        delete transactionsPool;
        // 修改合约状态
        isCurrentMiner = false;
        // 生成区块数据的字节数组
        bytes memory headerBytes = abi.encode(
            bHeader.parentHash,
            bHeader.beneficiary,
            bHeader.stateRoot,
            bHeader.transactionsRoot,
            bHeader.difficulty,
            bHeader.number,
            bHeader.gasLimit,
            bHeader.gasUsed,
            bHeader.timeStamp,
            bHeader.extraData
        );
        bytes memory txBytes = abi.encode(
            transaction.from,
            transaction.nonce,
            transaction.gasLimit,
            transaction.gasPrice,
            transaction.to,
            transaction.value,
            transaction.data
        );
        bytes memory blockData = abi.encode(headerBytes, txBytes);
        return blockData;
    }

    function createCoinbaseTx(Transaction memory _tx) internal returns (Transaction) {
        addBalance(owner, BLOCK_REWARD);
    }

    function initBlockHeader(BlockHeader memory _bHeader, uint256 _gasUsed)
        internal view returns (BlockHeader)
    {
        _bHeader.parentHash = getLatestBlockHash();
        _bHeader.beneficiary = owner;
        _bHeader.stateRoot = 0x0;
        _bHeader.transactionsRoot = 0x0;
        _bHeader.difficulty = getDifficulty();
        _bHeader.number = chainData.blocks.length;
        _bHeader.gasLimit = BLOCK_GAS_LIMIT;
        _bHeader.gasUsed = _gasUsed;
        _bHeader.timeStamp = block.timestamp;
        _bHeader.extraData = bytes32("Mined by simple miner.");
        return _bHeader;
    }

    function applyBlock(bytes _blockData) external onlySimulator {
        uint256 len = _blockData.length;
        bytes memory data = new bytes(len);
        for (uint i = 0; i < len; i++) {
            data[i] = _blockData[i];
        }

        // 从输入的字节数据恢复区块头数据
        BlockHeader memory bHeader = initBlockHeaderFromBlockData(bHeader, data);
        // 发放区块奖励
        addBalance(bHeader.beneficiary, BLOCK_REWARD);
        // 从输入的字节数据恢复交易数据
        Transaction memory bTx = initTransactionFromBlockData(bTx, data);
        // 更改 from 和 to 的余额
        addBalance(bTx.to, bTx.value);
        subBalance(bTx.from, bTx.value);
        // 创建并记录区块数据
        Block memory newBlock = Block({header: bHeader, txData: bTx});
        chainData.blocks.push(newBlock);
        // 产生区块日志
        // emit LogBlockReceived(
        //     bHeader.parentHash, 
        //     bHeader.beneficiary, 
        //     bHeader.stateRoot,
        //     bHeader.transactionsRoot,
        //     bHeader.difficulty,
        //     bHeader.number,
        //     bHeader.gasLimit,
        //     bHeader.gasUsed,
        //     bHeader.timeStamp,
        //     bHeader.extraData
        // );
        // 产生交易日志
        bytes32 txHash = getLatestTransactionHash();
        chainData.transactions[txHash] = chainData.blocks.length - 1;
        // emitLogTransaction(txHash);
    }

    function initBlockHeaderFromBlockData(
        BlockHeader memory _blockHeader, bytes memory _blockData
    ) 
        internal returns (BlockHeader) 
    {
        // emit LogMyData(_blockData, _blockData.length);
        assembly {
            let offset := mload(add(32, _blockData))
            let pos := add(add(add(32, _blockData), offset), 32)
            for {let i := 0} lt(i, 10) {i := add(i, 1)} {
                mstore(add(_blockHeader, mul(32, i)), mload(add(pos, mul(32, i))))
            }
        }
        return _blockHeader;
    }

    function initTransactionFromBlockData(
        Transaction memory _blockTx, bytes memory _blockData
    ) 
        internal returns (Transaction) 
    {
        uint256 dataLength;
        uint256 offset;
        uint256 transactionStartPtr;

        // emit LogMyData(_blockData, _blockData.length);
        assembly {
            offset := mload(add(add(32 ,_blockData), 32))
            let pos := add(add(add(32, _blockData), offset), 32)
            transactionStartPtr := pos
            for {let i := 0} lt(i, 6) {i := add(i, 1)} {
                mstore(add(_blockTx, mul(32, i)), mload(add(pos, mul(32, i))))
            }
            pos := add(pos, mul(32, 6))
            offset := mload(pos)
            dataLength := mload(add(transactionStartPtr, offset))
        }

        bytes memory tx_data = new bytes(dataLength);

        assembly {
            let tail := mod(dataLength, 32)
            let wordLen := div(dataLength, 32)
            let inTxDataOffset := add(add(transactionStartPtr, offset), 32)
            let outTxDataOffset := add(tx_data, 32)
            let i := 0
            for {} lt(i, wordLen) {i := add(i, 1)} {
                mstore(add(outTxDataOffset, mul(32, i)), mload(add(inTxDataOffset, mul(32, i))))
            }
            if gt(tail, 0) {
                mstore(add(outTxDataOffset, mul(32, i)), mload(add(inTxDataOffset, mul(32, i))))
            }
        }

        _blockTx.data = tx_data;
        return _blockTx;
    }

}

interface NetworkSimulator {
    function registerMiner() external payable returns (bool);
    function unregisterMiner() external returns (bool);
}