import 'package:flutter/material.dart';
import '../cards/index.dart';
import './modal-content.dart';
import './modal-footer.dart';

/// Modal body component
/// Handles the card structure with content and footer
class ModalBody extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? child;
  final double maxWidth;
  final double? maxHeightFactor;
  final double? minHeight;
  final double? maxHeight;
  final double padding;
  final bool reduceRightPadding;
  final bool showButtons;
  final String? closeBtnText;
  final String? confirmBtnText;
  final VoidCallback? onConfirm;
  final VoidCallback onClose;
  final bool confirmDisabled;
  final bool loading;
  final ValueNotifier<bool>? loadingNotifier;

  const ModalBody({
    super.key,
    required this.title,
    this.message,
    this.child,
    required this.maxWidth,
    this.maxHeightFactor,
    this.minHeight,
    this.maxHeight,
    required this.padding,
    this.reduceRightPadding = false,
    required this.showButtons,
    this.closeBtnText,
    this.confirmBtnText,
    this.onConfirm,
    required this.onClose,
    this.confirmDisabled = false,
    this.loading = false,
    this.loadingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate constraints if any height parameters are provided
    BoxConstraints? outerConstraints;
    if (minHeight != null || maxHeight != null || maxHeightFactor != null) {
      final screenHeight = MediaQuery.of(context).size.height;
      final calculatedMaxHeight =
          maxHeight ??
          (maxHeightFactor != null ? screenHeight * maxHeightFactor! : null);

      outerConstraints = BoxConstraints(
        minHeight: minHeight ?? 0,
        maxHeight: calculatedMaxHeight ?? double.infinity,
      );
    }

    // Calculate content constraints if height parameters are provided
    BoxConstraints? contentConstraints;
    if (minHeight != null || maxHeight != null || maxHeightFactor != null) {
      final screenHeight = MediaQuery.of(context).size.height;
      final calculatedMaxHeight =
          maxHeight ??
          (maxHeightFactor != null ? screenHeight * maxHeightFactor! : null);

      if (calculatedMaxHeight != null) {
        contentConstraints = BoxConstraints(
          maxHeight: calculatedMaxHeight - (showButtons ? 220 : 150),
        );
      }
    }

    Widget cardContent = AppCard(
      title: title,
      message: message,
      showLogo: false, // Don't show logo in card, we'll add it separately
      onClose: null, // Don't show close in card, we'll add it separately
      onLogoClicked: null,
      maxWidth: maxWidth,
      padding: padding,
      // this is what controls the padding of the card / entire modal content
      contentPadding: const EdgeInsets.only(
        right: 15,
        left: 15,
        top: 15,
        bottom: 0,
      ),
      bodyWidget: contentConstraints != null
          ? ConstrainedBox(
              constraints: contentConstraints,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrollable content
                  Expanded(
                    child: ModalContent(
                      child: child,
                      reduceRightPadding: reduceRightPadding,
                    ),
                  ),
                  // Buttons at bottom (always visible)
                  ModalFooter(
                    closeBtnText: closeBtnText,
                    confirmBtnText: confirmBtnText,
                    onConfirm: onConfirm,
                    onClose: onClose,
                    confirmDisabled: confirmDisabled,
                    loading: loading,
                    loadingNotifier: loadingNotifier,
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrollable content
                ModalContent(
                  child: child,
                  reduceRightPadding: reduceRightPadding,
                ),
                // Buttons at bottom (always visible)
                ModalFooter(
                  closeBtnText: closeBtnText,
                  confirmBtnText: confirmBtnText,
                  onConfirm: onConfirm,
                  onClose: onClose,
                  confirmDisabled: confirmDisabled,
                  loading: loading,
                  loadingNotifier: loadingNotifier,
                ),
              ],
            ),
    );

    // Wrap with constraints only if provided
    if (outerConstraints != null) {
      return ConstrainedBox(constraints: outerConstraints, child: cardContent);
    }

    return cardContent;
  }
}
