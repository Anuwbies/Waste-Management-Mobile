import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'Pages/Welcome_Page.dart';
import 'Pages/NavigationBar_Page.dart';
import 'services/auth_service.dart';
import 'services/cnn_classifier.dart';

Future<void> main() async {
  // Set up global error handling
  _setupGlobalErrorHandling();

  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize TFLite CNN classifier in background (non-blocking)
  _initializeCnnClassifier();

  // Wrap app in runZonedGuarded to catch async errors
  runZonedGuarded(
    () => runApp(const WasteManagementApp()),
    (error, stackTrace) {
      debugPrint('[Global] Uncaught async error: $error');
      debugPrint('[Global] Stack trace: $stackTrace');
      // In production, you could send this to a crash reporting service
    },
  );
}

/// Configure Flutter's global error handlers
void _setupGlobalErrorHandling() {
  // Handle Flutter framework errors (e.g., widget build errors)
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FlutterError] ${details.exception}');
    debugPrint('[FlutterError] Stack: ${details.stack}');
    // In debug mode, also show the standard error output
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  // Handle errors outside of the Flutter context
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    debugPrint('[PlatformError] Stack: $stack');
    return true; // Handled
  };
}

/// Initialize CNN classifier asynchronously in background
/// This ensures the model is loaded and ready when user reaches camera
void _initializeCnnClassifier() {
  // Run async without awaiting - don't block app startup
  CnnClassifier.instance.initialize().then((_) {
    debugPrint('[Main] CNN classifier initialized successfully');
  }).catchError((e) {
    debugPrint('[Main] CNN classifier initialization failed: $e');
    // Non-fatal - will be retried when needed
  });
}

class WasteManagementApp extends StatelessWidget {
  const WasteManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waste Management',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// ---------------- AUTH GATE ----------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final isAuth = await _authService.initialize();
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Waiting for auth check
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // User is logged in
    if (_isAuthenticated) {
      return const NavigationBarPage();
    }

    // User is NOT logged in
    return const WelcomePage();
  }
}