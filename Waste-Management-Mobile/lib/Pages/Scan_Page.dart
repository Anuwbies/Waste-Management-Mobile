import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scan_session.dart';
import '../services/waste_service.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../utils/error_card.dart';
import 'Camera/Camera_Page.dart';
import 'CnnResult_Page.dart';

/// Entry screen for the scan/upload flow.
/// Provides two actions: capture with camera or upload from gallery.
/// After receiving a File, uploads to backend, then navigates to CnnResultPage.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final WasteService _wasteService = WasteService();
  final ImagePicker _imagePicker = ImagePicker();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isUploading = false;

  /// The image that was picked / captured. Kept around for retry.
  File? _pendingImage;

  /// Structured error state – null means no error.
  _ScanError? _error;

  /// Open camera, await File result
  Future<void> _captureImage() async {
    final File? file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => const CameraPage()),
    );
    if (file != null && mounted) {
      await _uploadAndNavigate(file);
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (xfile != null && mounted) {
        await _uploadAndNavigate(File(xfile.path));
      }
    } catch (e) {
      debugPrint('[ScanPage] Gallery pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image from gallery'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Upload image to backend and navigate to result page
  Future<void> _uploadAndNavigate(File imageFile) async {
    if (_isUploading) return;

    // Keep image in memory for retry
    _pendingImage = imageFile;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    // ── Fail-fast offline check ────────────────────────────────────
    if (!await _connectivity.isConnected) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = const _ScanError(
          icon: Icons.wifi_off,
          iconColor: Colors.blueGrey,
          title: 'No Internet Connection',
          message:
              'Please check your Wi-Fi or mobile data and try again.\n'
              'Your photo has been saved — no need to retake it.',
        );
      });
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint(
            '[ScanPage] Uploading: ${imageFile.path} (${imageFile.lengthSync()} bytes)');
      }

      final result = await _wasteService.uploadAndClassify(imageFile);
      final c = result.classification;

      if (kDebugMode) {
        debugPrint('[ScanPage] Result: ${c.wasteType} '
            '(${(c.confidence * 100).toStringAsFixed(1)}%) '
            'raw=${c.rawLabel} status=${c.status} pts=${c.rewardPoints}');
      }

      if (!mounted) return;

      // Build CnnClassification for the scan pipeline
      final cnnClassification = CnnClassification(
        label: c.wasteType,
        confidence: c.confidence,
        imageId: c.id,
        imageUrl: c.imageUrl,
        potentialPoints: c.rewardPoints,
        status: c.status,
        rawLabel: c.rawLabel,
        topK: c.topK
            ?.map((t) => ClassificationPrediction(
                  label: t.canonicalLabel.isNotEmpty ? t.canonicalLabel : t.label,
                  confidence: t.score,
                ))
            .toList(),
      );

      final session = ScanSession(imageFile: imageFile)
          .copyWithClassification(cnnClassification);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CnnResultPage(session: session)),
      );
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[ScanPage] Upload failed: ${e.message} (${e.statusCode})');
      }
      if (!mounted) return;
      setState(() {
        _error = _mapApiError(e);
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[ScanPage] Unexpected error: $e');
        debugPrint('[ScanPage] Stack: $stack');
      }
      if (!mounted) return;
      setState(() {
        _error = const _ScanError(
          title: 'Classification Failed',
          message:
              'We couldn\'t analyze the image right now.\n'
              'Your photo is saved — tap Retry to try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Map [ApiException] to a user-friendly [_ScanError].
  _ScanError _mapApiError(ApiException e) {
    switch (e.statusCode) {
      case 401:
        // Redirect to login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
        return const _ScanError(
          icon: Icons.lock_outline,
          iconColor: Color(0xFFEF6C00),
          title: 'Session Expired',
          message: 'Your login session has expired. Redirecting to login…',
          showRetry: false,
        );
      case 408:
        return const _ScanError(
          icon: Icons.timer_off,
          iconColor: Colors.orange,
          title: 'Request Timed Out',
          message:
              'The server took too long to respond.\n'
              'Your photo is saved — tap Retry to try again.',
        );
      case 413:
        return const _ScanError(
          icon: Icons.photo_size_select_large,
          iconColor: Colors.orange,
          title: 'Image Too Large',
          message:
              'The image file exceeds the size limit.\n'
              'Please retake with a lower resolution.',
          showRetry: false,
        );
      case 503:
        return const _ScanError(
          icon: Icons.cloud_off,
          iconColor: Colors.blueGrey,
          title: 'AI Service Unavailable',
          message:
              'The classification service is temporarily down.\n'
              'Your photo is saved — please try again shortly.',
        );
      case 500:
      case 502:
      case 504:
        return const _ScanError(
          icon: Icons.cloud_off,
          iconColor: Colors.red,
          title: 'Server Error',
          message:
              'Something went wrong on our end.\n'
              'Your photo is saved — tap Retry to try again.',
        );
      default:
        return _ScanError(
          title: 'Classification Failed',
          message:
              'We couldn\'t analyze the image right now.\n'
              'Your photo is saved — tap Retry to try again.',
          detail: e.statusCode != null ? 'Error ${e.statusCode}' : null,
        );
    }
  }

  /// Retry with the same image.
  void _retryUpload() {
    if (_pendingImage != null) {
      _uploadAndNavigate(_pendingImage!);
    }
  }

  /// Dismiss error and return to the main scan UI.
  void _dismissError() {
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Scan Waste'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Hero icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 60,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Classify Your Waste',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Take a photo or upload an image of waste to get\n'
                      'AI-powered classification and earn rewards.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Capture with camera
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _captureImage,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text(
                          'Capture with Camera',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.green.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Upload from gallery
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text(
                          'Upload from Gallery',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          disabledForegroundColor: Colors.green.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _isUploading
                                ? Colors.green.withOpacity(0.3)
                                : Colors.green,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Supported types hint
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Supported Waste Types',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              _wasteChip('Plastic', Colors.blue),
                              _wasteChip('Paper', Colors.brown),
                              _wasteChip('Metal', Colors.grey),
                              _wasteChip('Glass', Colors.teal),
                              _wasteChip('Organic', Colors.green),
                              _wasteChip('E-Waste', Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Analyzing image\u2026',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Uploading to AI service for classification',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Error overlay — keeps image in memory for retry
          if (_error != null && !_isUploading)
            Container(
              color: const Color(0xFFF5F5F5),
              child: ErrorCard(
                icon: _error!.icon,
                iconColor: _error!.iconColor,
                title: _error!.title,
                message: _error!.message,
                detail: _error!.detail,
                retryLabel: 'Retry',
                onRetry: _error!.showRetry ? _retryUpload : null,
                secondaryLabel: 'Go Back',
                onSecondary: _dismissError,
              ),
            ),
        ],
      ),
    );
  }

  Widget _wasteChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Structured error model for ScanPage
// ─────────────────────────────────────────────────────────────────────────────

class _ScanError {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? detail;
  final bool showRetry;

  const _ScanError({
    this.icon = Icons.error_outline,
    this.iconColor = Colors.red,
    required this.title,
    required this.message,
    this.detail,
    this.showRetry = true,
  });
}
