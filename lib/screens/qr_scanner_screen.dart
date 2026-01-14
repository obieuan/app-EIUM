import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String value) async {
    if (!mounted) {
      return;
    }
    // Jump directly to action without confirmation dialog
    Navigator.of(context).pop(value);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) {
      return;
    }

    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final value = barcode?.rawValue ?? barcode?.displayValue;
    if (value == null || value.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    _handleCode(value);
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Apunta la camara al codigo QR.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Si no se abre la camara, revisa los permisos del navegador.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(MobileScannerException error) {
    final message = error.errorDetails?.message?.isNotEmpty == true
        ? error.errorDetails!.message!
        : 'No se pudo acceder a la camara.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) => _buildError(error),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildHint(),
          ),
        ],
      ),
    );
  }
}
