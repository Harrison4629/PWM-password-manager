// lib/utils/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // 1. 导入 Google Fonts
import 'constants.dart';

// 基础主题定义 (不包含 TextTheme，以便后面合并)
final ThemeData _baseTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryColor,
    brightness: Brightness.light,
    background: kContentBackgroundColor, // 内容区背景
    primaryContainer: kAppBarFooterColor, // pin码框内颜色
  ),
  scaffoldBackgroundColor: kContentBackgroundColor, // 内容区背景
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarFooterColor, // AppBar 背景
    foregroundColor: Colors.black87, // AppBar 文字/图标颜色 (会被 primaryTextTheme 覆盖字体)
    elevation: 1.0,
    scrolledUnderElevation: 1.0,
  ),
  // Bottom Nav Bar Theme (不直接控制字体，字体来自整体 TextTheme)
  // GNav 样式在 MainLayout 中单独设置
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: kPrimaryColor),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
  ),
   cardTheme: CardTheme(
     elevation: 0.5,
     margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
     color: kContentBackgroundColor,
   ),
   listTileTheme: const ListTileThemeData(
     // Define default ListTile styles here if needed
   ),
);

// Merge Google Fonts TextTheme onto the base theme
final ThemeData appTheme = _baseTheme.copyWith(
  // 2. 设置全局 TextTheme
  textTheme: GoogleFonts.notoSansScTextTheme(
    _baseTheme.textTheme, // 基于 _baseTheme 的原始 TextTheme 进行修改
  ).copyWith(
    // 3. (Optional) Fine-tune specific text styles (size/color)
    // Override here if GoogleFonts defaults aren't suitable
  ),
  // 4. Set PrimaryTextTheme (affects AppBar, etc.)
  primaryTextTheme: GoogleFonts.notoSansScTextTheme(
    _baseTheme.primaryTextTheme, // Based on the original PrimaryTextTheme of _baseTheme
  ).copyWith(
      // Ensure AppBar title color etc. meet expectations
  ),
  // accentTextTheme is deprecated in Material 3, usually not needed
);
