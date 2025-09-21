import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'theme/purple_theme.dart';
import 'screen/main_layout.dart';
import 'screen/login_screen.dart';
import 'screen/splash_screen.dart';
import 'service/auth_service.dart';
import 'service/notification_service.dart';
import 'service/smart_notification_service.dart';
import 'firebase_options.dart';

// Global route observer for tracking navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone
  tz.initializeTimeZones();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleSignInAccount? _currentUser;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes
    AuthService().onAuthStateChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
    });
    
    // Try silent sign in
    _trySignInSilently();
  }

  Future<void> _trySignInSilently() async {
    final user = await AuthService().signInSilently();
    setState(() {
      _currentUser = user;
      _isInitializing = false;
    });
    
    // Setup notifications if user is signed in
    if (user != null) {
      await _setupNotifications();
    }
  }

  Future<void> _setupNotifications() async {
    final notificationService = NotificationService();
    final smartNotificationService = SmartNotificationService();
    
    // Setup traditional notifications (daily reminders, etc.)
    await notificationService.scheduleDailyReminders();
    await notificationService.runExtendedNotificationChecks(); // This no longer includes quiz reminder
    await notificationService.updateLastActiveDate();
    
    // Initialize smart notification system
    await smartNotificationService.initialize();
  }






  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đông Sơn Go',
      debugShowCheckedModeBanner: false,
      theme: PurpleTheme.getTheme(),
      navigatorObservers: [routeObserver], // Add route observer
      home: _isInitializing 
        ? const SplashScreen()
        : _currentUser != null 
          ? const MainLayout()
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainLayout(),
      },
    );
  }
}

