pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/math/SafeMath.sol";

contract BitcoinChainData {
    // 使用 SafeMath
    using SafeMath for uint256;
    // Input 数据
    struct Input {
        bytes32 previousTxHash;
        uint256 index;
    }
    // Output 数据
    struct Output {
        uint256 value;
        address scriptPubKey;
    }
    // 交易数据
    struct Transaction {
        uint256 inCounter;
        // 所有 Input 数据经序列化后的字节数组
        bytes inputsData;
        uint256 outCounter;
        // 所有 Output 数据经序列化后的字节数组
        bytes outputsData;
    }
    // 区块头数据
    struct BlockHeader {
        bytes32 previousHash;
        bytes32 merkleRoot;
        uint256 number;
        uint256 timeStamp;
    }
    // 区块数据
    struct BtcBlock {
        bytes btcBlockData;
    }
    // Chain data
    BtcBlock[] internal allBlocks;
    // txHash => 交易数据
    mapping(bytes32 => Transaction) internal allTxes;
}