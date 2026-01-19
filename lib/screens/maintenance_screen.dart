import 'package:flutter/material.dart';

class MaintenanceScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const MaintenanceScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF011E4C),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction,
                size: 80,
                color: Color(0xFFFFB900),
              ),
              const SizedBox(height: 24),
              const Text(
                'Estamos mejorando la experiencia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'La aplicación está en mantenimiento temporal. Por favor intenta más tarde.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8190AA),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5BD1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Reintentar conexión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
