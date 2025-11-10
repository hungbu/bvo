import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'home_screen.dart';
// import 'topic_screen.dart'; // Will be used later when switching back to topic-based learning
import 'topic_level_screen.dart';
//import 'quiz_screen.dart';
import 'profile_screen.dart';
import 'practice_screen.dart';
import 'pronunciation_screen.dart';
import 'speak_screen.dart';
import 'grammar_screen.dart';
import '../service/notification_manager.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _currentIndex = 0;
  VoidCallback? _profileRefreshCallback;
  final NotificationManager _notificationManager = NotificationManager();

  // Danh sách các màn hình được build dynamically để pass callback
  // Note: Index 2 is Apps (no screen, shows bottom sheet)
  List<Widget> get _screens => [
    HomeScreen(onTabChange: (index) => setState(() => _currentIndex = index)), // Home - Dashboard & Overview
    const TopicLevelScreen(), // Topics - Learning by Level (temporarily replacing TopicScreen)
    // const TopicScreen(), // Topics - All topics list (will be used later)
    //const QuizScreen(), // Quiz - Review & Testing unlearned words
    ProfileScreen(onRefreshCallback: (callback) => _profileRefreshCallback = callback), // Profile - Stats & Settings
  ];

  // Map navigation index to screen index
  // 0 -> Home (screen 0)
  // 1 -> Topics (screen 1)
  // 2 -> Apps (no screen, shows bottom sheet)
  // 3 -> Profile (screen 2)
  int _getScreenIndex(int navIndex) {
    if (navIndex < 2) return navIndex;
    if (navIndex == 3) return 2; // Profile
    return 0; // Default to Home
  }

  // Danh sách title cho từng màn hình
  List<String> get _screenTitles => [
    'Home',
    'Học theo Level',
    'Apps',
    'Tài khoản',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App goes to background - schedule smart checks
      _scheduleSmartChecks();
    } else if (state == AppLifecycleState.resumed) {
      // App comes to foreground - check for streak motivation
      _checkStreakMotivation();
    }
  }

  Future<void> _scheduleSmartChecks() async {
    // Check for forgetting words when app goes to background
    await _notificationManager.checkForgettingWords();
  }

  Future<void> _checkStreakMotivation() async {
    // Check streak motivation when app resumes - now with proper cooldown control
    await _notificationManager.triggerStreakMotivation();
  }

  void _showAppListBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Apps',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildAppItem(
              context,
              icon: Icons.book,
              title: 'Reading',
              subtitle: 'Practice with exercises',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PracticeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildAppItem(
              context,
              icon: Icons.record_voice_over,
              title: 'Pronunciation',
              subtitle: 'Practice pronunciation',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PronunciationScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildAppItem(
              context,
              icon: Icons.mic,
              title: 'Speak',
              subtitle: 'Practice speaking',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SpeakScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildAppItem(
              context,
              icon: Icons.menu_book,
              title: 'Grammar',
              subtitle: 'Learn grammar rules',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GrammarScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitles[_currentIndex]),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Không hiển thị back button
        actions: _currentIndex == 3 ? [
          // Refresh button cho Profile screen
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _profileRefreshCallback?.call();
            },
          ),
        ] : null,
      ),
      body: SafeArea(
        child: _screens[_getScreenIndex(_currentIndex)],
      ),
      bottomNavigationBar: SafeArea(
        child: ConvexAppBar(
          style: TabStyle.react,
          backgroundColor: Theme.of(context).primaryColor,
          activeColor: Colors.white,
          color: Colors.white70,
          height: 60,
          items: const [
            TabItem(icon: Icons.home, title: 'Home'),
            TabItem(icon: Icons.topic, title: 'Chủ Đề'),
            TabItem(icon: Icons.apps, title: 'Apps'),
            //TabItem(icon: Icons.quiz, title: 'Kiểm Tra'),
            TabItem(icon: Icons.person, title: 'Tài khoản'),
          ],
          initialActiveIndex: 0,
          onTap: (int index) {
            // If tapping on Apps (index 2), show bottom sheet instead of switching
            if (index == 2) {
              _showAppListBottomSheet(context);
              // Don't change _currentIndex, keep current screen visible
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
        ),
      ),
    );
  }
}


