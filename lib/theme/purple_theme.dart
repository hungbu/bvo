import 'package:flutter/material.dart';

class PurpleTheme {
  static ThemeData getTheme() {
    return ThemeData(
      appBarTheme: AppBarTheme(
        backgroundColor:
            Colors.deepPurple[800],
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
      ),
      useMaterial3: true,
    );
  }
}
