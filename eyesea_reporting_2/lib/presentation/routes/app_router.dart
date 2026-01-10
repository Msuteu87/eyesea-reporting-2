import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';

class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';

  static final GoRouter router = GoRouter(
    initialLocation: home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
