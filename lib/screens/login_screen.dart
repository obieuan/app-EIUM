import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signIn();
      if (!mounted) {
        return;
      }
      if (result == null) {
        if (!kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo iniciar sesion.')),
          );
        }
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesion: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundBlue = Color(0xFF011E4C);
    const primaryBlue = Color(0xFF2D5BD1);
    const titleColor = Color(0xFF0F1B2D);
    const subtitleColor = Color(0xFF5B6B86);

    return Scaffold(
      backgroundColor: backgroundBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logotipo.png',
                        height: 96,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'App EIUM',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Inicia sesion con tu cuenta universitaria',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    MicrosoftLogo(),
                                    SizedBox(width: 10),
                                    Text('Iniciar sesion con Microsoft 365'),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Universidad Modelo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF42516A),
                        ),
                      ),
                      const Text(
                        'Solo cuentas @modelo.edu.mx',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7A92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MicrosoftLogo extends StatelessWidget {
  const MicrosoftLogo({super.key});

  @override
  Widget build(BuildContext context) {
    const double squareSize = 8;
    const double gap = 2;

    return SizedBox(
      width: squareSize * 2 + gap,
      height: squareSize * 2 + gap,
      child: Column(
        children: [
          Row(
            children: const [
              _LogoSquare(color: Color(0xFFF25022), size: squareSize),
              SizedBox(width: gap),
              _LogoSquare(color: Color(0xFF7FBA00), size: squareSize),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: const [
              _LogoSquare(color: Color(0xFF00A4EF), size: squareSize),
              SizedBox(width: gap),
              _LogoSquare(color: Color(0xFFFFB900), size: squareSize),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoSquare extends StatelessWidget {
  final Color color;
  final double size;

  const _LogoSquare({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color,
    );
  }
}
