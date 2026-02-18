import 'package:flutter/material.dart';
import 'Login_Page.dart';
import 'Register_Page.dart';

// ---------------------------------------------------------------------------
// Color palette
// ---------------------------------------------------------------------------
const _kDarkGreen = Color(0xFF166534);
const _kGradientTop = Color(0xFF0F766E); // teal-700
const _kGradientBottom = Color(0xFF16A34A); // green-600

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── gradient background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kGradientTop, _kGradientBottom],
              ),
            ),
          ),

          // ── decorative circles (subtle depth) ──
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.18,
            child: _GlowCircle(diameter: size.width * 0.6, opacity: 0.08),
          ),
          Positioned(
            bottom: size.height * 0.22,
            left: -size.width * 0.2,
            child: _GlowCircle(diameter: size.width * 0.5, opacity: 0.06),
          ),

          // ── main content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPad + 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // ── logo icon ──
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.recycling_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── app name ──
                      const Text(
                        'RecyClean',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── tagline ──
                      Text(
                        'Smart Waste. Smarter Rewards.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.4,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── illustration placeholder (reuse asset) ──
                      SizedBox(
                        height: size.height * 0.18,
                        child: Image.asset(
                          'lib/assets/images/room key.png',
                          fit: BoxFit.contain,
                          color: Colors.white.withValues(alpha: 0.15),
                          colorBlendMode: BlendMode.srcATop,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── Login button (primary) ──
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _kDarkGreen,
                            elevation: 4,
                            shadowColor:
                                Colors.black.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Register button (secondary / outlined) ──
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── footer note ──
                      Text(
                        'Recycle today, reward yourself tomorrow.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),

                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative translucent circle widget
// ---------------------------------------------------------------------------
class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.diameter, required this.opacity});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}