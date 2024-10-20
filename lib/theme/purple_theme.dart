import 'package:flutter/material.dart';

class PurpleTheme {
  static ThemeData getTheme() {
    return ThemeData(
      appBarTheme: AppBarTheme(
        backgroundColor:
            ColorScheme.fromSeed(seedColor: Colors.deepPurple).inversePrimary,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
      ),
      useMaterial3: true,
    );
  }
}
