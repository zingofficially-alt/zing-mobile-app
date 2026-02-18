import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:zing/AdminPanal/AdminPanalDashBoard.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/SettingProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/screen/MainShell.dart';
import 'package:zing/screen/StartingScreens/CreateAccount.dart';
import 'package:zing/screen/StartingScreens/LoginScreen.dart';
import 'package:zing/screen/StoreManagement/storeManagementScreen.dart';
import 'package:zing/screen/UserScreens/FavouriteStoreScreen.dart';
import 'dart:async';
import 'package:zing/screen/StartingScreens/onboardingScreen.dart';

import 'Cart/CartProvider.dart';
import 'Service/AdvertisementProvider.dart';
import 'Service/RecommendationProvider.dart';
import 'Service/ChatProvider.dart';
import 'Service/NotificationProvider.dart';
import 'Service/OfferProvider.dart';
import 'Service/OrderProvider.dart';
import 'Service/ThemeProvider.dart';

Future<void> requestPermissions() async {
  try {
    debugPrint('Requesting app permissions...');

    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.notification] == PermissionStatus.denied) {
      debugPrint('Notification permission denied');
    } else if (statuses[Permission.notification] == PermissionStatus.permanentlyDenied) {
      debugPrint('Notification permission permanently denied');
    } else if (statuses[Permission.notification] == PermissionStatus.granted) {
      debugPrint('Notification permission granted');
    }

    if (statuses[Permission.locationWhenInUse] == PermissionStatus.denied) {
      debugPrint('Location permission denied');
    } else if (statuses[Permission.locationWhenInUse] == PermissionStatus.permanentlyDenied) {
      debugPrint('Location permission permanently denied');
    } else if (statuses[Permission.locationWhenInUse] == PermissionStatus.granted) {
      debugPrint('Location permission granted');
    } else if (statuses[Permission.locationWhenInUse] == PermissionStatus.limited) {
      debugPrint('Location permission limited (iOS 14+)');
    }
  } catch (e) {
    debugPrint('Error requesting permissions: $e');
  }
}

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception.toString();
    if (exception.contains('semantics') ||
        exception.contains('parentDataDirty') ||
        exception.contains('_needsLayout')) {
      return;
    }
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp();

  if (!kIsWeb && Platform.isIOS) {
    debugPrint('Firebase initialized for iOS');
  }

  await requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CustomUserProvider()..fetchUserDetails()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..fetchGlobalRegistrationAmount()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => OfferProvider()..fetchOffers()),
        ChangeNotifierProvider(create: (_) => AdvertisementProvider()..fetchAdvertisements()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..startListening()),
      ],
      child: const Zing(),
    ),
  );
}

class Zing extends StatelessWidget {
  const Zing({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      themeMode: themeProvider.themeMode,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',
      routes: {
        '/auth': (_) => AuthWrapper(),
        '/splash': (_) => const SplashScreen(),
        '/onboarding': (_) => OnboardingScreen(),
        '/login': (_) => FirebaseLoginScreen(),
        '/createAccount': (_) => CreateAccountScreen(),
        '/home': (_) => const MainShell(),
        '/storeManagement': (_) => const StoreManagementWidget(),
        '/adminPanel': (_) => AdminPanelDashboard(),
        '/favorites': (_) => const FavouriteStoreScreen(),
        '/help': (_) => const HelpSupportPlaceholderScreen(),
      },
    );
  }
}

class HelpSupportPlaceholderScreen extends StatelessWidget {
  const HelpSupportPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Help & Support is coming soon.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const SplashScreen();
          } else {
            return const MainShell();
          }
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// Simplified Splash Screen — clean gradient, logo scale-in, text fade-in, minimal progress
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _progressController.forward();
    });

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _navigateToNext();
    });
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ZingColors.primaryDark,
              ZingColors.primary,
              ZingColors.primaryLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Logo with scale-in
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: Container(
                        width: size.width * 0.35,
                        height: size.width * 0.35,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/zing.png',
                          color: ZingColors.primaryDark,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Title text fade-in
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        Text(
                          'ZING',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MARKETING MASTERY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Minimal progress bar
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progressValue.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
