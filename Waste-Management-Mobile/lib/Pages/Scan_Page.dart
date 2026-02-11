import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scan_session.dart';
import '../services/waste_service.dart';
import '../services/api_client.dart';
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

  bool _isUploading = false;

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
    setState(() => _isUploading = true);

    try {
      debugPrint('[ScanPage] Uploading: ${imageFile.path} (${imageFile.lengthSync()} bytes)');

      final result = await _wasteService.uploadAndClassify(imageFile);
      final c = result.classification;

      debugPrint('[ScanPage] Result: ${c.wasteType} '
          '(${(c.confidence * 100).toStringAsFixed(1)}%) '
          'raw=${c.rawLabel} status=${c.status} pts=${c.rewardPoints}');

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
      debugPrint('[ScanPage] Upload failed: ${e.message} (${e.statusCode})');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _uploadAndNavigate(imageFile),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ScanPage] Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to classify image. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _uploadAndNavigate(imageFile),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
