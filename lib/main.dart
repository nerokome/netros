import 'package:flutter/material.dart';

import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _ink = Color(0xFF25251F);
  static const _background = Color(0xFFF8F7F3);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 245, 244, 242),
          surface: _background,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: _ink,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          bodyMedium: TextStyle(
            color: Color.fromARGB(255, 119, 118, 111),
            fontSize: 15,
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
