import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'core/api_client.dart';
import 'core/logger.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/thread_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/thread_list_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'screens/create_node_screen.dart';
import 'screens/create_thread_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API client (detects emulator vs physical device)
  await ApiClient.initialize();
  
  // Setup API logging for debugging
  ApiClient.setupInterceptors();
  
  runApp(const DayPartyApp());
}

class DayPartyApp extends StatefulWidget {
  const DayPartyApp({super.key});

  @override
  State<DayPartyApp> createState() => _DayPartyAppState();
}

class _DayPartyAppState extends State<DayPartyApp> {
  final _appLinks = AppLinks();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // Delay deep link initialization to ensure MaterialApp is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
      // On web, check for OAuth callback in URL
      if (kIsWeb) {
        _checkWebOAuthCallback();
      }
    });
  }

  // Check for OAuth callback in URL (web only)
  void _checkWebOAuthCallback() {
    final uri = Uri.base;
    
    // Check if this is an OAuth callback
    if (uri.path == '/auth/callback' && uri.queryParameters.containsKey('code')) {
      appLogger.d('Detected OAuth callback in URL: $uri');
      
      // Wait a bit for providers to be ready
      Future.delayed(const Duration(milliseconds: 500), () {
        final navigatorContext = _navigatorKey.currentContext;
        if (navigatorContext == null) {
          // Retry if context not ready
          Future.delayed(const Duration(milliseconds: 500), () => _checkWebOAuthCallback());
          return;
        }
        
        final authProvider = Provider.of<AuthProvider>(navigatorContext, listen: false);
        final navigator = _navigatorKey.currentState;
        
        // Build the full callback URL
        final callbackUrl = uri.toString();
        
        // Handle the OAuth callback
        authProvider.handleOAuthCallback(callbackUrl).then((success) {
          if (!mounted || navigator == null) return;
          
          if (success) {
            // Clear the URL parameters and navigate to home
            // On web, we can use window.history.replaceState to clean the URL
            if (kIsWeb) {
              // Import dart:html if needed, or use a different approach
              // For now, just navigate - the URL will stay but that's okay
            }
            
            // Navigate to home screen on success
            navigator.pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          } else {
            // Show error if failed
            if (mounted) {
              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                  content: Text(authProvider.error ?? 'שגיאה בהתחברות'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }).catchError((error) {
          appLogger.e('Error handling OAuth callback', error: error);
          if (mounted) {
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text('שגיאה: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      });
    }
  }

  void _initDeepLinks() {
    // Handle deep link when app is opened from a terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Handle deep link when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        appLogger.e('Deep link error', error: err);
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    appLogger.d('Received deep link: $uri');
    
    // Check if this is an OAuth callback
    if (uri.scheme == 'dayparty' && 
        uri.host == 'auth' && 
        uri.path == '/callback') {
      
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext == null) {
        appLogger.w('Navigator context not available yet, delaying deep link handling');
        // Retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), () => _handleDeepLink(uri));
        return;
      }
      
      final authProvider = Provider.of<AuthProvider>(navigatorContext, listen: false);
      
      // Build the full callback URL
      final callbackUrl = uri.toString();
      
      // Capture navigator before async operation
      final navigator = _navigatorKey.currentState;
      
      // Handle the OAuth callback
      authProvider.handleOAuthCallback(callbackUrl).then((success) {
        if (!mounted || navigator == null) return;
        
        if (success) {
          // Navigate to home screen on success
          navigator.pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        } else {
          // Show error if failed - use scaffoldMessengerKey to avoid BuildContext
          if (mounted) {
            _scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text(authProvider.error ?? 'שגיאה בהתחברות'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }).catchError((error) {
        appLogger.e('Error handling OAuth callback', error: error);
        if (mounted) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('שגיאה: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ThreadProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        title: 'Day Party',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2), // Primary Blue from design
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('he', 'IL'), // Hebrew
          Locale('en', 'US'), // English
        ],
        locale: const Locale('he', 'IL'), // Force RTL
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/threads': (context) {
            final topicId = ModalRoute.of(context)!.settings.arguments as String;
            return ThreadListScreen(topicId: topicId);
          },
          '/thread-detail': (context) {
            final threadId = ModalRoute.of(context)!.settings.arguments as String;
            return ThreadDetailScreen(threadId: threadId);
          },
          '/create-node': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return CreateNodeScreen(
              threadId: args['threadId'] as String,
              parentNodeId: args['parentNodeId'] as String?,
              title: args['title'] as String?,
            );
          },
          '/create-thread': (context) {
            final topicId = ModalRoute.of(context)!.settings.arguments as String;
            return CreateThreadScreen(topicId: topicId);
          },
        },
      ),
    );
  }
}
