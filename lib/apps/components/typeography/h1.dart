import './base_heading.dart';
import 'package:flutter/material.dart';

class H1 extends StatelessWidget {
  final String text;
  final String type;
  final double fontSize;
  final double marginTop;
  final double marginBottom;
  final FontWeight fontWeight;
  final TextAlign align;
  final VoidCallback? onPress;
  final TextStyle? style;

  const H1({
    super.key,
    required this.text,
    this.type = 'primary',
    this.fontSize = 32,
    this.marginTop = 0,
    this.marginBottom = 16,
    this.fontWeight = FontWeight.w700,
    this.align = TextAlign.center,
    this.onPress,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return HeadingBase(
      text: text,
      size: fontSize,
      weight: fontWeight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      align: align,
      type: type,
      onPress: onPress,
      style: style,
      accessibilityLevel: 1,
    );
  }
}
