import 'package:flutter/material.dart';
import 'package:zing/screen/HomeScreen.dart';
import 'package:zing/screen/MainShell.dart';
import 'package:zing/screen/SearchExploreScreen.dart';
import 'package:zing/screen/NotificationsScreen.dart';
import 'package:zing/screen/StartingScreens/CreateAccount.dart';
import 'package:zing/screen/StartingScreens/LoginScreen.dart';
import 'package:zing/screen/StartingScreens/onboardingScreen.dart';
import 'package:zing/screen/UserScreens/OrderHistoryPage.dart';
import 'package:zing/main.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String createAccount = '/createAccount';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String orders = '/orders';

  static Map<String, WidgetBuilder> get routes => {
    auth: (_) => AuthWrapper(),
    splash: (_) => const SplashScreen(),
    onboarding: (_) => OnboardingScreen(),
    login: (_) => FirebaseLoginScreen(),
    createAccount: (_) => CreateAccountScreen(),
    home: (_) => const MainShell(),
    search: (_) => const SearchExploreScreen(),
    notifications: (_) => const NotificationsScreen(),
    orders: (_) => OrderHistoryPage(),
  };

  /// Standard page transition: fade + slide-up
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
    }
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('Route not found')),
      ),
    );
  }
}
