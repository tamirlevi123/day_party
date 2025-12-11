import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/knesset/knesset_document_bill.dart';
import '../core/logger.dart';

/// Widget to display Knesset document details and view the document
class KnessetDocumentViewer extends StatefulWidget {
  final KnessetDocumentBill document;

  const KnessetDocumentViewer({
    super.key,
    required this.document,
  });

  /// Show document viewer as a modal dialog
  static Future<void> show(BuildContext context, KnessetDocumentBill document) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => KnessetDocumentViewer(document: document),
    );
  }

  @override
  State<KnessetDocumentViewer> createState() => _KnessetDocumentViewerState();
}

class _KnessetDocumentViewerState extends State<KnessetDocumentViewer> {
  WebViewController? _webViewController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeViewer();
  }

  /// Get viewer URL using online viewers for all document types
  String _getViewerUrl(String filePath) {
    // Build full URL if needed
    Uri? documentUri;
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      documentUri = Uri.tryParse(filePath);
    } else {
      documentUri = Uri.tryParse('https://main.knesset.gov.il$filePath');
    }
    
    if (documentUri == null) {
      throw Exception('Invalid file path: $filePath');
    }
    
    final documentUrl = documentUri.toString();
    final lowerPath = filePath.toLowerCase();
    
    // Use Google Docs Viewer for PDFs
    if (lowerPath.endsWith('.pdf')) {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(documentUrl)}&embedded=true';
    }
    
    // Use Microsoft Office Online Viewer for Office documents
    if (lowerPath.endsWith('.doc') || 
        lowerPath.endsWith('.docx') ||
        lowerPath.endsWith('.xls') ||
        lowerPath.endsWith('.xlsx') ||
        lowerPath.endsWith('.ppt') ||
        lowerPath.endsWith('.pptx') ||
        lowerPath.endsWith('.rtf')) {
      return 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(documentUrl)}';
    }
    
    // For HTML or other formats, use direct URL
    return documentUrl;
  }

  void _initializeViewer() {
    final filePath = widget.document.filePath;
    if (filePath == null || filePath.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'לא נמצא קישור למסמך';
      });
      return;
    }

    // Get viewer URL
    String viewerUrl;
    try {
      viewerUrl = _getViewerUrl(filePath);
      appLogger.d('Using online viewer for: $filePath -> $viewerUrl');
    } catch (e) {
      appLogger.e('Error building viewer URL', error: e);
      setState(() {
        _isLoading = false;
        _error = 'קישור לא תקין: $filePath';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            appLogger.e('WebView error: ${error.description}', error: error);
            setState(() {
              _isLoading = false;
              _error = 'לא ניתן להציג את המסמך בתוך האפליקציה. נסה לפתוח בדפדפן.';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation to viewer services and Knesset domain
            if (request.url.contains('view.officeapps.live.com') ||
                request.url.contains('docs.google.com') ||
                request.url.contains('knesset.gov.il')) {
              return NavigationDecision.navigate;
            }
            // For other URLs, open in external browser
            launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));
  }

  Future<void> _openInBrowser() async {
    final filePath = widget.document.filePath;
    if (filePath == null || filePath.isEmpty) return;

    Uri? uri;
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      uri = Uri.tryParse(filePath);
    } else {
      uri = Uri.tryParse('https://main.knesset.gov.il$filePath');
    }

    if (uri != null) {
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('לא ניתן לפתוח את הקישור בדפדפן'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        appLogger.e('Error launching URL', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בפתיחת הקישור: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.document.groupTypeDesc.isNotEmpty
                              ? widget.document.groupTypeDesc
                              : 'מסמך',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        if (widget.document.applicationDesc != null &&
                            widget.document.applicationDesc!.isNotEmpty)
                          Text(
                            widget.document.applicationDesc!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    tooltip: 'פתח בדפדפן',
                    onPressed: _openInBrowser,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'סגור',
                    onPressed: () => Navigator.of(context).pop(),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            // Document metadata
            if (widget.document.lastUpdatedDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'עודכן: ${_formatDate(widget.document.lastUpdatedDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            // Content area
            Expanded(
              child: _webViewController != null
                  ? Stack(
                      children: [
                        if (_error == null)
                          WebViewWidget(controller: _webViewController!)
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _openInBrowser,
                                    icon: const Icon(Icons.open_in_browser),
                                    label: const Text('פתח בדפדפן'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_isLoading && _error == null)
                          Container(
                            color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Format date in Hebrew-friendly format
    final months = [
      'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
      'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

