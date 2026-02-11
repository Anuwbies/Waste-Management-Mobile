// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title RecyclingRewardsV2
/// @notice On-chain rewards ledger with deduplication, role-based minting, and redemption
/// @dev Uses AccessControl for MINTER_ROLE to restrict who can credit/debit points
contract RecyclingRewardsV2 is AccessControl {
    /// @notice Role identifier for accounts that can record recycling and process redemptions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Supported waste categories
    enum WasteType {
        Plastic,
        Paper,
        Metal,
        Glass,
        Organic,
        EWaste,
        Other
    }

    /// @notice Current balance of reward points per user
    mapping(address => uint256) public balanceOf;

    /// @notice Tracks event hashes that have already been rewarded (deduplication)
    mapping(bytes32 => bool) public usedEventHashes;

    /// @notice Total points ever earned by a user
    mapping(address => uint256) public totalEarned;

    /// @notice Total points ever redeemed by a user
    mapping(address => uint256) public totalRedeemed;

    /// @notice Total number of recycling records per user
    mapping(address => uint256) public recordCount;

    /// @notice Global statistics
    uint256 public totalRecyclingEvents;
    uint256 public totalPointsMinted;
    uint256 public totalPointsBurned;

    /// @notice Emitted when a recycling event is recorded
    event RecyclingRecorded(
        bytes32 indexed eventHash,
        address indexed user,
        uint256 points,
        uint8 wasteType,
        uint256 timestamp
    );

    /// @notice Emitted when points are redeemed
    event Redeemed(
        address indexed user,
        uint256 points,
        string rewardType,
        bytes32 indexed redemptionId,
        uint256 timestamp
    );

    /// @notice Emitted when a merkle root is anchored for audit trail
    event MerkleRootAnchored(
        bytes32 indexed merkleRoot,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256 recordCount,
        uint256 timestamp
    );

    /// @notice Emitted when points are transferred between users (optional future use)
    event PointsTransferred(
        address indexed from,
        address indexed to,
        uint256 points,
        uint256 timestamp
    );

    /// @param admin The address that will receive DEFAULT_ADMIN_ROLE and MINTER_ROLE
    constructor(address admin) {
        require(admin != address(0), "Admin cannot be zero address");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    /// @notice Record a recycling event and credit points to user
    /// @param eventHash Unique hash identifying this recycling event (prevents double-claiming)
    /// @param user The wallet address to credit points to
    /// @param points Number of reward points to credit
    /// @param wasteType The type of waste recycled (enum value)
    /// @dev Only callable by accounts with MINTER_ROLE
    function recordRecycling(
        bytes32 eventHash,
        address user,
        uint256 points,
        WasteType wasteType
    ) external onlyRole(MINTER_ROLE) {
        require(!usedEventHashes[eventHash], "Event already rewarded");
        require(user != address(0), "Invalid user address");
        require(points > 0, "Points must be positive");

        usedEventHashes[eventHash] = true;
        balanceOf[user] += points;
        totalEarned[user] += points;
        recordCount[user] += 1;
        totalRecyclingEvents += 1;
        totalPointsMinted += points;

        emit RecyclingRecorded(
            eventHash,
            user,
            points,
            uint8(wasteType),
            block.timestamp
        );
    }

    /// @notice Redeem (burn) points for a reward
    /// @param user The wallet address to debit points from
    /// @param points Number of points to burn
    /// @param rewardType Description of what the points are being redeemed for
    /// @param redemptionId Unique identifier for this redemption transaction
    /// @dev Only callable by accounts with MINTER_ROLE
    function redeem(
        address user,
        uint256 points,
        string calldata rewardType,
        bytes32 redemptionId
    ) external onlyRole(MINTER_ROLE) {
        require(balanceOf[user] >= points, "Insufficient balance");
        require(points > 0, "Points must be positive");

        balanceOf[user] -= points;
        totalRedeemed[user] += points;
        totalPointsBurned += points;

        emit Redeemed(user, points, rewardType, redemptionId, block.timestamp);
    }

    /// @notice Anchor a merkle root for off-chain audit trail
    /// @param merkleRoot The root hash of the merkle tree containing event data
    /// @param fromTimestamp Start of the time range covered
    /// @param toTimestamp End of the time range covered
    /// @param _recordCount Number of records included in this anchor
    /// @dev Only callable by accounts with MINTER_ROLE
    function anchorMerkleRoot(
        bytes32 merkleRoot,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256 _recordCount
    ) external onlyRole(MINTER_ROLE) {
        require(merkleRoot != bytes32(0), "Invalid merkle root");
        require(toTimestamp >= fromTimestamp, "Invalid time range");

        emit MerkleRootAnchored(
            merkleRoot,
            fromTimestamp,
            toTimestamp,
            _recordCount,
            block.timestamp
        );
    }

    /// @notice Batch record multiple recycling events in one transaction (gas efficient)
    /// @param eventHashes Array of unique event hashes
    /// @param users Array of user addresses to credit
    /// @param points Array of points to credit
    /// @param wasteTypes Array of waste types
    /// @dev Only callable by accounts with MINTER_ROLE. Skips invalid/duplicate entries.
    function batchRecordRecycling(
        bytes32[] calldata eventHashes,
        address[] calldata users,
        uint256[] calldata points,
        WasteType[] calldata wasteTypes
    ) external onlyRole(MINTER_ROLE) {
        require(
            eventHashes.length == users.length &&
                users.length == points.length &&
                points.length == wasteTypes.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < eventHashes.length; i++) {
            // Skip invalid entries instead of reverting entire batch
            if (
                usedEventHashes[eventHashes[i]] ||
                users[i] == address(0) ||
                points[i] == 0
            ) {
                continue;
            }

            usedEventHashes[eventHashes[i]] = true;
            balanceOf[users[i]] += points[i];
            totalEarned[users[i]] += points[i];
            recordCount[users[i]] += 1;
            totalRecyclingEvents += 1;
            totalPointsMinted += points[i];

            emit RecyclingRecorded(
                eventHashes[i],
                users[i],
                points[i],
                uint8(wasteTypes[i]),
                block.timestamp
            );
        }
    }

    /// @notice Check if an event hash has already been used
    /// @param eventHash The event hash to check
    /// @return True if the event has already been rewarded
    function isEventUsed(bytes32 eventHash) external view returns (bool) {
        return usedEventHashes[eventHash];
    }

    /// @notice Get user statistics
    /// @param user The user address to query
    /// @return balance Current point balance
    /// @return earned Total points ever earned
    /// @return redeemed Total points ever redeemed
    /// @return records Total number of recycling records
    function getUserStats(
        address user
    )
        external
        view
        returns (
            uint256 balance,
            uint256 earned,
            uint256 redeemed,
            uint256 records
        )
    {
        return (
            balanceOf[user],
            totalEarned[user],
            totalRedeemed[user],
            recordCount[user]
        );
    }

    /// @notice Get global statistics
    /// @return events Total recycling events recorded
    /// @return minted Total points ever minted
    /// @return burned Total points ever burned (redeemed)
    function getGlobalStats()
        external
        view
        returns (uint256 events, uint256 minted, uint256 burned)
    {
        return (totalRecyclingEvents, totalPointsMinted, totalPointsBurned);
    }
}
