import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'Login_Page.dart';
import 'NavigationBar_Page.dart';

enum RegisterMethod { none, email, google }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  RegisterMethod _loadingMethod = RegisterMethod.none;
  bool get _isLoading => _loadingMethod != RegisterMethod.none;

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Live validation state — updated on every keystroke
  String _password = '';
  String _confirmPassword = '';
  bool _passwordFieldTouched = false;
  bool _confirmFieldTouched = false;

  // ── Password-rule checkers ─────────────────────────────────────────
  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUpperCase => _password.contains(RegExp(r'[A-Z]'));
  bool get _hasLowerCase => _password.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _password.contains(RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:,.<>?/\\|`~"' "'" r']'));
  bool get _passwordStrong =>
      _hasMinLength && _hasUpperCase && _hasLowerCase && _hasDigit && _hasSpecial;
  bool get _passwordsMatch =>
      _password.isNotEmpty &&
      _confirmPassword.isNotEmpty &&
      _password == _confirmPassword;

  /// The register button is enabled only when the form looks valid and
  /// we are not already loading.
  bool get _canSubmit =>
      !_isLoading &&
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordStrong &&
      _passwordsMatch;

  // ── Input decoration factory ───────────────────────────────────────
  InputDecoration _inputDecoration(
    String hint, {
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorMaxLines: 2,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // ── Validators (used by Form) ──────────────────────────────────────
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRe = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w{2,}$');
    if (!emailRe.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (!_passwordStrong) return 'Password does not meet all requirements';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _password) return 'Passwords do not match';
    return null;
  }

  // ── Register action ────────────────────────────────────────────────
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_canSubmit) return;

    setState(() => _loadingMethod = RegisterMethod.email);

    try {
      final success = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        _showError(_authService.error ?? 'Registration failed');
        setState(() => _loadingMethod = RegisterMethod.none);
      }
    } catch (_) {
      _showError('Something went wrong. Please try again.');
      if (mounted) setState(() => _loadingMethod = RegisterMethod.none);
    }
  }

  // ── Google sign-up ─────────────────────────────────────────────────
  Future<void> _signUpWithGoogle() async {
    setState(() => _loadingMethod = RegisterMethod.google);
    try {
      final success = await _authService.signInWithGoogle();
      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const NavigationBarPage()),
          (route) => false,
        );
      } else {
        if (_authService.error != null) {
          debugPrint("FAILED: ${_authService.error}");
          _showError(_authService.error!);
        }
        setState(() => _loadingMethod = RegisterMethod.none);
      }
    } catch (_) {
      _showError('Google sign-in failed. Please try again.');
      if (mounted) setState(() => _loadingMethod = RegisterMethod.none);
    }
  }

  // ── Snackbar helper ────────────────────────────────────────────────
  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
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

  // ── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Back button
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

              // ── Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
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
                        const SizedBox(height: 24),

                        // ── First name
                        TextFormField(
                          controller: _firstNameController,
                          decoration: _inputDecoration('First Name'),
                          textInputAction: TextInputAction.next,
                          validator: _validateName,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        // ── Last name
                        TextFormField(
                          controller: _lastNameController,
                          decoration: _inputDecoration('Last Name'),
                          textInputAction: TextInputAction.next,
                          validator: _validateName,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        // ── Email
                        TextFormField(
                          controller: _emailController,
                          decoration: _inputDecoration('Email'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        // ── Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey,
                                size: 22,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: _validatePassword,
                          onChanged: (val) => setState(() {
                            _password = val;
                            _passwordFieldTouched = true;
                          }),
                        ),

                        // ── Password strength indicators
                        if (_passwordFieldTouched) ...[
                          const SizedBox(height: 10),
                          _PasswordStrengthPanel(
                            hasMinLength: _hasMinLength,
                            hasUpperCase: _hasUpperCase,
                            hasLowerCase: _hasLowerCase,
                            hasDigit: _hasDigit,
                            hasSpecial: _hasSpecial,
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── Confirm password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          decoration: _inputDecoration(
                            'Confirm password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey,
                                size: 22,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            errorText: _confirmFieldTouched &&
                                    _confirmPassword.isNotEmpty &&
                                    !_passwordsMatch
                                ? 'Passwords do not match'
                                : null,
                          ),
                          validator: _validateConfirmPassword,
                          onChanged: (val) => setState(() {
                            _confirmPassword = val;
                            _confirmFieldTouched = true;
                          }),
                        ),

                        // ── Match indicator
                        if (_confirmFieldTouched && _confirmPassword.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(
                                  _passwordsMatch
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                                  size: 16,
                                  color: _passwordsMatch
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _passwordsMatch
                                      ? 'Passwords match'
                                      : 'Passwords do not match',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _passwordsMatch
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 28),

                        // ── Register button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: AnimatedOpacity(
                            opacity: _canSubmit || _isLoading ? 1.0 : 0.55,
                            duration: const Duration(milliseconds: 200),
                            child: ElevatedButton(
                              onPressed: _canSubmit ? _register : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F2937),
                                disabledBackgroundColor:
                                    const Color(0xFF1F2937).withOpacity(0.45),
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
                        ),

                        const SizedBox(height: 24),

                        // ── Divider
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

                        // ── Google button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _signUpWithGoogle,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _loadingMethod == RegisterMethod.google
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
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: const TextStyle(color: Colors.black),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Password-strength feedback panel  (stateless — parent drives rebuilds)
// ═══════════════════════════════════════════════════════════════════════════════

class _PasswordStrengthPanel extends StatelessWidget {
  const _PasswordStrengthPanel({
    required this.hasMinLength,
    required this.hasUpperCase,
    required this.hasLowerCase,
    required this.hasDigit,
    required this.hasSpecial,
  });

  final bool hasMinLength;
  final bool hasUpperCase;
  final bool hasLowerCase;
  final bool hasDigit;
  final bool hasSpecial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rule(hasMinLength, 'At least 8 characters'),
        _rule(hasUpperCase, 'At least 1 uppercase letter'),
        _rule(hasLowerCase, 'At least 1 lowercase letter'),
        _rule(hasDigit, 'At least 1 number'),
        _rule(hasSpecial, 'At least 1 special character'),
      ],
    );
  }

  Widget _rule(bool met, String label) {
    final color = met ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
