import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// ============================================================
/// CNN Classifier for On-Device Waste Classification
/// ============================================================
/// 
/// Model: EfficientNetB2 (TFLite)
/// Input: 260x260x3 RGB float32
/// Output: 9 classes with softmax probabilities
/// 
/// Preprocessing (from test_model.py):
/// - Resize to 260x260
/// - Convert to float32 [0, 1] by dividing by 255
/// - Normalize with ImageNet mean/std (torch mode):
///   mean = [0.485, 0.456, 0.406]
///   std  = [0.229, 0.224, 0.225]
/// 
/// Classes (from model training):
/// 0: E-waste
/// 1: Automobile
/// 2: Battery
/// 3: Glass
/// 4: Light Bulb
/// 5: Metal
/// 6: Organic
/// 7: Paper
/// 8: Plastic
/// ============================================================

/// Result of CNN classification
class CnnClassificationResult {
  /// Primary predicted label
  final String label;
  
  /// Confidence score (0.0 - 1.0)
  final double confidence;
  
  /// Top-K predictions with scores
  final List<ClassPrediction> topK;
  
  /// Raw output scores (all 9 classes)
  final List<double> rawScores;
  
  /// Index of predicted class
  final int classIndex;
  
  /// Timestamp of classification
  final DateTime timestamp;

  CnnClassificationResult({
    required this.label,
    required this.confidence,
    required this.topK,
    required this.rawScores,
    required this.classIndex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Check if confidence meets threshold for reward eligibility
  bool meetsThreshold(double threshold) => confidence >= threshold;

  /// Get formatted confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
    'label': label,
    'confidence': confidence,
    'classIndex': classIndex,
    'topK': topK.map((p) => p.toJson()).toList(),
    'rawScores': rawScores,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Single class prediction
class ClassPrediction {
  final String label;
  final double confidence;
  final int index;

  ClassPrediction({
    required this.label,
    required this.confidence,
    required this.index,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'confidence': confidence,
    'index': index,
  };
}

/// CNN Classifier Service - Singleton for on-device inference
class CnnClassifier {
  // Singleton pattern
  static CnnClassifier? _instance;
  static CnnClassifier get instance => _instance ??= CnnClassifier._();
  
  CnnClassifier._();

  // TFLite interpreter
  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Model configuration (from test_model.py)
  static const String _modelAssetPath = 'lib/assets/Models/final_model.tflite';
  static const int _inputWidth = 260;
  static const int _inputHeight = 260;
  static const int _inputChannels = 3;

  // ImageNet normalization constants (EfficientNet torch mode)
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  // Class labels (from test_model.py)
  static const List<String> _modelClassLabels = [
    'E-waste',
    'Automobile',
    'Battery',
    'Glass',
    'Light Bulb',
    'Metal',
    'Organic',
    'Paper',
    'Plastic',
  ];

  // Mapping from model classes to app's standard waste types
  static const Map<String, String> _labelMapping = {
    'E-waste': 'e-waste',
    'Automobile': 'metal',      // Automobile parts → metal
    'Battery': 'e-waste',       // Batteries → e-waste (hazardous)
    'Glass': 'glass',
    'Light Bulb': 'e-waste',    // Light bulbs → e-waste (hazardous)
    'Metal': 'metal',
    'Organic': 'organic',
    'Paper': 'paper',
    'Plastic': 'plastic',
  };

  /// Check if classifier is ready
  bool get isReady => _isInitialized && _interpreter != null;

  /// Initialize the TFLite interpreter
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      debugPrint('[CnnClassifier] Loading model from: $_modelAssetPath');
      
      // Load model from assets
      _interpreter = await Interpreter.fromAsset(_modelAssetPath);
      
      // Log model details
      _logModelDetails();
      
      // Warmup inference
      await _warmup();
      
      _isInitialized = true;
      debugPrint('[CnnClassifier] Model loaded successfully');
    } catch (e, stack) {
      debugPrint('[CnnClassifier] Failed to load model: $e');
      debugPrint('[CnnClassifier] Stack: $stack');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Log model input/output tensor details
  void _logModelDetails() {
    if (_interpreter == null) return;

    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    debugPrint('[CnnClassifier] === Model IO Summary ===');
    debugPrint('[CnnClassifier] Input shape: ${inputTensor.shape}');
    debugPrint('[CnnClassifier] Input dtype: ${inputTensor.type}');
    debugPrint('[CnnClassifier] Output shape: ${outputTensor.shape}');
    debugPrint('[CnnClassifier] Output dtype: ${outputTensor.type}');
    debugPrint('[CnnClassifier] ========================');
  }

  /// Warmup inference with dummy data
  Future<void> _warmup() async {
    if (_interpreter == null) return;

    debugPrint('[CnnClassifier] Running warmup inference...');
    
    // Create dummy input
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputHeight,
        (_) => List.generate(
          _inputWidth,
          (_) => List.filled(_inputChannels, 0.0),
        ),
      ),
    );

    // Create output buffer
    final output = List.generate(1, (_) => List.filled(_modelClassLabels.length, 0.0));

    // Run inference
    _interpreter!.run(input, output);
    
    debugPrint('[CnnClassifier] Warmup complete');
  }

  /// Classify an image file
  /// Returns CnnClassificationResult with label, confidence, and top-K predictions
  Future<CnnClassificationResult> classify(File imageFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null) {
      throw Exception('CNN Classifier not initialized');
    }

    debugPrint('[CnnClassifier] Classifying: ${imageFile.path}');

    // Read and decode image
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Preprocess image
    final input = _preprocessImage(image);

    // Run inference
    final rawScores = await _runInference(input);

    // Process results
    return _processResults(rawScores);
  }

  /// Classify from image bytes
  Future<CnnClassificationResult> classifyBytes(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null) {
      throw Exception('CNN Classifier not initialized');
    }

    // Decode image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image bytes');
    }

