import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../service/difficult_words_service.dart';

class SmartNotificationService {
  static final SmartNotificationService _instance = SmartNotificationService._internal();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final DifficultWordsService _difficultWordsService = DifficultWordsService();

  // Smart notification IDs
  static const int smartQuizReminderId = 100;
  static const int afterLearningQuizId = 101;
  static const int forgettingWordsId = 102;
  static const int streakMotivationId = 103;
  static const int eveningReviewId = 104;

  /// Initialize the smart notification service
  Future<void> initialize() async {
    // Schedule daily evening review check
    await _scheduleEveningReviewCheck();
    print('🤖 Smart Notification Service initialized');
  }

  /// Trigger after user completes a learning session (5-10 words)
  Future<void> triggerAfterLearningSession(int wordsLearned, String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final lastPrompt = prefs.getString('last_after_learning_prompt');
    final now = DateTime.now();
    
    // Only prompt once every 4 hours to avoid spam
    if (lastPrompt != null) {
      final lastPromptTime = DateTime.parse(lastPrompt);
      if (now.difference(lastPromptTime).inHours < 4) return;
    }

    // Only trigger if learned 5+ words
    if (wordsLearned >= 5) {
      await _showAfterLearningNotification(wordsLearned, topic);
      await prefs.setString('last_after_learning_prompt', now.toIso8601String());
    }
  }

  /// Check for words that are about to be forgotten
  Future<void> checkForgettingWords() async {
    try {
      final difficultWords = await _difficultWordsService.getWordsNeedingReview(threshold: 0.4);
      
      if (difficultWords.length >= 3) {
        await _showForgettingWordsNotification(difficultWords.take(3).toList());
      }
    } catch (e) {
      print('Error checking forgetting words: $e');
    }
  }

