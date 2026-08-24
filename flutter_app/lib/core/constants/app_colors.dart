import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF0D1441);
  static const Color navyLight = Color(0xFF1B2670);
  static const Color royalBlue = Color(0xFF2743C4);
  static const Color gold = Color(0xFFFFC93C);
  static const Color goldDark = Color(0xFFF5A623);
  static const Color goldLight = Color(0xFFFFE082);
  static const Color white = Colors.white;
  static const Color red = Color(0xFFE53935);
  static const Color green = Color(0xFF43A047);
  static const Color yellow = Color(0xFFFDD835);
  static const Color blue = Color(0xFF1E88E5);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0F33), navy, royalBlue],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDark],
  );
}
