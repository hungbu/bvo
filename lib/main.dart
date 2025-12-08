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
import 'service/performance_monitor.dart';
// import 'firebase_options.dart';

// Global route observer for tracking navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background messaging removed (offline app)

void main() async {
  final appStartStopwatch = Stopwatch()..start();
  PerformanceMonitor.startApp();
  PerformanceMonitor.trackMemoryUsage('main.start');
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite_common_ffi for Windows/Linux/macOS desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final ffiStopwatch = Stopwatch()..start();
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
    ffiStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('main.initSqfliteFfi', ffiStopwatch.elapsed);
    print('✅ Initialized sqflite_common_ffi for desktop platform');
  }
  
  // Initialize timezone
  final tzStopwatch = Stopwatch()..start();
  tz.initializeTimeZones();
  tzStopwatch.stop();
  PerformanceMonitor.trackAsyncOperation('main.initTimezones', tzStopwatch.elapsed);
  
  // Initialize AudioService
  final audioStopwatch = Stopwatch()..start();
  await AudioService().initialize();
  audioStopwatch.stop();
  PerformanceMonitor.trackAsyncOperation('main.initAudioService', audioStopwatch.elapsed);
  
  // Firebase removed (offline app)
  
  // Fix notification issues first
  final notificationFixStopwatch = Stopwatch()..start();
  await NotificationFixService.fixNotificationIssues();
  notificationFixStopwatch.stop();
  PerformanceMonitor.trackAsyncOperation('main.fixNotificationIssues', notificationFixStopwatch.elapsed);
  
  // Initialize notification manager
  final notificationInitStopwatch = Stopwatch()..start();
  await NotificationManager().initialize();
  notificationInitStopwatch.stop();
  PerformanceMonitor.trackAsyncOperation('main.initNotificationManager', notificationInitStopwatch.elapsed);
  
  appStartStopwatch.stop();
  PerformanceMonitor.trackAsyncOperation('main.total', appStartStopwatch.elapsed, metadata: {
    'platform': Platform.operatingSystem,
  });
  PerformanceMonitor.trackMemoryUsage('main.end');
  
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
    final stopwatch = Stopwatch()..start();
    PerformanceMonitor.trackMemoryUsage('_MyAppState._startSplashCountdown.start');
    
    // OPTIMIZED: Don't wait for notifications - load them async after UI renders
    // This allows UI to show immediately instead of waiting 22+ seconds
    _setupNotificationsAsync(); // Fire and forget - don't await
    
    // Only wait for minimum splash delay (1.5s) for branding
    final delayStopwatch = Stopwatch()..start();
    await Future.delayed(const Duration(milliseconds: 1500));
    delayStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('_MyAppState._startSplashCountdown.delay', delayStopwatch.elapsed);
    
    // Show UI immediately after splash delay
    setState(() {
      _isInitializing = false;
    });
    
    stopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('_MyAppState._startSplashCountdown', stopwatch.elapsed);
    PerformanceMonitor.trackMemoryUsage('_MyAppState._startSplashCountdown.end');
    
    // Print performance report after splash screen
    Future.delayed(const Duration(seconds: 2), () {
      PerformanceMonitor.printReport();
    });
  }
  
  /// Setup notifications asynchronously in background (non-blocking)
  /// This runs after UI has rendered, so it doesn't delay app startup
  void _setupNotificationsAsync() {
    // Run in background without blocking
    _setupNotifications().catchError((error) {
      print('⚠️ Error setting up notifications (non-critical): $error');
      // Don't crash app if notifications fail
    });
  }

  Future<void> _setupNotifications() async {
    final stopwatch = Stopwatch()..start();
    final notificationManager = NotificationManager();
    
    // Schedule daily reminders (only once per day)
    final scheduleStopwatch = Stopwatch()..start();
    await notificationManager.scheduleDailyReminders();
    scheduleStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('_MyAppState._setupNotifications.scheduleDailyReminders', scheduleStopwatch.elapsed);
    
    // Run controlled notification checks (with cooldowns)
    final checkStopwatch = Stopwatch()..start();
    await notificationManager.runControlledNotificationChecks();
    checkStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('_MyAppState._setupNotifications.runControlledNotificationChecks', checkStopwatch.elapsed);
    
    // Update last active date
    final updateStopwatch = Stopwatch()..start();
    await notificationManager.updateLastActiveDate();
    updateStopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('_MyAppState._setupNotifications.updateLastActiveDate', updateStopwatch.elapsed);
    
    stopwatch.stop();
    PerformanceMonitor.trackAsyncOperation('_MyAppState._setupNotifications', stopwatch.elapsed);
    
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

