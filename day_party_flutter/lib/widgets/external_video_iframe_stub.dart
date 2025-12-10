import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms
Widget buildWebVideoIframe(String embedUrl) {
  // This should never be called on non-web platforms
  return Container(
    color: Colors.black12,
    alignment: Alignment.center,
    child: const Icon(Icons.play_circle_outline, size: 48, color: Colors.black54),
  );
}

