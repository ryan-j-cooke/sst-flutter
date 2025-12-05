import 'package:flutter/material.dart';
import '../bts/primary.dart';
import '../bts/secondary.dart';
import '../../../intl/intl.dart';

/// Modal footer component
class ModalFooter extends StatelessWidget {
  final String? closeBtnText;
  final String? confirmBtnText;
  final VoidCallback? onConfirm;
  final VoidCallback onClose;
  final bool confirmDisabled;
  final bool loading;
  final ValueNotifier<bool>? loadingNotifier;

  const ModalFooter({
    super.key,
    this.closeBtnText,
    this.confirmBtnText,
    this.onConfirm,
    required this.onClose,
    required this.confirmDisabled,
    this.loading = false,
    this.loadingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final showButtons = closeBtnText != null || confirmBtnText != null;

    if (!showButtons) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (closeBtnText != null)
                Expanded(
                  child: SecondaryButton(
                    title: closeBtnText ?? ct('close'),
                    onPressed: onClose,
                  ),
                ),
              if (closeBtnText != null && confirmBtnText != null)
                const SizedBox(width: 12),
              if (confirmBtnText != null)
                Expanded(
                  child: PrimaryButton(
                    title: confirmBtnText ?? ct('confirm'),
                    onPressed: onConfirm ?? onClose,
                    disabled: confirmDisabled,
                    loading: loading,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
