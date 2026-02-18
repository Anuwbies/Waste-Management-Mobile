import 'pagination.dart';

/// Recycling log model
class RecyclingLog {
  final String id;
  final String wasteType;
  final int quantity;
  final int rewardPoints;
  final String? txHash;
  final String? status; // pending | confirmed | failed | duplicate
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RecyclingLog({
    required this.id,
    required this.wasteType,
    this.quantity = 1,
    this.rewardPoints = 0,
    this.txHash,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory RecyclingLog.fromJson(Map<String, dynamic> json) {
    return RecyclingLog(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      wasteType: json['wasteType'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      txHash: json['txHash'] as String?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wasteType': wasteType,
      'quantity': quantity,
      'rewardPoints': rewardPoints,
      'txHash': txHash,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

/// Recycling response from API
class RecyclingResponse {
  final String message;
  final RecyclingLog log;
  final int totalRewards;

  RecyclingResponse({
    required this.message,
    required this.log,
    required this.totalRewards,
  });

  factory RecyclingResponse.fromJson(Map<String, dynamic> json) {
    return RecyclingResponse(
      message: json['message'] as String? ?? '',
      log: RecyclingLog.fromJson(json['log'] as Map<String, dynamic>? ?? {}),
      totalRewards: (json['totalRewards'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Paginated recycling logs
class RecyclingLogsResponse {
  final List<RecyclingLog> logs;
  final Pagination pagination;

  RecyclingLogsResponse({
    required this.logs,
    required this.pagination,
  });

  factory RecyclingLogsResponse.fromJson(Map<String, dynamic> json) {
    return RecyclingLogsResponse(
      logs: (json['logs'] as List<dynamic>?)
          ?.map((e) => RecyclingLog.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
