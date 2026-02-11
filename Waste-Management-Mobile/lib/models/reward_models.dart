import 'pagination.dart';

/// On-chain statistics from blockchain
class ChainStats {
  final int balance;
  final int totalEarned;
  final int totalRedeemed;
  final int recordCount;

  ChainStats({
    this.balance = 0,
    this.totalEarned = 0,
    this.totalRedeemed = 0,
    this.recordCount = 0,
  });

  factory ChainStats.fromJson(Map<String, dynamic> json) {
    return ChainStats(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
      totalRedeemed: (json['totalRedeemed'] as num?)?.toInt() ?? 0,
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'totalEarned': totalEarned,
    'totalRedeemed': totalRedeemed,
    'recordCount': recordCount,
  };
}

/// Reward balance response
/// Backend returns: { balance, chainStats: { balance, totalEarned, totalRedeemed, recordCount }, walletAddress }
class RewardBalance {
  final int balance;
  final ChainStats chainStats;
  final String? walletAddress;

  /// Backward-compat shorthand for chainStats.balance
  int get chainRewards => chainStats.balance;

  RewardBalance({
    this.balance = 0,
    ChainStats? chainStats,
    this.walletAddress,
  }) : chainStats = chainStats ?? ChainStats();

  factory RewardBalance.fromJson(Map<String, dynamic> json) {
    return RewardBalance(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      chainStats: json['chainStats'] is Map<String, dynamic>
          ? ChainStats.fromJson(json['chainStats'] as Map<String, dynamic>)
          : ChainStats(
              balance: (json['chainRewards'] as num?)?.toInt() ?? 0,
            ),
      walletAddress: json['walletAddress'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'chainStats': chainStats.toJson(),
    'walletAddress': walletAddress,
  };
}

/// Redeemable reward option from GET /rewards/options
class RewardOption {
  final String id;
  final String name;
  final int pointsCost;
  final String description;
  final bool canAfford;

  RewardOption({
    required this.id,
    required this.name,
    required this.pointsCost,
    this.description = '',
    this.canAfford = false,
  });

  factory RewardOption.fromJson(Map<String, dynamic> json) {
    return RewardOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      canAfford: json['canAfford'] as bool? ?? false,
    );
  }
}

/// Response from GET /rewards/options
class RewardOptionsResponse {
  final int currentBalance;
  final List<RewardOption> options;

  RewardOptionsResponse({
    this.currentBalance = 0,
    this.options = const [],
  });

  factory RewardOptionsResponse.fromJson(Map<String, dynamic> json) {
    return RewardOptionsResponse(
      currentBalance: (json['currentBalance'] as num?)?.toInt() ?? 0,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => RewardOption.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Response from POST /rewards/redeem
class RedemptionResponse {
  final String message;
  final String id;
  final String redemptionId;
  final String rewardType;
  final String rewardName;
  final int pointsRedeemed;
  final String? txHash;
  final String status;
  final int newBalance;

  RedemptionResponse({
    this.message = '',
    this.id = '',
    this.redemptionId = '',
    this.rewardType = '',
    this.rewardName = '',
    this.pointsRedeemed = 0,
    this.txHash,
    this.status = '',
    this.newBalance = 0,
  });

  factory RedemptionResponse.fromJson(Map<String, dynamic> json) {
    final redemption = json['redemption'] as Map<String, dynamic>? ?? {};
    return RedemptionResponse(
      message: json['message'] as String? ?? '',
      id: redemption['id'] as String? ?? redemption['_id'] as String? ?? '',
      redemptionId: redemption['redemptionId'] as String? ?? '',
      rewardType: redemption['rewardType'] as String? ?? '',
      rewardName: redemption['rewardName'] as String? ?? '',
      pointsRedeemed: (redemption['pointsRedeemed'] as num?)?.toInt() ?? 0,
      txHash: redemption['txHash'] as String?,
      status: redemption['status'] as String? ?? '',
      newBalance: (json['newBalance'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Reward history item
class RewardHistoryItem {
  final String id;
  final String type;
  final int points;
  final String description;
  final String? txHash;
  final DateTime? createdAt;

  RewardHistoryItem({
    required this.id,
    required this.type,
    this.points = 0,
    this.description = '',
    this.txHash,
    this.createdAt,
  });

  factory RewardHistoryItem.fromJson(Map<String, dynamic> json) {
    return RewardHistoryItem(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      txHash: json['txHash'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'points': points,
      'description': description,
      'txHash': txHash,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

/// Paginated reward history
class RewardHistoryResponse {
  final List<RewardHistoryItem> history;
  final Pagination pagination;

  RewardHistoryResponse({
    required this.history,
    required this.pagination,
  });

  factory RewardHistoryResponse.fromJson(Map<String, dynamic> json) {
    return RewardHistoryResponse(
      history: (json['history'] as List<dynamic>?)
          ?.map((e) => RewardHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Reward statistics
class RewardStats {
  final int totalRewards;
  final Map<String, TypeStats> statsByType;

  RewardStats({
    this.totalRewards = 0,
    this.statsByType = const {},
  });

  factory RewardStats.fromJson(Map<String, dynamic> json) {
    final statsMap = <String, TypeStats>{};
    final rawStats = json['statsByType'] as Map<String, dynamic>?;
    if (rawStats != null) {
      rawStats.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          statsMap[key] = TypeStats.fromJson(value);
        }
      });
    }

    return RewardStats(
      totalRewards: (json['totalRewards'] as num?)?.toInt() ?? 0,
      statsByType: statsMap,
    );
  }
}

/// Stats per reward type
class TypeStats {
  final int totalPoints;
  final int count;

  TypeStats({
    this.totalPoints = 0,
    this.count = 0,
  });

  factory TypeStats.fromJson(Map<String, dynamic> json) {
    return TypeStats(
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
