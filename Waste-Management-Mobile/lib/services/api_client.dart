import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;

  /// Whether this error is transient and the same request may succeed later.
  bool get isRetryable =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  /// User-safe description — never exposes raw backend text.
  String get userMessage {
    switch (statusCode) {
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 408:
        return 'Request timed out. Please try again.';
      case 409:
        return 'This item was already submitted.';
      case 413:
        return 'The file is too large. Please use a smaller image.';
      case 422:
        return 'Invalid request. Please try again.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
      case 504:
        return 'Server is temporarily unreachable. Please try again.';
      case 503:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        // Network-level errors (SocketException, etc.) have no statusCode.
        if (statusCode == null) {
          final lower = message.toLowerCase();
          if (lower.contains('no internet') || lower.contains('socket')) {
            return 'No internet connection. Please check your network.';
          }
          if (lower.contains('timed out') || lower.contains('timeout')) {
            return 'Request timed out. Please try again.';
          }
          return message; // already user-safe from our catch blocks
        }
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Centralized API client for all HTTP requests
class ApiClient {
  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Base URL — resolved at runtime from ApiConfig (dotenv / SharedPreferences)
  // No hardcoded constant needed; every request reads the latest value.
  String get _baseUrl => ApiConfig.baseUrl;

  // Secure storage for JWT token
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // HTTP client
  final http.Client _client = http.Client();

  // Token management
  String? _cachedToken;

  /// Default timeout for regular API calls.
  static final Duration _defaultTimeout = ApiConfig.timeout;

  /// Longer timeout for file uploads.
  static final Duration _uploadTimeout = ApiConfig.uploadTimeout;

  /// Get the active base URL (delegates to ApiConfig)
  String get baseUrl => ApiConfig.baseUrl;

  /// Get stored JWT token
  Future<String?> getToken() async {
    _cachedToken ??= await _secureStorage.read(key: _tokenKey);
    return _cachedToken;
  }

  /// Store JWT token
  Future<void> setToken(String token) async {
    _cachedToken = token;
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  /// Clear stored token (logout)
  Future<void> clearToken() async {
    _cachedToken = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
  }

  /// Store user data locally
  Future<void> setUserData(Map<String, dynamic> userData) async {
    await _secureStorage.write(key: _userKey, value: jsonEncode(userData));
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _secureStorage.read(key: _userKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Build headers with optional authentication
  Future<Map<String, String>> _buildHeaders({
    bool requireAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Parse response and handle errors
  Map<String, dynamic> _parseResponse(http.Response response) {
    final Map<String, dynamic> data;
    
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        'Invalid response format',
        statusCode: response.statusCode,
      );
    } catch (e) {
      throw ApiException(
        'Invalid response format',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    // Handle specific error codes
    final message = data['message'] as String? ?? 'Request failed';

    if (response.statusCode == 401) {
      // Token expired or invalid - clear token
      clearToken();
      throw ApiException(message, statusCode: 401, data: data);
    }

    throw ApiException(message, statusCode: response.statusCode, data: data);
  }

  // ── Debug logging helpers ───────────────────────────────────────────────

  void _logRequest(String method, Uri uri, {dynamic body}) {
    if (kDebugMode) {
      debugPrint('[ApiClient] \u2192 $method $uri');
      if (body != null) {
        final s = body.toString();
        debugPrint('[ApiClient]   body: ${s.length > 400 ? '${s.substring(0, 400)}\u2026' : s}');
      }
    }
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    if (kDebugMode) {
      debugPrint('[ApiClient] \u2190 $method $uri [${response.statusCode}]');
      final b = response.body;
      debugPrint('[ApiClient]   body: ${b.length > 500 ? '${b.substring(0, 500)}\u2026' : b}');
    }
  }

  void _logError(String method, Uri uri, Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[ApiClient] \u2716 $method $uri  error=$error');
      if (stack != null) debugPrint('[ApiClient]   stack: $stack');
    }
  }

  /// GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint').replace(
      queryParameters: queryParams,
    );
    _logRequest('GET', uri);
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.get(uri, headers: headers)
          .timeout(_defaultTimeout);
      _logResponse('GET', uri, response);
      return _parseResponse(response);
    } on TimeoutException {
      _logError('GET', uri, 'TimeoutException');
      throw ApiException('Request timed out. Please try again.',
          statusCode: 408);
    } on SocketException catch (e) {
      _logError('GET', uri, e);
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      _logError('GET', uri, e);
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    _logRequest('POST', uri, body: body);
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_defaultTimeout);
      _logResponse('POST', uri, response);
      return _parseResponse(response);
    } on TimeoutException {
      _logError('POST', uri, 'TimeoutException');
      throw ApiException('Request timed out. Please try again.',
          statusCode: 408);
    } on SocketException catch (e) {
      _logError('POST', uri, e);
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      _logError('POST', uri, e);
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    _logRequest('PUT', uri, body: body);
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_defaultTimeout);
      _logResponse('PUT', uri, response);
      return _parseResponse(response);
    } on TimeoutException {
      _logError('PUT', uri, 'TimeoutException');
      throw ApiException('Request timed out. Please try again.',
          statusCode: 408);
    } on SocketException catch (e) {
      _logError('PUT', uri, e);
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      _logError('PUT', uri, e);
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    _logRequest('DELETE', uri);
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.delete(uri, headers: headers)
          .timeout(_defaultTimeout);
      _logResponse('DELETE', uri, response);
      return _parseResponse(response);
    } on TimeoutException {
      _logError('DELETE', uri, 'TimeoutException');
      throw ApiException('Request timed out. Please try again.',
          statusCode: 408);
    } on SocketException catch (e) {
      _logError('DELETE', uri, e);
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      _logError('DELETE', uri, e);
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Multipart POST request for file uploads
  Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required File file,
    String fieldName = 'image',
    Map<String, String>? fields,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    _logRequest('UPLOAD', uri, body: 'file=${file.path}');
    try {
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      if (requireAuth) {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      // Detect MIME type from file (extension + magic bytes fallback)
      final mimeType = await _detectImageMimeType(file);
      final filename = _ensureValidImageFilename(file.path, mimeType);

      // Debug logging
      if (kDebugMode) {
        debugPrint('[ApiClient] Uploading file:');
        debugPrint('  Path: ${file.path}');
        debugPrint('  Filename: $filename');
        debugPrint('  MIME Type: $mimeType');
        debugPrint('  File exists: ${file.existsSync()}');
        debugPrint('  File size: ${file.lengthSync()} bytes');
      }

      // Add file with explicit content type
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add other fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse =
          await request.send().timeout(_uploadTimeout);
      final response =
          await http.Response.fromStream(streamedResponse);

      _logResponse('UPLOAD', uri, response);
      return _parseResponse(response);
    } on TimeoutException {
      _logError('UPLOAD', uri, 'TimeoutException');
      throw ApiException('Upload timed out. Please try again.',
          statusCode: 408);
    } on SocketException catch (e) {
      _logError('UPLOAD', uri, e);
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      _logError('UPLOAD', uri, e);
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Detect image MIME type from file extension and magic bytes
  Future<String> _detectImageMimeType(File file) async {
    // First, try to detect from file extension
    final ext = path.extension(file.path).toLowerCase();
    final extensionMime = _extensionToMime(ext);
    
    if (extensionMime != null) {
      return extensionMime;
    }

    // Fallback: read magic bytes to detect image type
    try {
      final bytes = await file.openRead(0, 12).first;
      
      // JPEG: starts with FF D8 FF
      if (bytes.length >= 3 && 
          bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      
      // PNG: starts with 89 50 4E 47 0D 0A 1A 0A
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
          bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
        return 'image/png';
      }
      
      // WebP: starts with RIFF....WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return 'image/webp';
      }
      
      // GIF: starts with GIF87a or GIF89a
      if (bytes.length >= 6 &&
          bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return 'image/gif';
      }

      // HEIC/HEIF: look for ftyp box with heic/mif1/msf1
      if (bytes.length >= 12 &&
          bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
        return 'image/heic';
      }
    } catch (e) {
      debugPrint('[ApiClient] Error reading magic bytes: $e');
    }

    // Default to JPEG for camera images (most common)
    debugPrint('[ApiClient] Could not detect MIME type, defaulting to image/jpeg');
    return 'image/jpeg';
  }

  /// Map file extension to MIME type
  String? _extensionToMime(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  /// Ensure filename has a valid image extension
  String _ensureValidImageFilename(String filePath, String mimeType) {
    final basename = path.basenameWithoutExtension(filePath);
    final currentExt = path.extension(filePath).toLowerCase();
    
    // If extension is already valid, use the original filename
    if (_extensionToMime(currentExt) != null) {
      return path.basename(filePath);
    }
    
    // Otherwise, append correct extension based on MIME type
    final newExt = _mimeToExtension(mimeType);
    return '$basename$newExt';
  }

  /// Map MIME type to file extension
  String _mimeToExtension(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
      case 'image/heif':
        return '.heic';
      case 'image/gif':
        return '.gif';
      default:
        return '.jpg';
    }
  }

  /// Upload file from bytes (for web or in-memory images)
  Future<Map<String, dynamic>> uploadFileBytes(
    String endpoint, {
    required Uint8List bytes,
    required String filename,
    String fieldName = 'image',
    Map<String, String>? fields,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    _logRequest('UPLOAD_BYTES', uri, body: 'filename=$filename size=${bytes.length}');
    try {
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      if (requireAuth) {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      // Detect MIME type from bytes and ensure valid filename
      final mimeType = _detectMimeTypeFromBytes(bytes);
      final validFilename = _ensureValidFilenameFromMime(filename, mimeType);

      // Debug logging
      if (kDebugMode) {
        debugPrint('[ApiClient] Uploading bytes:');
        debugPrint('  Filename: $validFilename');
        debugPrint('  MIME Type: $mimeType');
        debugPrint('  Bytes size: ${bytes.length}');
      }

      // Add file from bytes with explicit content type
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: validFilename,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add other fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse =
          await request.send().timeout(_uploadTimeout);
      final response =
          await http.Response.fromStream(streamedResponse);

      _logResponse('UPLOAD_BYTES', uri, response);
      return _parseResponse(response);
    } on TimeoutException {
      _logError('UPLOAD_BYTES', uri, 'TimeoutException');
      throw ApiException('Upload timed out. Please try again.',
          statusCode: 408);
    } on SocketException catch (e) {
      _logError('UPLOAD_BYTES', uri, e);
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      _logError('UPLOAD_BYTES', uri, e);
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// Detect MIME type from byte array (magic bytes)
  String _detectMimeTypeFromBytes(Uint8List bytes) {
    if (bytes.length >= 3 && 
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return 'image/png';
    }
    
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }

    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }

    if (bytes.length >= 12 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  /// Ensure filename has valid extension based on MIME type
  String _ensureValidFilenameFromMime(String filename, String mimeType) {
    final ext = path.extension(filename).toLowerCase();
    if (_extensionToMime(ext) != null) {
      return filename;
    }
    final basename = path.basenameWithoutExtension(filename);
    return '$basename${_mimeToExtension(mimeType)}';
  }

  /// Get full URL for uploaded files
  String getFileUrl(String relativePath) {
    if (relativePath.startsWith('http')) {
      return relativePath;
    }
    return '$_baseUrl$relativePath';
  }

  /// Dispose client
  void dispose() {
    _client.close();
  }
}
