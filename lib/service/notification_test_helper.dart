import 'package:bvo/service/smart_notification_service.dart';
import 'package:bvo/service/gamification_service.dart';

class NotificationTestHelper {
  static final SmartNotificationService _smartService = SmartNotificationService();
  static final GamificationService _gamificationService = GamificationService();

  /// Test all notification types for development
  static Future<void> testAllNotifications() async {
    print('🧪 Testing Smart Notification System...');
    
    // Test after learning notification
    await _smartService.triggerAfterLearningSession(8, 'Business English');
    print('✅ After learning notification sent');
    
    // Test forgetting words notification
    await _smartService.checkForgettingWords();
    print('✅ Forgetting words check completed');
    
    // Test streak motivation
    await _smartService.triggerStreakMotivation();
    print('✅ Streak motivation sent');
    
    // Test evening review
    await _smartService.performEveningReviewCheck();
    print('✅ Evening review check completed');
    
    // Test achievements
    await _gamificationService.checkAchievements(
      wordsLearned: 100,
      streakDays: 7,
      accuracy: 85.0,
      quizzesTaken: 25,
    );
    print('✅ Achievement checks completed');
    
    // Test encouragement
    await _gamificationService.showEncouragementNotification();
    print('✅ Encouragement notification sent');
    
    print('🎉 All notifications tested successfully!');
  }

  /// Test specific notification type
  static Future<void> testAfterLearningNotification() async {
    await _smartService.triggerAfterLearningSession(5, 'Travel Vocabulary');
    print('✅ After learning notification sent for Travel Vocabulary');
  }

  /// Test achievement notifications
  static Future<void> testAchievementNotifications() async {
    await _gamificationService.checkAchievements(
      wordsLearned: 50, // Should trigger first milestone
      streakDays: 7,    // Should trigger week milestone
      accuracy: 90.0,   // Should trigger accuracy achievement
    );
    print('✅ Achievement notifications tested');
  }

  /// Test forgetting words notification
  static Future<void> testForgettingWordsNotification() async {
    await _smartService.checkForgettingWords();
    print('✅ Forgetting words notification tested');
  }
}
