import 'package:flutter/material.dart';

/// Brand color tokens from TECHNICAL_DOCUMENTATION.md §7.
/// Use these for the seed and for semantic colors that aren't part of the
/// Material 3 [ColorScheme] (expense/income/info/warning).
class AppColors {
  AppColors._();

  // Primary
  static const Color mint = Color(0xFF16B981);
  static const Color mintDark = Color(0xFF0F6E56);
  static const Color mintContainer = Color(0xFFE1F5EE);
  static const Color mintContainerAlt = Color(0xFFD2F0E5);

  // Semantic
  static const Color expense = Color(0xFFD85A30); // coral
  static const Color income = Color(0xFF16B981); // mint
  static const Color info = Color(0xFF185FA5);
  static const Color warning = Color(0xFFBA7517);
}
