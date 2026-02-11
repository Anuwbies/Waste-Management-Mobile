// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title RecyclingRewards
/// @notice Users can record recycling actions and earn reward points on-chain.
contract RecyclingRewards {
  /// @notice Supported waste categories.
  enum WasteType {
    Plastic,
    Paper,
    Metal,
    Glass,
    Organic,
    EWaste
  }

  /// @notice A single recycling action recorded by a user.
  struct RecyclingRecord {
    WasteType wasteType;
    uint256 rewardPoints;
    uint256 timestamp;
  }

  /// @notice Per-user recycling history.
  mapping(address => RecyclingRecord[]) private recordsByUser;

  /// @notice Total reward points per user.
  mapping(address => uint256) public totalRewards;

  /// @notice Emitted when a user records a recycling action.
  event Recycled(
    address indexed user,
    WasteType wasteType,
    uint256 rewardPoints,
    uint256 timestamp
  );

  /// @notice Record a recycling action for the caller.
  /// @param wasteType The type of waste recycled.
  function recordRecycling(WasteType wasteType) external {
    uint256 rewardPoints = _rewardForWaste(wasteType);
    RecyclingRecord memory record = RecyclingRecord({
      wasteType: wasteType,
      rewardPoints: rewardPoints,
      timestamp: block.timestamp
    });

    recordsByUser[msg.sender].push(record);
    totalRewards[msg.sender] += rewardPoints;

    emit Recycled(msg.sender, wasteType, rewardPoints, block.timestamp);
  }

  /// @notice Returns the caller's recycling history.
  function getMyRecords() external view returns (RecyclingRecord[] memory) {
    return recordsByUser[msg.sender];
  }

  /// @dev Internal reward logic based on waste type.
  function _rewardForWaste(WasteType wasteType) internal pure returns (uint256) {
    if (wasteType == WasteType.Plastic) return 10;
    if (wasteType == WasteType.Paper) return 8;
    if (wasteType == WasteType.Metal) return 15;
    if (wasteType == WasteType.Glass) return 12;
    if (wasteType == WasteType.Organic) return 5;
    if (wasteType == WasteType.EWaste) return 20;

    return 0;
  }
}
