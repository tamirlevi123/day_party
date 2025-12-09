# Build Fix: Flutter Plugin Issues

## ⚠️ NOTE: This document is outdated

**As of 2025-01-27**, the project has migrated from `html_editor_enhanced` to **Flutter Quill** (`flutter_quill` package) for rich text editing. The issues described below related to `html_editor_enhanced` are no longer relevant.

## Current Rich Text Editor

- **Package**: `flutter_quill` (^10.7.0)
- **Format**: Delta JSON (Quill Delta format)
- **Features**: Bold, italic, underline, strikethrough, links, numbered lists, bullet lists
- **Custom Renderer**: Custom Delta renderer in `lib/widgets/html_content_widget.dart` for displaying content with clickable links

## Historical Context (Outdated)

The following information is kept for historical reference only:

### Problems (No Longer Applicable)

1. **Namespace Issues**: Several Flutter plugins didn't have namespace declarations (fixed in newer versions)
2. **Asset Path Issues**: The `html_editor_enhanced` package had incorrect asset declarations (package removed)

### Previous Solution
A PowerShell script (`fix-namespace.ps1`) was created to patch plugins, but this is no longer needed since `html_editor_enhanced` has been removed.

## Migration Notes

- **Old Format**: HTML (stored as HTML strings)
- **New Format**: Delta JSON (stored as JSON strings with `textFormat: 'delta'`)
- **Migration Script**: `backend/scripts/html-to-delta.ts` converts existing HTML content to Delta format
- **Backend Schema**: Updated to include `'delta'` and `'html'` in `TextFormat` enum

See `03-Decision-Log.md` for migration decision details.

