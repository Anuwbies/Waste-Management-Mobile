import 'package:flutter/material.dart';
import '../models/scan_session.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import 'LlmSuggestion_Page.dart';

/// CNN Classification Result Page
/// Shows the AI classification result with confidence score
/// User can proceed to LLM suggestion or retake photo
class CnnResultPage extends StatefulWidget {
  final ScanSession session;

  const CnnResultPage({
    super.key,
    required this.session,
  });

  @override
  State<CnnResultPage> createState() => _CnnResultPageState();
}

class _CnnResultPageState extends State<CnnResultPage> {
  late ScanSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  /// Safe getter - returns null if classification is missing
  CnnClassification? get _classification => _session.classification;

  bool get _meetsThreshold => _classification?.meetsConfidenceThreshold ?? false;
  bool get _isWarning => (_classification?.confidence ?? 0) < ApiConfig.cnnWarningThreshold;
  bool get _isUnknown => _classification?.label.toLowerCase() == 'unknown';
  bool get _isDenied => _classification?.status == 'denied';
  bool get _isApproved => _classification?.status == 'approved';

  Color get _confidenceColor {
    if (_isDenied) return Colors.red;
    if (_isApproved) return Colors.green;
    if (_meetsThreshold) return Colors.green;
    if (_isWarning) return Colors.red;
    return Colors.orange;
  }

  IconData get _statusIcon {
    if (_isDenied) return Icons.cancel;
    if (_isApproved) return Icons.check_circle;
    if (_meetsThreshold) return Icons.check_circle;
    if (_isWarning) return Icons.error;
    return Icons.warning;
  }

  String get _statusMessage {
    if (_isDenied) {
      return 'Reward denied \u2014 low confidence or unrecognized item';
    }
    if (_isApproved) {
      return 'Classification approved \u2014 reward earned!';
    }
    if (_meetsThreshold) {
      return 'High confidence classification';
    } else if (_isWarning) {
      return 'Confidence too low to qualify for rewards. Please retake the photo.';
    } else {
      return 'Confidence below reward threshold \u2014 retake for a clearer image';
    }
  }

  void _proceedToSuggestion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LlmSuggestionPage(session: _session),
      ),
    );
  }

  void _retakePhoto() {
    // Pop back to camera page
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Handle missing classification
    if (_classification == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('Classification Result'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Classification data is missing',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please retake the photo and try again.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Classification Result'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            _buildImagePreview(),
            const SizedBox(height: 16),

            // Backend status banner
            _buildStatusBanner(),
            const SizedBox(height: 16),

            // Warning for unknown type
            if (_isUnknown) _buildUnknownWarning(),

            // Classification result card
            _buildClassificationCard(),
            const SizedBox(height: 16),

            // Confidence breakdown
            _buildConfidenceCard(),
            const SizedBox(height: 16),

            // Top-K predictions (if available)
            if (_classification!.topK != null && _classification!.topK!.length > 1)
              _buildTopPredictionsCard(),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _session.imageFile.existsSync()
            ? Image.file(
                _session.imageFile,
                fit: BoxFit.cover,
                width: double.infinity,
              )
            : (_classification?.imageUrl != null
                ? Image.network(
                    ApiClient().getFileUrl(_classification!.imageUrl!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                  )),
      ),
    );
  }

  /// Backend decision banner — approved or denied
  Widget _buildStatusBanner() {
    if (_classification?.status == null) return const SizedBox.shrink();

    final isApproved = _isApproved;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.cancel,
            color: isApproved ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApproved ? 'REWARD APPROVED' : 'REWARD DENIED',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isApproved
                      ? '+${_classification!.potentialPoints} points earned'
                      : 'Low confidence or unrecognized waste type',
                  style: TextStyle(
                    fontSize: 12,
                    color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Warning banner for unknown waste type
  Widget _buildUnknownWarning() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This item could not be identified. Try a clearer photo '
                'with better lighting, or a different angle.',
                style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Waste type icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getWasteTypeColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getWasteTypeIcon(),
                size: 40,
                color: _getWasteTypeColor(),
              ),
            ),
            const SizedBox(height: 16),

            // Classification label
            Text(
              _classification!.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            if (_classification!.rawLabel != null &&
                _classification!.rawLabel!.toLowerCase() != _classification!.label.toLowerCase()) ...[              const SizedBox(height: 4),
              Text(
                'Model prediction: ${_classification!.rawLabel}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 8),

            // Status message
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_statusIcon, color: _confidenceColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: _confidenceColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Potential points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _isDenied
                        ? '0 points (denied)'
                        : '+${_classification!.potentialPoints} points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isDenied ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceCard() {
    final confidencePercent = (_classification!.confidence * 100).toStringAsFixed(1);
    final thresholdPercent = (ApiConfig.cnnConfidenceThreshold * 100).toStringAsFixed(0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confidence Score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),

            // Confidence progress bar
            Stack(
              children: [
                // Background
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Threshold marker
                Positioned(
                  left: (MediaQuery.of(context).size.width - 80) *
                      ApiConfig.cnnConfidenceThreshold,
                  child: Container(
                    width: 2,
                    height: 12,
                    color: Colors.red,
                  ),
                ),
                // Confidence bar
                FractionallySizedBox(
                  widthFactor: _classification!.confidence.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_confidenceColor.withOpacity(0.7), _confidenceColor],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Confidence value
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$confidencePercent%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _confidenceColor,
                  ),
                ),
                Text(
                  'Threshold: $thresholdPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPredictionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other Possibilities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            ..._classification!.topK!.skip(1).take(3).map((pred) {
              final percent = (pred.confidence * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pred.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary action - proceed
        ElevatedButton(
          onPressed: _proceedToSuggestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get Disposal Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Secondary action - retake
        OutlinedButton(
          onPressed: _retakePhoto,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey[400]!),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 8),
              Text(
                'Retake Photo',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getWasteTypeColor() {
    switch (_classification!.label.toLowerCase()) {
      case 'plastic':
        return Colors.blue;
      case 'paper':
        return Colors.brown;
      case 'metal':
        return Colors.grey;
      case 'glass':
        return Colors.teal;
      case 'organic':
        return Colors.green;
      case 'e-waste':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getWasteTypeIcon() {
    switch (_classification!.label.toLowerCase()) {
      case 'plastic':
        return Icons.local_drink;
      case 'paper':
        return Icons.description;
      case 'metal':
        return Icons.build;
      case 'glass':
        return Icons.wine_bar;
      case 'organic':
        return Icons.eco;
      case 'e-waste':
        return Icons.devices;
      default:
        return Icons.help_outline;
    }
  }
}
