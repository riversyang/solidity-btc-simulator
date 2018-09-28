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
    // struct Block {
    //     BlockHeader header;
    //     Transaction[] txList;
    // }
    // 上述区块数据 struct 无法在内存中进行初始化，故将其拆分为两个 mapping 直接作为 ChainData 的成员
    // 区块链数据
    struct ChainData {
        // 区块计数器
        uint256 blockCounter;
        // 区块号 => 区块头数据
        mapping(uint256 => BlockHeader) blockHeaders;
        // 区块号 => 交易index => InputCounter
        mapping(uint256 => mapping(uint256 => uint256)) blockInputCounters;
        // 区块号 => 交易index => Input数组
        mapping(uint256 => mapping(uint256 => Input[])) blockInputs;
        // 区块号 => 交易index => OutputCounter
        mapping(uint256 => mapping(uint256 => uint256)) blockOutputCounters;
        // 区块号 => 交易index => Output数组
        mapping(uint256 => mapping(uint256 => Output[])) blockOutputs;
    }

    // Chain data
    ChainData internal chainData;

}