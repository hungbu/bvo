import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../repository/quiz_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int morningReminderId = 1;
  static const int noonReminderId = 2;
  static const int eveningReminderId = 3;
  static const int streakWarningId = 4;
  static const int dueWordsId = 5;
  static const int dailyGoalProgressId = 6;
  
  // Phase 2 IDs
  static const int achievementId = 7;
  static const int weeklySummaryId = 8;
  static const int streakMilestoneId = 9;
  static const int quizReminderId = 10;
  static const int comebackEncouragementId = 11;

  Future<void> initialize() async {
    // Android initialization
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    await notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  // PHASE 1 NOTIFICATIONS

  /// 1. Daily Learning Reminders
  Future<void> scheduleDailyReminders() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if notifications are enabled
    final morningEnabled = prefs.getBool('morning_reminder_enabled') ?? true;
    final noonEnabled = prefs.getBool('noon_reminder_enabled') ?? true;
    final eveningEnabled = prefs.getBool('evening_reminder_enabled') ?? true;
    
    // Get custom times or use defaults
    final morningHour = prefs.getInt('morning_reminder_hour') ?? 8;
    final morningMinute = prefs.getInt('morning_reminder_minute') ?? 0;
    final noonHour = prefs.getInt('noon_reminder_hour') ?? 11;
    final noonMinute = prefs.getInt('noon_reminder_minute') ?? 45;
    final eveningHour = prefs.getInt('evening_reminder_hour') ?? 19;
    final eveningMinute = prefs.getInt('evening_reminder_minute') ?? 0;

    if (morningEnabled) {
      await _scheduleDailyNotification(
        id: morningReminderId,
        title: 'Chào Buổi Sáng! ☀️',
        body: 'Sẵn sàng học 10 từ mới hôm nay chưa?',
        hour: morningHour,
        minute: morningMinute,
        payload: 'morning_reminder',
      );
    }

    if (noonEnabled) {
      await _scheduleDailyNotification(
        id: noonReminderId,
        title: 'Nghỉ Trưa Học Từ! ☀️',
        body: 'Thời gian hoàn hảo để học vài từ mới trong giờ nghỉ!',
        hour: noonHour,
        minute: noonMinute,
        payload: 'noon_reminder',
      );
    }

    if (eveningEnabled) {
      await _scheduleDailyNotification(
        id: eveningReminderId,
        title: 'Ôn Tập Buổi Tối 🌙',
        body: 'Đã đến lúc ôn lại những từ hôm nay!',
        hour: eveningHour,
        minute: eveningMinute,
        payload: 'evening_reminder',
      );
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String payload,
  }) async {
      await notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(_nextInstanceOfTime(hour, minute), tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Nhắc Nhở Học Hàng Ngày',
          channelDescription: 'Nhắc nhở hàng ngày để học từ vựng',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'daily_reminders',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// 2. Streak Warning Notifications
  Future<void> checkAndScheduleStreakWarning() async {
    final prefs = await SharedPreferences.getInstance();
    final streakWarningEnabled = prefs.getBool('streak_warning_enabled') ?? true;
    
    if (!streakWarningEnabled) return;

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final learnedToday = prefs.getBool('learned_$todayKey') ?? false;

    // If user hasn't learned today and it's after 6 PM, schedule warning
    if (!learnedToday && today.hour >= 18) {
      final currentStreak = prefs.getInt('streak_days') ?? 0;
      
      if (currentStreak > 0) {
        // Schedule warning for 10 PM (2 hours before midnight)
        final warningTime = DateTime(today.year, today.month, today.day, 22, 0);
        
        if (today.isBefore(warningTime)) {
          await notifications.zonedSchedule(
            streakWarningId,
            'Đừng phá vỡ chuỗi học! 🔥',
            'Bạn có chuỗi $currentStreak ngày. Chỉ cần 5 phút học thôi!',
            tz.TZDateTime.from(warningTime, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'streak_warnings',
                'Cảnh Báo Chuỗi Học',
                channelDescription: 'Cảnh báo duy trì chuỗi học tập',
                importance: Importance.max,
                priority: Priority.max,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(
                categoryIdentifier: 'streak_warnings',
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'streak_warning',
          );
        }
      }
    }
  }

  /// 3. Due Words Alert
  Future<void> checkAndScheduleDueWordsAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final dueWordsEnabled = prefs.getBool('due_words_enabled') ?? true;
    
    if (!dueWordsEnabled) return;

    try {
      final quizRepo = QuizRepository();
      final dueWords = await quizRepo.getDueWords();
      
      if (dueWords.isNotEmpty) {
        await notifications.show(
          dueWordsId,
          'Giờ Ôn Tập! 📝',
          '${dueWords.length} từ cần được ôn tập. Hoàn thiện trí nhớ của bạn!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'due_words',
              'Thông Báo Từ Cần Ôn',
              channelDescription: 'Thông báo cho các từ cần ôn tập',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'due_words',
            ),
          ),
          payload: 'due_words',
        );
      }
    } catch (e) {
      print('Error checking due words: $e');
    }
  }

  /// 4. Daily Goal Progress Notifications
  Future<void> checkAndScheduleGoalProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final goalProgressEnabled = prefs.getBool('goal_progress_enabled') ?? true;
    
    if (!goalProgressEnabled) return;

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final todayWordsLearned = prefs.getInt('words_learned_$todayKey') ?? 0;
    final dailyGoal = prefs.getInt('daily_goal') ?? 10;

    // Check if we should send progress notification
    final lastProgressNotification = prefs.getString('last_progress_notification');
    final todayString = todayKey;

    if (lastProgressNotification != todayString) {
      String? title;
      String? body;

      if (todayWordsLearned == 0 && today.hour >= 12) {
        // Afternoon reminder if no progress
        title = 'Hãy bắt đầu nào! 🎯';
        body = 'Mục tiêu hôm nay: $dailyGoal từ. Đây là thời điểm hoàn hảo!';
      } else if (todayWordsLearned >= dailyGoal) {
        // Goal achieved
        title = 'Hoàn Thành Mục Tiêu! ✅';
        body = 'Tuyệt vời! Bạn đã học $todayWordsLearned từ hôm nay. Bạn thật xuất sắc! 🔥';
      } else if (todayWordsLearned >= dailyGoal * 0.5) {
        // 50% progress
        title = 'Đã Được Một Nửa! 🎯';
        body = 'Đã học $todayWordsLearned/$dailyGoal từ. Tiếp tục nhé!';
      }

      if (title != null && body != null) {
        await notifications.show(
          dailyGoalProgressId,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'goal_progress',
              'Tiến Độ Mục Tiêu Hàng Ngày',
              channelDescription: 'Cập nhật tiến độ mục tiêu học tập hàng ngày',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'goal_progress',
            ),
          ),
          payload: 'goal_progress',
        );

        // Mark that we sent notification today
        await prefs.setString('last_progress_notification', todayString);
      }
    }
  }

  // Utility methods
  DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await notifications.cancelAll();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Enable/disable all notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    
    if (enabled) {
      await scheduleDailyReminders();
    } else {
      await cancelAllNotifications();
    }
  }

  /// Run all notification checks (call this periodically)
  Future<void> runNotificationChecks() async {
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    await checkAndScheduleStreakWarning();
    await checkAndScheduleDueWordsAlert();
    await checkAndScheduleGoalProgress();
    await checkAndScheduleQuizReminder();
    await checkAndScheduleComebackEncouragement();
  }

  // PHASE 2 NOTIFICATIONS

  /// 5. Achievement Notifications
  Future<void> showAchievementNotification({
    required String achievementTitle,
    required String achievementDescription,
    required String achievementType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final achievementEnabled = prefs.getBool('achievement_enabled') ?? true;
    
    if (!achievementEnabled) return;

    String emoji = '🏆';
    switch (achievementType) {
      case 'first_word':
        emoji = '🌟';
        break;
      case 'streak':
        emoji = '🔥';
        break;
      case 'words_milestone':
        emoji = '📚';
        break;
      case 'quiz_master':
        emoji = '🎯';
        break;
      case 'accuracy':
        emoji = '💯';
        break;
      case 'explorer':
        emoji = '🗺️';
        break;
    }

    await notifications.show(
      achievementId,
      'Mở Khóa Thành Tích! $emoji',
      '$achievementTitle - $achievementDescription',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          'Thông Báo Thành Tích',
          channelDescription: 'Thông báo cho các thành tích mở khóa',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'achievements',
        ),
      ),
      payload: 'achievement:$achievementType',
    );
  }

  /// 6. Weekly Summary Notifications
  Future<void> scheduleWeeklySummary() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklySummaryEnabled = prefs.getBool('weekly_summary_enabled') ?? true;
    
    if (!weeklySummaryEnabled) return;

    // Schedule for Sunday evening at 8 PM
    final now = DateTime.now();
    DateTime nextSunday = now.add(Duration(days: (7 - now.weekday) % 7));
    if (nextSunday.weekday != DateTime.sunday || nextSunday.isBefore(now)) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }
    final summaryTime = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 20, 0);

    // Calculate weekly stats
    final weeklyStats = await _calculateWeeklyStats();
    
    await notifications.zonedSchedule(
      weeklySummaryId,
      'Báo Cáo Tiến Độ Tuần 📊',
      'Tuần này: ${weeklyStats['wordsLearned']} từ, chuỗi ${weeklyStats['streakDays']} ngày, độ chính xác ${weeklyStats['accuracy']}%!',
      tz.TZDateTime.from(summaryTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_summary',
          'Tổng Kết Tuần',
          channelDescription: 'Báo cáo tiến độ học tập hàng tuần',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'weekly_summary',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_summary',
    );
  }

  /// 7. Streak Milestone Celebrations
  Future<void> showStreakMilestone(int streakDays) async {
    final prefs = await SharedPreferences.getInstance();
    final streakMilestoneEnabled = prefs.getBool('streak_milestone_enabled') ?? true;
    
    if (!streakMilestoneEnabled) return;

    String title = '';
    String body = '';
    
    if (streakDays == 7) {
      title = 'Tuyệt vời! 🎉';
      body = 'Đạt được chuỗi học 7 ngày! Bạn đang xây dựng thói quen tuyệt vời!';
    } else if (streakDays == 30) {
      title = 'Không thể tin nổi! 🏆';
      body = 'Chuỗi 30 ngày! Bạn là một học viên tận tâm!';
    } else if (streakDays == 100) {
      title = 'Huyền thoại! 👑';
      body = 'Bậc thầy chuỗi 100 ngày! Bạn không thể cản được!';
    } else if (streakDays % 50 == 0 && streakDays > 100) {
      title = 'Phi thường! ⭐';
      body = '$streakDays ngày học tập kiên trì! Bạn là nguồn cảm hứng!';
    } else {
      return; // Only celebrate specific milestones
    }

    await notifications.show(
      streakMilestoneId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_milestones',
          'Cốt Mốc Chuỗi Học',
          channelDescription: 'Chúc mừng các thành tích chuỗi học',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'streak_milestones',
        ),
      ),
      payload: 'streak_milestone:$streakDays',
    );
  }

  /// 8. Quiz Reminders
  Future<void> checkAndScheduleQuizReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final quizReminderEnabled = prefs.getBool('quiz_reminder_enabled') ?? true;
    
    if (!quizReminderEnabled) return;

    final lastQuizDate = prefs.getString('last_quiz_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    if (lastQuizDate == null || lastQuizDate != todayString) {
      // Check if user hasn't done quiz in 2 days
      DateTime? lastQuiz;
      if (lastQuizDate != null) {
        final parts = lastQuizDate.split('-');
        lastQuiz = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }

      if (lastQuiz == null || today.difference(lastQuiz).inDays >= 2) {
        await notifications.show(
          quizReminderId,
          'Giờ Kiểm Tra! ❓',
          'Hãy kiểm tra kiến thức từ vựng với một bài quiz nhanh!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'quiz_reminders',
              'Nhắc Nhở Kiểm Tra',
              channelDescription: 'Nhắc nhở làm kiểm tra từ vựng',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'quiz_reminders',
            ),
          ),
          payload: 'quiz_reminder',
        );
      }
    }
  }

  /// 9. Comeback Encouragement
  Future<void> checkAndScheduleComebackEncouragement() async {
    final prefs = await SharedPreferences.getInstance();
    final comebackEnabled = prefs.getBool('comeback_enabled') ?? true;
    
    if (!comebackEnabled) return;

    final lastActiveDate = prefs.getString('last_active_date');
    if (lastActiveDate != null) {
      final lastActive = DateTime.parse(lastActiveDate);
      final daysSinceActive = DateTime.now().difference(lastActive).inDays;

      if (daysSinceActive >= 3) {
        final messages = [
          'Chúng tôi nhớ bạn! 😊 Từ vựng của bạn đang chờ được mở rộng',
          'Hãy quay lại và tiếp tục hành trình học tập! 🌟',
          'Đừng để tiến độ của bạn tuột mất! 💪 Cùng học nào',
          'Những từ vựng đang cô đơn thiếu bạn! 📚 Đã đến lúc đoàn tụ?',
          'Sẵn sàng quay lại đúng hướng? 🚀 Mục tiêu của bạn đang chờ!',
        ];
        
        final randomMessage = messages[DateTime.now().millisecond % messages.length];

        await notifications.show(
          comebackEncouragementId,
          'Hãy Quay Lại! 🎯',
          randomMessage,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'comeback_encouragement',
              'Khích Lệ Trở Lại',
              channelDescription: 'Tin nhắn khích lệ cho người dùng không hoạt động',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'comeback_encouragement',
            ),
          ),
          payload: 'comeback_encouragement',
        );
      }
    }
  }

  // Helper methods for Phase 2

  Future<Map<String, dynamic>> _calculateWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    int wordsLearned = 0;
    int streakDays = 0;
    int totalAttempts = 0;
    int correctAnswers = 0;

    // Calculate words learned this week
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month}-${date.day}';
      wordsLearned += prefs.getInt('words_learned_$dateKey') ?? 0;
    }

    // Get current streak
    streakDays = prefs.getInt('streak_days') ?? 0;

    // Calculate accuracy from quiz stats (simplified)
    try {
      final quizRepo = QuizRepository();
      final stats = await quizRepo.getQuizStats();
      totalAttempts = stats['totalAttempts'] ?? 0;
      correctAnswers = stats['correctAnswers'] ?? 0;
    } catch (e) {
      print('Error getting quiz stats: $e');
    }

    final accuracy = totalAttempts > 0 ? ((correctAnswers / totalAttempts) * 100).round() : 0;

    return {
      'wordsLearned': wordsLearned,
      'streakDays': streakDays,
      'accuracy': accuracy,
    };
  }

  /// Update last active date (call this when user interacts with app)
  Future<void> updateLastActiveDate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    await prefs.setString('last_active_date', today.toIso8601String());
  }

  /// Mark quiz as completed today
  Future<void> markQuizCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    await prefs.setString('last_quiz_date', todayString);
  }

  /// Extended notification checks for Phase 2
  Future<void> runExtendedNotificationChecks() async {
    await runNotificationChecks(); // Phase 1 checks
    await scheduleWeeklySummary(); // Schedule weekly summary
  }
}