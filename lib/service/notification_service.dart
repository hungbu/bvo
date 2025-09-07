import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../repository/quiz_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int morningReminderId = 1;
  static const int eveningReminderId = 2;
  static const int streakWarningId = 3;
  static const int dueWordsId = 4;
  static const int dailyGoalProgressId = 5;
  
  // Phase 2 IDs
  static const int achievementId = 6;
  static const int weeklySummaryId = 7;
  static const int streakMilestoneId = 8;
  static const int quizReminderId = 9;
  static const int comebackEncouragementId = 10;

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

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    await _notifications
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
    final eveningEnabled = prefs.getBool('evening_reminder_enabled') ?? true;
    
    // Get custom times or use defaults
    final morningHour = prefs.getInt('morning_reminder_hour') ?? 8;
    final morningMinute = prefs.getInt('morning_reminder_minute') ?? 0;
    final eveningHour = prefs.getInt('evening_reminder_hour') ?? 19;
    final eveningMinute = prefs.getInt('evening_reminder_minute') ?? 0;

    if (morningEnabled) {
      await _scheduleDailyNotification(
        id: morningReminderId,
        title: 'Good Morning! ☀️',
        body: 'Ready to learn 10 new words today?',
        hour: morningHour,
        minute: morningMinute,
        payload: 'morning_reminder',
      );
    }

    if (eveningEnabled) {
      await _scheduleDailyNotification(
        id: eveningReminderId,
        title: 'Evening Review 🌙',
        body: 'Time to practice today\'s words!',
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
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(_nextInstanceOfTime(hour, minute), tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily Learning Reminders',
          channelDescription: 'Daily reminders to study vocabulary',
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
          await _notifications.zonedSchedule(
            streakWarningId,
            'Don\'t break your streak! 🔥',
            'You have a $currentStreak-day streak. Just 5 minutes of study!',
            tz.TZDateTime.from(warningTime, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'streak_warnings',
                'Streak Warnings',
                channelDescription: 'Warnings to maintain learning streak',
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
        await _notifications.show(
          dueWordsId,
          'Review Time! 📝',
          '${dueWords.length} words are due for review. Perfect your memory!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'due_words',
              'Due Words Alerts',
              channelDescription: 'Alerts for words that need review',
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
        title = 'Let\'s get started! 🎯';
        body = 'Your daily goal: $dailyGoal words. Perfect time to begin!';
      } else if (todayWordsLearned >= dailyGoal) {
        // Goal achieved
        title = 'Daily Goal Completed! ✅';
        body = 'Amazing! You\'ve learned $todayWordsLearned words today. You\'re on fire! 🔥';
      } else if (todayWordsLearned >= dailyGoal * 0.5) {
        // 50% progress
        title = 'Halfway There! 🎯';
        body = '$todayWordsLearned/$dailyGoal words learned. Keep going!';
      }

      if (title != null && body != null) {
        await _notifications.show(
          dailyGoalProgressId,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'goal_progress',
              'Daily Goal Progress',
              channelDescription: 'Updates on daily learning goal progress',
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
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
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

    await _notifications.show(
      achievementId,
      'Achievement Unlocked! $emoji',
      '$achievementTitle - $achievementDescription',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          'Achievement Notifications',
          channelDescription: 'Notifications for unlocked achievements',
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
    
    await _notifications.zonedSchedule(
      weeklySummaryId,
      'Weekly Progress Report 📊',
      'This week: ${weeklyStats['wordsLearned']} words, ${weeklyStats['streakDays']} day streak, ${weeklyStats['accuracy']}% accuracy!',
      tz.TZDateTime.from(summaryTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_summary',
          'Weekly Summary',
          channelDescription: 'Weekly learning progress reports',
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
      title = 'Amazing! 🎉';
      body = '7-day learning streak achieved! You\'re building great habits!';
    } else if (streakDays == 30) {
      title = 'Incredible! 🏆';
      body = '30-day streak! You\'re a dedicated learner!';
    } else if (streakDays == 100) {
      title = 'Legendary! 👑';
      body = '100-day streak master! You\'re unstoppable!';
    } else if (streakDays % 50 == 0 && streakDays > 100) {
      title = 'Phenomenal! ⭐';
      body = '$streakDays days of consistent learning! You\'re an inspiration!';
    } else {
      return; // Only celebrate specific milestones
    }

    await _notifications.show(
      streakMilestoneId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_milestones',
          'Streak Milestones',
          channelDescription: 'Celebrations for streak achievements',
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
        await _notifications.show(
          quizReminderId,
          'Quiz Time! ❓',
          'Test your vocabulary knowledge with a quick quiz!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'quiz_reminders',
              'Quiz Reminders',
              channelDescription: 'Reminders to take vocabulary quizzes',
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
          'We miss you! 😊 Your vocabulary is waiting to grow',
          'Come back and continue your learning journey! 🌟',
          'Don\'t let your progress slip away! 💪 Let\'s learn together',
          'Your words are lonely without you! 📚 Time to reunite?',
          'Ready to get back on track? 🚀 Your goals are waiting!',
        ];
        
        final randomMessage = messages[DateTime.now().millisecond % messages.length];

        await _notifications.show(
          comebackEncouragementId,
          'Come Back! 🎯',
          randomMessage,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'comeback_encouragement',
              'Comeback Encouragement',
              channelDescription: 'Encouraging messages for inactive users',
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