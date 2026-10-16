import 'package:flutter/material.dart';

import 'screens/assessment_screen.dart';

void main() {
  runApp(const DiabetesExpertSystemApp());
}

class DiabetesExpertSystemApp extends StatelessWidget {
  const DiabetesExpertSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบประเมินความเสี่ยงสุขภาพ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF806F),
          surface: const Color(0xFFFFF7F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF7F5),
        visualDensity: VisualDensity.standard,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const AssessmentScreen(),
    );
  }
}
