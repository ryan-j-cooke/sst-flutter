import 'package:stttest/apps/interfaces/has_route_name.dart';
import 'package:stttest/apps/services/route_service.dart';
import 'package:flutter/material.dart';

mixin RouteAwareWidget<T extends StatefulWidget> on State<T>
    implements RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute? route = ModalRoute.of(context);
    if (route is PageRoute) {
      RouteService().routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    RouteService().routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    if (widget is HasRouteName) {
      RouteService().setCurrentRoute((widget as HasRouteName).routeName);
    }
  }

  @override
  void didPopNext() {
    if (widget is HasRouteName) {
      RouteService().setCurrentRoute((widget as HasRouteName).routeName);
    }
  }
}

