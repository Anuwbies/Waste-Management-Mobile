import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

/// Centralized API client for all HTTP requests
class ApiClient {
  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Base URL - change this for production
  static const String _baseUrl = 'http://10.0.2.2:5000'; // Android emulator
  // static const String _baseUrl = 'http://localhost:5000'; // iOS simulator
  // static const String _baseUrl = 'https://your-production-api.com'; // Production

  // Secure storage for JWT token
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // HTTP client
  final http.Client _client = http.Client();

  // Token management
  String? _cachedToken;

  /// Get the base URL
  String get baseUrl => _baseUrl;

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

  /// GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );
      
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.get(uri, headers: headers);
      
      return _parseResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _buildHeaders(requireAuth: requireAuth);
      
      final response = await _client.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      return _parseResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _buildHeaders(requireAuth: requireAuth);
      
      final response = await _client.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      return _parseResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _buildHeaders(requireAuth: requireAuth);
      
      final response = await _client.delete(uri, headers: headers);
      
      return _parseResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
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
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
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
      debugPrint('[ApiClient] Uploading file:');
      debugPrint('  Path: ${file.path}');
      debugPrint('  Filename: $filename');
      debugPrint('  MIME Type: $mimeType');
      debugPrint('  File exists: ${file.existsSync()}');
      debugPrint('  File size: ${file.lengthSync()} bytes');

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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _parseResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
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
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
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
      debugPrint('[ApiClient] Uploading bytes:');
      debugPrint('  Filename: $validFilename');
      debugPrint('  MIME Type: $mimeType');
      debugPrint('  Bytes size: ${bytes.length}');

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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _parseResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on http.ClientException catch (e) {
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
