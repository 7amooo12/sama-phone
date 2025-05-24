import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:smartbiztracker_new/utils/app_constants.dart';
import 'package:smartbiztracker_new/services/api_service.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';

class ExternalLinksScreen extends StatefulWidget {
  const ExternalLinksScreen({super.key});

  @override
  State<ExternalLinksScreen> createState() => _ExternalLinksScreenState();
}

class _ExternalLinksScreenState extends State<ExternalLinksScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  final List<String> _externalLinks = [
    AppConstants.authLoginUrl,
    '${AppConstants.secondaryUrl}/auth/login',
  ];

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  // Open WebView for the specified URL
  Future<void> _openWebView(String url) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Navigate to web view
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _WebViewScreen(url: url),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.link,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'الروابط الخارجية',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اضغط على أي رابط للانتقال إلى الموقع المطلوب',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // List of external links
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _externalLinks.length,
                itemBuilder: (context, index) {
                  final url = _externalLinks[index];
                  final title = url.contains('samastock')
                      ? 'نظام إدارة المخزون'
                      : 'نظام إدارة المستودع';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          (index + 1).toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(url),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'فتح الرابط',
                            onPressed: () => _openWebView(url),
                            icon: Icons.open_in_new,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Loading indicator
        if (_isLoading) const CustomLoader(),
      ],
    );
  }
}

class _WebViewScreen extends StatefulWidget {
  const _WebViewScreen({required this.url});
  final String url;

  @override
  State<_WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<_WebViewScreen> {
  final GlobalKey _webViewKey = GlobalKey();
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.url.contains('samastock')
              ? 'نظام إدارة المخزون'
              : 'نظام إدارة المستودع',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            key: _webViewKey,
            initialUrlRequest: URLRequest(
              url: WebUri(widget.url),
            ),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              supportZoom: true,
              useWideViewPort: true,
              horizontalScrollBarEnabled: true,
              verticalScrollBarEnabled: true,
              initialScale: 1,
            ),
            onWebViewCreated: (controller) async {
              _webViewController = controller;

              // Auto-login after page loads
              controller.addJavaScriptHandler(
                handlerName: 'autoLogin',
                callback: (args) {
                  return {
                    'username': AppConstants.adminUsername,
                    'password': AppConstants.adminPassword,
                  };
                },
              );
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              
              // Inject CSS to fix overflow issues
              await controller.injectCSSCode(source: '''
                * {
                  max-width: 100% !important;
                  overflow-x: auto !important;
                  box-sizing: border-box !important;
                  word-wrap: break-word !important;
                }
                table, tr, td, img, div {
                  max-width: 100% !important;
                  height: auto !important;
                }
                body {
                  width: 100% !important;
                  overflow-x: hidden !important;
                }
              ''');
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onReceivedError: (controller, request, error) {
              // Handle loading errors
              print("WebView Error: $error");
            },
          ),

          // Show progress bar while loading
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري التحميل... ${(_progress * 100).toStringAsFixed(0)}%',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
