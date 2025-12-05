import '../../../consts/theme.dart';
import 'package:flutter/material.dart';

class HeadingBase extends StatelessWidget {
  final String text;
  final String type; // color key (e.g., 'primary')
  final double size; // font size
  final FontWeight weight;
  final double marginBottom;
  final double marginTop;
  final TextAlign align;
  final VoidCallback? onPress;
  final int? accessibilityLevel; // for semantics
  final TextStyle? style;

  const HeadingBase({
    super.key,
    required this.text,
    this.type = 'primary',
    required this.size,
    this.weight = FontWeight.w600,
    this.marginBottom = 8.0,
    this.marginTop = 0.0,
    this.align = TextAlign.center,
    this.onPress,
    this.accessibilityLevel,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = _getColor(type);

    final textWidget = Text(
      text,
      textAlign: align,
      style:
          style?.copyWith(fontSize: size, fontWeight: weight, color: color) ??
          TextStyle(fontSize: size, fontWeight: weight, color: color),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom, top: marginTop),
      child: onPress != null
          ? GestureDetector(onTap: onPress, child: textWidget)
          : textWidget,
    );
  }

  Color _getColor(String type) {
    switch (type) {
      case 'primary':
        return AppColors.primary;
      case 'secondary':
        return AppColors.secondary;
      case 'info':
        return AppColors.info;
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'danger':
        return AppColors.danger;
      case 'dark':
        return AppColors.dark;
      case 'muted':
        return AppColors.muted;
      case 'light':
        return AppColors.light;
      case 'white':
        return AppColors.white;
      case 'black':
        return AppColors.black;
      default:
        return AppColors.primary;
    }
  }
}
