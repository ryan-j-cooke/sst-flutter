import 'package:flutter/material.dart';

/// Modal header logo component
class ModalHeaderLogo extends StatelessWidget {
  final Future<void> Function()? onTap;

  const ModalHeaderLogo({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -66,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background logo
              Image.asset(
                'assets/images/logo-card-bg.png',
                width: 72 * 1.25,
                height: 72 * 1.15,
                fit: BoxFit.contain,
              ),
              // Foreground logo with offset
              Transform.translate(
                offset: const Offset(1, 15),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
