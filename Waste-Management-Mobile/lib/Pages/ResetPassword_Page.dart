import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Step 3 of the password-reset flow.
/// User enters a new password that meets the strong password policy.
class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String resetToken;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.resetToken,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // ── Frontend password-policy mirror (matches backend) ──

  static const int _minLength = 12;

  List<_PolicyRule> get _rules => [
        _PolicyRule(
          'At least $_minLength characters',
          _passwordController.text.length >= _minLength,
        ),
        _PolicyRule(
          'At least one uppercase letter',
          _passwordController.text.contains(RegExp(r'[A-Z]')),
        ),
        _PolicyRule(
          'At least one lowercase letter',
          _passwordController.text.contains(RegExp(r'[a-z]')),
        ),
        _PolicyRule(
          'At least one number',
          _passwordController.text.contains(RegExp(r'[0-9]')),
        ),
        _PolicyRule(
          'At least one special character',
          _passwordController.text.contains(RegExp(r'[^A-Za-z0-9]')),
        ),
      ];

  bool get _allRulesMet => _rules.every((r) => r.met);

  // ── Submit ──

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (!_allRulesMet) {
      _showSnackBar('Password does not meet all requirements');
      return;
    }
    if (password != confirm) {
      _showSnackBar('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.resetPassword(
        email: widget.email,
        resetToken: widget.resetToken,
        newPassword: password,
      );

      if (!mounted) return;

      _showSnackBar('Password reset successfully!', isError: false);

      // Pop all the way back to Login
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _showSnackBar(_mapResetError(e));
    } catch (_) {
      _showSnackBar('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapResetError(ApiException e) {
    final code = e.data?['code'] as String?;
    if (code == 'VALIDATION_ERROR') {
      final details = e.data?['details'];
      if (details is List && details.isNotEmpty) {
        return details.first.toString();
      }
    }
    if (code == 'INVALID_TOKEN') {
      return 'Reset link has expired. Please start over.';
    }
    return e.message;
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          backgroundColor: isError ? null : Colors.green.shade700,
        ),
      );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Back button
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      const Text(
                        'Create New Password',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Your new password must meet the requirements below.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),

                      const SizedBox(height: 28),

                      // New password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDecoration(
                          'New Password',
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
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

                      const SizedBox(height: 16),

                      // Confirm password
                      TextField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        decoration: _inputDecoration(
                          'Confirm Password',
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                _obscureConfirm
                                    ? 'lib/assets/images/eye closed.png'
                                    : 'lib/assets/images/eye open.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Policy checklist
                      ..._rules.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  r.met
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: r.met ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  r.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: r.met
                                        ? Colors.green.shade700
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F2937),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Reset Password',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 32),
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

// Small helper for password policy rules
class _PolicyRule {
  final String label;
  final bool met;
  const _PolicyRule(this.label, this.met);
}
