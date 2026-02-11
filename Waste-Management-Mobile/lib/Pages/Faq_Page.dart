import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Header: Back button + centered title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Expanded(
                    child: Text(
                      'FAQ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Spacer to balance the back button width
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SectionTitle('1. What is this application for?'),
                    _SectionText(
                      'This application helps users correctly identify and sort waste items using '
                          'AI-based image classification. It also provides guidance on proper disposal.',
                    ),

                    _SectionTitle('2. How does waste classification work?'),
                    _SectionText(
                      'You can take a photo or upload an image of an item. The system analyzes the image '
                          'and predicts the most likely waste category based on trained models.',
                    ),

                    _SectionTitle('3. Is the waste classification always accurate?'),
                    _SectionText(
                      'The system aims to be accurate, but results may vary depending on image quality, '
                          'lighting conditions, and the type of waste. Always follow local disposal rules.',
                    ),

                    _SectionTitle('4. Do I earn rewards for recycling?'),
                    _SectionText(
                      'Some versions of the application may include a reward system for responsible '
                          'recycling actions. Rewards and availability may vary.',
                    ),

                    _SectionTitle('5. Is my personal data safe?'),
                    _SectionText(
                      'We take user privacy seriously and apply reasonable security measures to protect '
                          'your information. Please refer to the Privacy Policy for more details.',
                    ),

                    _SectionTitle('6. Can I use the app without an internet connection?'),
                    _SectionText(
                      'Certain features may require an internet connection, such as account access '
                          'and model updates. Offline functionality may be limited.',
                    ),

                    _SectionTitle('7. Who can I contact for support?'),
                    _SectionText(
                      'For questions or support, please refer to the About section or contact the '
                          'project administrators if available.',
                    ),

                    SizedBox(height: 16),

                    Center(
                      child: Text(
                        'Need more help? Contact support.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
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

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionText extends StatelessWidget {
  final String text;

  const _SectionText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Colors.black87,
      ),
    );
  }
}
