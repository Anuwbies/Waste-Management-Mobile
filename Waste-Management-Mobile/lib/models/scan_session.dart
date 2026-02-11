import 'dart:io';

/// Scan session model to hold state across the scan pipeline
/// 
/// Flow: Camera → CnnResult → LlmSuggestion → RewardDecision
class ScanSession {
  /// Image file from camera/gallery
  final File imageFile;

  /// CNN classification result
  CnnClassification? classification;

  /// LLM disposal suggestion
  DisposalSuggestion? suggestion;

  /// Reward decision from backend
  RewardDecision? decision;

  /// Session creation timestamp
  final DateTime createdAt;

  ScanSession({
    required this.imageFile,
    this.classification,
    this.suggestion,
    this.decision,
  }) : createdAt = DateTime.now();

  /// Create a copy with updated classification
  ScanSession copyWithClassification(CnnClassification classification) {
    return ScanSession(
      imageFile: imageFile,
      classification: classification,
      suggestion: suggestion,
      decision: decision,
    );
  }

  /// Create a copy with updated suggestion
  ScanSession copyWithSuggestion(DisposalSuggestion suggestion) {
    return ScanSession(
      imageFile: imageFile,
      classification: classification,
      suggestion: suggestion,
      decision: decision,
    );
  }

  /// Create a copy with updated decision
  ScanSession copyWithDecision(RewardDecision decision) {
    return ScanSession(
      imageFile: imageFile,
      classification: classification,
      suggestion: suggestion,
      decision: decision,
    );
  }

  /// Check if session is ready for reward submission
  bool get canSubmitForReward =>
      classification != null && 
      classification!.meetsConfidenceThreshold;
}

/// CNN classification result
class CnnClassification {
  /// Predicted waste label (plastic, paper, metal, glass, organic, e-waste)
  final String label;

  /// Confidence score (0.0 - 1.0)
  final double confidence;

  /// Top-K predictions (optional)
  final List<ClassificationPrediction>? topK;

  /// Image ID from backend (if uploaded)
  final String? imageId;

  /// Image URL from backend
  final String? imageUrl;

  /// Timestamp of classification
  final DateTime timestamp;

  /// Potential reward points
  final int potentialPoints;

  /// Backend classification status ("approved" | "denied")
  final String? status;

  /// Raw model label before canonical mapping
  final String? rawLabel;

