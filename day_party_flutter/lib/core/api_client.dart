import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger.dart';

// HTTP client for Day Party backend
// Automatically detects emulator vs physical device and sets baseUrl accordingly
class ApiClient {
  // Azure VM IP for production backend
  static const String _azureVmIp = '172.167.43.172';
  
  // Local IP for physical device testing (when backend is running locally)
  // To find your IP: Windows (ipconfig), Mac/Linux (ifconfig or ip addr)
  // Look for IPv4 address on your local network (usually starts with 192.168.x.x or 10.x.x.x)
  static const String _localDeviceIp = '192.168.0.101'; // LAN IP for local testing
  
  // Set to true to use Azure VM, false to use local backend
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
        // Emulators typically have "sdk", "generic", or "google_sdk" in model/product/device
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
          appLogger.d('Using Azure VM backend: $_azureVmIp');
          return 'http://$_azureVmIp/api';
        } else {
          // Use local backend
          if (isEmulator) {
            appLogger.d('Detected Android emulator - using 10.0.2.2');
            return 'http://10.0.2.2:3000/api';
          } else {
            appLogger.d('Detected physical Android device - using $_localDeviceIp');
            return 'http://$_localDeviceIp:3000/api';
          }
        }
      } catch (e) {
        appLogger.w('Error detecting device type, defaulting to emulator', error: e);
        return 'http://10.0.2.2:3000/api';
      }
    } else if (Platform.isIOS) {
      if (_useAzureVm) {
        return 'http://$_azureVmIp/api';
      } else {
        return 'http://$_localDeviceIp:3000/api';
      }
    }
    
    // Default fallback
    if (_useAzureVm) {
      return 'http://$_azureVmIp/api';
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

