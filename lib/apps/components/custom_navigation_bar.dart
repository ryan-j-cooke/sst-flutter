import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomNavigationBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final VoidCallback? onRecent;
  final VoidCallback? onDevPage;

  const CustomNavigationBar({
    super.key,
    this.onBack,
    this.onHome,
    this.onRecent,
    this.onDevPage,
  });

  static const MethodChannel _channel = MethodChannel(
    'io.stttest.app/app_minimize',
  );

  Future<void> _handleHome(BuildContext context) async {
    // On Android, minimize the app to background (like pressing home button)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('moveTaskToBack', true);
      } catch (e) {
        // If platform channel fails, fallback to navigation
        if (context.mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        }
      }
    } else {
      // On other platforms, just navigate to root
      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    }
  }

  void _handleBack(BuildContext context) {
    final route = ModalRoute.of(context);
    final routeName = route?.settings.name ?? '';

    // Check if we're on entry page or home page (after login)
    // These pages typically have '/' or '/entry' or '/home' as route names
    // or we can check if we can't pop (meaning we're at root)
    final isEntryOrHomePage =
        !Navigator.canPop(context) ||
        routeName == '/' ||
        routeName.contains('entry') ||
        routeName.contains('home');

    // On entry/home pages, minimize the app instead of going back
    if (isEntryOrHomePage && !kIsWeb && Platform.isAndroid) {
      _channel.invokeMethod<bool>('moveTaskToBack', true).catchError((e) {
        // If platform channel fails, do nothing (can't navigate back anyway)
        return false;
      });
    } else if (Navigator.canPop(context)) {
      // Normal back behavior for other pages
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    // Use fixed height - ignore safe area to prevent content shifting
    // This prevents UI animation when system navigation bar appears/disappears
    final fixedHeight = 56.0;

    // Determine if back button should minimize (on entry/home pages) or navigate back
    final route = ModalRoute.of(context);
    final routeName = route?.settings.name ?? '';
    final isEntryOrHomePage =
        !canPop ||
        routeName == '/' ||
        routeName.contains('entry') ||
        routeName.contains('home');

    // Show back button if we can pop OR if we're on entry/home page (to allow minimizing)
    final showBackButton = canPop || isEntryOrHomePage;

    return Container(
      height: fixedHeight,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        // Add subtle background blur/glass effect for light theme
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            // Dev page button (left) - opens dev tools
            Expanded(
              child: _NavButton(
                icon: Icons.apps,
                enabled: true,
                onPressed: onDevPage ?? (onHome ?? () => _handleHome(context)),
              ),
            ),
            // Home button (middle) - goes home
            Expanded(
              child: _NavButton(
                icon: Icons.home,
                enabled: true,
                onPressed: onHome ?? () => _handleHome(context),
              ),
            ),
            // Back button (moved to right)
            Expanded(
              child: _NavButton(
                icon: Icons.arrow_back_ios,
                enabled: showBackButton,
                onPressed: showBackButton
                    ? (onBack ?? () => _handleBack(context))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _NavButton({
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(0),
        splashColor: Colors.black.withValues(alpha: 0.1),
        highlightColor: Colors.black.withValues(alpha: 0.05),
        child: SizedBox.expand(
          child: Center(
            child: Icon(
              icon,
              color: Colors.black.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

