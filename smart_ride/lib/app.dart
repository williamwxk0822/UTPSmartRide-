import 'package:flutter/material.dart';
import 'theme/app_ui.dart';
import 'pages/auth/login_page.dart';

// ---------------- app root ----------------
class LoginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTP Smart Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppUI.primary)
            .copyWith(primary: AppUI.primary, surface: Colors.white),
        scaffoldBackgroundColor: AppUI.bg,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppUI.ink),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppUI.ink),
          bodyMedium: TextStyle(color: AppUI.ink, height: 1.35),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppUI.ink,
          titleTextStyle: TextStyle(
              color: AppUI.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            backgroundColor: AppUI.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF4F6FB),
          labelStyle: const TextStyle(color: AppUI.inkSoft),
          prefixIconColor: AppUI.inkSoft,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE3E7F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppUI.primary, width: 1.6)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0xFF1A237E).withOpacity(0.06),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE9EDF5))),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE9EDF5)),
      ),
      home: LoginPage(),
    );
  }
}
