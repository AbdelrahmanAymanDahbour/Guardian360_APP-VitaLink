import 'package:flutter/material.dart';

/// ==========================================
/// 🗺️ Navigation Helper - Guardian 360
/// ==========================================
/// مساعد التنقل الاحترافي مع حركات انتقال سلسة
class NavigationHelper {
  /// الانتقال مع استبدال الشاشة الحالية
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget destination, {
    RouteTransitionType transition = RouteTransitionType.fade,
  }) {
    return Navigator.pushReplacement(
      context,
      _buildRoute<T>(destination, transition),
    );
  }

  /// الانتقال العادي مع إمكانية العودة
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget destination, {
    RouteTransitionType transition = RouteTransitionType.slide,
  }) {
    return Navigator.push(context, _buildRoute<T>(destination, transition));
  }

  /// الانتقال مع حذف جميع الشاشات السابقة
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Widget destination, {
    bool Function(Route<dynamic>)? predicate,
    RouteTransitionType transition = RouteTransitionType.fade,
  }) {
    return Navigator.pushAndRemoveUntil(
      context,
      _buildRoute<T>(destination, transition),
      predicate ?? (route) => false,
    );
  }

  /// العودة للشاشة السابقة
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    }
  }

  /// بناء المسار مع نوع الانتقال المحدد
  static PageRoute<T> _buildRoute<T>(
    Widget destination,
    RouteTransitionType transition,
  ) {
    switch (transition) {
      case RouteTransitionType.fade:
        return _FadeRoute<T>(page: destination);
      case RouteTransitionType.slide:
        return _SlideRoute<T>(page: destination);
      case RouteTransitionType.scale:
        return _ScaleRoute<T>(page: destination);
      case RouteTransitionType.none:
        return MaterialPageRoute<T>(builder: (_) => destination);
    }
  }
}

/// أنواع حركات الانتقال
enum RouteTransitionType { fade, slide, scale, none }

/// ==========================================
/// 🎨 Custom Route Transitions
/// ==========================================

/// انتقال بالتلاشي (Fade)
class _FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  _FadeRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
}

/// انتقال بالانزلاق (Slide)
class _SlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  _SlideRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      );
}

/// انتقال بالتكبير (Scale)
class _ScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  _ScaleRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeOutBack;

          final tween = Tween(
            begin: 0.8,
            end: 1.0,
          ).chain(CurveTween(curve: curve));

          return ScaleTransition(
            scale: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      );
}
