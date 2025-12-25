import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const CentralizadoApp());
}

class CentralizadoApp extends StatelessWidget {
  const CentralizadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2D5BD1);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App EIUM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
