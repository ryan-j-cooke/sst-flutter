import 'package:flutter/material.dart';
import '../../../consts/theme.dart';

class AppCard extends StatelessWidget {
  final String? title;
  final String? message;
  final bool showLogo;
  final VoidCallback? onClose;
  final Future<void> Function()? onLogoClicked;
  final double maxWidth;
  final double padding;
  final double? topPadding;
  final EdgeInsets? contentPadding;
  final Widget? child;
  final bool safe;
  final double keyboardOffset;
  final String iosBehavior;
  final bool animateBody;
  final Widget? titleWidget;
  final Widget? messageWidget;
  final Widget? bodyWidget;

  const AppCard({
    super.key,
    this.title,
    this.message,
    this.showLogo = true,
    this.onClose,
    this.onLogoClicked,
    this.maxWidth = 520,
    this.padding = 20,
    this.topPadding,
    this.contentPadding = const EdgeInsets.all(20),
    this.child,
    this.safe = false,
    this.keyboardOffset = 0,
    this.iosBehavior = 'padding',
    this.animateBody = false,
    this.titleWidget,
    this.messageWidget,
    this.bodyWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: EdgeInsets.only(
              top: topPadding ?? (showLogo ? padding + 25 : padding),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              // color: Colors.red,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: contentPadding ?? EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (titleWidget != null ||
                          (title != null && title!.isNotEmpty))
                        titleWidget ??
                            Text(
                              title!,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                      if (message != null && message!.isNotEmpty)
                        messageWidget ??
                            Text(
                              message!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                      if ((titleWidget != null ||
                              (title != null && title!.isNotEmpty)) ||
                          (message != null && message!.isNotEmpty))
                        const SizedBox(height: 16),
                      if (bodyWidget != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight > 0
                                ? constraints.maxHeight - 100
                                : double.infinity,
                          ),
                          child: bodyWidget!,
                        )
                      else if (child != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight > 0
                                ? constraints.maxHeight - 100
                                : double.infinity,
                          ),
                          child: child!,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Logo (clickable)
        if (showLogo)
          Positioned(
            top: -66,
            child: GestureDetector(
              onTap: onLogoClicked,
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
          ),

        // Close button
        if (onClose != null)
          Positioned(
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: onClose,
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
          ),
      ],
    );

    if (safe) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: keyboardOffset),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
