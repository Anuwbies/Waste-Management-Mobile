import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

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
                      'Terms of Use',
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
                    _SectionTitle('1. Acceptance of Terms'),
                    _SectionText(
                      'By accessing or using this application, you agree to be bound by these Terms of Use. '
                          'If you do not agree with any part of these terms, you must not use the application.',
                    ),

                    _SectionTitle('2. Use of the Application'),
                    _SectionText(
                      'This application is intended to help users classify waste, receive disposal guidance, '
                          'and participate in recycling reward programs. You agree to use the app only for lawful '
                          'and intended purposes.',
                    ),

                    _SectionTitle('3. User Responsibilities'),
                    _SectionText(
                      'You are responsible for the accuracy of information you provide and for maintaining '
                          'the confidentiality of your account. Misuse of the system may result in suspension '
                          'or termination of access.',
                    ),

                    _SectionTitle('4. Rewards and Points'),
                    _SectionText(
                      'Rewards earned through recycling activities have no cash value unless explicitly stated. '
                          'The application reserves the right to modify or discontinue reward mechanisms at any time.',
                    ),

                    _SectionTitle('5. Limitation of Liability'),
                    _SectionText(
                      'The application is provided "as is". We are not responsible for incorrect waste '
                          'classification results, disposal errors, or any damages arising from the use of the app.',
                    ),

                    _SectionTitle('6. Changes to Terms'),
                    _SectionText(
                      'We may update these Terms of Use from time to time. Continued use of the application '
                          'after changes are made constitutes acceptance of the updated terms.',
                    ),

                    SizedBox(height: 16),

                    Center(
                      child: Text(
                        'Last updated: January 2026',
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
