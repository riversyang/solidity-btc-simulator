pragma solidity ^0.4.24;

import "./openzeppelin-solidity/contracts/AddressUtils.sol";
import "./openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./openzeppelin-solidity/contracts/introspection/SupportsInterfaceWithLookup.sol";

contract BitcoinNetworkSimulator {
    // 使用 AddressUtils
    using AddressUtils for address;
    // 对所有 uint256 类型使用 SafeMath
    using SafeMath for uint256;
    // 记录所有矿工地址的数组
    address[] private allMiners;
    // 矿工地址到其 Stake 数值的映射
    mapping (address => uint256) private minerStakes;
    // 矿工地址到其在 allMiners 数组中索引的映射
    mapping (address => uint256) private allMinersIndex;
    // 当前矿工地址
    address private curMiner;
    // 所有矿工账户的余额总和
    uint256 private totalStake;
    // 上一个区块创建的时间
    uint256 private timeStampOfLastBlock;

    constructor() public {
    }

    modifier onlyMiner() {
        require(minerStakes[msg.sender] > 0, "This function must be called by miner address.");
        _;
    }

    /**
     * @dev 矿工注册
     * @notice 
     */
    function registerMiner() external payable returns (bool) {
        // 注册的地址必须是合约
        require(msg.sender.isContract(), "Please register miner from a contract.");
        // 必须转入一定的 stake
        require(msg.value > 0, "Please deposit some ethers before registering as a miner.");
        // 检查目标合约是否实现了必要的矿工合约函数
        SupportsInterfaceWithLookup siwl = SupportsInterfaceWithLookup(msg.sender);
        require(
            siwl.supportsInterface(bytes4(keccak256("storeTransactionToPool(bytes)"))),
            "Your contract doesn't have necessary functions."
        );
        require(
            siwl.supportsInterface(bytes4(keccak256("createBlock()"))),
            "Your contract doesn't have necessary functions."
        );
        require(
            siwl.supportsInterface(bytes4(keccak256("applyBlock(bytes)"))),
            "Your contract doesn't have necessary functions."
        );

        if (allMiners.length == 0 || 
            allMinersIndex[msg.sender] == 0 && 
            msg.sender != allMiners[0]) 
        {
            allMinersIndex[msg.sender] = allMiners.length;
            allMiners.push(msg.sender);
            totalStake += msg.value;
            minerStakes[msg.sender] = msg.value;
            if (allMiners.length == 1) {
                curMiner = allMiners[0];
            }
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev 矿工退出
     * @notice 
     */
    function unregisterMiner() external onlyMiner returns (bool) {
        // 至少需要保留一个矿工
        require(allMiners.length > 1, "The simulator needs at least one miner to work.");

        uint256 minerIndex = allMinersIndex[msg.sender];
        if (minerIndex > 0 || msg.sender == allMiners[0]) {
            uint256 lastMinerIndex = allMiners.length.sub(1);
            address lastMiner = allMiners[lastMinerIndex];
            allMiners[minerIndex] = lastMiner;
            delete allMiners[lastMinerIndex];
            allMiners.length--;
            allMinersIndex[msg.sender] = 0;
            totalStake -= minerStakes[msg.sender];
            minerStakes[msg.sender] = 0;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev 基于简化的 PoS 算法选出下一个矿工地址
     * @notice 
     */
    function selectNewMiner() private {
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp))) % totalStake;
        uint256 tmpSum;
        address curAddress;
        uint minersCount = allMiners.length;
        for (uint i = 0; i < minersCount; i++) {
            curAddress = allMiners[i];
            tmpSum = tmpSum.add(minerStakes[curAddress]);
            if (tmpSum > rand) {
                curMiner = curAddress;
                break;
            }
        }
    }

    /**
     * @dev 基于简化的 PoS 算法选出一个矿工并生成一个新区块
     * @notice 
     */
    function generateNewBlock() external {
        // 需要网络中至少有一个矿工
        require(allMiners.length > 0, "Need at least one miner to generate block.");
        // 某一个区块时间内只能创建一个新区块
        require(block.timestamp - timeStampOfLastBlock > 0, "Cannot create more block in one blocktime.");
        // 选择当前记账矿工
        selectNewMiner();
        // 由当前矿工创建区块
        bytes memory blockData = BitcoinMinerBase(curMiner).createBlock();
        // 将区块数据同步到所有其他矿工
        for (uint256 i = 0; i < allMiners.length; i++) {
            if (allMiners[i] != curMiner) {
                BitcoinMinerBase(allMiners[i]).applyBlock(blockData);
            }
        }
        // 保存区块生成时间
        timeStampOfLastBlock = block.timestamp;
    }

    /**
     * @dev 某个矿工生成新的 tx 之后调用此函数将 tx 广播到网络中的所有矿工节点
     * @param _txData 序列化（ABI 编码）后的交易数据
     * @notice 
     */
    function broadcastTransaction(bytes _txData) external onlyMiner {
        // 将交易数据同步到所有其他矿工
        for (uint256 i = 0; i < allMiners.length; i++) {
            if (allMiners[i] != msg.sender) {
                BitcoinMinerBase(allMiners[i]).storeTransactionToPool(_txData);
            }
        }
    }

}

interface BitcoinMinerBase {
    function storeTransactionToPool(bytes) external;
    function createBlock() external returns (bytes);
    function applyBlock(bytes) external;
}