import 'package:flutter/material.dart';
import './header-logo.dart';
import './close-button.dart';

/// Modal header component
/// Combines the header logo, close button, and title
class ModalHeader extends StatelessWidget {
  final String title;
  final bool showLogo;
  final bool showCloseButton;
  final Future<void> Function()? onLogoClicked;
  final VoidCallback? onClose;
  final Color? closeBtnColor;

  const ModalHeader({
    super.key,
    required this.title,
    this.showLogo = true,
    this.showCloseButton = true,
    this.onLogoClicked,
    this.onClose,
    this.closeBtnColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Floating logo (positioned relative to modal container, not scrollable content)
        if (showLogo) ModalHeaderLogo(onTap: onLogoClicked),

        // Floating close button (positioned relative to modal container, not scrollable content)
        if (showCloseButton)
          ModalCloseButton(
            onTap: onClose ?? () => Navigator.of(context).pop(),
            color: closeBtnColor,
          ),
      ],
    );
  }
}
