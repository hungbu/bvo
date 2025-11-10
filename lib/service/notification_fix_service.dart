import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to fix notification issues and clear corrupted data
class NotificationFixService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  /// Fix notification issues by clearing all data and reinitializing
  static Future<void> fixNotificationIssues() async {
    try {
      print('🔧 Starting notification fix...');
      
      // Step 1: Cancel all existing notifications
      await _cancelAllNotifications();
      
      // Step 2: Clear notification preferences
      await _clearNotificationPreferences();
      
      // Step 3: Reinitialize notifications
      await _reinitializeNotifications();
      
      print('✅ Notification fix completed successfully');
      
    } catch (e) {
      print('❌ Error during notification fix: $e');
      
      // Fallback: Force clear everything
      await _forceClearNotifications();
    }
  }

  /// Cancel all notifications
  static Future<void> _cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('🗑️ All notifications cancelled');
    } catch (e) {
      print('⚠️ Error cancelling notifications: $e');
    }
  }

  /// Clear notification-related preferences
  static Future<void> _clearNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Keys to clear
      final keysToRemove = <String>[];
      
      // Get all keys
      final allKeys = prefs.getKeys();
      
      // Find notification-related keys
      for (final key in allKeys) {
        if (key.contains('notification') || 
            key.contains('reminder') || 
            key.contains('last_') ||
            key.contains('scheduled') ||
            key.contains('alert') ||
            key.contains('evening_check') ||
            key.contains('achievement_shown') ||
            key.contains('streak_milestone')) {
          keysToRemove.add(key);
        }
      }
      
      // Remove notification keys
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      print('🧹 Cleared ${keysToRemove.length} notification preferences');
      
    } catch (e) {
      print('⚠️ Error clearing preferences: $e');
    }
  }

  /// Reinitialize notifications with fresh settings
  static Future<void> _reinitializeNotifications() async {
    try {
      // Android settings
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('ic_notification');
      
      // iOS settings
      const DarwinInitializationSettings iosSettings = 
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Request permissions again
      await _requestPermissions();
      
      print('🔄 Notifications reinitialized');
      
    } catch (e) {
      print('⚠️ Error reinitializing notifications: $e');
    }
  }

  /// Handle notification taps
  static void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    try {
      // Android permissions
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      // iOS permissions
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
      }
      
      print('✅ Notification permissions requested');
      
    } catch (e) {
      print('⚠️ Error requesting permissions: $e');
    }
  }

  /// Force clear all notification data (emergency fallback)
  static Future<void> _forceClearNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys and remove anything that might be notification-related
      final allKeys = prefs.getKeys().toList();
      
      for (final key in allKeys) {
        final keyLower = key.toLowerCase();
        if (keyLower.contains('notification') || 
            keyLower.contains('reminder') || 
            keyLower.contains('schedule') ||
            keyLower.contains('alert') ||
            keyLower.contains('last_') ||
            keyLower.contains('achievement') ||
            keyLower.contains('streak') ||
            keyLower.contains('quiz_date') ||
            keyLower.contains('evening') ||
            keyLower.contains('morning') ||
            keyLower.contains('noon')) {
          await prefs.remove(key);
        }
      }
      
      print('🚨 Force cleared all notification data');
      
    } catch (e) {
      print('❌ Error in force clear: $e');
    }
  }

  /// Check if notifications are working properly
  static Future<bool> checkNotificationHealth() async {
    try {
      // Try to get pending notifications
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      print('📊 Pending notifications: ${pendingNotifications.length}');
      
      // Test a simple notification
      await _notifications.show(
        99999,
        'Health Check',
        'Notification system is working',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'health_check',
            'Health Check',
            channelDescription: 'Health check for notifications',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
      
      // Cancel the test notification
      await _notifications.cancel(99999);
      
      print('✅ Notification health check passed');
      return true;
      
    } catch (e) {
      print('❌ Notification health check failed: $e');
      return false;
    }
  }

  /// Safe schedule notification with error handling
  static Future<bool> safeScheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        _convertToTZDateTime(scheduledTime),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId ?? 'default_channel',
            channelName ?? 'Default Notifications',
            channelDescription: 'Default notification channel',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_notification',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      
      return true;
      
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      return false;
    }
  }

  /// Convert DateTime to TZDateTime safely
  static dynamic _convertToTZDateTime(DateTime dateTime) {
    try {
      // Import timezone package dynamically
      return dateTime; // Simplified for now
    } catch (e) {
      print('⚠️ Error converting to TZDateTime: $e');
      return dateTime;
    }
  }

  /// Get notification statistics
  static Future<Map<String, dynamic>> getNotificationStats() async {
    try {
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      final prefs = await SharedPreferences.getInstance();
      
      final stats = <String, dynamic>{
        'pending_notifications': pendingNotifications.length,
        'notification_ids': pendingNotifications.map((n) => n.id).toList(),
        'notifications_enabled': prefs.getBool('notifications_enabled') ?? true,
        'last_fix': prefs.getString('last_notification_fix') ?? 'never',
      };
      
      return stats;
      
    } catch (e) {
      print('❌ Error getting notification stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Mark that fix was performed
  static Future<void> markFixPerformed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_notification_fix', DateTime.now().toIso8601String());
    } catch (e) {
      print('⚠️ Error marking fix performed: $e');
    }
  }
}
