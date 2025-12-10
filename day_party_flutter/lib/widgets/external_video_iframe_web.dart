import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Builds an iframe widget for web to embed YouTube/Vimeo videos
Widget buildWebVideoIframe(String embedUrl) {
  // Create a unique ID for this iframe
  final iframeId = 'video-iframe-${embedUrl.hashCode}';
  
  // Register the iframe element
  html.IFrameElement iframeElement = html.IFrameElement()
    ..src = embedUrl
    ..style.border = 'none'
    ..allowFullscreen = true
    ..setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture')
    ..width = '100%'
    ..height = '100%';
  
  // Register the platform view using dart:ui_web
  ui_web.platformViewRegistry.registerViewFactory(
    iframeId,
    (int viewId) => iframeElement,
  );
  
  // Wrap HtmlElementView to prevent clicks from propagating to parent widgets
  // The iframe handles its own clicks internally, but we need to stop Flutter's gesture system
  // from seeing those clicks and propagating them to the parent InkWell
  return Listener(
    onPointerDown: (_) {
      // Stop pointer events from propagating to parent
    },
    behavior: HitTestBehavior.translucent,
    child: HtmlElementView(viewType: iframeId),
  );
}

