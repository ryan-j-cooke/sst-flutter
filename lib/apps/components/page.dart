import 'package:stttest/apps/components/route_aware_widget.dart';
import 'package:stttest/apps/interfaces/has_route_name.dart';
import 'package:stttest/apps/services/route_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stttest/apps/components/custom_navigation_bar.dart';
import 'package:stttest/apps/components/page_background.dart';
import 'package:stttest/apps/pages/dev/index.dart';
import 'package:stttest/apps/consts/theme.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class AppPage extends StatefulWidget implements HasRouteName {
  final String routeName;
  final Widget? child;
  final bool showBackground;
  final bool headerTransparent;
  final bool hasExtraHeaderPadding;
  final bool centerChildren;
  final String? headerTitle;
  final VoidCallback? onTitlePressed;
  final VoidCallback? onBackButtonPressed;
  final PreferredSizeWidget? appBar;
  final Widget? headerLeft;
  final Widget? headerRight;
  final Brightness? statusBarBrightness;
  final Color? statusBarColor;
  final Color? headerTextColor;
  final bool showBackButton;
  final bool showCustomNavigationBar;

  final double? padding;
  final double? paddingTop;
  final double? paddingBottom;
  final double? paddingLeft;
  final double? paddingRight;

  const AppPage({
    super.key,
    required this.routeName,
    this.child,
    this.showBackground = true,
    this.headerTransparent = true,
    this.hasExtraHeaderPadding = true,
    this.centerChildren = false,
    this.headerTitle,
    this.onTitlePressed,
    this.appBar,
    this.headerLeft,
    this.headerRight,
    this.statusBarBrightness,
    this.statusBarColor,
    this.headerTextColor,
    this.padding,
    this.paddingTop,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingRight,
    this.showBackButton = false,
    this.showCustomNavigationBar = true,
    this.onBackButtonPressed,
  });

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage>
    with RouteAware, RouteAwareWidget<AppPage> {
  SystemUiOverlayStyle? _overlayStyle;

  void initState() {
    super.initState();
    RouteService().setCurrentRoute(widget.routeName);
  }

  // Helper: determine Android platform safely (works on web too)
  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  // Hide navigation bar when navigating to/from this page
  void _hideNavigationBar() {
    if (_isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: const [SystemUiOverlay.top],
        );
      });
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
      // System bar is hidden
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    // Listen for system UI changes to track navigation bar visibility
    if (_isAndroid && widget.showCustomNavigationBar) {
      SystemChrome.setSystemUIChangeCallback(_onSystemUIChange);
    }

    _updateOverlay();
  }

  Future<void> _onSystemUIChange(bool systemOverlaysAreVisible) async {
    // Update system UI overlay style when bar visibility changes
    if (mounted && widget.showCustomNavigationBar) {
      if (systemOverlaysAreVisible) {
        // When system bar is visible, make it light themed
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: _overlayStyle?.statusBarColor ?? Colors.transparent,
            statusBarIconBrightness:
                _overlayStyle?.statusBarIconBrightness ?? Brightness.light,
            statusBarBrightness:
                _overlayStyle?.statusBarBrightness ?? Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
      } else {
        // When system bar is hidden, restore original overlay style
        _applyOverlay();
      }
    }
  }

  void _updateOverlay() {
    final Brightness effectiveBrightness =
        widget.statusBarBrightness ?? Brightness.light;

    _overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Always transparent
      statusBarIconBrightness: effectiveBrightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: effectiveBrightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    );

    _applyOverlay();
  }

  void _applyOverlay() {
    if (_overlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_overlayStyle!);
    }

    // Only set overlay style, don't hide bar here - let navigation callbacks handle hiding
  }

  @override
  void didPush() {
    RouteService().setCurrentRoute(widget.routeName);
    // Hide navigation bar when navigating to this page
    _hideNavigationBar();
    _applyOverlay();
  }

  @override
  void didPopNext() {
    RouteService().setCurrentRoute(widget.routeName);
    // Hide navigation bar when returning to this page
    _hideNavigationBar();
    _applyOverlay();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);

    // Remove system UI change callback
    if (_isAndroid) {
      SystemChrome.setSystemUIChangeCallback(null);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    // Use fixed bottom padding - ignore actual navigation bar height to prevent content shifting
    // Always use fixed height for custom nav bar (56px) regardless of system bar visibility
    final double fixedBottomPadding = widget.showCustomNavigationBar
        ? 56.0
        : 0.0;
    final double headerHeight = kToolbarHeight;

    final double topExtraPadding = widget.hasExtraHeaderPadding
        ? (_isAndroid ? 0 : statusBarHeight)
        : 0;

    // Use fixed bottom padding - don't react to system navigation bar changes
    // This prevents content from shifting when user swipes up the navigation bar
    final double bottomPadding =
        (widget.paddingBottom ?? 0) + fixedBottomPadding;

    final EdgeInsets finalPadding = widget.padding != null
        ? EdgeInsets.fromLTRB(
            widget.padding!,
            widget.padding!,
            widget.padding!,
            widget.padding! + fixedBottomPadding, // Use fixed bottom padding
          )
        : EdgeInsets.only(
            top: (widget.paddingTop ?? 0) + topExtraPadding,
            bottom: bottomPadding,
            left: widget.paddingLeft ?? 0,
            right: widget.paddingRight ?? 0,
          );

    Widget contentWidget = widget.child ?? const SizedBox.shrink();
    if (widget.centerChildren) {
      contentWidget = Center(child: contentWidget);
    }
    // Use absolute positioning - content doesn't react to navigation bar visibility
    final Widget content = Padding(padding: finalPadding, child: contentWidget);

    final bool canPop = Navigator.canPop(context);
    final bool showHeader =
        widget.appBar != null ||
        widget.headerTitle != null ||
        widget.headerLeft != null ||
        (canPop && widget.showBackButton);

    PreferredSizeWidget? defaultAppBar;
    if (showHeader) {
      if (widget.appBar != null) {
        defaultAppBar = widget.appBar;
      } else {
        defaultAppBar = AppBar(
          backgroundColor: widget.headerTransparent
              ? Colors.transparent
              : AppColors.secondary,
          elevation: widget.headerTransparent ? 0 : 4,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: widget.headerTextColor ?? Colors.white,
          ),
          title: widget.headerTitle != null
              ? (widget.onTitlePressed != null
                    ? GestureDetector(
                        onTap: widget.onTitlePressed,
                        child: Text(
                          widget.headerTitle!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: widget.headerTextColor ?? Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Text(
                        widget.headerTitle!,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: widget.headerTextColor ?? Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ))
              : null,
          leading:
              widget.headerLeft ??
              (canPop && widget.showBackButton
                  ? IconButton(
                      icon: Icon(
                        _isAndroid ? Icons.arrow_back : Icons.chevron_left,
                        color: widget.headerTextColor ?? Colors.white,
                        size: 24,
                      ),
                      onPressed: () => {
                        widget.onBackButtonPressed?.call(),
                        Navigator.pop(context),
                      },
                    )
                  : null),
          actions: widget.headerRight != null ? [widget.headerRight!] : null,
          toolbarHeight: headerHeight,
          systemOverlayStyle: _overlayStyle ?? SystemUiOverlayStyle.light,
        );
      }
    } else {
      defaultAppBar = null;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: widget.headerTransparent,
      appBar: defaultAppBar,
      body: PageBackground(
        showBackground: widget.showBackground,
        child: Stack(
          children: [
            // Content - absolute positioning, doesn't react to navigation bar
            Positioned.fill(child: content),
            // Custom navigation bar - absolute bottom position, ignore safe area
            // Always visible regardless of system navigation bar visibility
            if (widget.showCustomNavigationBar && _isAndroid)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomNavigationBar(
                  onDevPage: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DevPage()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
