import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/auth_service.dart';
import '../service/notification_service.dart';
import '../repository/word_repository.dart';
import '../repository/topic_repository.dart';
import '../repository/quiz_repository.dart';

class ProfileScreen extends StatefulWidget {
  final Function(VoidCallback)? onRefreshCallback;
  
  const ProfileScreen({Key? key, this.onRefreshCallback}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, List<dynamic>> reviewedWordsByTopic = {};
  int totalWordsLearned = 0;
  int totalWordsInQuiz = 0;
  int dueWordsCount = 0;
  int currentStreak = 0;
  int longestStreak = 0;
  double accuracy = 0.0;
  int totalTopics = 0;
  int todayWordsLearned = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    // Đăng ký callback với MainLayout
    widget.onRefreshCallback?.call(_loadUserStats);
  }

  Future<void> _loadUserStats() async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final wordRepo = WordRepository();
      final topicRepo = TopicRepository();
      final quizRepo = QuizRepository();

      // Use same logic as HomePage - get reviewed words from repository
      final reviewedWords = await wordRepo.getReviewedWordsGroupedByTopic();
      final totalLearned = reviewedWords.values.fold(0, (sum, words) => sum + words.length);

      // Get all topics for total count
      final topics = await topicRepo.getTopics();

      // Get quiz statistics
      final quizStats = await quizRepo.getQuizStats();
      final quizWords = await quizRepo.getQuizWords();
      final dueWords = await quizRepo.getDueWords();

      // Calculate accuracy from quiz stats
      double calculatedAccuracy = 0.0;
      if (quizStats['totalAttempts'] > 0) {
        calculatedAccuracy = (quizStats['correctAnswers'] / quizStats['totalAttempts']) * 100;
      }

      // Use same streak keys as HomePage
      final currentStreakValue = prefs.getInt('streak_days') ?? 0;
      final longestStreakValue = prefs.getInt('longest_streak') ?? 0;

      // Get today's words learned
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final todayWords = prefs.getInt('words_learned_$todayKey') ?? 0;

