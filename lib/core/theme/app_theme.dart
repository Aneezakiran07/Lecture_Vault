import 'package:flutter/material.dart';
import '../constants/colors.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.headerCard),
    useMaterial3: true,
  );
}