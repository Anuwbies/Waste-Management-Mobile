import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/waste_classification.dart';
import '../models/scan_session.dart';
import '../config/api_config.dart';
import 'api_client.dart';
import 'cnn_classifier.dart';

/// Service for waste classification and image uploads
class WasteService {
  // Singleton pattern
  static final WasteService _instance = WasteService._internal();
  factory WasteService() => _instance;
  WasteService._internal();

  final ApiClient _api = ApiClient();
  final CnnClassifier _cnnClassifier = CnnClassifier.instance;

  /// Initialize the on-device CNN classifier
  /// Call this early (e.g., in main.dart) for faster first inference
  Future<void> initializeClassifier() async {
    try {
      await _cnnClassifier.initialize();
      debugPrint('[WasteService] CNN Classifier initialized');
    } catch (e) {
      debugPrint('[WasteService] Failed to initialize CNN Classifier: $e');
    }
  }

  /// Check if on-device classifier is ready
  bool get isClassifierReady => _cnnClassifier.isReady;

  /// ============================================================
  /// ON-DEVICE CLASSIFICATION (PRIMARY METHOD)
  /// ============================================================

  /// Classify image locally using on-device TFLite model
  /// Returns CnnClassification for the scan pipeline
  /// This is the PRIMARY method for classification - no network required!
  Future<CnnClassification> classifyLocal(File imageFile) async {
    debugPrint('[WasteService] Running local classification...');
    
    try {
      // Run on-device inference
      final result = await _cnnClassifier.classify(imageFile);

      debugPrint('[WasteService] Local classification result:');
      debugPrint('  Label: ${result.label}');
      debugPrint('  Confidence: ${result.confidencePercent}');

      // Convert to CnnClassification for pipeline
      final potentialPoints = ApiConfig.wasteRewardPoints[result.label.toLowerCase()] ?? 0;

      return CnnClassification(
        label: result.label,
        confidence: result.confidence,
        topK: result.topK
            .map((p) => ClassificationPrediction(
                  label: p.label,
                  confidence: p.confidence,
                ))
            .toList(),
        potentialPoints: potentialPoints,
      );
    } catch (e) {
      debugPrint('[WasteService] Local classification failed: $e');
      throw ApiException('On-device classification failed: $e');
    }
  }

  /// Log a local classification to the backend for tracking/analytics
  /// Call this after successful local classification if online
  Future<void> logClassificationToBackend({
    required String label,
    required double confidence,
    required List<ClassPrediction> topK,
    String? localEventId,
  }) async {
    try {
      await _api.post(
        '/waste/classifications',
        body: {
          'label': label,
          'confidence': confidence,
          'topK': topK.map((p) => p.toJson()).toList(),
          'localEventId': localEventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'deviceTime': DateTime.now().toIso8601String(),
          'source': 'on-device',
        },
      );
      debugPrint('[WasteService] Classification logged to backend');
    } catch (e) {
      // Non-critical - don't fail if logging fails
      debugPrint('[WasteService] Failed to log classification to backend: $e');
    }
  }

  /// ============================================================
  /// REMOTE CLASSIFICATION (FALLBACK)
  /// ============================================================

  /// Upload and classify waste image (REMOTE)
  /// Returns classification result with reward points
  Future<WasteClassificationResult> uploadAndClassify(File imageFile) async {
    try {
      final response = await _api.uploadFile(
        '/waste/upload',
        file: imageFile,
        fieldName: 'image',
      );

      return WasteClassificationResult.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to upload and classify image');
    }
  }

  /// Classify image for the scan pipeline
  /// STRATEGY: Local first, remote fallback
  /// - Tries on-device TFLite inference first (fast, offline)
  /// - Falls back to remote API if local fails
  Future<CnnClassification> classifyForPipeline(File imageFile, {bool forceRemote = false}) async {
    // Try local classification first (unless forced remote)
    if (!forceRemote && _cnnClassifier.isReady) {
      try {
        debugPrint('[WasteService] Attempting local classification...');
        return await classifyLocal(imageFile);
      } catch (e) {
        debugPrint('[WasteService] Local classification failed, falling back to remote: $e');
      }
    } else if (!forceRemote) {
      // Try to initialize classifier if not ready
      try {
        await initializeClassifier();
        if (_cnnClassifier.isReady) {
          return await classifyLocal(imageFile);
        }
      } catch (e) {
        debugPrint('[WasteService] Could not initialize local classifier: $e');
      }
    }

    // Fallback to remote classification
    debugPrint('[WasteService] Using remote classification...');
    return await _classifyRemote(imageFile);
  }

