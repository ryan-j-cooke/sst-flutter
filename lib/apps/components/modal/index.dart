import 'package:flutter/material.dart';
import './modal-header.dart';
import './modal-bg-overlay.dart';
import './modal-body.dart';

class AppModal extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? child;
  final bool showLogo;
  final VoidCallback? onClose;
  final Future<void> Function()? onLogoClicked;
  final double maxWidth;
  final double? maxHeightFactor;
  final EdgeInsets? insetPadding;
  final double padding;
  final EdgeInsets? contentPadding;
  final bool reduceRightPadding;
  final bool showCloseButton;
  final String? closeBtnText;
  final String? confirmBtnText;
  final VoidCallback? onConfirm;
  final Color? confirmBtnColor;
  final double topModalPosition;
  final bool confirmDisabled;
  final bool loading;
  final ValueNotifier<bool>? loadingNotifier;

  const AppModal({
    super.key,
    required this.title,
    this.message,
    this.child,
    this.showLogo = true,
    this.onClose,
    this.onLogoClicked,
    this.maxWidth = 520,
    this.maxHeightFactor,
    this.insetPadding,
    this.padding = 20,
    this.contentPadding,
    this.reduceRightPadding = false,
    this.showCloseButton = true,
    this.closeBtnText,
    this.confirmBtnText,
    this.onConfirm,
    this.confirmBtnColor,
    this.topModalPosition = 150,
    this.confirmDisabled = false,
    this.loading = false,
    this.loadingNotifier,
  });

  /// Shows the AppModal as a dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? child,
    bool showLogo = true,
    VoidCallback? onClose,
    Future<void> Function()? onLogoClicked,
    double maxWidth = 520,
    double? maxHeightFactor,
    EdgeInsets? insetPadding,
    double padding = 20,
    EdgeInsets? contentPadding,
    bool reduceRightPadding = true,
    bool barrierDismissible = true,
    bool showCloseButton = true,
    String? closeBtnText,
    String? confirmBtnText,
    VoidCallback? onConfirm,
    Color? confirmBtnColor,
    double topModalPosition = 150,
    bool confirmDisabled = false,
    bool loading = false,
    ValueNotifier<bool>? loadingNotifier,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppModal(
        title: title,
        message: message,
        child: child,
        showLogo: showLogo,
        onClose: onClose ?? () => Navigator.of(context).pop(),
        onLogoClicked: onLogoClicked,
        maxWidth: maxWidth,
        maxHeightFactor: maxHeightFactor,
        insetPadding: insetPadding,
        padding: padding,
        contentPadding: contentPadding,
        reduceRightPadding: reduceRightPadding,
        showCloseButton: showCloseButton,
        closeBtnText: closeBtnText,
        confirmBtnText: confirmBtnText,
        onConfirm: onConfirm,
        confirmBtnColor: confirmBtnColor,
        topModalPosition: topModalPosition,
        confirmDisabled: confirmDisabled,
        loading: loading,
        loadingNotifier: loadingNotifier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final closeCallback = onClose ?? () => Navigator.of(context).pop();
    final showButtons = closeBtnText != null || confirmBtnText != null;
    final maxHeight =
        MediaQuery.of(context).size.height * (maxHeightFactor ?? 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          insetPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ModalBgOverlay(
        onTap: closeCallback,
        allowDismiss: showCloseButton,
        child: maxHeightFactor != null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: _buildModalContent(closeCallback, showButtons),
              )
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _buildModalContent(closeCallback, showButtons),
              ),
      ),
    );
  }

  Widget _buildModalContent(VoidCallback closeCallback, bool showButtons) {
    return Padding(
      padding: EdgeInsets.only(top: topModalPosition),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Fixed modal body (card without floating elements)
          ModalBody(
            title: title,
            message: message,
            child: child,
            maxWidth: maxWidth,
            maxHeightFactor: maxHeightFactor,
            padding: padding,
            reduceRightPadding: reduceRightPadding,
            showButtons: showButtons,
            closeBtnText: closeBtnText,
            confirmBtnText: confirmBtnText,
            onConfirm: onConfirm,
            onClose: closeCallback,
            confirmDisabled: confirmDisabled,
            loading: loading,
            loadingNotifier: loadingNotifier,
          ),
          // Modal header (logo, close button, and title)
          ModalHeader(
            title: title,
            showLogo: showLogo,
            showCloseButton: showCloseButton,
            onLogoClicked: onLogoClicked,
            onClose: closeCallback,
          ),
        ],
      ),
    );
  }
}
