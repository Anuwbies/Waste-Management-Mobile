import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:waste_management/Pages/About_page.dart';
import 'package:waste_management/Pages/Faq_Page.dart';
import 'package:waste_management/Pages/PrivacyPolicy.dart';
import 'package:waste_management/Pages/TermsOfUse_Page.dart';

import '../services/auth_service.dart';
import 'Welcome_Page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();

  Future<void> _logout(BuildContext context) async {
    try {
      await _authService.logout();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    final String? photoUrl = user?.photoUrl;
    final String displayName = user?.name ?? 'No name';
    final String email = user?.email ?? 'No email';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ---------------- PROFILE HEADER ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1), // border thickness
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue, // outline color
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage:
                            photoUrl != null && photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? SvgPicture.asset(
                              'lib/assets/images/profile.svg',
                              width: 52,
                              height: 52,
                              colorFilter: const ColorFilter.mode(
                                Colors.blue,
                                BlendMode.srcIn,
                              ),
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.50,
                                ),
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // ---------------- EDGE DIVIDER ----------------
              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.grey.shade400,
              ),

              const SizedBox(height: 12),

              // ---------------- MENU ITEMS ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _ProfileItem(
                      icon: Icons.description_outlined,
                      title: 'Terms Of Use',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
                        );
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.lock_outline,
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                        );
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutPage()),
                        );
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.help_outline,
                      title: 'Faq',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FaqPage()),
                        );
                      },
                    ),
                    _ProfileItem(
                      icon: Icons.logout,
                      title: 'Log Out',
                      onTap: () => _showLogoutConfirmation(context),
                      isLogout: true,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout;
  final bool showDivider;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isLogout = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    icon,
                    size: 22,
                    color: isLogout ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isLogout ? Colors.red : Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.6,
            color: Colors.grey.shade400,
          ),
      ],
    );
  }
}
