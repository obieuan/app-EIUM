import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
// import 'home_screen.dart'; // REMOVED
// import 'login_screen.dart'; // REMOVED
import 'maintenance_screen.dart';

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
    // Check maintenance mode first
    final isMaintenance = await _authService.checkAppStatus();
    if (isMaintenance) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(onRetry: _bootstrap),
        ),
      );
      return;
    }

    var session = await _authService.getValidSession();
    if (session == null && kIsWeb) {
      session = await _authService.completeWebSignInIfNeeded();
    }
    if (!mounted) {
      return;
    }
    final nextRoute = session == null ? '/login' : '/home';
    Navigator.of(context).pushReplacementNamed(nextRoute);
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
