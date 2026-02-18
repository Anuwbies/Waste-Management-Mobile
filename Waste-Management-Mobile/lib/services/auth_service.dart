import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_response.dart';
import 'api_client.dart';

/// Authentication service for login, register, and user management
class AuthService extends ChangeNotifier {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _api = ApiClient();
  final GoogleSignIn _googleSignIn = GoogleSignIn(serverClientId: "127507564653-ev16rej74t096hhhlhpb240a0k1f90j7.apps.googleusercontent.com");

  // Current user state
  UserData? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserData? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;

  /// Initialize auth state - call on app start
  Future<bool> initialize() async {
    try {
      final isAuth = await _api.isAuthenticated();
      if (isAuth) {
        // Try to get cached user data first
        final cachedUser = await _api.getUserData();
        if (cachedUser != null) {
          _currentUser = UserData.fromJson(cachedUser);
        }
        // Refresh from server
        await refreshUser();
        return _currentUser != null;
      }
      return false;
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      return false;
    }
  }

  /// Register new user with email and password
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String? walletAddress,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _api.post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
          if (walletAddress != null) 'walletAddress': walletAddress,
        },
        requireAuth: false,
      );

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Registration failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        requireAuth: false,
      );

      final authResponse = AuthResponse.fromJson(response);

      if (authResponse.token != null && authResponse.user != null) {
        await _api.setToken(authResponse.token!);
        await _api.setUserData(authResponse.user!.toJson());
        _currentUser = authResponse.user;
        notifyListeners();
        _setLoading(false);
        return true;
      }

      _setError(authResponse.message ?? 'Login failed');
      _setLoading(false);
      return false;
    } on ApiException catch (e) {
      // Map backend error codes to user-friendly messages
      final code = e.data?['code'] as String?;
      switch (code) {
        case 'INVALID_CREDENTIALS':
          _setError('Invalid email or password');
          break;
        case 'TOO_MANY_ATTEMPTS':
          _setError('Too many attempts. Please try again later.');
          break;
        case 'VALIDATION_ERROR':
          _setError(e.message);
          break;
        default:
          _setError(e.message);
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Login failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  /// Login/Register with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      // Sign out first to allow account selection
      await _googleSignIn.signOut();

      // Start Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      debugPrint("$googleUser");
      if (googleUser == null) {
        _setLoading(false);
        return false; // User cancelled
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        _setError('Failed to get Google authentication token');
        _setLoading(false);
        return false;
      }

      // Send token to backend
      final response = await _api.post(
        '/auth/google',
        body: {'idToken': googleAuth.idToken},
        requireAuth: false,
      );

      final authResponse = AuthResponse.fromJson(response);

      if (authResponse.token != null && authResponse.user != null) {
        await _api.setToken(authResponse.token!);
        await _api.setUserData(authResponse.user!.toJson());
        _currentUser = authResponse.user;
        notifyListeners();
        _setLoading(false);
        return true;
      }

      _setError(authResponse.message ?? 'Google sign-in failed');
      _setLoading(false);
      return false;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  /// Get current user from server
  Future<UserData?> refreshUser() async {
    try {
      final response = await _api.get('/auth/me');

      if (response['user'] != null) {
        _currentUser = UserData.fromJson(
          response['user'] as Map<String, dynamic>,
        );
        await _api.setUserData(_currentUser!.toJson());
        notifyListeners();
        return _currentUser;
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token invalid, clear auth
        await logout();
      }
      return null;
    } catch (e) {
      debugPrint('Refresh user error: $e');
      return null;
    }
  }

  /// Update current user profile
  Future<bool> updateProfile({
    String? name,
    String? walletAddress,
    String? photoUrl,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (walletAddress != null) body['walletAddress'] = walletAddress;
      if (photoUrl != null) body['photoUrl'] = photoUrl;

      final response = await _api.put('/auth/me', body: body);

      if (response['user'] != null) {
        _currentUser = UserData.fromJson(
          response['user'] as Map<String, dynamic>,
        );
        await _api.setUserData(_currentUser!.toJson());
        notifyListeners();
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to update profile');
      _setLoading(false);
      return false;
    }
  }

  // ----------------------------------------------------------------
  // Forgot-password / OTP flow
  // ----------------------------------------------------------------

  /// Request a password-reset OTP for [email].
  /// The backend always returns 200 to prevent email enumeration.
  Future<void> forgotPassword(String email) async {
    await _api.post(
      '/auth/forgot-password',
      body: {'email': email},
      requireAuth: false,
    );
  }

  /// Verify the 6-digit [otp] for [email].
  /// Returns the one-time `resetToken` on success.
  Future<String> verifyOtp(String email, String otp) async {
    final response = await _api.post(
      '/auth/verify-otp',
      body: {'email': email, 'otp': otp},
      requireAuth: false,
    );
    final resetToken = response['resetToken'] as String?;
    if (resetToken == null || resetToken.isEmpty) {
      throw ApiException('Invalid server response');
    }
    return resetToken;
  }

  /// Reset password using the [resetToken] obtained from [verifyOtp].
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/reset-password',
      body: {
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
      requireAuth: false,
    );
  }

  // ----------------------------------------------------------------
  // Logout
  // ----------------------------------------------------------------

  /// Logout — clear local token and notify listeners.
  Future<void> logout() async {
    try {
      // Best-effort server-side logout
      await _api.post('/auth/logout');
    } catch (_) {}

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    await _api.clearToken();
    _currentUser = null;
    notifyListeners();
  }

  /// Check if token is still valid
  Future<bool> validateToken() async {
    try {
      await _api.get('/auth/me');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Private helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
