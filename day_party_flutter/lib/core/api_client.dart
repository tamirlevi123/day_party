import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger.dart';

class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  
  _PendingRequest(this.options, this.handler);
}

// HTTP client for Day Party backend
// Automatically detects emulator vs physical device and sets baseUrl accordingly
class ApiClient {
  // Backend endpoints
  static const String _azureVmBaseUrl = 'http://172.167.43.172/api';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:3000/api';
  
  // Allow insecure SSL certificates for development (self-signed certs)
  // WARNING: Only use this in development! Never enable in production.
  static const bool _allowInsecureSSL = true;

  static String? _baseUrl;

  static String get baseUrl {
    if (_baseUrl == null) {
      throw StateError('ApiClient not initialized. Call ApiClient.initialize() first.');
    }
    return _baseUrl!;
  }

  static Future<String> _determineBaseUrl() async {
    if (kIsWeb) {
      // Web platform - use localhost
      return 'http://localhost:3000/api';
    }

    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        // Check if running on emulator
        final model = androidInfo.model.toLowerCase();
        final product = androidInfo.product.toLowerCase();
        final device = androidInfo.device.toLowerCase();
        final brand = androidInfo.brand.toLowerCase();

        final isEmulator = model.contains('sdk') ||
            product.contains('sdk') ||
            device.contains('generic') ||
            brand.contains('generic') ||
            model.contains('emulator') ||
            product.contains('emulator') ||
            model.contains('google_sdk');

        // Emulator uses local dev server, physical device uses Azure VM
        if (isEmulator) {
          appLogger.d('Detected Android emulator - using local dev server: $_androidEmulatorBaseUrl');
          return _androidEmulatorBaseUrl;
        } else {
          appLogger.d('Detected physical Android device - using Azure VM backend: $_azureVmBaseUrl');
          return _azureVmBaseUrl;
        }
      } catch (e) {
        appLogger.w('Error detecting device type, defaulting to emulator', error: e);
        return _androidEmulatorBaseUrl;
      }
    } else if (Platform.isIOS) {
      // For iOS, assume physical device (use Azure VM)
      // iOS Simulator detection could be added here if needed
      appLogger.d('Detected iOS device - using Azure VM backend: $_azureVmBaseUrl');
      return _azureVmBaseUrl;
    }

    // Default fallback (for other platforms)
    appLogger.d('Unknown platform - defaulting to Azure VM backend: $_azureVmBaseUrl');
    return _azureVmBaseUrl;
  }

  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static bool _isRefreshing = false;
  static final List<_PendingRequest> _pendingRequests = [];

  static Dio? _dio;

  /// Configure SSL certificate validation for development
  /// This allows self-signed certificates and bypasses hostname verification
  static void _configureSSL(Dio dio) {
    if (_allowInsecureSSL && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        // Allow self-signed certificates and bypass hostname verification
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          appLogger.w('Allowing insecure SSL connection to $host:$port (development mode)');
          return true; // Accept all certificates in development
        };
        return client;
      };
      appLogger.w('⚠️ Insecure SSL mode enabled for development. This should NEVER be enabled in production!');
    }
  }

  static Dio get instance {
    _dio ??= Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30), // Increased from 10 to 30 seconds
      receiveTimeout: const Duration(seconds: 60), // Increased from 30 to 60 seconds
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    // Apply SSL configuration if needed
    _configureSSL(_dio!);
    return _dio!;
  }

  /// Initialize the API client and detect device type
  static Future<void> initialize() async {
    // This will trigger device detection and set _baseUrl
    final url = await _determineBaseUrl();
    _baseUrl = url;

    // Create Dio instance with the determined baseUrl
    // Increased timeout for physical device connections (may be slower)
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: const Duration(seconds: 30), // Increased from 10 to 30 seconds
      receiveTimeout: const Duration(seconds: 60), // Increased from 30 to 60 seconds
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Configure SSL certificate validation for development
    // This handles cases where HTTP requests are redirected to HTTPS,
    // or when connecting to servers with self-signed certificates
    _configureSSL(_dio!);

    appLogger.d('API Client initialized with baseUrl: $_baseUrl');
  }

  static void setupInterceptors() {
    if (_dio == null) {
      throw StateError('ApiClient not initialized. Call ApiClient.initialize() first.');
    }

    // Add auth interceptor to inject JWT token
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          // Add JWT token to headers if available
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (e) {
          // If storage fails, continue without token
          appLogger.w('Error reading token in interceptor', error: e);
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized - try to refresh token
        if (error.response?.statusCode == 401 && error.requestOptions.path != '/auth/refresh') {
          appLogger.d('Received 401 Unauthorized, attempting token refresh');
          try {
            final refreshToken = await _storage.read(key: _refreshTokenKey);
            
            if (refreshToken != null && refreshToken.isNotEmpty) {
              // If already refreshing, queue this request
              if (_isRefreshing) {
                appLogger.d('Token refresh already in progress, queueing request');
                _pendingRequests.add(_PendingRequest(error.requestOptions, handler));
                return;
              }
              
              _isRefreshing = true;
              appLogger.d('Starting token refresh');
              
              try {
                // Attempt to refresh the token
                final refreshResponse = await _dio!.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );
                
                final newToken = refreshResponse.data['token'] as String;
                if (newToken.isEmpty) {
                  throw Exception('Received empty token from refresh endpoint');
                }
                
                await _storage.write(key: _tokenKey, value: newToken);
                appLogger.d('Token refreshed successfully');
                
                // Update the failed request with new token
                error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                
                // Retry the original request
                final opts = error.requestOptions;
                final response = await _dio!.fetch(opts);
                
                // Process pending requests
                for (final pending in _pendingRequests) {
                  pending.options.headers['Authorization'] = 'Bearer $newToken';
                  try {
                    final retryResponse = await _dio!.fetch(pending.options);
                    pending.handler.resolve(retryResponse);
                  } catch (e) {
                    pending.handler.reject(DioException(
                      requestOptions: pending.options,
                      error: e,
                    ));
                  }
                }
                _pendingRequests.clear();
                
                _isRefreshing = false;
                return handler.resolve(response);
              } catch (refreshError) {
                _isRefreshing = false;
                appLogger.w('Token refresh failed', error: refreshError);
                // Refresh failed - clear tokens and let the error propagate
                await _storage.delete(key: _tokenKey);
                await _storage.delete(key: _refreshTokenKey);
                
                // Reject pending requests
                for (final pending in _pendingRequests) {
                  pending.handler.reject(DioException(
                    requestOptions: pending.options,
                    error: refreshError,
                  ));
                }
                _pendingRequests.clear();
                
                // Return the original error, not the refresh error
                return handler.next(error);
              }
            } else {
              appLogger.w('No refresh token available, clearing access token');
              // No refresh token - clear access token
              await _storage.delete(key: _tokenKey);
            }
          } catch (e) {
            appLogger.w('Error handling 401', error: e);
          }
        }
        return handler.next(error);
      },
    ));

    // Add logging interceptor with enhanced error details
    _dio!.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      requestHeader: true,
      responseHeader: false,
      logPrint: (obj) {
        // Use our logger instead of print
        appLogger.d(obj.toString());
      },
    ));
  }
}
