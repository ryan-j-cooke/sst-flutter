import 'package:flutter/material.dart';
import '../../../consts/theme.dart';

/// Modal close button component
class ModalCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;

  const ModalCloseButton({
    super.key,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -5,
      right: -10,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text(
            '×',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
