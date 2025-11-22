import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'theme/purple_theme.dart';
import 'screen/main_layout.dart';
// import 'screen/login_screen.dart';
import 'screen/splash_screen.dart';
// import 'service/auth_service.dart';
import 'service/notification_manager.dart';
import 'service/notification_fix_service.dart';
import 'service/audio_service.dart';
// import 'firebase_options.dart';

// Global route observer for tracking navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background messaging removed (offline app)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite_common_ffi for Windows/Linux/macOS desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
    print('✅ Initialized sqflite_common_ffi for desktop platform');
  }
  
  // Initialize timezone
  tz.initializeTimeZones();
  
  // Initialize AudioService
  await AudioService().initialize();
  
  // Firebase removed (offline app)
  
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
    
    // No auth: just delay splash then proceed
    _startSplashCountdown();
  }

  Future<void> _startSplashCountdown() async {
    await _setupNotifications();
    await Future.delayed(const Duration(milliseconds: 1500));
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

