import 'package:flutter/material.dart';

// -----------------------------
// Color definitions
// -----------------------------
class AppColors {
  static const Color primary = Color(0xFFDD5FD3);
  static const Color secondary = Color(0xFF1E90FF);
  static const Color info = Color(0xFF17A2B8);
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFDC3545);

  static const Color dark = Color(0xFF343A40);
  static const Color muted = Color(0xFF6C757D);
  static const Color light = Color(0xFFF8F9FA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color softBlue = Color.fromRGBO(30, 144, 255, 1);
  static const Color boldBlue = Color.fromRGBO(30, 64, 175, 1);

  // Subtitle colors
  static const Color subtitleInfo = Color.fromRGBO(30, 144, 255, 1);
  static const Color subtitleDanger = Color.fromRGBO(255, 0, 0, 1);
}

// -----------------------------
// Helper: hex to rgba with alpha
// -----------------------------
Color hexToRgbaLighter(String hex, double alpha) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) {
    final int intVal = int.parse(hex, radix: 16);
    final int r = (intVal >> 16) & 0xFF;
    final int g = (intVal >> 8) & 0xFF;
    final int b = intVal & 0xFF;
    return Color.fromRGBO(r, g, b, alpha);
  } else {
    throw FormatException('Invalid hex color');
  }
}

// -----------------------------
// Header / AppBar style
// -----------------------------
class TSHeader {
  static const Brightness barBrightness = Brightness.dark;
  static final Color backgroundColor = AppColors.secondary;
}

// -----------------------------
// Card drop shadow
// -----------------------------
class TSCardDropShadow {
  static const Color shadowColor = Colors.black;
  static const Offset shadowOffset = Offset(0, 2);
  static const double shadowOpacity = 0.15;
  static const double shadowRadius = 6.0;
  static const double elevation = 4.0;

  static BoxDecoration get boxDecoration {
    return BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: shadowColor.withValues(alpha: shadowOpacity),
          offset: shadowOffset,
          blurRadius: shadowRadius,
        ),
      ],
    );
  }
}
