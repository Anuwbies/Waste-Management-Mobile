import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:waste_management/Pages/Snaptip_Page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isRearCamera = true;
  FlashMode _flashMode = FlashMode.off;
  
  // Error state
  String? _initError;
  bool _isInitializing = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  /// Safe setState - prevents calling setState after dispose
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _initCamera() async {
    _safeSetState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.request();
      
      if (!cameraStatus.isGranted) {
        _safeSetState(() {
          _isInitializing = false;
          _initError = cameraStatus.isPermanentlyDenied
              ? 'Camera permission permanently denied. Please enable in Settings.'
              : 'Camera permission denied. Please grant access to use the camera.';
        });
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        _safeSetState(() {
          _isInitializing = false;
          _initError = 'No cameras found on this device.';
        });
        return;
      }

      // Start the camera
      await _startCamera(_cameras!.first);
      
      _safeSetState(() => _isInitializing = false);
    } catch (e, stack) {
      debugPrint('[CameraPage] Camera init failed: $e\n$stack');
      _safeSetState(() {
        _isInitializing = false;
        _initError = 'Failed to initialize camera: ${e.toString()}';
      });
    }
  }

  /// Pick image from gallery and return via Navigator.pop
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? xfile =
          await _imagePicker.pickImage(source: ImageSource.gallery);

      if (xfile == null || !mounted) return;

      Navigator.pop(context, File(xfile.path));
    } catch (e) {
      debugPrint('[CameraPage] Gallery pick failed: $e');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    try {
      await _controller?.dispose();

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      // Reset flash whenever camera changes
      _flashMode = FlashMode.off;
      await _controller!.setFlashMode(_flashMode);

      _safeSetState(() {});
    } on CameraException catch (e, stack) {
      debugPrint('[CameraPage] CameraException: ${e.code} - ${e.description}\n$stack');
      _safeSetState(() {
        _initError = 'Camera error: ${e.description ?? e.code}';
      });
    } catch (e, stack) {
      debugPrint('[CameraPage] _startCamera failed: $e\n$stack');
      _safeSetState(() {
        _initError = 'Failed to start camera: ${e.toString()}';
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _safeSetState(() {
        _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      });

      await _controller!.setFlashMode(_flashMode);
    } catch (e, stack) {
      debugPrint('[CameraPage] Toggle flash failed: $e\n$stack');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    try {
      _isRearCamera = !_isRearCamera;
      final camera = _isRearCamera ? _cameras!.first : _cameras!.last;

      await _startCamera(camera);
    } catch (e, stack) {
      debugPrint('[CameraPage] Switch camera failed: $e\n$stack');
    }
  }

  /// Capture image and return via Navigator.pop
  Future<void> _captureAndReturn() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('[CameraPage] Cannot capture - controller not ready');
      return;
    }

    try {
      final XFile xfile = await _controller!.takePicture();
      if (!mounted || _isDisposed) return;

      Navigator.pop(context, File(xfile.path));
    } catch (e, stack) {
      debugPrint('[CameraPage] Capture failed: $e\n$stack');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    // Error state
    if (_initError != null) {
      return Container(
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _initError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (_isInitializing || _controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    // Camera preview with safe previewSize handling
    final previewSize = _controller!.value.previewSize;
    final width = previewSize?.height ?? 1280;
    final height = previewSize?.width ?? 720;

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: width,
        height: height,
        child: CameraPreview(_controller!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? Icons.flash_off_rounded
                                : Icons.flash_on_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _toggleFlash,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cameraswitch_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _switchCamera,
                        ),
                      ],
                    ),
                  ),
                ),

                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: _buildCameraPreview(),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BottomAction(
                          icon: Icons.photo_library_rounded,
                          label: 'Photos',
                          onTap: _pickImageFromGallery,
                        ),

                        GestureDetector(
                          onTap: _captureAndReturn,
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        _BottomAction(
                          icon: Icons.help_outline_rounded,
                          label: 'Snap Tips',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SnapTipsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          iconSize: 28,
          color: Colors.white70,
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}
