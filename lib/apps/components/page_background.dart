import 'package:flutter/material.dart';
import 'package:stttest/apps/components/sleek_background.dart';

/// A reusable background component for pages
/// 
/// Wraps content with the app's standard background (SleekBackground)
/// and provides a transparent container for content overlay
class PageBackground extends StatelessWidget {
  final Widget child;
  final bool showBackground;

  const PageBackground({
    super.key,
    required this.child,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: showBackground ? Colors.white : Colors.transparent,
      child: Stack(
        children: [
          // Background - absolute positioning
          if (showBackground)
            const Positioned.fill(child: SleekBackground()),
          // Content - absolute positioning
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

