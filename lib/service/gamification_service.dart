import 'dart:io' show Platform;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Check if platform supports notifications
  bool get _isNotificationSupported {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // Achievement notification IDs
  static const int achievementNotificationId = 200;
  static const int milestoneNotificationId = 201;
  static const int encouragementNotificationId = 202;

  /// Check and trigger achievement notifications
  Future<void> checkAchievements({
    int? wordsLearned,
    int? streakDays,
    double? accuracy,
    int? quizzesTaken,
  }) async {
    if (!_isNotificationSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check various achievements
    if (wordsLearned != null) {
      await _checkWordMilestones(wordsLearned, prefs);
    }
    
    if (streakDays != null) {
      await _checkStreakMilestones(streakDays, prefs);
    }
    
    if (accuracy != null) {
      await _checkAccuracyAchievements(accuracy, prefs);
    }
    
    if (quizzesTaken != null) {
      await _checkQuizMilestones(quizzesTaken, prefs);
    }
  }

  /// Check word learning milestones
  Future<void> _checkWordMilestones(int wordsLearned, SharedPreferences prefs) async {
    final milestones = [50, 100, 250, 500, 1000, 2000, 5000];
    
    for (int milestone in milestones) {
      final achievementKey = 'achievement_words_$milestone';
      final hasAchievement = prefs.getBool(achievementKey) ?? false;
      
      if (!hasAchievement && wordsLearned >= milestone) {
        await _showAchievementNotification(
          _getWordMilestoneNotification(milestone),
        );
        await prefs.setBool(achievementKey, true);
        break; // Only show one achievement at a time
      }
    }
  }

  /// Check streak milestones
  Future<void> _checkStreakMilestones(int streakDays, SharedPreferences prefs) async {
    final milestones = [7, 14, 30, 60, 100, 365];
    
    for (int milestone in milestones) {
      final achievementKey = 'achievement_streak_$milestone';
      final hasAchievement = prefs.getBool(achievementKey) ?? false;
      
      if (!hasAchievement && streakDays >= milestone) {
        await _showAchievementNotification(
          _getStreakMilestoneNotification(milestone),
        );
        await prefs.setBool(achievementKey, true);
        break;
      }
    }
  }

  /// Check accuracy achievements
  Future<void> _checkAccuracyAchievements(double accuracy, SharedPreferences prefs) async {
    final accuracyMilestones = [80.0, 90.0, 95.0, 99.0];
    
    for (double milestone in accuracyMilestones) {
      final achievementKey = 'achievement_accuracy_${milestone.toInt()}';
      final hasAchievement = prefs.getBool(achievementKey) ?? false;
      
      if (!hasAchievement && accuracy >= milestone) {
        await _showAchievementNotification(
          _getAccuracyAchievementNotification(milestone),
        );
        await prefs.setBool(achievementKey, true);
        break;
      }
    }
  }

  /// Check quiz milestones
  Future<void> _checkQuizMilestones(int quizzesTaken, SharedPreferences prefs) async {
    final milestones = [10, 25, 50, 100, 250, 500];
    
    for (int milestone in milestones) {
      final achievementKey = 'achievement_quiz_$milestone';
      final hasAchievement = prefs.getBool(achievementKey) ?? false;
      
      if (!hasAchievement && quizzesTaken >= milestone) {
        await _showAchievementNotification(
          _getQuizMilestoneNotification(milestone),
        );
        await prefs.setBool(achievementKey, true);
        break;
      }
    }
  }

  /// Show achievement notification
  Future<void> _showAchievementNotification(Map<String, String> notification) async {
    await _notifications.show(
      achievementNotificationId,
      notification['title']!,
      notification['body']!,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'achievements',
          'Thành tích',
          channelDescription: 'Thông báo thành tích và cột mốc',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: 'achievement',
    );
  }

  /// Generate word milestone notifications
  Map<String, String> _getWordMilestoneNotification(int milestone) {
    final notifications = {
      50: {
        'title': '🎉 Cột mốc đầu tiên!',
        'body': 'Chúc mừng! Bạn đã học được $milestone từ vựng — khởi đầu tuyệt vời!'
      },
      100: {
        'title': '💯 Trăm từ đầu tiên!',
        'body': 'Wow! $milestone từ vựng — bạn đang xây dựng nền tảng vững chắc!'
      },
      250: {
        'title': '🚀 Tăng tốc mạnh mẽ!',
        'body': '$milestone từ vựng! Bạn đã vượt qua giai đoạn khó khăn nhất!'
      },
      500: {
        'title': '⭐ Nửa ngàn từ vựng!',
        'body': 'Tuyệt vời! $milestone từ — bạn đã có vốn từ vựng ấn tượng!'
      },
      1000: {
        'title': '🏆 Nghìn từ vựng!',
        'body': 'Đỉnh cao! $milestone từ vựng — bạn đã trở thành chuyên gia!'
      },
      2000: {
        'title': '👑 Bậc thầy từ vựng!',
        'body': '$milestone từ vựng! Bạn đã đạt trình độ cao thủ!'
      },
      5000: {
        'title': '🌟 Huyền thoại!',
        'body': '$milestone từ vựng! Bạn là huyền thoại của từ vựng!'
      },
    };
    
    return notifications[milestone] ?? {
      'title': '🎯 Cột mốc mới!',
      'body': 'Chúc mừng! Bạn đã đạt $milestone từ vựng!'
    };
  }

  /// Generate streak milestone notifications
  Map<String, String> _getStreakMilestoneNotification(int days) {
    final notifications = {
      7: {
        'title': '🔥 Tuần đầu tiên!',
        'body': '$days ngày liên tục! Bạn đã tạo thói quen tuyệt vời!'
      },
      14: {
        'title': '💪 Hai tuần kiên trì!',
        'body': '$days ngày không nghỉ! Ý chí của bạn thật đáng ngưỡng mộ!'
      },
      30: {
        'title': '🌟 Một tháng hoàn hảo!',
        'body': '$days ngày liên tục! Bạn đã chứng minh sự quyết tâm!'
      },
      60: {
        'title': '🚀 Hai tháng phi thường!',
        'body': '$days ngày! Bạn đã vượt qua mọi thử thách!'
      },
      100: {
        'title': '👑 Trăm ngày huyền thoại!',
        'body': '$days ngày! Bạn là biểu tượng của sự kiên trì!'
      },
      365: {
        'title': '🏆 Một năm hoàn hảo!',
        'body': '$days ngày! Bạn đã tạo nên kỳ tích!'
      },
    };
    
    return notifications[days] ?? {
      'title': '🔥 Chuỗi dài ấn tượng!',
      'body': '$days ngày liên tục! Bạn thật tuyệt vời!'
    };
  }

  /// Generate accuracy achievement notifications
  Map<String, String> _getAccuracyAchievementNotification(double accuracy) {
    final notifications = {
      80: {
        'title': '🎯 Độ chính xác cao!',
        'body': '${accuracy.toInt()}% chính xác! Bạn đang tiến bộ vượt bậc!'
      },
      90: {
        'title': '⭐ Xuất sắc!',
        'body': '${accuracy.toInt()}% chính xác! Trình độ của bạn thật ấn tượng!'
      },
      95: {
        'title': '🏆 Gần như hoàn hảo!',
        'body': '${accuracy.toInt()}% chính xác! Bạn đã đạt trình độ chuyên gia!'
      },
      99: {
        'title': '👑 Hoàn hảo tuyệt đối!',
        'body': '${accuracy.toInt()}% chính xác! Bạn là bậc thầy thực thụ!'
      },
    };
    
    return notifications[accuracy.toInt()] ?? {
      'title': '🎯 Độ chính xác tuyệt vời!',
      'body': '${accuracy.toInt()}% chính xác! Bạn thật xuất sắc!'
    };
  }

  /// Generate quiz milestone notifications
  Map<String, String> _getQuizMilestoneNotification(int quizzes) {
    final notifications = {
      10: {
        'title': '📝 Mười bài quiz đầu tiên!',
        'body': '$quizzes bài quiz! Bạn đã bắt đầu hành trình ôn tập!'
      },
      25: {
        'title': '🎓 Người học chăm chỉ!',
        'body': '$quizzes bài quiz! Bạn thực sự yêu thích việc học!'
      },
      50: {
        'title': '⚡ Năng suất cao!',
        'body': '$quizzes bài quiz! Tốc độ học tập của bạn thật ấn tượng!'
      },
      100: {
        'title': '🏅 Trăm bài quiz!',
        'body': '$quizzes bài quiz! Bạn là chiến binh của tri thức!'
      },
      250: {
        'title': '🚀 Siêu năng suất!',
        'body': '$quizzes bài quiz! Bạn đã trở thành máy học tập!'
      },
      500: {
        'title': '👑 Bậc thầy quiz!',
        'body': '$quizzes bài quiz! Bạn là huyền thoại của việc ôn tập!'
      },
    };
    
    return notifications[quizzes] ?? {
      'title': '📚 Cột mốc quiz mới!',
      'body': 'Chúc mừng! Bạn đã hoàn thành $quizzes bài quiz!'
    };
  }

  /// Show encouragement notification for struggling users
  Future<void> showEncouragementNotification() async {
    if (!_isNotificationSupported) return;
    
    final encouragements = [
      {
        'title': '💪 Đừng bỏ cuộc!',
        'body': 'Mỗi từ vựng bạn học đều là một bước tiến — hãy tiếp tục!'
      },
      {
        'title': '🌱 Từng bước một!',
        'body': 'Học từ vựng giống như trồng cây — cần thời gian để ra quả!'
      },
      {
        'title': '⭐ Bạn làm được!',
        'body': 'Khó khăn chỉ là tạm thời — thành công đang chờ bạn phía trước!'
      },
      {
        'title': '🎯 Tập trung vào tiến bộ!',
        'body': 'Không cần hoàn hảo — chỉ cần tiến bộ mỗi ngày một chút!'
      },
    ];

    final encouragement = encouragements[Random().nextInt(encouragements.length)];

    await _notifications.show(
      encouragementNotificationId,
      encouragement['title']!,
      encouragement['body']!,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'encouragement',
          'Động viên',
          channelDescription: 'Thông báo động viên và khích lệ',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'encouragement',
    );
  }
}
