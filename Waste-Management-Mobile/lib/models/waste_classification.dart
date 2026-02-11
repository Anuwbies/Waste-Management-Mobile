import 'pagination.dart';

/// Top-K prediction entry from backend AI service
class TopKEntry {
  final String label;
  final String canonicalLabel;
  final double score;

  TopKEntry({
    required this.label,
    required this.canonicalLabel,
    required this.score,
  });

  factory TopKEntry.fromJson(Map<String, dynamic> json) {
    return TopKEntry(
      label: json['label'] as String? ?? '',
      canonicalLabel: json['canonicalLabel'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'canonicalLabel': canonicalLabel,
    'score': score,
  };
}

/// Waste classification model (matches backend POST /waste/upload response)
class WasteClassification {
  final String id;
  final String imageUrl;
  final String wasteType;
  final double confidence;
  final int rewardPoints;
  final String? rawLabel;
  final String? modelVersion;
  final String? status; // "approved" | "denied"
  final List<TopKEntry>? topK;
  final DateTime? createdAt;

  WasteClassification({
    required this.id,
    required this.imageUrl,
    required this.wasteType,
    this.confidence = 0.0,
    this.rewardPoints = 0,
    this.rawLabel,
    this.modelVersion,
    this.status,
    this.topK,
    this.createdAt,
  });

  factory WasteClassification.fromJson(Map<String, dynamic> json) {
    return WasteClassification(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      wasteType: json['wasteType'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      rawLabel: json['rawLabel'] as String?,
      modelVersion: json['modelVersion'] as String?,
      status: json['status'] as String?,
      topK: (json['topK'] as List<dynamic>?)
          ?.map((e) => TopKEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'wasteType': wasteType,
      'confidence': confidence,
      'rewardPoints': rewardPoints,
      'rawLabel': rawLabel,
      'modelVersion': modelVersion,
      'status': status,
      'topK': topK?.map((e) => e.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

/// Classification preview (without storage)
class ClassificationPreview {
  final String wasteType;
  final double confidence;
  final int potentialRewardPoints;

  ClassificationPreview({
    required this.wasteType,
    this.confidence = 0.0,
    this.potentialRewardPoints = 0,
  });

  factory ClassificationPreview.fromJson(Map<String, dynamic> json) {
    return ClassificationPreview(
      wasteType: json['wasteType'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      potentialRewardPoints: (json['potentialRewardPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Paginated classification history
class ClassificationHistory {
  final List<WasteClassification> classifications;
  final Pagination pagination;

  ClassificationHistory({
    required this.classifications,
    required this.pagination,
  });

  factory ClassificationHistory.fromJson(Map<String, dynamic> json) {
    return ClassificationHistory(
      classifications: (json['classifications'] as List<dynamic>?)
          ?.map((e) => WasteClassification.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
