import 'package:flutter/material.dart';

/// Ilovaning umumiy mavzusi (qorong'i, binafsha urg'u).
ThemeData buildAppTheme({String? fontFamily, List<String>? fallback}) => ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8C7BFF),
        brightness: Brightness.dark,
        surface: const Color(0xFF16132E),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A1F),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1A3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1A3D),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
