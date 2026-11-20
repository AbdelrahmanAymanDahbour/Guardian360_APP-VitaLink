import 'package:flutter/material.dart';

class AppColors {
  // الألوان الأساسية - درجات الأحمر الدموي
  static const Color primaryDark = Color(0xFF710000); // أحمر غامق جداً
  static const Color primaryRed = Color(0xFFc90101); // أحمر فاقع للفت الانتباه
  static const Color darkMaroon = Color(0xFF580303); // ماروني غامق
  static const Color deepRed = Color(0xFF540000); // درجة ثانية من الغامق

  // ألوان الخلفية والنصوص
  static const Color background = Color(
    0xFFF8F9FA,
  ); // 👈 رمادي فاتح فخم جداً (اللي اعتمدناه امبارح)
  static const Color surfaceWhite = Colors.white; // للبطاقات (Cards)

  static const Color textBlack = Color(
    0xFF2D2D2D,
  ); // أسود مطفي (أريح للعين من الأسود الصريح)
  static const Color textGrey = Colors.grey; // للنصوص الفرعية
}
