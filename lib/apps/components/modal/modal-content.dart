import 'package:flutter/material.dart';

/// Modal content component
/// Handles the scrollable content area of the modal
class ModalContent extends StatelessWidget {
  final Widget? child;
  final bool reduceRightPadding;

  const ModalContent({super.key, this.child, this.reduceRightPadding = false});

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}
