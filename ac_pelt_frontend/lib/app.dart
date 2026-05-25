import 'package:flutter/material.dart';

import 'data/auth/auth_storage.dart';
import 'pages/home/home_page.dart';
import 'pages/login/login_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF121212);
    const card = Color(0xFF1E1E1E);

    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Peltier AC Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: bg,
        cardColor: card,
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(color: card),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white70),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: card,
          labelStyle: TextStyle(color: Colors.white),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: card,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          contentTextStyle: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
      home: FutureBuilder<String?>(
        future: AuthStorage().getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final token = snapshot.data;
          if (token == null || token.isEmpty) {
            return const LoginPage();
          }

          return const HomePage();
        },
      ),
    );
  }
}
