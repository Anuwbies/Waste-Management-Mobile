import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'NavigationBar_Page.dart';
import 'Register_Page.dart';

enum LoginMethod { none, email, google }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  LoginMethod _loadingMethod = LoginMethod.none;

  bool get _isLoading => _loadingMethod != LoginMethod.none;

  // IMPORTANT: single GoogleSignIn instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ---------------- EMAIL/PASSWORD LOGIN ----------------
  Future<void> _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('All fields are required');
      return;
    }

    setState(() => _loadingMethod = LoginMethod.email);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const NavigationBarPage(),
        ),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
      if (mounted) setState(() => _loadingMethod = LoginMethod.none);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
      if (mounted) setState(() => _loadingMethod = LoginMethod.none);
    }
  }

  // ---------------- GOOGLE SIGN-IN ----------------
  Future<void> _signInWithGoogle() async {
    setState(() => _loadingMethod = LoginMethod.google);

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _loadingMethod = LoginMethod.none);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final AuthCredential credential =
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const NavigationBarPage(),
        ),
            (route) => false,
      );

    } catch (_) {
      _showError('Google sign-in failed. Please try again.');
      if (mounted) setState(() => _loadingMethod = LoginMethod.none);
    }
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ---------------- INPUT DECORATION ----------------
  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: Column(
            children: [
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      const Text(
                        'Welcome back! Glad to see you again',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _emailController,
                        decoration: _inputDecoration('Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          'Password',
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                _obscurePassword
                                    ? 'lib/assets/images/eye closed.png'
                                    : 'lib/assets/images/eye open.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loginWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F2937),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loadingMethod == LoginMethod.email
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Or Login with',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          child: _loadingMethod == LoginMethod.google
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'lib/assets/images/google icon.png',
                                height: 22,
                                width: 22,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Google',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Don’t have an account? '),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register Now',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}