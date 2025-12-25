import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App EIUM'),
      ),
      body: const Center(
        child: Text(
          'Pantalla principal (en blanco por ahora).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
