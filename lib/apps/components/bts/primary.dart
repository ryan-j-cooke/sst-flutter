import '../../../consts/theme.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatefulWidget {
  final String? title;
  final Widget? child;
  final VoidCallback onPressed;
  final bool loading;
  final bool disabled;
  final bool fullWidth;
  final double height;
  final TextStyle? textStyle;
  final String? accessibilityLabel;
  final Key? testKey;

  const PrimaryButton({
    super.key,
    this.title,
    this.child,
    required this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.fullWidth = false,
    this.height = 50,
    this.textStyle,
    this.accessibilityLabel,
    this.testKey,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) {
      setState(() {
        _pressed = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.disabled || widget.loading;

    return GestureDetector(
      key: widget.testKey,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed && !isDisabled ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: Container(
          height: widget.height,
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey : AppColors.primary,
            borderRadius: BorderRadius.circular(25),
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : widget.child ??
                    Text(
                      widget.title ?? '',
                      style:
                          widget.textStyle ??
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                    ),
        ),
      ),
    );
  }
}
