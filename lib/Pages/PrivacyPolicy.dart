import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                      'Privacy Policy',
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
                    _SectionTitle('1. Information We Collect'),
                    _SectionText(
                      'We may collect basic personal information such as your name, email address, '
                          'and profile photo when you create an account or sign in using third-party services.',
                    ),

                    _SectionTitle('2. How We Use Your Information'),
                    _SectionText(
                      'Your information is used to provide application functionality, personalize '
                          'user experience, track recycling activities, and improve overall system performance.',
                    ),

                    _SectionTitle('3. Data Storage and Security'),
                    _SectionText(
                      'We take reasonable measures to protect your data. However, no system can be '
                          'guaranteed to be completely secure, and absolute protection cannot be assured.',
                    ),

                    _SectionTitle('4. Sharing of Information'),
                    _SectionText(
                      'We do not sell or rent your personal information. Data may only be shared '
                          'when required by law or to operate essential application services.',
                    ),

                    _SectionTitle('5. Third-Party Services'),
                    _SectionText(
                      'The application may use third-party services such as authentication providers '
                          'or analytics tools. These services are governed by their own privacy policies.',
                    ),

                    _SectionTitle('6. User Rights and Choices'),
                    _SectionText(
                      'You may request access, correction, or deletion of your personal data where applicable. '
                          'You may also stop using the application at any time.',
                    ),

                    _SectionTitle('7. Changes to This Policy'),
                    _SectionText(
                      'We may update this Privacy Policy periodically. Continued use of the application '
                          'after changes indicates acceptance of the revised policy.',
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
