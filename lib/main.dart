import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CentralizadoApp());
}

class CentralizadoApp extends StatelessWidget {
  const CentralizadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2D5BD1);
    final textTheme = GoogleFonts.soraTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App EIUM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1B2D),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF0F1B2D)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
