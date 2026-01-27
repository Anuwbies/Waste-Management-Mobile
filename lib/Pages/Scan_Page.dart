import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ScanPage extends StatefulWidget {
  final ImageProvider image;

  const ScanPage({super.key, required this.image});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  late ScanPageModel _model;

  @override
  void initState() {
    super.initState();
    _model = ScanPageModel();
    _model.init(widget.image, context, this);
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 250,
                    height: 350,
                    child: Image(
                      image: widget.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_model.isScanning) ...[
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      LoadingAnimationWidget.threeArchedCircle(
                        color: Colors.blueAccent,
                        size: 60,
                      ),
                      Icon(
                        LucideIcons.search,
                        size: 30,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Analyzing image...",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   MODEL (same file, no extra dart)
   ============================================================ */

class ScanPageModel {
  late BuildContext _context;
  late ImageProvider _image;
  late TickerProvider _vsync;

  bool isScanning = true;

  void init(
      ImageProvider image,
      BuildContext context,
      TickerProvider vsync,
      ) {
    _image = image;
    _context = context;
    _vsync = vsync;

    _startScan();
  }

  Future<void> _startScan() async {
    // Simulated processing delay
    await Future.delayed(const Duration(seconds: 5));

    isScanning = false;

    if (_context.mounted) {
      (_context as Element).markNeedsBuild();
    }
  }

  void dispose() {
    // Keep for future controllers or streams
  }
}
