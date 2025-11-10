import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger.dart';

// HTTP client for Day Party backend
// Automatically detects emulator vs physical device and sets baseUrl accordingly
class ApiClient {
  // Backend endpoints
  static const String _azureVmBaseUrl = 'https://dayparty.work.gd/api';
  static const String _localDeviceBaseUrl = 'http://192.168.0.101:3000/api';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:3000/api';

  // Toggle between Azure VM and local development backend
  static const bool _useAzureVm = true;

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

        if (_useAzureVm) {
          // Use Azure VM for both emulator and physical device
          appLogger.d('Using Azure VM backend: $_azureVmBaseUrl');
          return _azureVmBaseUrl;
        } else {
          // Use local backend
          if (isEmulator) {
            appLogger.d('Detected Android emulator - using $_androidEmulatorBaseUrl');
            return _androidEmulatorBaseUrl;
          } else {
            appLogger.d('Detected physical Android device - using $_localDeviceBaseUrl');
            return _localDeviceBaseUrl;
          }
        }
      } catch (e) {
        appLogger.w('Error detecting device type, defaulting to emulator', error: e);
        return _androidEmulatorBaseUrl;
      }
    } else if (Platform.isIOS) {
      if (_useAzureVm) {
        return _azureVmBaseUrl;
      } else {
        return _localDeviceBaseUrl;
      }
    }

    // Default fallback
    if (_useAzureVm) {
      return _azureVmBaseUrl;
    } else {
      return 'http://localhost:3000/api';
    }
  }

  static const String _tokenKey = 'jwt_token';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static Dio? _dio;

  static Dio get instance {
    _dio ??= Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    return _dio!;
  }

  /// Initialize the API client and detect device type
  static Future<void> initialize() async {
    // This will trigger device detection and set _baseUrl
    final url = await _determineBaseUrl();
    _baseUrl = url;

    // Create Dio instance with the determined baseUrl
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

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

    // Add logging interceptor
    _dio!.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }
}
