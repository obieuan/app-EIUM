import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import 'screenshot_capture_stub.dart'
    if (dart.library.html) 'screenshot_capture_web.dart'
    if (dart.library.io) 'screenshot_capture_mobile.dart';

/// Captures a screenshot of a widget identified by a GlobalKey.
///
/// Returns the screenshot as PNG bytes, or null if capture fails.
///
/// This function has platform-specific implementations:
/// - On Web: Uses HTML canvas to capture the widget
/// - On Mobile: Uses RenderRepaintBoundary.toImage()
Future<Uint8List?> captureWidget(GlobalKey key) async {
  return captureWidgetImpl(key);
}