      setState(() {
        totalWordsLearned = totalLearned;
        reviewedWordsByTopic = reviewedWords;
        totalWordsInQuiz = quizWords.length;
        dueWordsCount = dueWords.length;
        accuracy = calculatedAccuracy;
        currentStreak = currentStreakValue;
        longestStreak = longestStreakValue;
        totalTopics = topics.length;
        todayWordsLearned = todayWords;
        isLoading = false;
      });

    } catch (error) {
      print('Error loading user stats: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper method to update streak data (can be called from other screens like QuizGameScreen)
  static Future<void> updateStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final lastActiveDate = prefs.getString('last_active_date');
      
      if (lastActiveDate == null) {
        // First time user
        await prefs.setInt('current_streak', 1);
        await prefs.setInt('longest_streak', 1);
        await prefs.setString('last_active_date', today.toIso8601String());
      } else {
        final lastActive = DateTime.parse(lastActiveDate);
        final daysDifference = today.difference(lastActive).inDays;
        
        if (daysDifference == 1) {
          // Consecutive day
          final currentStreak = prefs.getInt('current_streak') ?? 0;
          final newStreak = currentStreak + 1;
          await prefs.setInt('current_streak', newStreak);
          
          // Update longest streak if needed
          final longestStreak = prefs.getInt('longest_streak') ?? 0;
          if (newStreak > longestStreak) {
            await prefs.setInt('longest_streak', newStreak);
          }
          
          await prefs.setString('last_active_date', today.toIso8601String());
        } else if (daysDifference > 1) {
          // Streak broken
          await prefs.setInt('current_streak', 1);
          await prefs.setString('last_active_date', today.toIso8601String());
        }
        // If daysDifference == 0, same day, no update needed
      }
    } catch (error) {
      print('Error updating streak data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your progress...'),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadUserStats,
            child: SingleChildScrollView(
        child: Column(
          children: [
          
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Cards
                  const Text(
                    'Tiến Độ Của Bạn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Từ Đã Học',
                          totalWordsLearned.toString(),
                          Icons.school,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Từ Hôm Nay',
                          todayWordsLearned.toString(),
                          Icons.today,
                          Colors.cyan,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Chuỗi Hiện Tại',
                          '$currentStreak days',
                          Icons.local_fire_department,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Chuỗi Dài Nhất',
                          '$longestStreak days',
                          Icons.emoji_events,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Độ Chính Xác',
                          '${accuracy.toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Từ Quiz',
                          totalWordsInQuiz.toString(),
                          Icons.quiz,
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Từ Cần Ôn',
                          dueWordsCount.toString(),
                          Icons.schedule,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Tổng Chủ Đề',
                          totalTopics.toString(),
                          Icons.topic,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Achievements Section
                  const Text(
                    'Thành Tích',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _buildAchievementsList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings Section
                  const Text(
                    'Cài Đặt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSettingsItem(
                    icon: Icons.notifications,
                    title: 'Thông Báo',
                    subtitle: 'Nhắc nhở hàng ngày và cập nhật',
                    onTap: () {
                      _showNotificationSettings();
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.volume_up,
                    title: 'Âm Thanh',
                    subtitle: 'Giọng nói và hiệu ứng âm thanh',
                    onTap: () {
                      // Handle sound settings
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    subtitle: 'Câu hỏi thường gặp và liên hệ',
                    onTap: () {
                      // Handle help
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.privacy_tip,
                    title: 'Chính Sách Bảo Mật',
                    subtitle: 'Điều khoản và điều kiện',
                    onTap: () {
                      // Handle privacy policy
                    },
                  ),

                  const SizedBox(height: 20),

                  //Clear Local Data Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showClearDataDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.orange.shade200),
                        ),
                      ),
                      child: const Text(
                        'Xóa Dữ Liệu Cục Bộ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showSignOutDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      child: const Text(
                        'Đăng Xuất',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
            ),
          ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAchievementsList() {
    List<Widget> achievements = [];

    // First Word Achievement
    if (totalWordsLearned > 0) {
      achievements.add(_buildAchievementBadge('Từ Đầu Tiên', Icons.star, Colors.amber));
    }

    // Streak Achievements
    if (currentStreak >= 3) {
      achievements.add(_buildAchievementBadge('3 Day Streak', Icons.local_fire_department, Colors.orange));
    }
    if (currentStreak >= 7) {
      achievements.add(_buildAchievementBadge('7 Day Streak', Icons.local_fire_department, Colors.deepOrange));
    }
    if (longestStreak >= 30) {
      achievements.add(_buildAchievementBadge('30 Day Streak', Icons.emoji_events, Colors.red));
    }

    // Words Learned Achievements
    if (totalWordsLearned >= 10) {
      achievements.add(_buildAchievementBadge('10 Words', Icons.school, Colors.blue));
    }
    if (totalWordsLearned >= 50) {
      achievements.add(_buildAchievementBadge('50 Words', Icons.school, Colors.indigo));
    }
    if (totalWordsLearned >= 100) {
      achievements.add(_buildAchievementBadge('100 Words', Icons.school, Colors.purple));
    }

    // Quiz Achievements
    if (totalWordsInQuiz >= 20) {
      achievements.add(_buildAchievementBadge('Bậc Thầy Quiz', Icons.quiz, Colors.green));
    }
    if (accuracy >= 80.0) {
      achievements.add(_buildAchievementBadge('Độ Chính Xác Cao', Icons.trending_up, Colors.teal));
    }

    // Topic Achievements
    if (reviewedWordsByTopic.length >= 3) {
      achievements.add(_buildAchievementBadge('Nhà Khám Phá', Icons.explore, Colors.cyan));
    }

    // Daily Achievements
    if (todayWordsLearned >= 5) {
      achievements.add(_buildAchievementBadge('Mục Tiêu Hàng Ngày', Icons.today, Colors.lightBlue));
    }
    if (todayWordsLearned >= 10) {
      achievements.add(_buildAchievementBadge('Siêu Học Viên', Icons.star_rate, Colors.amber));
    }

    // If no achievements, show placeholder
    if (achievements.isEmpty) {
      achievements.add(_buildAchievementBadge('Bắt Đầu Học', Icons.play_arrow, Colors.grey));
    }

    return achievements;
  }

  Widget _buildAchievementBadge(String title, IconData icon, Color color) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

    void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đăng Xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất? Điều này sẽ xóa tất cả dữ liệu cục bộ của bạn.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleSignOut();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Đăng Xuất'),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa Dữ Liệu Cục Bộ'),
          content: const Text('Bạn có chắc chắn muốn xóa tất cả dữ liệu cục bộ? Điều này sẽ xóa tất cả chủ đề và từ vựng đã lưu. Bạn có thể làm mới dữ liệu bằng cách điều hướng qua ứng dụng lại.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearLocalData();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Xóa Dữ Liệu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearLocalData() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Clearing local data...'),
              ],
            ),
          );
        },
      );

      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys and remove those related to words and topics
      final keys = prefs.getKeys();
      final keysToRemove = keys.where((key) => 
        key.startsWith('words_') || 
        key.startsWith('cached_topics') ||
        key.startsWith('reviewed_words_')
      ).toList();

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local data cleared successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      print('Local data cleared!');

    } catch (error) {
      // Close loading dialog if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing data: $error'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error clearing data: $error');
    }
  }

  Future<void> _handleSignOut() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Sign out using AuthService
      await AuthService().signOut();

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Navigate to login page (replace entire navigation stack)
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (Route<dynamic> route) => false,
      );

    } catch (error) {
      // Close loading dialog if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSettingsSheet(),
    );
  }

}

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool _notificationsEnabled = true;
  bool _morningReminderEnabled = true;
  bool _noonReminderEnabled = true;
  bool _eveningReminderEnabled = true;
  bool _streakWarningEnabled = true;
  bool _dueWordsEnabled = true;
  bool _goalProgressEnabled = true;
  
  // Phase 2 settings
  bool _achievementEnabled = true;
  bool _weeklySummaryEnabled = true;
  bool _streakMilestoneEnabled = true;
  bool _quizReminderEnabled = true;
  bool _comebackEnabled = true;
  
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _noonTime = const TimeOfDay(hour: 11, minute: 45);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 19, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _morningReminderEnabled = prefs.getBool('morning_reminder_enabled') ?? true;
      _noonReminderEnabled = prefs.getBool('noon_reminder_enabled') ?? true;
      _eveningReminderEnabled = prefs.getBool('evening_reminder_enabled') ?? true;
      _streakWarningEnabled = prefs.getBool('streak_warning_enabled') ?? true;
      _dueWordsEnabled = prefs.getBool('due_words_enabled') ?? true;
      _goalProgressEnabled = prefs.getBool('goal_progress_enabled') ?? true;
      
      // Phase 2 settings
      _achievementEnabled = prefs.getBool('achievement_enabled') ?? true;
      _weeklySummaryEnabled = prefs.getBool('weekly_summary_enabled') ?? true;
      _streakMilestoneEnabled = prefs.getBool('streak_milestone_enabled') ?? true;
      _quizReminderEnabled = prefs.getBool('quiz_reminder_enabled') ?? true;
      _comebackEnabled = prefs.getBool('comeback_enabled') ?? true;
      
      final morningHour = prefs.getInt('morning_reminder_hour') ?? 8;
      final morningMinute = prefs.getInt('morning_reminder_minute') ?? 0;
      final noonHour = prefs.getInt('noon_reminder_hour') ?? 11;
      final noonMinute = prefs.getInt('noon_reminder_minute') ?? 45;
      final eveningHour = prefs.getInt('evening_reminder_hour') ?? 19;
      final eveningMinute = prefs.getInt('evening_reminder_minute') ?? 0;
      
      _morningTime = TimeOfDay(hour: morningHour, minute: morningMinute);
      _noonTime = TimeOfDay(hour: noonHour, minute: noonMinute);
      _eveningTime = TimeOfDay(hour: eveningHour, minute: eveningMinute);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('morning_reminder_enabled', _morningReminderEnabled);
    await prefs.setBool('noon_reminder_enabled', _noonReminderEnabled);
    await prefs.setBool('evening_reminder_enabled', _eveningReminderEnabled);
    await prefs.setBool('streak_warning_enabled', _streakWarningEnabled);
    await prefs.setBool('due_words_enabled', _dueWordsEnabled);
    await prefs.setBool('goal_progress_enabled', _goalProgressEnabled);
    
    // Phase 2 settings
    await prefs.setBool('achievement_enabled', _achievementEnabled);
    await prefs.setBool('weekly_summary_enabled', _weeklySummaryEnabled);
    await prefs.setBool('streak_milestone_enabled', _streakMilestoneEnabled);
    await prefs.setBool('quiz_reminder_enabled', _quizReminderEnabled);
    await prefs.setBool('comeback_enabled', _comebackEnabled);
    
    await prefs.setInt('morning_reminder_hour', _morningTime.hour);
    await prefs.setInt('morning_reminder_minute', _morningTime.minute);
    await prefs.setInt('noon_reminder_hour', _noonTime.hour);
    await prefs.setInt('noon_reminder_minute', _noonTime.minute);
    await prefs.setInt('evening_reminder_hour', _eveningTime.hour);
    await prefs.setInt('evening_reminder_minute', _eveningTime.minute);

    // Update notification service
    final notificationService = NotificationService();
    await notificationService.setNotificationsEnabled(_notificationsEnabled);
    if (_notificationsEnabled) {
      await notificationService.scheduleDailyReminders();
      await notificationService.runExtendedNotificationChecks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cài Đặt Thông Báo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Master toggle
          _buildSwitchTile(
            title: 'Bật Thông Báo',
            subtitle: 'Bật/tắt tất cả thông báo',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveSettings();
            },
            icon: Icons.notifications,
          ),
          
          if (_notificationsEnabled) ...[
            const Divider(height: 30),
            
            // Daily Reminders Section
            const Text(
              'Nhắc Nhở Hàng Ngày',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            
            _buildSwitchTile(
              title: 'Nhắc Nhở Buổi Sáng',
              subtitle: 'Nhắc nhở học tập hàng ngày lúc ${_morningTime.format(context)}',
              value: _morningReminderEnabled,
              onChanged: (value) {
                setState(() {
                  _morningReminderEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.wb_sunny,
              trailing: _morningReminderEnabled 
                ? IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () => _selectTime('morning'),
                  )
                : null,
            ),
            
            _buildSwitchTile(
              title: 'Nhắc Nhở Buổi Trưa',
              subtitle: 'Nhắc nhở học tập lúc ${_noonTime.format(context)}',
              value: _noonReminderEnabled,
              onChanged: (value) {
                setState(() {
                  _noonReminderEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.wb_sunny,
              trailing: _noonReminderEnabled
                ? IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () => _selectTime('noon'),
                  )
                : null,
            ),
            
            _buildSwitchTile(
              title: 'Ôn Tập Buổi Tối',
              subtitle: 'Nhắc nhở ôn tập lúc ${_eveningTime.format(context)}',
              value: _eveningReminderEnabled,
              onChanged: (value) {
                setState(() {
                  _eveningReminderEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.nightlight_round,
              trailing: _eveningReminderEnabled 
                ? IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed: () => _selectTime('evening'),
                  )
                : null,
            ),
            
            const Divider(height: 30),
            
            // Other Notifications Section
            const Text(
              'Cảnh Báo Học Tập',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            
            _buildSwitchTile(
              title: 'Cảnh Báo Chuỗi Học',
              subtitle: 'Nhắc nhở duy trì chuỗi học tập',
              value: _streakWarningEnabled,
              onChanged: (value) {
                setState(() {
                  _streakWarningEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.local_fire_department,
            ),
            
            _buildSwitchTile(
              title: 'Nhắc Nhở Ôn Tập',
              subtitle: 'Thông báo khi có từ cần ôn tập',
              value: _dueWordsEnabled,
              onChanged: (value) {
                setState(() {
                  _dueWordsEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.quiz,
            ),
            
            _buildSwitchTile(
              title: 'Tiến Độ Mục Tiêu',
              subtitle: 'Cập nhật tiến độ học tập hàng ngày',
              value: _goalProgressEnabled,
              onChanged: (value) {
                setState(() {
                  _goalProgressEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.track_changes,
            ),
            
            const Divider(height: 30),
            
            // Phase 2 Notifications Section
            const Text(
              'Thành Tích & Cốt Mốc',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            
            _buildSwitchTile(
              title: 'Thông Báo Thành Tích',
              subtitle: 'Chúc mừng các cốt mốc học tập',
              value: _achievementEnabled,
              onChanged: (value) {
                setState(() {
                  _achievementEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.emoji_events,
            ),
            
            _buildSwitchTile(
              title: 'Cốt Mốc Chuỗi Học',
              subtitle: 'Celebrate 7, 30, 100+ day streaks',
              value: _streakMilestoneEnabled,
              onChanged: (value) {
                setState(() {
                  _streakMilestoneEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.local_fire_department,
            ),
            
            _buildSwitchTile(
              title: 'Tổng Kết Tuần',
              subtitle: 'Báo cáo tiến độ tối Chủ nhật',
              value: _weeklySummaryEnabled,
              onChanged: (value) {
                setState(() {
                  _weeklySummaryEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.bar_chart,
            ),
            
            const Divider(height: 30),
            
            // Engagement Notifications Section
            const Text(
              'Tương Tác & Động Lực',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            
            _buildSwitchTile(
              title: 'Nhắc Nhở Kiểm Tra',
              subtitle: 'Remind to take quizzes every 2 days',
              value: _quizReminderEnabled,
              onChanged: (value) {
                setState(() {
                  _quizReminderEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.quiz,
            ),
            
            _buildSwitchTile(
              title: 'Tin Nhắn Trở Lại',
              subtitle: 'Tin nhắn khích lệ khi không hoạt động',
              value: _comebackEnabled,
              onChanged: (value) {
                setState(() {
                  _comebackEnabled = value;
                });
                _saveSettings();
              },
              icon: Icons.favorite,
            ),
          ],
          
          const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: trailing ?? Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  Future<void> _selectTime(String timeType) async {
    TimeOfDay initialTime;
    switch (timeType) {
      case 'morning':
        initialTime = _morningTime;
        break;
      case 'noon':
        initialTime = _noonTime;
        break;
      case 'evening':
        initialTime = _eveningTime;
        break;
      default:
        initialTime = _morningTime;
    }
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (picked != null) {
      setState(() {
        switch (timeType) {
          case 'morning':
            _morningTime = picked;
            break;
          case 'noon':
            _noonTime = picked;
            break;
          case 'evening':
            _eveningTime = picked;
            break;
        }
      });
      await _saveSettings();
    }
  }

}
