import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'Login_Page.dart';
import 'NavigationBar_Page.dart';

enum RegisterMethod { none, email, google }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  RegisterMethod _loadingMethod = RegisterMethod.none;
  bool get _isLoading => _loadingMethod != RegisterMethod.none;

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  // ---------------- EMAIL / PASSWORD REGISTER ----------------
  Future<void> _register() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if ([firstName, lastName, email, password]
        .any((value) => value.isEmpty)) {
      _showError('All fields are required');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _loadingMethod = RegisterMethod.email);

    try {
      final UserCredential credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName('$firstName $lastName');
        await user.reload();

        // Do not keep user logged in
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed');
      if (mounted) setState(() => _loadingMethod = RegisterMethod.none);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
      if (mounted) setState(() => _loadingMethod = RegisterMethod.none);
    }
  }

  // ---------------- GOOGLE REGISTER ----------------
  Future<void> _signUpWithGoogle() async {
    setState(() => _loadingMethod = RegisterMethod.google);

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _loadingMethod = RegisterMethod.none);
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
      if (mounted) setState(() => _loadingMethod = RegisterMethod.none);
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                        'Hello! Register to get started',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _firstNameController,
                        decoration: _inputDecoration('First Name'),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _lastNameController,
                        decoration: _inputDecoration('Last Name'),
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
                        decoration: _inputDecoration('Password'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _confirmPasswordController,
                        decoration: _inputDecoration('Confirm password'),
                        obscureText: true,
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F2937),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loadingMethod == RegisterMethod.email
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : const Text(
                            'Register',
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
                              'Or Register with',
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
                          onPressed: _signUpWithGoogle,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loadingMethod ==
                              RegisterMethod.google
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                              : Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
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
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style:
                      const TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Login Now',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
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