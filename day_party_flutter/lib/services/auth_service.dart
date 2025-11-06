import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
// Note: google_sign_in package included in pubspec but using backend OAuth flow
// import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  
  final Dio _dio = ApiClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  // Note: GoogleSignIn plugin not used - we use backend OAuth flow via url_launcher
  // If you want to use google_sign_in plugin directly, uncomment and adjust the flow
  // final GoogleSignIn _googleSignIn = GoogleSignIn(
  //   scopes: ['email', 'profile'],
  // );

  // Get stored token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      appLogger.w('Error reading token', error: e);
      return null;
    }
  }

  // Get stored user data
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson != null && userJson.isNotEmpty) {
        // Parse JSON string to Map
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    } catch (e) {
      appLogger.w('Error reading user data', error: e);
    }
    return null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Start Google OAuth flow
  Future<void> signInWithGoogle() async {
    try {
      // Step 1: Get authorization URL from backend
      final response = await _dio.post(
        '/auth/social/start',
        data: {
          'provider': 'google',
          'redirectUri': 'dayparty://auth/callback',
        },
      );

      final authorizationUrl = response.data['authorizationUrl'] as String;

      // Debug: Log the URL being opened
      appLogger.d('Opening OAuth URL: $authorizationUrl');

      // Step 2: Launch browser for OAuth
      final uri = Uri.parse(authorizationUrl);
      
      // Try to launch the URL - use platformDefault first (works better in emulator)
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        
        if (!launched) {
          // Fallback: try externalApplication if platformDefault fails
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        // If launch fails, provide more detailed error
        throw Exception('Could not launch OAuth URL: $e. Make sure a browser is installed.');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception(
          'Authentication endpoint not available. Please ensure the backend server is running and the auth endpoints are implemented.',
        );
      } else if (e.response?.statusCode != null) {
        throw Exception('Server error: ${e.response?.statusCode} - ${e.response?.statusMessage}');
      } else if (e.type == DioExceptionType.connectionTimeout || 
                 e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Connection timeout. Please check if the backend server is running at ${ApiClient.baseUrl}');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot connect to backend server. Please ensure it is running at ${ApiClient.baseUrl}');
      }
      throw Exception('Failed to start Google sign-in: ${e.message}');
    } catch (e) {
      throw Exception('Failed to start Google sign-in: $e');
    }
  }

  // Handle OAuth callback from deep link URL
  // Extracts code from URL and exchanges it for JWT tokens
  Future<void> handleOAuthCallback(String callbackUrl) async {
    try {
      final uri = Uri.parse(callbackUrl);
      
      // Extract code from callback URL
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw Exception('No code found in callback URL');
      }
      
      // Exchange code for tokens
      final response = await _dio.post(
        '/auth/social/callback',
        data: {
          'provider': 'google',
          'code': code,
          'redirectUri': 'dayparty://auth/callback',
        },
      );

      final token = response.data['token'] as String;
      final user = response.data['user'] as Map<String, dynamic>;

      // Store token and user data
      await _storage.write(key: _tokenKey, value: token);
      if (response.data['refreshToken'] != null) {
        await _storage.write(
          key: _refreshTokenKey,
          value: response.data['refreshToken'] as String,
        );
      }
      // Store user data as JSON string
      await _storage.write(key: _userKey, value: jsonEncode(user));

      // Update API client with token
      _updateApiClientToken(token);
    } catch (e) {
      throw Exception('Failed to complete sign-in: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        // Call logout endpoint
        await _dio.post(
          '/auth/logout',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
      }
    } catch (e) {
      // Continue with local logout even if API call fails
      appLogger.w('Logout API call failed', error: e);
    } finally {
      // Clear local storage
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userKey);

      // Clear API client token
      _updateApiClientToken(null);
    }
  }

  // Update API client with JWT token
  void _updateApiClientToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  // Initialize - load token on app start and validate it
  Future<void> initialize() async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        _updateApiClientToken(token);
        
        // Validate token by making a lightweight API call
        // If token is invalid, clear it and user will need to login again
        try {
          // Try to fetch user info or make a simple authenticated call
          // For now, we'll just check if token exists - validation happens on first API call
          // The 401 interceptor will clear invalid tokens automatically
          appLogger.d('Token found on startup - will validate on first API call');
        } catch (e) {
          // If validation fails, clear the token
          appLogger.w('Token validation failed, clearing', error: e);
          await logout();
        }
      } else {
        appLogger.d('No token found on startup');
      }
    } catch (e) {
      appLogger.e('Error initializing auth', error: e);
      // Continue without token if initialization fails
    }
  }
}

