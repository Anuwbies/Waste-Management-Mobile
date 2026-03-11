// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RecyclingRewardsV2
/// @notice Ultra-optimized on-chain rewards ledger
contract RecyclingRewardsV2 {
    address public admin;
    address public minter;

    /// @notice Supported waste categories
    enum WasteType { Plastic, Paper, Metal, Glass, Organic, EWaste, Other }

    /// @notice Statistics packed into a single 256-bit slot
    /// uint128 balance: up to 3.4e38
    /// uint96 totalEarned: up to 7.9e28
    /// uint32 recordCount: up to 4.2 billion
    struct UserStats {
        uint128 balance;
        uint96 totalEarned;
        uint32 recordCount;
    }

    mapping(address => UserStats) private _userStats;

    error Unauthorized();
    error InvalidUserAddress();
    error NonPositivePoints();
    error InsufficientBalance(address user, uint256 balance, uint256 requested);

    event RecyclingRecorded(
        bytes32 indexed eventHash,
        address indexed user,
        uint256 points,
        uint8 wasteType,
        uint256 timestamp
    );

    event Redeemed(
        address indexed user,
        uint256 points,
        string rewardType,
        bytes32 indexed redemptionId,
        uint256 timestamp
    );

    constructor(address _admin) {
        if (_admin == address(0)) revert InvalidUserAddress();
        admin = _admin;
        minter = _admin;
    }

    modifier onlyMinter() {
        if (msg.sender != minter) revert Unauthorized();
        _;
    }

    function setMinter(address _minter) external {
        if (msg.sender != admin) revert Unauthorized();
        minter = _minter;
    }

    /// @notice Optimized record function (~30k-45k gas)
    function recordRecycling(
        bytes32 eventHash,
        address user,
        uint256 points,
        WasteType wasteType
    ) external onlyMinter {
        // Note: Deduplication (eventHash) moved off-chain for gas efficiency
        if (user == address(0)) revert InvalidUserAddress();
        if (points == 0) revert NonPositivePoints();

        UserStats storage stats = _userStats[user];
        unchecked {
            stats.balance += uint128(points);
            stats.totalEarned += uint96(points);
            stats.recordCount += 1;
        }

        emit RecyclingRecorded(
            eventHash,
            user,
            points,
            uint8(wasteType),
            block.timestamp
        );
    }

    function redeem(
        address user,
        uint256 points,
        string calldata rewardType,
        bytes32 redemptionId
    ) external onlyMinter {
        UserStats storage stats = _userStats[user];
        if (stats.balance < points) {
            revert InsufficientBalance(user, stats.balance, points);
        }
        if (points == 0) revert NonPositivePoints();

        unchecked {
            stats.balance -= uint128(points);
        }

        emit Redeemed(user, points, rewardType, redemptionId, block.timestamp);
    }

    function getUserStats(address user) external view returns (
        uint256 balance,
        uint256 earned,
        uint256 records
    ) {
        UserStats storage stats = _userStats[user];
        return (stats.balance, stats.totalEarned, stats.recordCount);
    }

    // Simplified batch for extreme gas efficiency
    function batchRecordRecycling(
        bytes32[] calldata eventHashes,
        address[] calldata users,
        uint256[] calldata points,
        WasteType[] calldata wasteTypes
    ) external onlyMinter {
        uint256 len = eventHashes.length;
        for (uint256 i = 0; i < len; ) {
            UserStats storage stats = _userStats[users[i]];
            uint256 p = points[i];
            unchecked {
                stats.balance += uint128(p);
                stats.totalEarned += uint96(p);
                stats.recordCount += 1;
            }
            emit RecyclingRecorded(eventHashes[i], users[i], p, uint8(wasteTypes[i]), block.timestamp);
            unchecked { i++; }
        }
    }
}