    // Preprocess image
    final input = _preprocessImage(image);

    // Run inference
    final rawScores = await _runInference(input);

    // Process results
    return _processResults(rawScores);
  }

  /// Preprocess image for model input
  /// Matches test_model.py preprocessing exactly
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    debugPrint('[CnnClassifier] Original image size: ${image.width}x${image.height}');

    // Resize to model input size
    final resized = img.copyResize(
      image,
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.linear,
    );

    debugPrint('[CnnClassifier] Resized to: ${_inputWidth}x$_inputHeight');

    // Create input tensor [1, 260, 260, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputHeight,
        (y) => List.generate(
          _inputWidth,
          (x) {
            final pixel = resized.getPixel(x, y);
            
            // Get RGB values (0-255)
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();

            // EfficientNet preprocessing (torch mode):
            // 1. Scale to [0, 1]
            // 2. Normalize with ImageNet mean/std
            return [
              ((r / 255.0) - _mean[0]) / _std[0],  // R channel
              ((g / 255.0) - _mean[1]) / _std[1],  // G channel
              ((b / 255.0) - _mean[2]) / _std[2],  // B channel
            ];
          },
        ),
      ),
    );

    // Debug: print tensor stats
    _logTensorStats(input);

    return input;
  }

  /// Log tensor statistics for debugging
  void _logTensorStats(List<List<List<List<double>>>> input) {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sum = 0;
    int count = 0;

    for (final batch in input) {
      for (final row in batch) {
        for (final col in row) {
          for (final val in col) {
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
            sum += val;
            count++;
          }
        }
      }
    }

    debugPrint('[CnnClassifier] Tensor stats - min: ${minVal.toStringAsFixed(3)}, '
        'max: ${maxVal.toStringAsFixed(3)}, mean: ${(sum / count).toStringAsFixed(3)}');
  }

  /// Run inference on preprocessed input
  Future<List<double>> _runInference(List<List<List<List<double>>>> input) async {
    // Create output buffer [1, 9]
    final output = List.generate(
      1,
      (_) => List.filled(_modelClassLabels.length, 0.0),
    );

    // Run inference
    _interpreter!.run(input, output);

    // Get raw scores
    final rawScores = output[0];

    debugPrint('[CnnClassifier] Raw output scores:');
    for (int i = 0; i < rawScores.length; i++) {
      debugPrint('  ${_modelClassLabels[i]}: ${rawScores[i].toStringAsFixed(4)}');
    }

    return rawScores;
  }

  /// Process raw scores into classification result
  CnnClassificationResult _processResults(List<double> rawScores) {
    // Find top-K predictions
    final indexed = rawScores.asMap().entries.toList();
    indexed.sort((a, b) => b.value.compareTo(a.value));

    // Get top prediction
    final topIndex = indexed[0].key;
    final topScore = indexed[0].value;
    final modelLabel = _modelClassLabels[topIndex];
    final appLabel = _labelMapping[modelLabel] ?? modelLabel.toLowerCase();

    debugPrint('[CnnClassifier] Top prediction: $modelLabel ($appLabel) = ${(topScore * 100).toStringAsFixed(2)}%');

    // Build top-K list (top 5)
    final topK = indexed.take(5).map((e) {
      final label = _modelClassLabels[e.key];
      return ClassPrediction(
        label: _labelMapping[label] ?? label.toLowerCase(),
        confidence: e.value,
        index: e.key,
      );
    }).toList();

    return CnnClassificationResult(
      label: appLabel,
      confidence: topScore,
      topK: topK,
      rawScores: rawScores,
      classIndex: topIndex,
    );
  }

  /// Get the mapped app label for a given model label
  static String getAppLabel(String modelLabel) {
    return _labelMapping[modelLabel] ?? modelLabel.toLowerCase();
  }

  /// Get all supported class labels (app format)
  static List<String> get supportedLabels => 
      _labelMapping.values.toSet().toList();

  /// Dispose the interpreter
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _instance = null;
    debugPrint('[CnnClassifier] Disposed');
  }
}
