import 'dart:io' show Platform;
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

  // Check if platform supports notifications
  bool get _isNotificationSupported {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // Smart notification IDs
  static const int smartQuizReminderId = 100;
  static const int afterLearningQuizId = 101;
  static const int forgettingWordsId = 102;
  static const int streakMotivationId = 103;
  static const int eveningReviewId = 104;

  /// Initialize the smart notification service
  Future<void> initialize() async {
    if (!_isNotificationSupported) {
      print('⚠️ Smart notifications not supported on this platform (${Platform.operatingSystem})');
      return;
    }
    
    // Schedule daily evening review check
    await _scheduleEveningReviewCheck();
    print('🤖 Smart Notification Service initialized');
  }

  /// Trigger after user completes a learning session (5-10 words)
  Future<void> triggerAfterLearningSession(int wordsLearned, String topic) async {
    if (!_isNotificationSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastPrompt = prefs.getString('last_after_learning_prompt');
    final now = DateTime.now();
    
    // Only prompt once every 4 hours to avoid spam
    if (lastPrompt != null) {
      final lastPromptTime = DateTime.parse(lastPrompt);
      if (now.difference(lastPromptTime).inHours < 4) {
        print('🔕 After-learning notification skipped - in 4-hour cooldown');
        return;
      }
    }

    // Only trigger if learned 5+ words
    if (wordsLearned >= 5) {
      await _showAfterLearningNotification(wordsLearned, topic);
      await prefs.setString('last_after_learning_prompt', now.toIso8601String());
      print('✅ After-learning notification shown for $wordsLearned words on topic: $topic');
    } else {
      print('🔕 After-learning notification skipped - only $wordsLearned words learned (need 5+)');
    }
  }

  /// Check for words that are about to be forgotten
  Future<void> checkForgettingWords() async {
    if (!_isNotificationSupported) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';
      
      // Check if forgetting words notification was already shown today
      final lastForgettingNotificationDate = prefs.getString('last_forgetting_notification_date');
      if (lastForgettingNotificationDate == todayString) {
        print('🔕 Forgetting words notification skipped - already shown today');
        return;
      }
      
      final difficultWords = await _difficultWordsService.getWordsNeedingReview(threshold: 0.4);
      
      if (difficultWords.length >= 3) {
        await _showForgettingWordsNotification(difficultWords.take(3).toList());
        // Mark that we've shown forgetting words notification today
        await prefs.setString('last_forgetting_notification_date', todayString);
        print('✅ Forgetting words notification shown and tracked for $todayString');
      } else {
        print('🔕 Forgetting words notification skipped - only ${difficultWords.length} words need review (need 3+)');
      }
    } catch (e) {
      print('❌ Error checking forgetting words: $e');
    }
  }

  /// Trigger streak motivation notification
  Future<void> triggerStreakMotivation() async {
    if (!_isNotificationSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    final streakDays = prefs.getInt('streak_days') ?? 0;
    final lastQuizDate = prefs.getString('last_quiz_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    
    // Check if streak notification was already shown today
    final lastStreakNotificationDate = prefs.getString('last_streak_notification_date');
    if (lastStreakNotificationDate == todayString) {
      print('🔕 Streak motivation skipped - already shown today');
      return;
    }

    // Check if user hasn't done quiz today and has a streak
    if (streakDays > 0 && (lastQuizDate == null || lastQuizDate != todayString)) {
      await _showStreakMotivationNotification(streakDays);
      // Mark that we've shown streak notification today
      await prefs.setString('last_streak_notification_date', todayString);
      print('✅ Streak motivation notification shown and tracked for $todayString');
    } else {
      print('🔕 Streak motivation skipped - no streak or quiz already done today');
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

    // Add more variety for different moods and tones
    baseNotifications.addAll([
      {
        'title': '🚀 Bạn đang tăng tốc!',
        'body': 'Với $wordsLearned từ mới, não bộ đang hoạt động hết công suất — giữ đà bằng quiz nhé!'
      },
      {
        'title': '📚 Kiến thức mới đã cập bến!',
        'body': 'Chủ đề "$topic" vừa được cập nhật $wordsLearned từ. Ôn nhanh kẻo trôi!'
      },
      {
        'title': '🧠 Bộ nhớ cần "save"!',
        'body': '$wordsLearned từ mới đang ở RAM — chuyển sang ROM bằng quiz 2 phút nào!'
      },
      {
        'title': '🎯 Đánh dấu thành công!',
        'body': 'Hoàn thành $wordsLearned từ — chỉ còn quiz để "chốt sổ" kiến thức hôm nay!'
      },
      {
        'title': '💫 Bạn học nhanh thật!',
        'body': 'Chỉ vài phút đã xong $wordsLearned từ. Thử thách trí nhớ với quiz ngay nhé!'
      },
      {
        'title': '📈 Biểu đồ tiến bộ đang lên!',
        'body': 'Thêm $wordsLearned từ vào kho báu — quiz để đảm bảo chúng không "đào tẩu"!'
      },
      {
        'title': '🧩 Ghép nối kiến thức!',
        'body': 'Bạn vừa ghép $wordsLearned mảnh ghép từ vựng. Hoàn thiện bức tranh với quiz nhé!'
      },
      {
        'title': '⚡️ Momentum đang cực tốt!',
        'body': 'Đừng dừng lại! Quiz nhanh $wordsLearned từ để giữ nhịp học tập tuyệt vời này.'
      },
    ]);

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
      },
      // NEW ONES
      {
        'title': '🆘 Cứu nguy từ vựng!',
        'body': '"${word.word}" sắp "trôi" khỏi trí nhớ — 30 giây để kéo nó trở lại!'
      },
      {
        'title': '🧩 Còn nhớ "${word.word}" không?',
        'body': 'Não đang hỏi bạn đấy — trả lời bằng quiz để chứng minh bạn vẫn nhớ!'
      },
      {
        'title': '⏳ Đếm ngược bắt đầu!',
        'body': 'Nếu không ôn "${word.word}" ngay, nó sẽ biến mất — thử thách nhỏ nào!'
      },
      {
        'title': '🧠 Não đang nhắc bạn!',
        'body': 'Ôi, "${word.word}" — hình như bạn lâu rồi chưa gặp nó? Cùng ôn lại nhé!'
      },
      {
        'title': '💎 Đánh bóng viên ngọc!',
        'body': '"${word.word}" là viên ngọc quý — đừng để nó xỉn màu, ôn lại ngay!'
      },
      {
        'title': '🔁 Lặp lại là mẹ thành công!',
        'body': 'Lần ôn thứ N cho "${word.word}" — nhưng lần này sẽ dễ hơn nhiều!'
      },
      {
        'title': '❤️‍🩹 Chữa lành khoảng trống!',
        'body': 'Kiến thức đang có lỗ hổng ở từ "${word.word}" — vá nó bằng quiz 1 phút!'
      },
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
        },
        // NEW ONES
        {
          'title': '🏅 Huy chương $streakDays ngày!',
          'body': 'Bạn xứng đáng được vinh danh — đừng để ngày hôm nay làm gián đoạn chiến tích!'
        },
        {
          'title': '🚀 Bay cao cùng chuỗi $streakDays!',
          'body': 'Mỗi ngày là một bước tiến — hôm nay, hãy thêm một bậc nữa lên đỉnh cao!'
        },
        {
          'title': '💎 Chuỗi kim cương $streakDays ngày!',
          'body': 'Đừng để một ngày nghỉ phá vỡ viên kim cương bạn đã mài giũa bấy lâu!'
        },
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
        },
        // NEW ONES
        {
          'title': '📅 $streakDays ngày — thói quen vàng!',
          'body': 'Bạn đang xây dựng thói quen học tập tuyệt vời — đừng bỏ lỡ hôm nay!'
        },
        {
          'title': '🕊️ Thả chim bồ câu $streakDays ngày!',
          'body': 'Mỗi ngày là một lá thư gửi tới phiên bản tương lai — hãy gửi thêm một lá nữa!'
        },
        {
          'title': '🌱 Gieo hạt $streakDays ngày rồi!',
          'body': 'Cây tri thức đang lớn từng ngày — tưới nước bằng quiz hôm nay nhé!'
        },
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
    if (!_isNotificationSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastQuizDate = prefs.getString('last_quiz_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    
    // Check if evening review notification was already shown today
    final lastEveningNotificationDate = prefs.getString('last_evening_notification_date');
    if (lastEveningNotificationDate == todayString) {
      print('🔕 Evening review notification skipped - already shown today');
      return;
    }

    // If no quiz today, send evening motivation
    if (lastQuizDate == null || lastQuizDate != todayString) {
      await _showEveningReviewNotification();
      // Mark that we've shown evening notification today
      await prefs.setString('last_evening_notification_date', todayString);
      print('✅ Evening review notification shown and tracked for $todayString');
    } else {
      print('🔕 Evening review notification skipped - quiz already done today');
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
      },
      // NEW ONES
      {
        'title': '🕯️ Thắp nến ôn tập!',
        'body': 'Buổi tối yên tĩnh là thời điểm hoàn hảo để ôn $todayWordsLearned từ — thư giãn và ghi nhớ sâu hơn.'
      },
      {
        'title': '📖 Đóng sách thật đẹp!',
        'body': 'Kết thúc ngày với $todayWordsLearned từ — quiz nhanh để "gói quà" kiến thức mang theo vào giấc ngủ.'
      },
      {
        'title': '🌌 Trước khi chìm vào giấc mơ...',
        'body': 'Hãy điểm lại $todayWordsLearned từ bạn chinh phục hôm nay — não sẽ xử lý tốt hơn khi ngủ đấy!'
      },
      {
        'title': '🛌 Ôn trước khi ngủ = nhớ lâu hơn!',
        'body': 'Khoa học chứng minh: ôn $todayWordsLearned từ trước khi ngủ giúp ghi nhớ sâu — thử ngay nhé!'
      },
      {
        'title': '🌠 Kết ngày bằng ánh sao tri thức!',
        'body': '$todayWordsLearned từ lấp lánh hôm nay — điểm lại để chúng tỏa sáng trong tâm trí bạn mãi mãi.'
      },
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
  
  /// Reset notification tracking for a new day (called when quiz is completed)
  Future<void> markQuizCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    
    // Clear all daily notification flags since user completed quiz
    await prefs.remove('last_streak_notification_date');
    await prefs.remove('last_evening_notification_date');
    
    print('🎯 Quiz completed - cleared daily notification tracking for $todayString');
  }
  
  /// Clear all notification tracking data (for debugging or reset)
  Future<void> clearAllNotificationTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_streak_notification_date');
    await prefs.remove('last_forgetting_notification_date');
    await prefs.remove('last_evening_notification_date');
    await prefs.remove('last_after_learning_prompt');
    
    print('🧹 All notification tracking data cleared');
  }
}