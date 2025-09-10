import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'home_screen.dart';
import 'topic_screen.dart';
import 'quiz_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  VoidCallback? _profileRefreshCallback;
  VoidCallback? _homeRefreshCallback;
  VoidCallback? _topicRefreshCallback;

  // Danh sách các màn hình được build dynamically để pass callback
  List<Widget> get _screens => [
    HomeScreen(onTabChange: (index) => setState(() => _currentIndex = index)), // Home - Dashboard & Overview
    const TopicScreen(), // Topics - All topics list
    const QuizScreen(), // Quiz - Review & Testing unlearned words
    ProfileScreen(onRefreshCallback: (callback) => _profileRefreshCallback = callback), // Profile - Stats & Settings
  ];

  // Danh sách title cho từng màn hình
  List<String> get _screenTitles => [
    'Home',
    'Tất Cả Chủ Đề',
    'Kiểm Tra & Ôn Tập',
    'Tài khoản',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0 ? null : AppBar(
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
        child: _screens[_currentIndex],
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
            TabItem(icon: Icons.quiz, title: 'Kiểm Tra'),
            TabItem(icon: Icons.person, title: 'Tài khoản'),
          ],
          initialActiveIndex: 0,
          onTap: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}