  /// Trigger streak motivation notification
  Future<void> triggerStreakMotivation() async {
    final prefs = await SharedPreferences.getInstance();
    final streakDays = prefs.getInt('streak_days') ?? 0;
    final lastQuizDate = prefs.getString('last_quiz_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    // Check if user hasn't done quiz today and has a streak
    if (streakDays > 0 && (lastQuizDate == null || lastQuizDate != todayString)) {
      await _showStreakMotivationNotification(streakDays);
    }
  }

  /// Schedule evening review check (8 PM daily)
  Future<void> _scheduleEveningReviewCheck() async {
    await _notifications.zonedSchedule(
      eveningReviewId,
      '', // Will be set dynamically
      '',
      _nextInstanceOf(20, 0), // 8 PM
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_review',
          'Ôn tập buổi tối',
          channelDescription: 'Nhắc nhở ôn tập buổi tối',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Show notification after learning session
  Future<void> _showAfterLearningNotification(int wordsLearned, String topic) async {
    final notifications = _generateAfterLearningNotifications(wordsLearned, topic);
    final notification = notifications[Random().nextInt(notifications.length)];

    await _notifications.show(
      afterLearningQuizId,
      notification['title']!,
      notification['body']!,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'after_learning_quiz',
          'Quiz sau khi học',
          channelDescription: 'Gợi ý quiz sau khi học từ mới',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'after_learning_quiz',
    );
  }

  /// Show notification for words about to be forgotten
  Future<void> _showForgettingWordsNotification(List<DifficultWordData> words) async {
    final word = words.first;
    final notifications = _generateForgettingWordsNotifications(word);
    final notification = notifications[Random().nextInt(notifications.length)];

    await _notifications.show(
      forgettingWordsId,
      notification['title']!,
      notification['body']!,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'forgetting_words',
          'Từ sắp quên',
          channelDescription: 'Nhắc nhở từ sắp bị quên',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'forgetting_words:${word.word}',
    );
  }

  /// Show streak motivation notification
  Future<void> _showStreakMotivationNotification(int streakDays) async {
    final notifications = _generateStreakMotivationNotifications(streakDays);
    final notification = notifications[Random().nextInt(notifications.length)];

    await _notifications.show(
      streakMotivationId,
      notification['title']!,
      notification['body']!,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_motivation',
          'Động lực streak',
          channelDescription: 'Khích lệ duy trì chuỗi học tập',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'streak_motivation',
    );
  }

  /// Generate personalized after-learning notifications with better UX
  List<Map<String, String>> _generateAfterLearningNotifications(int wordsLearned, String topic) {
    final baseNotifications = [
      {
        'title': '🎉 Tuyệt vời! Vừa hoàn thành bài học',
        'body': 'Bạn đã học $wordsLearned từ về "$topic". Thử làm quiz nhanh để ghi nhớ lâu hơn nhé!'
      },
      {
        'title': '✨ Tiến bộ đáng kể rồi đấy!',
        'body': '$wordsLearned từ mới đã vào não — quiz 2 phút để "khóa" kiến thức này?'
      },
      {
        'title': '🧠 Não đang "nóng" đây!',
        'body': 'Đây là lúc tuyệt vời nhất để ôn lại $wordsLearned từ vừa học. Cùng quiz nhé!'
      },
      {
        'title': '🎯 Gần xong rồi!',
        'body': 'Chỉ cần quiz nhanh $wordsLearned từ "$topic" là hoàn thiện bài học!'
      },
      {
        'title': '🌟 Học giỏi quá!',
        'body': '$wordsLearned từ vựng "$topic" đã sẵn sàng. Quiz để chắc chắn nhớ lâu nhé!'
      }
    ];

    // Add time-sensitive messages based on learning session size
    if (wordsLearned >= 10) {
      baseNotifications.add({
        'title': '🏆 Wow! Học nhiều thế!',
        'body': '$wordsLearned từ trong một lần — bạn thật kiên trì! Quiz để không quên nhé!'
      });
    } else if (wordsLearned >= 5) {
      baseNotifications.add({
        'title': '👏 Tiến độ ổn định!',
        'body': '$wordsLearned từ về "$topic" — momentum tốt đấy! Thử quiz luôn?'
      });
    }

    return baseNotifications;
  }

  /// Generate forgetting words notifications with positive framing
  List<Map<String, String>> _generateForgettingWordsNotifications(DifficultWordData word) {
    return [
      {
        'title': '💡 Thời gian "refresh" từ vựng!',
        'body': 'Từ "${word.word}" cần được ôn lại. 1 phút thôi để ghi nhớ lâu hơn!'
      },
      {
        'title': '🔄 Củng cố kiến thức!',
        'body': '"${word.word}" đang chờ được "làm mới" trong trí nhớ. Quiz nhanh nhé!'
      },
      {
        'title': '🧠 Duy trì độ sắc bén!',
        'body': 'Ôn lại "${word.word}" để não luôn "tươi tỉnh" với từ này!'
      },
      {
        'title': '🎯 Thử thách nhỏ!',
        'body': 'Bạn còn nhớ "${word.word}" không? Thử sức với từ này nhé!'
      },
      {
        'title': '⭐ Giữ vững kiến thức!',
        'body': '"${word.word}" cần một lần ôn tập nữa để khắc sâu trong tâm trí!'
      }
    ];
  }

  /// Generate streak motivation notifications
  List<Map<String, String>> _generateStreakMotivationNotifications(int streakDays) {
    if (streakDays >= 7) {
      return [
        {
          'title': '🔥 Giữ lửa chuỗi $streakDays ngày!',
          'body': 'Làm 1 quiz nhanh để giữ chuỗi — bạn sắp đạt mốc mới đấy!'
        },
        {
          'title': '🏆 Chuỗi $streakDays ngày tuyệt vời!',
          'body': 'Đừng để nó đứt ở đây — chỉ cần 3 phút quiz để tiếp tục!'
        },
        {
          'title': '⭐ $streakDays ngày kiên trì!',
          'body': 'Bạn đã làm được điều tuyệt vời — hãy duy trì đà này!'
        }
      ];
    } else {
      return [
        {
          'title': '🌱 Chuỗi $streakDays ngày đang lớn!',
          'body': 'Quiz nhanh để nuôi dưỡng thói quen tốt này nhé!'
        },
        {
          'title': '💪 Tiếp tục chuỗi $streakDays ngày!',
          'body': 'Mỗi ngày một chút — bạn đang xây dựng thói quen tuyệt vời!'
        }
      ];
    }
  }

  /// Get next instance of specific time
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// Evening review check - called by scheduled notification
  Future<void> performEveningReviewCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastQuizDate = prefs.getString('last_quiz_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    // If no quiz today, send evening motivation
    if (lastQuizDate == null || lastQuizDate != todayString) {
      await _showEveningReviewNotification();
    }
  }

  /// Show evening review notification with better timing
  Future<void> _showEveningReviewNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final todayWordsLearned = prefs.getInt('words_learned_$todayKey') ?? 0;
    
    // Only show if user learned something today
    if (todayWordsLearned == 0) {
      print('🌙 Evening review skipped - no words learned today');
      return;
    }
    
    final notifications = [
      {
        'title': '🌙 Ngày học tập tuyệt vời!',
        'body': 'Bạn đã học $todayWordsLearned từ hôm nay. Quiz nhanh để ngủ ngon hơn nhé!'
      },
      {
        'title': '✨ Hoàn thiện ngày học!',
        'body': '$todayWordsLearned từ mới trong ngày — thử quiz để kiểm tra xem nhớ được bao nhiêu!'
      },
      {
        'title': '🎯 Điểm lại thành quả!',
        'body': 'Hôm nay tiến bộ $todayWordsLearned từ. Quiz 3 phút để "khóa" kiến thức?'
      },
      {
        'title': '🌟 Kết thúc ngày thành công!',
        'body': 'Với $todayWordsLearned từ mới, bạn đã làm rất tốt! Quiz để ghi nhớ lâu hơn?'
      }
    ];

    final notification = notifications[Random().nextInt(notifications.length)];

    await _notifications.show(
      eveningReviewId,
      notification['title']!,
      notification['body']!,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_review',
          'Ôn tập buổi tối',
          channelDescription: 'Nhắc nhở ôn tập buổi tối',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'evening_review',
    );
  }

  /// Cancel all smart notifications
  Future<void> cancelAllSmartNotifications() async {
    await _notifications.cancel(smartQuizReminderId);
    await _notifications.cancel(afterLearningQuizId);
    await _notifications.cancel(forgettingWordsId);
    await _notifications.cancel(streakMotivationId);
    await _notifications.cancel(eveningReviewId);
  }
}
