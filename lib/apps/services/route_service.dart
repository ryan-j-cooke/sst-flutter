import 'package:flutter/material.dart';

class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  String? _currentRouteName;
  String? get currentRouteName => _currentRouteName;

  void setCurrentRoute(String? route) {
    _currentRouteName = route;
  }
}

