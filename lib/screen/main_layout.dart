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

  // Danh sách các màn hình được build dynamically để pass callback
  List<Widget> get _screens => [
    HomeScreen(onTabChange: (index) => setState(() => _currentIndex = index)), // Home - Dashboard & Overview
    const TopicScreen(), // Topics - All topics list
    const QuizScreen(), // Quiz - Review & Testing unlearned words
    const ProfileScreen(), // Profile - Stats & Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        backgroundColor: Theme.of(context).primaryColor,
        activeColor: Colors.white,
        color: Colors.white70,
        height: 60,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.topic, title: 'Topics'),
          TabItem(icon: Icons.quiz, title: 'Quiz'),
          TabItem(icon: Icons.person, title: 'Profile'),
        ],
        initialActiveIndex: 0,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}


