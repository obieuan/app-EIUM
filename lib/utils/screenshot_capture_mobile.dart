import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Mobile implementation using RenderRepaintBoundary.toImage()
Future<Uint8List?> captureWidgetImpl(GlobalKey key) async {
  print('[ALBUM] Screenshot: Using mobile implementation');

  final context = key.currentContext;
  if (context == null) {
    print('[ALBUM] Screenshot: GlobalKey context is NULL');
    return null;
  }

  final renderObject = context.findRenderObject();
  if (renderObject == null) {
    print('[ALBUM] Screenshot: RenderObject is NULL');
    return null;
  }

  if (renderObject is! RenderRepaintBoundary) {
    print('[ALBUM] Screenshot: RenderObject is not RepaintBoundary');
    return null;
  }

  final boundary = renderObject as RenderRepaintBoundary;
  print('[ALBUM] Screenshot: Found RepaintBoundary, creating image...');

  final image = await boundary.toImage(pixelRatio: 2.0);
  print('[ALBUM] Screenshot: Image created (${image.width}x${image.height})');

  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    print('[ALBUM] Screenshot: ByteData is NULL');
    return null;
  }

  final bytes = byteData.buffer.asUint8List();
  print('[ALBUM] Screenshot: Success! ${bytes.length} bytes');
  return bytes;
}
