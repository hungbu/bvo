import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'smart_notification_service.dart';
import 'gamification_service.dart';

/// Centralized notification manager to prevent spam and coordinate all notifications
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final NotificationService _notificationService = NotificationService();
  final SmartNotificationService _smartService = SmartNotificationService();
  final GamificationService _gamificationService = GamificationService();

  // Cooldown periods (in minutes)
  static const int _sameCategoryCooldown = 120; // Same category cooldown
  static const int _appOpenCooldown = 5; // Cooldown after app opens
  
  // Notification categories
  static const String _categoryLearning = 'learning';
  static const String _categoryReminder = 'reminder';
  static const String _categoryAchievement = 'achievement';
  static const String _categoryStreak = 'streak';
  static const String _categoryQuiz = 'quiz';

  /// Initialize the notification manager
  Future<void> initialize() async {
    try {
      await _notificationService.initialize();
      await _smartService.initialize();
      await _markAppOpened();
      print('✅ NotificationManager initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationManager: $e');
      // Continue without crashing
    }
  }

  /// Mark that app was opened (to apply cooldown)
  Future<void> _markAppOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_app_open', DateTime.now().toIso8601String());
  }

  /// Check if we can send notifications (not in cooldown after app open)
  Future<bool> _canSendNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAppOpenStr = prefs.getString('last_app_open');
    
    if (lastAppOpenStr == null) return true;
    
    final lastAppOpen = DateTime.parse(lastAppOpenStr);
    final now = DateTime.now();
    final minutesSinceOpen = now.difference(lastAppOpen).inMinutes;
    
    return minutesSinceOpen >= _appOpenCooldown;
  }

  /// Check if we can send notification of specific category
  Future<bool> _canSendCategoryNotification(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCategoryNotificationStr = prefs.getString('last_notification_$category');
    
    if (lastCategoryNotificationStr == null) return true;
    
    final lastNotification = DateTime.parse(lastCategoryNotificationStr);
    final now = DateTime.now();
    final minutesSinceLastNotification = now.difference(lastNotification).inMinutes;
    
    return minutesSinceLastNotification >= _sameCategoryCooldown;
  }

  /// Mark that we sent a notification of specific category
  Future<void> _markCategoryNotificationSent(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_notification_$category', DateTime.now().toIso8601String());
  }

  /// Schedule daily reminders (only once per day)
  Future<void> scheduleDailyReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final lastScheduled = prefs.getString('last_daily_reminders_scheduled');
      
      // Only schedule once per day
      if (lastScheduled == todayKey) {
        print('📅 Daily reminders already scheduled for today');
        return;
      }
      
      await _notificationService.scheduleDailyReminders();
      await prefs.setString('last_daily_reminders_scheduled', todayKey);
      print('📅 Daily reminders scheduled for $todayKey');
    } catch (e) {
      print('❌ Error scheduling daily reminders: $e');
      // Continue without crashing the app
    }
  }

  /// Controlled notification checks (with cooldowns)
  Future<void> runControlledNotificationChecks() async {
    if (!await _canSendNotifications()) {
      print('🔕 Notification checks skipped - in app open cooldown');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) return;

    print('🔔 Running controlled notification checks...');
    
    // Only run essential checks that don't send immediate notifications
    await _checkStreakWarningLater();
    await _checkDueWordsLater();
    await _checkGoalProgressLater();
    
    print('✅ Controlled notification checks completed');
  }

  /// Check streak warning but schedule for later if needed
  Future<void> _checkStreakWarningLater() async {
    if (!await _canSendCategoryNotification(_categoryStreak)) return;
    
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final learnedToday = prefs.getBool('learned_$todayKey') ?? false;

    // Only warn if not learned today and it's after 6 PM
    if (!learnedToday && today.hour >= 18) {
      await _notificationService.checkAndScheduleStreakWarning();
      await _markCategoryNotificationSent(_categoryStreak);
    }
  }

  /// Check due words but with cooldown
  Future<void> _checkDueWordsLater() async {
    if (!await _canSendCategoryNotification(_categoryReminder)) return;
    
    await _notificationService.checkAndScheduleDueWordsAlert();
    await _markCategoryNotificationSent(_categoryReminder);
  }

  /// Check goal progress but with cooldown
  Future<void> _checkGoalProgressLater() async {
    if (!await _canSendCategoryNotification(_categoryLearning)) return;
    
    await _notificationService.checkAndScheduleGoalProgress();
    await _markCategoryNotificationSent(_categoryLearning);
  }

  /// Trigger after learning session (Smart Notification)
  Future<void> triggerAfterLearningSession(int wordsLearned, String topic) async {
    if (!await _canSendCategoryNotification(_categoryLearning)) {
      print('🔕 After learning notification skipped - in cooldown');
      return;
    }
    
    await _smartService.triggerAfterLearningSession(wordsLearned, topic);
    await _markCategoryNotificationSent(_categoryLearning);
    print('📚 After learning notification triggered: $wordsLearned words in $topic');
  }

  /// Check forgetting words (Smart Notification)
  Future<void> checkForgettingWords() async {
    if (!await _canSendCategoryNotification(_categoryReminder)) {
      print('🔕 Forgetting words check skipped - in cooldown');
      return;
    }
    
    await _smartService.checkForgettingWords();
    await _markCategoryNotificationSent(_categoryReminder);
    print('🧠 Forgetting words check completed');
  }

  /// Show achievement notification (with throttling)
  Future<void> showAchievement({
    required String title,
    required String description,
    required String type,
    required int value,
  }) async {
    if (!await _canSendCategoryNotification(_categoryAchievement)) {
      print('🔕 Achievement notification skipped - in cooldown');
      return;
    }

    // Check if this exact achievement was already shown recently
    final prefs = await SharedPreferences.getInstance();
    final achievementKey = 'achievement_shown_${type}_$value';
    final lastShown = prefs.getString(achievementKey);
    
    if (lastShown != null) {
      final lastShownTime = DateTime.parse(lastShown);
      final hoursSinceShown = DateTime.now().difference(lastShownTime).inHours;
      
      if (hoursSinceShown < 24) {
        print('🔕 Achievement already shown in last 24 hours: $type $value');
        return;
      }
    }
    
    await _gamificationService.checkAchievements(
      wordsLearned: type == 'words' ? value : null,
      streakDays: type == 'streak' ? value : null,
      accuracy: type == 'accuracy' ? value.toDouble() : null,
      quizzesTaken: type == 'quiz' ? value : null,
    );
    
    await prefs.setString(achievementKey, DateTime.now().toIso8601String());
    await _markCategoryNotificationSent(_categoryAchievement);
    print('🏆 Achievement notification shown: $title');
  }

  /// Evening review check (only once per evening)
  Future<void> performEveningReviewCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final eveningCheckDone = prefs.getBool('evening_check_done_$todayKey') ?? false;
    
    if (eveningCheckDone) {
      print('🌙 Evening review check already done today');
      return;
    }
    
    // Only do evening check after 7 PM
    if (today.hour >= 19) {
      await _smartService.performEveningReviewCheck();
      
      // Also check for quiz reminders during evening review
      if (await _canSendCategoryNotification(_categoryQuiz)) {
        await _notificationService.checkAndScheduleQuizReminder();
        await _markCategoryNotificationSent(_categoryQuiz);
      }
      
      await prefs.setBool('evening_check_done_$todayKey', true);
      print('🌙 Evening review check completed');
    }
  }

  /// Streak motivation (controlled timing)
  Future<void> triggerStreakMotivation() async {
    final now = DateTime.now();
    
    // Only trigger streak motivation in the evening (after 6 PM) or if streak is at risk
    if (now.hour < 18) {
      print('🔕 Streak motivation skipped - too early in the day');
      return;
    }
    
    if (!await _canSendCategoryNotification(_categoryStreak)) {
      print('🔕 Streak motivation skipped - in cooldown');
      return;
    }
    
    await _smartService.triggerStreakMotivation();
    await _markCategoryNotificationSent(_categoryStreak);
    print('🔥 Streak motivation triggered');
  }

  /// Get notification settings summary
  Future<Map<String, dynamic>> getNotificationSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    final summary = <String, dynamic>{};
    
    // Check cooldown status for each category
    for (final category in [_categoryLearning, _categoryReminder, _categoryAchievement, _categoryStreak, _categoryQuiz]) {
      final lastNotificationStr = prefs.getString('last_notification_$category');
      if (lastNotificationStr != null) {
        final lastNotification = DateTime.parse(lastNotificationStr);
        final minutesSinceLastNotification = now.difference(lastNotification).inMinutes;
        summary['${category}_cooldown_remaining'] = (_sameCategoryCooldown - minutesSinceLastNotification).clamp(0, _sameCategoryCooldown);
      } else {
        summary['${category}_cooldown_remaining'] = 0;
      }
    }
    
    // App open cooldown
    final lastAppOpenStr = prefs.getString('last_app_open');
    if (lastAppOpenStr != null) {
      final lastAppOpen = DateTime.parse(lastAppOpenStr);
      final minutesSinceOpen = now.difference(lastAppOpen).inMinutes;
      summary['app_open_cooldown_remaining'] = (_appOpenCooldown - minutesSinceOpen).clamp(0, _appOpenCooldown);
    } else {
      summary['app_open_cooldown_remaining'] = 0;
    }
    
    return summary;
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
    await _smartService.cancelAllSmartNotifications();
  }

  /// Update last active date
  Future<void> updateLastActiveDate() async {
    await _notificationService.updateLastActiveDate();
  }

  /// Show streak milestone (with deduplication)
  Future<void> showStreakMilestone(int streakDays) async {
    final prefs = await SharedPreferences.getInstance();
    final milestoneKey = 'streak_milestone_shown_$streakDays';
    final alreadyShown = prefs.getBool(milestoneKey) ?? false;
    
    if (alreadyShown) {
      print('🔕 Streak milestone already shown: $streakDays days');
      return;
    }
    
    await _notificationService.showStreakMilestone(streakDays);
    await prefs.setBool(milestoneKey, true);
    print('🏆 Streak milestone shown: $streakDays days');
  }
}
