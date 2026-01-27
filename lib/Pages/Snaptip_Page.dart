import 'package:flutter/material.dart';

class SnapTipsPage extends StatelessWidget {
  const SnapTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // replaces AppColors.surfaceA0
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                "Snap Tips",
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
              const Spacer(),

              // Placeholder for Image.asset('assets/images/perfect.png')
              const Icon(
                Icons.check_circle_outline,
                size: 190,
                color: Colors.white54,
              ),

              const SizedBox(height: 50),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _TipItem(label: 'Too close'),
                  _TipItem(label: 'Too far'),
                  _TipItem(label: 'Multi-species'),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // replaces AppColors.primaryA0
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Got it",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String label;

  const _TipItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Placeholder for Image.asset(...)
        const Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: Colors.white38,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
