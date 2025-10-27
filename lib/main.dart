import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'theme/purple_theme.dart';
import 'screen/main_layout.dart';
// import 'screen/login_screen.dart';
import 'screen/splash_screen.dart';
// import 'service/auth_service.dart';
import 'service/notification_manager.dart';
import 'service/notification_fix_service.dart';
import 'firebase_options.dart';

// Global route observer for tracking navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background messaging handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone
  tz.initializeTimeZones();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Fix notification issues first
  await NotificationFixService.fixNotificationIssues();
  
  // Initialize notification manager
  await NotificationManager().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _startSplashCountdown();
    _setupFirebaseMessaging();
  }

  Future<void> _startSplashCountdown() async {
    await _setupNotifications();
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _setupNotifications() async {
    final notificationManager = NotificationManager();
    
    // Schedule daily reminders (only once per day)
    await notificationManager.scheduleDailyReminders();
    
    // Run controlled notification checks (with cooldowns)
    await notificationManager.runControlledNotificationChecks();
    
    // Update last active date
    await notificationManager.updateLastActiveDate();
    
    print('📱 Notification system initialized with smart controls');
  }

  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Get the device token
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // Handle messages when the app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App opened from terminated state with message: ${message.messageId}');
      }
    });

    // Handle interaction when the app is in the background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background with message: ${message.messageId}');
    });
  }


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đông Sơn Go',
      debugShowCheckedModeBanner: false,
      theme: PurpleTheme.getTheme(),
      navigatorObservers: [routeObserver], // Add route observer
      home: _isInitializing ? const SplashScreen() : const MainLayout(),
      routes: {
        '/main': (context) => const MainLayout(),
      },
    );
  }
}
