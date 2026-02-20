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

/// Reward balance response.
///
/// Backend now returns the **on-chain balance** as the top-level `balance`
/// field.  `chainStats` is kept for backward-compat.  The `source` field
/// indicates whether the value came from `"chain"` or `"cache"` (Mongo
/// fallback when the chain is unreachable).
class RewardBalance {
  /// Authoritative balance (from chain when available).
  final int balance;

  /// Full on-chain stats (mirrors top-level fields for backward-compat).
  final ChainStats chainStats;

  /// Wallet address (null until first recycling event).
  final String? walletAddress;

  /// Whether the balance came from chain or Mongo cache.
  final String source;

  /// Total points ever earned (on-chain).
  final int totalEarned;

  /// Total points ever redeemed (on-chain).
  final int totalRedeemed;

  /// Total recycling records (on-chain).
  final int recordCount;

  /// Optional integrity warning when Mongo cache differs from chain.
  final String? integrityWarning;

  /// Backward-compat shorthand for chainStats.balance
  int get chainRewards => chainStats.balance;

  RewardBalance({
    this.balance = 0,
    ChainStats? chainStats,
    this.walletAddress,
    this.source = 'cache',
    this.totalEarned = 0,
    this.totalRedeemed = 0,
    this.recordCount = 0,
    this.integrityWarning,
  }) : chainStats = chainStats ?? ChainStats();

  factory RewardBalance.fromJson(Map<String, dynamic> json) {
    final cs = json['chainStats'] is Map<String, dynamic>
        ? ChainStats.fromJson(json['chainStats'] as Map<String, dynamic>)
        : ChainStats(
            balance: (json['balance'] as num?)?.toInt() ?? 0,
            totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
            totalRedeemed: (json['totalRedeemed'] as num?)?.toInt() ?? 0,
            recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
          );

    return RewardBalance(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      chainStats: cs,
      walletAddress: json['walletAddress'] as String?,
      source: json['source'] as String? ?? 'cache',
      totalEarned: (json['totalEarned'] as num?)?.toInt() ?? cs.totalEarned,
      totalRedeemed: (json['totalRedeemed'] as num?)?.toInt() ?? cs.totalRedeemed,
      recordCount: (json['recordCount'] as num?)?.toInt() ?? cs.recordCount,
      integrityWarning: json['integrityWarning'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'chainStats': chainStats.toJson(),
    'walletAddress': walletAddress,
    'source': source,
    'totalEarned': totalEarned,
    'totalRedeemed': totalRedeemed,
    'recordCount': recordCount,
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

/// Reward statistics (chain-authoritative totals + Mongo breakdowns)
class RewardStats {
  /// Authoritative balance from chain.
  final int totalRewards;

  /// Total ever earned (on-chain).
  final int totalEarned;

  /// Total ever redeemed (on-chain).
  final int totalRedeemed;

  /// Number of on-chain recycling records.
  final int recordCount;

  /// `"chain"` or `"cache"`.
  final String source;

  /// Per-type breakdown from off-chain history.
  final Map<String, TypeStats> statsByType;

  RewardStats({
    this.totalRewards = 0,
    this.totalEarned = 0,
    this.totalRedeemed = 0,
    this.recordCount = 0,
    this.source = 'cache',
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
      totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
      totalRedeemed: (json['totalRedeemed'] as num?)?.toInt() ?? 0,
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'cache',
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
