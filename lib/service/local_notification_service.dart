import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Initialize the local notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    print('Local notifications initialized');
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      print('Notification payload: $payload');
      // TODO: Handle navigation based on payload
    }
  }

  // Request permissions (mainly for iOS)
  static Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
          await androidImplementation?.requestNotificationsPermission();
      return grantedNotificationPermission ?? false;
    }
    return true;
  }

  // Show an immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
    Priority priority = Priority.defaultPriority,
    Importance importance = Importance.defaultImportance,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId ?? 'default_channel',
      channelName ?? 'Kênh Mặc Định',
      channelDescription: channelDescription ?? 'Kênh thông báo mặc định',
      importance: importance,
      priority: priority,
      icon: 'ic_notification',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'default_category',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Schedule a notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId ?? 'scheduled_channel',
      channelName ?? 'Thông Báo Đã Lên Lịch',
      channelDescription: channelDescription ?? 'Kênh thông báo đã lên lịch',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'default_category',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  // Schedule a repeating notification
  static Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required RepeatInterval repeatInterval,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId ?? 'repeating_channel',
      channelName ?? 'Thông Báo Lặp Lại',
      channelDescription: 'Kênh thông báo lặp lại',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'default_category',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.periodicallyShow(
      id,
      title,
      body,
      repeatInterval,
      platformChannelSpecifics,
      payload: payload, androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  // Show vocabulary reminder notification
  static Future<void> showVocabularyReminder({
    String? word,
    String? meaning,
  }) async {
    await showNotification(
      id: 1001,
      title: 'Time to Practice! 📚',
      body: word != null 
          ? 'Review the word: $word${meaning != null ? ' - $meaning' : ''}'
          : 'Don\'t forget to practice your vocabulary today!',
      payload: 'vocabulary_reminder',
      channelId: 'vocabulary_channel',
      channelName: 'Nhắc Nhở Từ Vựng',
      channelDescription: 'Thông báo nhắc nhở luyện tập từ vựng',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  // Schedule daily vocabulary reminder
  static Future<void> scheduleDailyVocabularyReminder({
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await scheduleRepeatingNotification(
      id: 1002,
      title: 'Daily Vocabulary Practice 📖',
      body: 'Time for your daily vocabulary practice session!',
      repeatInterval: RepeatInterval.daily,
      payload: 'daily_vocabulary',
      channelId: 'daily_vocabulary_channel',
      channelName: 'Daily Vocabulary',
    );
  }

  // Show learning streak notification
  static Future<void> showStreakNotification(int streakDays) async {
    await showNotification(
      id: 1003,
      title: 'Amazing Streak! 🔥',
      body: 'You\'ve been learning for $streakDays days straight! Keep it up!',
      payload: 'streak_notification',
      channelId: 'achievement_channel',
      channelName: 'Achievements',
      channelDescription: 'Notifications for learning achievements',
      importance: Importance.high,
      priority: Priority.high,
    );
  }
}
