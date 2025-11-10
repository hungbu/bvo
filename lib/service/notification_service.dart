import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../repository/quiz_repository.dart';
import '../model/word.dart';
import 'notification_vocabulary_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  final NotificationVocabularyService _vocabularyService = NotificationVocabularyService();

  // Check if platform supports notifications
  bool get _isNotificationSupported {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

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
    if (!_isNotificationSupported) {
      print('⚠️ Notifications not supported on this platform (${Platform.operatingSystem})');
      return;
    }

    // Android initialization
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    
    // iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
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
    
    final iosImplementation = notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      final bool? result = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: false,
      );
      print('iOS notification permissions granted: $result');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  // PHASE 1 NOTIFICATIONS

  /// 1. Daily Learning Reminders
  Future<void> scheduleDailyReminders() async {
    if (!_isNotificationSupported) return;
    
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
      // Lấy từ vựng cho buổi sáng
      final morningWord = await _vocabularyService.getMorningWord();
      String morningBody = 'Sẵn sàng học 10 từ mới hôm nay chưa?';
      
      if (morningWord != null) {
        final wordText = _vocabularyService.formatWordForNotification(morningWord);
        morningBody = 'Từ vựng hôm nay: $wordText\nSẵn sàng học thêm không? 📚';
      }
      
      await _scheduleDailyNotification(
        id: morningReminderId,
        title: 'Chào Buổi Sáng! ☀️',
        body: morningBody,
        hour: morningHour,
        minute: morningMinute,
        payload: 'morning_reminder',
      );
    }

    if (noonEnabled) {
      // Lấy từ vựng cho buổi trưa
      final noonWord = await _vocabularyService.getNoonWord();
      String noonBody = 'Thời gian hoàn hảo để học vài từ mới trong giờ nghỉ!';
      
      if (noonWord != null) {
        final wordText = _vocabularyService.formatWordForNotification(noonWord);
        noonBody = 'Từ vựng: $wordText\nGiờ nghỉ trưa học từ nào! ☕';
      }
      
      await _scheduleDailyNotification(
        id: noonReminderId,
        title: 'Nghỉ Trưa Học Từ! ☀️',
        body: noonBody,
        hour: noonHour,
        minute: noonMinute,
        payload: 'noon_reminder',
      );
    }

    if (eveningEnabled) {
      // Lấy từ vựng cho buổi tối (ôn tập)
      final eveningWord = await _vocabularyService.getEveningWord();
      String eveningBody = 'Đã đến lúc ôn lại những từ hôm nay!';
      
      if (eveningWord != null) {
        final wordText = _vocabularyService.formatWordForNotification(eveningWord);
        eveningBody = 'Ôn tập: $wordText\nKết thúc ngày với việc ôn từ vựng! 🌙';
      }
      
      await _scheduleDailyNotification(
        id: eveningReminderId,
        title: 'Ôn Tập Buổi Tối 🌙',
        body: eveningBody,
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
    try {
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
            icon: 'ic_notification',
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'daily_reminders',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      print('📅 Scheduled daily notification: $title at $hour:$minute');
    } catch (e) {
      print('❌ Error scheduling daily notification: $e');
      // Don't rethrow to prevent app crash
    }
  }

  /// 2. Streak Warning Notifications
  Future<void> checkAndScheduleStreakWarning() async {
    if (!_isNotificationSupported) return;
    
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
          try {
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
                  icon: 'ic_notification',
                ),
                iOS: DarwinNotificationDetails(
                  categoryIdentifier: 'streak_warnings',
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: 'streak_warning',
            );
            print('🔥 Scheduled streak warning for $currentStreak days');
          } catch (e) {
            print('❌ Error scheduling streak warning: $e');
          }
        }
      }
    }
  }

  /// 3. Due Words Alert
  Future<void> checkAndScheduleDueWordsAlert() async {
    if (!_isNotificationSupported) return;
    
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
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'due_words',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
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
    if (!_isNotificationSupported) return;
    
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
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'goal_progress',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
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

  /// Test notification immediately
  Future<void> sendTestNotification() async {
    if (!_isNotificationSupported) {
      print('⚠️ Notifications not supported on this platform');
      return;
    }
    
    await notifications.show(
      999,
      'Test Notification',
      'Đây là notification test để kiểm tra icon hiển thị',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Channel',
          channelDescription: 'Channel for testing notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'test_notification',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_notification',
    );
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
    if (!_isNotificationSupported) return;
    
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    await checkAndScheduleStreakWarning();
    await checkAndScheduleDueWordsAlert();
    await checkAndScheduleGoalProgress();
    // REMOVED: await checkAndScheduleQuizReminder(); // No longer trigger quiz notification on app open
    await checkAndScheduleComebackEncouragement();
  }

  // PHASE 2 NOTIFICATIONS

  /// 5. Achievement Notifications
  Future<void> showAchievementNotification({
    required String achievementTitle,
    required String achievementDescription,
    required String achievementType,
  }) async {
    if (!_isNotificationSupported) return;
    
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
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'achievements',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'achievement:$achievementType',
    );
  }

  /// 6. Weekly Summary Notifications
  Future<void> scheduleWeeklySummary() async {
    if (!_isNotificationSupported) return;
    
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
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'weekly_summary',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_summary',
    );
  }

  /// 7. Streak Milestone Celebrations
  Future<void> showStreakMilestone(int streakDays) async {
    if (!_isNotificationSupported) return;
    
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
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'streak_milestones',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'streak_milestone:$streakDays',
    );
  }

  /// 8. Quiz Reminders (called only during evening review or manually)
  Future<void> checkAndScheduleQuizReminder() async {
    if (!_isNotificationSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    final quizReminderEnabled = prefs.getBool('quiz_reminder_enabled') ?? true;
    
    if (!quizReminderEnabled) return;

    final now = DateTime.now();
    // Only trigger quiz reminders in the evening (after 6 PM) or late morning (after 10 AM)
    if (now.hour < 10 || (now.hour > 12 && now.hour < 18)) {
      print('🔕 Quiz reminder skipped - not appropriate time (${now.hour}:00)');
      return;
    }

    final lastQuizDate = prefs.getString('last_quiz_date');
    final todayString = '${now.year}-${now.month}-${now.day}';

    // Only remind if no quiz today and it's been more than 1 day since last quiz
    if (lastQuizDate == null || lastQuizDate != todayString) {
      DateTime? lastQuiz;
      if (lastQuizDate != null) {
        try {
          final parts = lastQuizDate.split('-');
          lastQuiz = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } catch (e) {
          print('Error parsing last quiz date: $e');
        }
      }

      // Only remind if no quiz in last 2 days (instead of immediately)
      if (lastQuiz == null || now.difference(lastQuiz).inDays >= 2) {
        // Check if user learned something today (more contextual reminder)
        final todayWordsLearned = prefs.getInt('words_learned_$todayString') ?? 0;
        final reminderTitle = todayWordsLearned > 0 
            ? '🎯 Thử kiểm tra kiến thức!'
            : '📝 Đã lâu không quiz rồi!';
        final reminderBody = todayWordsLearned > 0
            ? 'Bạn học $todayWordsLearned từ hôm nay. Quiz để xem nhớ được bao nhiêu nhé!'
            : 'Hãy kiểm tra xem bạn còn nhớ những từ đã học không!';

        await notifications.show(
          quizReminderId,
          reminderTitle,
          reminderBody,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'quiz_reminders',
              'Nhắc Nhở Kiểm Tra',
              channelDescription: 'Nhắc nhở làm kiểm tra từ vựng',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'quiz_reminders',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: 'quiz_reminder',
        );
        
        print('📝 Quiz reminder sent - last quiz: ${lastQuiz?.toString() ?? "never"}');
      }
    }
  }

  /// 9. Comeback Encouragement
  Future<void> checkAndScheduleComebackEncouragement() async {
    if (!_isNotificationSupported) return;
    
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
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'comeback_encouragement',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
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

  /// Test method để kiểm tra thông báo với từ vựng
  Future<void> testVocabularyNotifications() async {
    if (!_isNotificationSupported) {
      print('⚠️ Notifications not supported on this platform');
      return;
    }
    
    print('🧪 Testing vocabulary notifications...');
    
    try {
      // Test lấy từ vựng cho các thời điểm khác nhau
      final morningWord = await _vocabularyService.getMorningWord();
      final noonWord = await _vocabularyService.getNoonWord();
      final eveningWord = await _vocabularyService.getEveningWord();
      
      print('📅 Morning word: ${morningWord?.en} - ${morningWord?.vi}');
      print('🌅 Noon word: ${noonWord?.en} - ${noonWord?.vi}');
      print('🌙 Evening word: ${eveningWord?.en} - ${eveningWord?.vi}');
      
      // Test hiển thị thông báo ngay lập tức
      if (morningWord != null) {
        final wordText = _vocabularyService.formatWordForNotification(morningWord);
        await notifications.show(
          999, // Test ID
          'Test Thông Báo Từ Vựng 📚',
          'Từ vựng test: $wordText\nĐây là thông báo thử nghiệm!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'test_vocabulary',
              'Test Từ Vựng',
              channelDescription: 'Kênh test thông báo từ vựng',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'test_vocabulary',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: 'test_vocabulary',
        );
        
        print('✅ Test notification sent with word: ${morningWord.en}');
      } else {
        print('❌ No morning word found for test');
      }
      
    } catch (e) {
      print('❌ Error testing vocabulary notifications: $e');
    }
  }

  /// Hiển thị thông báo từ vựng ngay lập tức (để test)
  Future<void> showImmediateVocabularyNotification({
    required String timeOfDay, // 'morning', 'noon', 'evening'
  }) async {
    if (!_isNotificationSupported) {
      print('⚠️ Notifications not supported on this platform');
      return;
    }
    
    try {
      dWord? word;
      String title;
      String emoji;
      
      switch (timeOfDay.toLowerCase()) {
        case 'morning':
          word = await _vocabularyService.getMorningWord();
          title = 'Chào Buổi Sáng! ☀️';
          emoji = '🌅';
          break;
        case 'noon':
          word = await _vocabularyService.getNoonWord();
          title = 'Nghỉ Trưa Học Từ! ☀️';
          emoji = '☕';
          break;
        case 'evening':
          word = await _vocabularyService.getEveningWord();
          title = 'Ôn Tập Buổi Tối 🌙';
          emoji = '🌙';
          break;
        default:
          word = await _vocabularyService.getRandomWordForNotification();
          title = 'Học Từ Vựng! 📚';
          emoji = '📚';
      }
      
      if (word != null) {
        final wordText = _vocabularyService.formatWordForNotification(word);
        final body = 'Từ vựng: $wordText\nTap để học thêm! $emoji';
        
        await notifications.show(
          1000 + timeOfDay.hashCode, // Unique ID based on time of day
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'immediate_vocabulary',
              'Từ Vựng Ngay Lập Tức',
              channelDescription: 'Thông báo từ vựng hiển thị ngay',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'immediate_vocabulary',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: 'immediate_vocabulary:${word.en}:${word.topic}',
        );
        
        print('✅ Immediate vocabulary notification sent: ${word.en} - ${word.vi}');
      } else {
        print('❌ No word found for $timeOfDay notification');
      }
    } catch (e) {
      print('❌ Error showing immediate vocabulary notification: $e');
    }
  }
}