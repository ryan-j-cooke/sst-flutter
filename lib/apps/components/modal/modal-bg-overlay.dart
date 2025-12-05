import 'package:flutter/material.dart';

/// Modal background overlay component
/// Handles the clickable background that can close the modal
class ModalBgOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool allowDismiss;

  const ModalBgOverlay({
    super.key,
    required this.child,
    this.onTap,
    this.allowDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: allowDismiss ? (onTap ?? () => Navigator.of(context).pop()) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap:
              () {}, // Prevent tap from propagating when clicking on modal content
          child: child,
        ),
      ),
    );
  }
}
