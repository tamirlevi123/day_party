import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger.dart';

// HTTP client for Day Party backend
// Automatically detects emulator vs physical device and sets baseUrl accordingly
class ApiClient {
  // Backend endpoints
  static const String _azureVmBaseUrl = 'https://dayparty.work.gd/api';
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
  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

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
        // Handle 401 Unauthorized - token expired
        if (error.response?.statusCode == 401) {
          try {
            // Clear token and redirect to login
            await _storage.delete(key: _tokenKey);
            // You might want to emit an event here to notify the app
          } catch (e) {
            appLogger.w('Error deleting token', error: e);
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
