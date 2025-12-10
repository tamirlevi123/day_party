// Web implementation
// This file is used when compiling for web platform
import 'dart:html' as html;

void redirectWeb(String url) {
  html.window.location.href = url;
}

