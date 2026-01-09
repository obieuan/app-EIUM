import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var session = await _authService.getValidSession();
    if (session == null && kIsWeb) {
      session = await _authService.completeWebSignInIfNeeded();
    }
    if (!mounted) {
      return;
    }
    final nextScreen = session == null ? const LoginScreen() : const HomeScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF011E4C),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/logotipo.png'),
          height: 120,
        ),
      ),
    );
  }
}
