import 'package:bvo/screen/home_screen.dart';
import 'package:bvo/theme/purple_theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // i need to setup background color of all appbar

    return MaterialApp(
      title: 'Bun Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: PurpleTheme.getTheme(),
      home: const HomeScreen(),
    );
  }
}
