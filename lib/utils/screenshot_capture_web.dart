// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Web implementation using HTML Canvas to capture the widget
Future<Uint8List?> captureWidgetImpl(GlobalKey key) async {
  print('[ALBUM] Screenshot: Using web implementation');

  try {
    final context = key.currentContext;
    if (context == null) {
      print('[ALBUM] Screenshot: GlobalKey context is NULL');
      return null;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) {
      print('[ALBUM] Screenshot: RenderObject is NULL or not RenderBox');
      return null;
    }

    final renderBox = renderObject as RenderBox;
    final size = renderBox.size;
    print('[ALBUM] Screenshot: Widget size: ${size.width}x${size.height}');

    // Get the widget's position in the global coordinate system
    final offset = renderBox.localToGlobal(Offset.zero);
    print('[ALBUM] Screenshot: Widget offset: ${offset.dx}, ${offset.dy}');

    // Create a canvas with the widget's dimensions
    final canvas = html.CanvasElement(
      width: (size.width * html.window.devicePixelRatio).toInt(),
      height: (size.height * html.window.devicePixelRatio).toInt(),
    );

    final ctx = canvas.context2D;
    ctx.scale(html.window.devicePixelRatio, html.window.devicePixelRatio);

    // Try to capture the visible region
    // Note: This is a simplified approach and may not work perfectly
    // for complex widgets with transforms

    // For now, we'll use a different approach: render to Picture
    // Unfortunately, Flutter Web doesn't provide direct access to the rendered output

    // Alternative: Return null and handle gracefully (save without snapshot)
    print('[ALBUM] Screenshot: Web screenshot not fully supported, proceeding without image');

    // TODO: For a complete solution, consider using the 'screenshot' package
    // which has better web support, or implement server-side rendering

    return null;
  } catch (e, stackTrace) {
    print('[ALBUM] Screenshot: Web capture error: $e');
    print('[ALBUM] Screenshot: Stack trace: $stackTrace');
    return null;
  }
}
