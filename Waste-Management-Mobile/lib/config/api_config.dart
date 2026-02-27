import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API Configuration — runtime-resolved.
///
/// Priority for [baseUrl]:
///   1. SharedPreferences override  (Developer Settings screen)
///   2. dotenv value from assets/env/.env.<ENV>
///   3. Hardcoded fallback (10.0.2.2:5000 — Android emulator default)
///
/// Call [ApiConfig.init()] once in main() after dotenv.load().

class ApiConfig {
  ApiConfig._();

  // ── SharedPreferences key ──────────────────────────────────────────────
  static const String _baseUrlPrefKey = 'dev_api_base_url';

  // ── Fallback (compile-time, zero-dependency) ───────────────────────────
  static const String _fallbackBaseUrl = 'http://10.0.2.2:5000';

  // ── Runtime base URL ──────────────────────────────────────────────────
  static String _baseUrl = _fallbackBaseUrl;

  /// The active API base URL. Always resolved at runtime — never requires
  /// `flutter clean` when switching devices.
  static String get baseUrl => _baseUrl;

  /// Overwrite the base URL at runtime (used by Developer Settings).
  /// Persists to SharedPreferences so the value survives app restart.
  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trimRight().endsWith('/')
        ? url.trimRight().substring(0, url.trimRight().length - 1)
        : url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlPrefKey, _baseUrl);
  }

  /// Clear the SharedPreferences override and fall back to dotenv/default.
  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlPrefKey);
    _baseUrl = dotenv.env['API_BASE_URL'] ?? _fallbackBaseUrl;
  }

  /// Call once in main(), after [dotenv.load()].
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_baseUrlPrefKey);
    if (override != null && override.isNotEmpty) {
      _baseUrl = override;
    } else {
      _baseUrl = dotenv.env['API_BASE_URL'] ?? _fallbackBaseUrl;
    }
  }

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '127507564653-ev16rej74t096hhhlhpb240a0k1f90j7.apps.googleusercontent.com',
  );

  /// API timeout duration
  static const Duration timeout = Duration(seconds: 30);

  /// Upload timeout (longer for image uploads)
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Maximum file upload size (10MB)
  static const int maxUploadSize = 10 * 1024 * 1024;

  // ============================================================
  // CNN Classification Thresholds
  // ============================================================

  /// Minimum confidence threshold for reward eligibility (0.0 - 1.0)
  /// Classifications below this threshold will be DENIED rewards
  static const double cnnConfidenceThreshold = 0.80;

  /// Warning threshold - show caution for low-confidence results
  static const double cnnWarningThreshold = 0.60;

  // ============================================================
  // Authentication Endpoints
  // ============================================================

  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authGoogle = '/auth/google';
  static const String authLogout = '/auth/logout';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authResetPassword = '/auth/reset-password';
  static const String authMe = '/auth/me';

  // ============================================================
  // Waste Classification Endpoints
  // ============================================================

  static const String wasteUpload = '/waste/upload';
  static const String wasteClassify = '/waste/classify';
  static const String wasteHistory = '/waste/history';

  /// Disposal suggestion endpoint (LLM-based)
  static const String wasteSuggestion = '/waste/suggestion';

  // ============================================================
  // Recycling Endpoints
  // ============================================================

  static const String recycle = '/recycle';
  static const String recycleLogs = '/recycle/logs';

  // ============================================================
  // Rewards Endpoints
  // ============================================================

  static const String rewardsBalance = '/rewards/balance';
  static const String rewardsHistory = '/rewards/history';
  static const String rewardsStats = '/rewards/stats';
  static const String rewardsOptions = '/rewards/options';
  static const String rewardsRedeem = '/rewards/redeem';

  // ============================================================
  // Wallet Endpoints
  // ============================================================

  static const String walletEnsure = '/wallet/ensure';

  // ============================================================
  // Health / Diagnostics Endpoints
  // ============================================================

  static const String blockchainHealth = '/health/blockchain';

  // ============================================================
  // Waste Type Constants
  // ============================================================

  static const List<String> wasteTypes = [
    'plastic',
    'paper',
    'metal',
    'glass',
    'organic',
    'e-waste',
  ];

  /// Reward points per waste type (matches backend rewardService.ts)
  static const Map<String, int> wasteRewardPoints = {
    'plastic': 5,
    'paper': 4,
    'metal': 8,
    'glass': 6,
    'organic': 3,
    'e-waste': 15,
  };

  /// Bin colors per waste type
  static const Map<String, String> wasteBinColors = {
    'plastic': 'Blue',
    'paper': 'Blue',
    'metal': 'Blue',
    'glass': 'Green',
    'organic': 'Green/Brown',
    'e-waste': 'Special Collection',
  };
}
