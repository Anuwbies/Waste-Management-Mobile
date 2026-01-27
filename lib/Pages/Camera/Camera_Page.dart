import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waste_management/Pages/Scan_Page.dart';
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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    await _startCamera(_cameras!.first);
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? file =
      await _imagePicker.pickImage(source: ImageSource.gallery);

      if (file == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanPage(
            image: FileImage(File(file.path)),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Gallery pick failed: $e');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
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

    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _flashMode =
      _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    });

    await _controller!.setFlashMode(_flashMode);
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _isRearCamera = !_isRearCamera;
    final camera = _isRearCamera ? _cameras!.first : _cameras!.last;

    await _startCamera(camera);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
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
                child: _controller == null ||
                    !_controller!.value.isInitialized
                    ? Container(
                  color: Colors.grey.shade900,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
                    : FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:
                    _controller!.value.previewSize!.height,
                    height:
                    _controller!.value.previewSize!.width,
                    child: CameraPreview(_controller!),
                  ),
                ),
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
                      onTap: () async {
                        if (_controller == null || !_controller!.value.isInitialized) return;

                        try {
                          final XFile file = await _controller!.takePicture();

                          if (!mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScanPage(
                                image: FileImage(File(file.path)),
                              ),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Capture failed: $e');
                        }
                      },
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
