import 'package:flutter/material.dart';

/// Safe navigation utilities with error handling
class NavigationUtils {
  /// Push a route safely with error handling
  /// Returns true if navigation succeeded, false otherwise
  static Future<bool> pushSafely(
    BuildContext context,
    Widget page, {
    String? routeName,
  }) async {
    if (!_isContextValid(context)) {
      debugPrint('[Navigation] Invalid context for push to ${routeName ?? page.runtimeType}');
      return false;
    }

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => page,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
      );
      return true;
    } catch (e, stack) {
      debugPrint('[Navigation] Push failed: $e');
      debugPrint('[Navigation] Stack: $stack');
      return false;
    }
  }

  /// Push and replace current route safely
  static Future<bool> pushReplacementSafely(
    BuildContext context,
    Widget page, {
    String? routeName,
  }) async {
    if (!_isContextValid(context)) {
      debugPrint('[Navigation] Invalid context for pushReplacement');
      return false;
    }

    try {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => page,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
      );
      return true;
    } catch (e, stack) {
      debugPrint('[Navigation] Push replacement failed: $e');
      debugPrint('[Navigation] Stack: $stack');
      return false;
    }
  }

  /// Pop safely with mounted check
  static bool popSafely(BuildContext context, [dynamic result]) {
    if (!_isContextValid(context)) {
      debugPrint('[Navigation] Invalid context for pop');
      return false;
    }

    try {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, result);
        return true;
      } else {
        debugPrint('[Navigation] Cannot pop - no routes to pop');
        return false;
      }
    } catch (e, stack) {
      debugPrint('[Navigation] Pop failed: $e');
      debugPrint('[Navigation] Stack: $stack');
      return false;
    }
  }

  /// Pop until a specific route
  static bool popUntilSafely(BuildContext context, String routeName) {
    if (!_isContextValid(context)) {
      debugPrint('[Navigation] Invalid context for popUntil');
      return false;
    }

    try {
      Navigator.popUntil(context, ModalRoute.withName(routeName));
      return true;
    } catch (e, stack) {
      debugPrint('[Navigation] PopUntil failed: $e');
      debugPrint('[Navigation] Stack: $stack');
      return false;
    }
  }

  /// Push and clear all previous routes
  static Future<bool> pushAndClearStackSafely(
    BuildContext context,
    Widget page, {
    String? routeName,
  }) async {
    if (!_isContextValid(context)) {
      debugPrint('[Navigation] Invalid context for pushAndClearStack');
      return false;
    }

    try {
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => page,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
        (route) => false,
      );
      return true;
    } catch (e, stack) {
      debugPrint('[Navigation] PushAndClearStack failed: $e');
      debugPrint('[Navigation] Stack: $stack');
      return false;
    }
  }

  /// Check if context is still valid for navigation
  static bool _isContextValid(BuildContext context) {
    try {
      // Check if the widget is still mounted
      final element = context as Element;
      if (!element.mounted) {
        return false;
      }
      // Check if we can find a Navigator
      return Navigator.maybeOf(context) != null;
    } catch (e) {
      return false;
    }
  }
}

/// Extension methods for convenient navigation
extension SafeNavigatorExtension on BuildContext {
  /// Navigate to a page safely
  Future<bool> navigateTo(Widget page, {String? routeName}) {
    return NavigationUtils.pushSafely(this, page, routeName: routeName);
  }

  /// Navigate and replace current page safely
  Future<bool> navigateReplace(Widget page, {String? routeName}) {
    return NavigationUtils.pushReplacementSafely(this, page, routeName: routeName);
  }

  /// Pop back safely
  bool popBack([dynamic result]) {
    return NavigationUtils.popSafely(this, result);
  }

  /// Push and clear stack safely
  Future<bool> navigateClearStack(Widget page, {String? routeName}) {
    return NavigationUtils.pushAndClearStackSafely(this, page, routeName: routeName);
  }
}
