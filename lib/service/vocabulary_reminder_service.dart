import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:bvo/service/difficult_words_service.dart';

class VocabularyReminderService {
  static const String _reminderDataKey = 'vocabulary_reminder_data';
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final DifficultWordsService _difficultWordsService = DifficultWordsService();

  // Notification IDs
  static const int morningNotificationId = 1001;
  static const int afternoonNotificationId = 1002;
  static const int eveningNotificationId = 1003;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
  }

  /// Lên lịch nhắc nhở từ vựng
  Future<void> scheduleVocabularyReminders() async {
    final settings = await _difficultWordsService.getReminderSettings();
    
    if (!settings.isEnabled) {
      await cancelAllReminders();
      return;
    }

    // Lấy từ khó cần ôn tập
    final difficultWords = await _difficultWordsService.getWordsNeedingReview(
      threshold: settings.minimumErrorRate,
    );

    if (difficultWords.isEmpty) {
      await cancelAllReminders();
      return;
    }

    // Lên lịch cho 3 buổi trong ngày
    await _scheduleReminder(
      morningNotificationId,
      'Ôn từ vựng buổi sáng 🌅',
      settings.morningTime,
      difficultWords,
      settings.wordsPerReminder,
    );

    await _scheduleReminder(
      afternoonNotificationId,
      'Ôn từ vựng buổi trưa ☀️',
      settings.afternoonTime,
      difficultWords,
      settings.wordsPerReminder,
    );

    await _scheduleReminder(
      eveningNotificationId,
      'Ôn từ vựng buổi tối 🌙',
      settings.eveningTime,
      difficultWords,
      settings.wordsPerReminder,
    );
  }

  Future<void> _scheduleReminder(
    int notificationId,
    String title,
    String time,
    List<DifficultWordData> difficultWords,
    int wordsPerReminder,
  ) async {
    // Parse time (format: "HH:mm")
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Lấy từ ngẫu nhiên từ danh sách từ khó
    final selectedWords = _selectRandomWords(difficultWords, wordsPerReminder);
    final wordsText = selectedWords.map((w) => w.word).join(', ');
    
    final body = selectedWords.isEmpty 
        ? 'Hãy ôn tập từ vựng để cải thiện kỹ năng!'
        : 'Từ cần ôn: $wordsText';

    // Lên lịch thông báo hàng ngày
    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vocabulary_reminder',
          'Nhắc nhở từ vựng',
          channelDescription: 'Nhắc nhở ôn tập từ vựng khó',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Lưu dữ liệu reminder
    await _saveReminderData(notificationId, selectedWords);
  }

  List<DifficultWordData> _selectRandomWords(List<DifficultWordData> words, int count) {
    if (words.length <= count) return words;
    
    // Sắp xếp theo tỷ lệ sai giảm dần và lấy ngẫu nhiên từ top 50%
    words.sort((a, b) => b.errorRate.compareTo(a.errorRate));
    final topHalf = words.take((words.length * 0.5).ceil()).toList();
    
    topHalf.shuffle();
    return topHalf.take(count).toList();
  }

  TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = TZDateTime.now(local);
    var scheduledDate = TZDateTime(local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// Lưu dữ liệu reminder
  Future<void> _saveReminderData(int notificationId, List<DifficultWordData> words) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'notificationId': notificationId,
      'words': words.map((w) => {
        'word': w.word,
        'topic': w.topic,
        'errorRate': w.errorRate,
      }).toList(),
      'scheduledAt': DateTime.now().toIso8601String(),
    };
    
    await prefs.setString('${_reminderDataKey}_$notificationId', jsonEncode(data));
  }

  /// Lấy dữ liệu reminder
  Future<Map<String, dynamic>?> getReminderData(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString('${_reminderDataKey}_$notificationId');
    
    if (dataJson != null) {
      return jsonDecode(dataJson);
    }
    
    return null;
  }

  /// Hủy tất cả reminder
  Future<void> cancelAllReminders() async {
    await _notifications.cancel(morningNotificationId);
    await _notifications.cancel(afternoonNotificationId);
    await _notifications.cancel(eveningNotificationId);
  }

  /// Hủy một reminder cụ thể
  Future<void> cancelReminder(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Kiểm tra quyền thông báo
  Future<bool> checkNotificationPermission() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    
    return true; // iOS sẽ tự động yêu cầu quyền
  }

  /// Lấy thống kê reminder
  Future<Map<String, dynamic>> getReminderStats() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final reminderKeys = allKeys.where((key) => key.startsWith(_reminderDataKey)).toList();
    
    int totalReminders = reminderKeys.length;
    int todayReminders = 0;
    
    final today = DateTime.now();
    for (String key in reminderKeys) {
      final dataJson = prefs.getString(key);
      if (dataJson != null) {
        final data = jsonDecode(dataJson);
        final scheduledAt = DateTime.parse(data['scheduledAt']);
        if (scheduledAt.year == today.year && 
            scheduledAt.month == today.month && 
            scheduledAt.day == today.day) {
          todayReminders++;
        }
      }
    }
    
    return {
      'totalReminders': totalReminders,
      'todayReminders': todayReminders,
      'isEnabled': (await _difficultWordsService.getReminderSettings()).isEnabled,
    };
  }
}

// Typedef để sử dụng TZDateTime
typedef TZDateTime = tz.TZDateTime;
final tz.Location local = tz.local;