  /// Remote classification via API (preview mode — /waste/classify)
  Future<CnnClassification> _classifyRemote(File imageFile) async {
    try {
      final response = await _api.uploadFile(
        ApiConfig.wasteClassify,
        file: imageFile,
        fieldName: 'image',
      );

      // Parse top-K predictions
      List<ClassificationPrediction> topK = [];
      if (response['topK'] != null) {
        topK = (response['topK'] as List)
            .map((p) => ClassificationPrediction.fromJson(p as Map<String, dynamic>))
            .toList();
      }

      // Backend returns wasteType (canonical), not label
      final label = response['wasteType'] as String? ?? 'unknown';
      final confidence = (response['confidence'] as num?)?.toDouble() ?? 0.0;
      final potentialPoints = (response['potentialRewardPoints'] as num?)?.toInt() ?? 0;

      debugPrint('[WasteService] Remote classify: $label ($confidence) status=${response['status']}');

      return CnnClassification(
        label: label,
        confidence: confidence,
        topK: topK.isEmpty
            ? [ClassificationPrediction(label: label, confidence: confidence)]
            : topK,
        potentialPoints: potentialPoints,
        status: response['status'] as String?,
        rawLabel: response['rawLabel'] as String?,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to classify image remotely');
    }
  }

  /// Get disposal suggestions from LLM backend
  /// Falls back to default suggestions if API fails
  Future<DisposalSuggestion> getDisposalSuggestion(
    String wasteLabel, {
    double? confidence,
    String? additionalContext,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.wasteSuggestion,
        body: {
          'wasteType': wasteLabel,
          'confidence': confidence,
          'context': additionalContext,
        },
      );

      return DisposalSuggestion.fromJson(response);
    } on ApiException {
      // Fallback to default suggestions on API error
      debugPrint('LLM suggestion API failed, using defaults');
      return DisposalSuggestion.getDefault(wasteLabel);
    } catch (e) {
      // Fallback to default suggestions on any error
      debugPrint('Error getting suggestion: $e, using defaults');
      return DisposalSuggestion.getDefault(wasteLabel);
    }
  }

  /// Classify waste image without storing (preview mode)
  Future<ClassificationPreview> classifyPreview(File imageFile) async {
    try {
      final response = await _api.uploadFile(
        '/waste/classify',
        file: imageFile,
        fieldName: 'image',
      );

      return ClassificationPreview.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to classify image');
    }
  }

  /// Upload image from bytes (for camera capture)
  Future<WasteClassificationResult> uploadAndClassifyBytes(
    Uint8List imageBytes,
    String filename,
  ) async {
    try {
      final response = await _api.uploadFileBytes(
        '/waste/upload',
        bytes: imageBytes,
        filename: filename,
        fieldName: 'image',
      );

      return WasteClassificationResult.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to upload and classify image');
    }
  }

  /// Get classification history
  Future<ClassificationHistory> getHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _api.get(
        '/waste/history',
        queryParams: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      return ClassificationHistory.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load classification history');
    }
  }

  /// Get single classification by ID
  Future<WasteClassification> getClassification(String id) async {
    try {
      final response = await _api.get('/waste/$id');

      if (response['classification'] != null) {
        return WasteClassification.fromJson(
          response['classification'] as Map<String, dynamic>,
        );
      }

      throw ApiException('Classification not found');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load classification');
    }
  }

  /// Get full URL for waste images
  String getImageUrl(String relativePath) {
    return _api.getFileUrl(relativePath);
  }
}

/// Result of waste classification upload
class WasteClassificationResult {
  final String message;
  final WasteClassification classification;
  final int totalRewards;

  WasteClassificationResult({
    required this.message,
    required this.classification,
    required this.totalRewards,
  });

  factory WasteClassificationResult.fromJson(Map<String, dynamic> json) {
    return WasteClassificationResult(
      message: json['message'] as String? ?? '',
      classification: WasteClassification.fromJson(
        json['classification'] as Map<String, dynamic>? ?? {},
      ),
      totalRewards: (json['totalRewards'] as num?)?.toInt() ?? 0,
    );
  }
}