  CnnClassification({
    required this.label,
    required this.confidence,
    this.topK,
    this.imageId,
    this.imageUrl,
    this.potentialPoints = 0,
    this.status,
    this.rawLabel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Check if confidence meets threshold for reward (default 0.80)
  bool get meetsConfidenceThreshold => confidence >= 0.80;

  /// Get formatted confidence percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get normalized label for display
  String get displayLabel => label.replaceAll(RegExp(r'[-_]'), ' ').toUpperCase();

  factory CnnClassification.fromJson(Map<String, dynamic> json) {
    return CnnClassification(
      label: json['wasteType'] as String? ?? json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      topK: (json['topK'] as List<dynamic>?)
          ?.map((e) => ClassificationPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageId: json['imageId'] as String? ?? json['id'] as String?,
      imageUrl: json['imageUrl'] as String?,
      potentialPoints: (json['potentialRewardPoints'] as num?)?.toInt() ?? 
                       (json['rewardPoints'] as num?)?.toInt() ?? 0,
      status: json['status'] as String?,
      rawLabel: json['rawLabel'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'topK': topK?.map((e) => e.toJson()).toList(),
      'imageId': imageId,
      'imageUrl': imageUrl,
      'potentialPoints': potentialPoints,
      'status': status,
      'rawLabel': rawLabel,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Single prediction in top-K results
class ClassificationPrediction {
  final String label;
  final double confidence;

  ClassificationPrediction({
    required this.label,
    required this.confidence,
  });

  factory ClassificationPrediction.fromJson(Map<String, dynamic> json) {
    return ClassificationPrediction(
      label: json['canonicalLabel'] as String? ?? json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ??
                  (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
    };
  }
}

/// LLM-generated disposal suggestion
class DisposalSuggestion {
  /// Recommended bin color/type
  final String binType;

  /// Disposal steps
  final List<String> steps;

  /// Important warnings or notes
  final List<String> warnings;

  /// Eco tips
  final List<String> tips;

  /// Location-specific rules (if available)
  final String? localRules;

  /// Whether item can be recycled
  final bool isRecyclable;

  /// Environmental impact message
  final String? impactMessage;

  DisposalSuggestion({
    required this.binType,
    this.steps = const [],
    this.warnings = const [],
    this.tips = const [],
    this.localRules,
    this.isRecyclable = true,
    this.impactMessage,
  });

  factory DisposalSuggestion.fromJson(Map<String, dynamic> json) {
    return DisposalSuggestion(
      binType: json['binType'] as String? ?? json['bin'] as String? ?? 'Unknown',
      steps: (json['steps'] as List<dynamic>?)?.cast<String>() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      tips: (json['tips'] as List<dynamic>?)?.cast<String>() ?? [],
      localRules: json['localRules'] as String?,
      isRecyclable: json['isRecyclable'] as bool? ?? true,
      impactMessage: json['impactMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'binType': binType,
      'steps': steps,
      'warnings': warnings,
      'tips': tips,
      'localRules': localRules,
      'isRecyclable': isRecyclable,
      'impactMessage': impactMessage,
    };
  }

  /// Generate a default suggestion for a waste type (fallback when API unavailable)
  static DisposalSuggestion getDefault(String wasteType) {
    switch (wasteType.toLowerCase()) {
      case 'plastic':
        return DisposalSuggestion(
          binType: 'Blue Recycling Bin',
          steps: [
            'Remove any food residue',
            'Rinse the container if possible',
            'Remove caps and lids (recycle separately)',
            'Flatten bottles to save space',
            'Place in blue recycling bin',
          ],
          warnings: [
            'No plastic bags in recycling bin',
            'Styrofoam is not recyclable',
          ],
          tips: [
            'Check the recycling symbol (♻️) for plastic type',
            'Types 1 (PET) and 2 (HDPE) are most recyclable',
          ],
          isRecyclable: true,
          impactMessage: 'Recycling one plastic bottle saves enough energy to power a lightbulb for 3 hours!',
        );
      case 'paper':
      case 'cardboard':
        return DisposalSuggestion(
          binType: 'Blue Recycling Bin',
          steps: [
            'Remove any plastic wrapping or tape',
            'Flatten cardboard boxes',
            'Keep paper dry and clean',
            'Place in paper recycling bin',
          ],
          warnings: [
            'No wet or greasy paper (like pizza boxes)',
            'No wax-coated paper',
          ],
          tips: [
            'Paper can be recycled 5-7 times',
            'Shredded paper should go in a paper bag',
          ],
          isRecyclable: true,
          impactMessage: 'Recycling paper saves 17 trees per ton!',
        );
      case 'metal':
      case 'aluminum':
        return DisposalSuggestion(
          binType: 'Blue Recycling Bin',
          steps: [
            'Empty and rinse cans',
            'Remove paper labels if possible',
            'Crush cans to save space',
            'Place in metal recycling bin',
          ],
          warnings: [
            'No aerosol cans unless empty',
            'No paint cans (hazardous waste)',
          ],
          tips: [
            'Aluminum can be recycled infinitely',
            'Recycling aluminum uses 95% less energy than new production',
          ],
          isRecyclable: true,
          impactMessage: 'Recycling one aluminum can saves enough energy to run a TV for 3 hours!',
        );
      case 'glass':
        return DisposalSuggestion(
          binType: 'Green Glass Bin',
          steps: [
            'Empty and rinse containers',
            'Remove metal caps and lids',
            'Do not break the glass',
            'Sort by color if required locally',
            'Place in glass recycling bin',
          ],
          warnings: [
            'No window glass or mirrors',
            'No ceramics or pottery',
            'No light bulbs',
          ],
          tips: [
            'Glass can be recycled endlessly without quality loss',
            'Clear glass is most valuable for recycling',
          ],
          isRecyclable: true,
          impactMessage: 'Glass bottles can be recycled and back on shelves in 30 days!',
        );
      case 'organic':
      case 'food':
      case 'compost':
        return DisposalSuggestion(
          binType: 'Green Compost Bin',
          steps: [
            'Separate from packaging',
            'Remove stickers from fruit',
            'Place in compost bin or food waste container',
            'Consider home composting',
          ],
          warnings: [
            'No meat or dairy in home compost (municipal only)',
            'No plastic "biodegradable" bags unless certified',
          ],
          tips: [
            'Compost enriches soil naturally',
            'Reduces methane emissions from landfills',
          ],
          isRecyclable: false,
          impactMessage: 'Composting food waste reduces greenhouse gas emissions by up to 50%!',
        );
      case 'ewaste':
      case 'e-waste':
      case 'electronic':
      case 'electronics':
        return DisposalSuggestion(
          binType: 'E-Waste Collection Point',
          steps: [
            'Remove batteries if possible',
            'Wipe personal data from devices',
            'Keep cords and accessories together',
            'Take to authorized e-waste collection center',
          ],
          warnings: [
            'Never put in regular trash (hazardous)',
            'Never burn electronics',
            'Keep lithium batteries separate',
          ],
          tips: [
            'Many retailers offer e-waste take-back programs',
            'Working devices can be donated',
          ],
          isRecyclable: true,
          impactMessage: 'E-waste contains valuable metals like gold, silver, and copper!',
        );
      default:
        return DisposalSuggestion(
          binType: 'General Waste Bin',
          steps: [
            'Check if item can be recycled',
            'If unsure, place in general waste',
            'Consider if item can be donated or reused',
          ],
          warnings: [
            'When in doubt, throw it out (to avoid contamination)',
          ],
          tips: [
            'Contact local waste management for specific guidelines',
          ],
          isRecyclable: false,
        );
    }
  }
}

/// Reward decision status
enum RewardStatus {
  approved,
  denied,
  pending,
}

/// Reward decision from backend
class RewardDecision {
  /// Decision status
  final RewardStatus status;

  /// Points earned (if approved)
  final int points;

  /// Reason for decision
  final String? reason;

  /// Transaction hash (if recorded on blockchain)
  final String? txHash;

  /// Event ID for tracking
  final String? eventId;

  /// Event hash for deduplication
  final String? eventHash;

  /// User's new total balance
  final int? newBalance;

  /// Wallet address used
  final String? walletAddress;

  RewardDecision({
    required this.status,
    this.points = 0,
    this.reason,
    this.txHash,
    this.eventId,
    this.eventHash,
    this.newBalance,
    this.walletAddress,
  });

  /// Is the reward approved?
  bool get isApproved => status == RewardStatus.approved;

  /// Is the reward denied?
  bool get isDenied => status == RewardStatus.denied;

  /// Is the reward pending review?
  bool get isPending => status == RewardStatus.pending;

  /// Get display status text
  String get statusText {
    switch (status) {
      case RewardStatus.approved:
        return 'APPROVED';
      case RewardStatus.denied:
        return 'DENIED';
      case RewardStatus.pending:
        return 'PENDING';
    }
  }

  factory RewardDecision.fromJson(Map<String, dynamic> json) {
    RewardStatus status;
    final statusStr = (json['status'] as String?)?.toLowerCase() ?? 
                      (json['log']?['status'] as String?)?.toLowerCase() ?? 'pending';
    
    switch (statusStr) {
      case 'approved':
      case 'confirmed':
        status = RewardStatus.approved;
        break;
      case 'denied':
      case 'failed':
      case 'rejected':
        status = RewardStatus.denied;
        break;
      default:
        status = RewardStatus.pending;
    }

    return RewardDecision(
      status: status,
      points: (json['log']?['rewardPoints'] as num?)?.toInt() ??
              (json['rewardPoints'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? json['message'] as String?,
      txHash: json['log']?['txHash'] as String? ?? json['txHash'] as String?,
      eventId: json['log']?['eventId'] as String? ?? json['eventId'] as String?,
      eventHash: json['log']?['eventHash'] as String? ?? json['eventHash'] as String?,
      newBalance: (json['totalRewards'] as num?)?.toInt(),
      walletAddress: json['wallet'] as String?,
    );
  }

  /// Create an approved decision
  factory RewardDecision.approved({
    required int points,
    String? txHash,
    String? eventId,
    int? newBalance,
  }) {
    return RewardDecision(
      status: RewardStatus.approved,
      points: points,
      reason: 'Recycling recorded successfully!',
      txHash: txHash,
      eventId: eventId,
      newBalance: newBalance,
    );
  }

  /// Create a denied decision
  factory RewardDecision.denied(String reason) {
    return RewardDecision(
      status: RewardStatus.denied,
      reason: reason,
    );
  }

  /// Create a pending decision
  factory RewardDecision.pending([String? reason]) {
    return RewardDecision(
      status: RewardStatus.pending,
      reason: reason ?? 'Your submission is under review.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'points': points,
      'reason': reason,
      'txHash': txHash,
      'eventId': eventId,
      'eventHash': eventHash,
      'newBalance': newBalance,
      'walletAddress': walletAddress,
    };
  }
}
