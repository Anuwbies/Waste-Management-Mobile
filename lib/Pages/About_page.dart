import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
                      'About',
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
                    _SectionTitle('1. About the Application'),
                    _SectionText(
                      'This application is designed to help users identify and sort waste correctly '
                          'using AI-powered classification. It aims to promote responsible disposal '
                          'habits and environmental awareness through an easy-to-use interface.',
                    ),

                    _SectionTitle('2. Purpose'),
                    _SectionText(
                      'The goal of this project is to encourage proper waste segregation, reduce '
                          'landfill waste, and support recycling initiatives by guiding users in making '
                          'better disposal decisions.',
                    ),

                    _SectionTitle('3. How It Works'),
                    _SectionText(
                      'Users can capture or upload an image of an item, and the system will analyze '
                          'it to determine its waste category. The application then provides guidance on '
                          'proper disposal and may offer rewards for responsible actions.',
                    ),

                    _SectionTitle('4. Project Background'),
                    _SectionText(
                      'This application is developed as part of an academic project focused on '
                          'sustainable technology, artificial intelligence, and community-driven '
                          'environmental solutions.',
                    ),

                    _SectionTitle('5. Disclaimer'),
                    _SectionText(
                      'Waste classification results are generated using machine learning models and '
                          'may not always be 100% accurate. Users should follow local disposal regulations '
                          'when handling waste.',
                    ),

                    SizedBox(height: 16),

                    Center(
                      child: Text(
                        'Version 1.0.0',
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
          fontSize: 18,
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
