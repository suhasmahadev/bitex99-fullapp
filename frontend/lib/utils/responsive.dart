import 'package:flutter/material.dart';

/// Responsive utility optimised for large Android & iOS phones:
/// Android: 412 × 915 (Samsung Galaxy S23 Ultra / Pixel 7 Pro)
/// iOS    : 430 × 932 (iPhone 14 Pro Max / iPhone 15 Plus)
class R {
  static late double w;
  static late double h;

  static void init(BuildContext context) {
    w = MediaQuery.of(context).size.width;
    h = MediaQuery.of(context).size.height;
  }

  /// Percentage of screen width
  static double wp(double pct) => w * pct / 100;

  /// Percentage of screen height
  static double hp(double pct) => h * pct / 100;

  /// Font size as percentage of screen width
  static double sp(double pct) => w * pct / 100;
}
