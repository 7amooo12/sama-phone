import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/api_service.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _trackingLink;
  bool _isWebViewLoading = true;
  double _webViewProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackingLink();
    });
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  // Load tracking link for current user
  Future<void> _loadTrackingLink() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null && user.trackingLink != null) {
        setState(() {
          _trackingLink = user.trackingLink;
        });
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
        _trackingLink == null
            ? _buildNoTrackingLink()
            : _buildTrackingContent(),

        // Loading indicator
        if (_isLoading) const CustomLoader(),
      ],
    );
  }

  // Build UI when there is no tracking link
  Widget _buildNoTrackingLink() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation
          SizedBox(
            height: 200,
            width: 200,
            child: Lottie.network(
              'https://assets6.lottiefiles.com/packages/lf20_nw1nkazv.json',
              repeat: true,
            ),
          ),
          const SizedBox(height: 24),

          // Message
          const Text(
            'لا توجد طلبات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'لم يتم تعيين رابط تتبع لحسابك بعد. يرجى التواصل مع المدير لتحديث معلوماتك.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Build tracking content when a link is available
  Widget _buildTrackingContent() {
    return Column(
      children: [
        // Heading
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.safeOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 16),
              const Flexible(
                child: Text(
                  'تتبع الطلب',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // WebView for tracking
        Expanded(
          child: Container(
            key: ValueKey('tracking_webview_${DateTime.now().millisecondsSinceEpoch}'),
            child: InAppWebView(
              key: ValueKey('webview_${_trackingLink.hashCode}'),
              initialUrlRequest: URLRequest(
                url: WebUri.uri(Uri.parse(_trackingLink!)),
              ),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              useHybridComposition: true,
              supportZoom: true,
              useWideViewPort: true,
              // Enable horizontal scrolling to prevent overflow
              horizontalScrollBarEnabled: true,
              verticalScrollBarEnabled: true,
              // Set initial scale to fit the content
              initialScale: 1,
            ),
            onLoadStart: (controller, url) {
              setState(() {
                _isWebViewLoading = true;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isWebViewLoading = false;
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
              ''');
            },
            onProgressChanged: (controller, progress) {
              if (mounted) {
                setState(() {
                  _webViewProgress = progress / 100;
                });
              }
            },
            onReceivedError: (controller, request, error) {
              AppLogger.error('Tracking WebView Error: ${error.description}');
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في تحميل صفحة التتبع: ${error.description}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            ),
          ),
        ),

        // Loading indicator for WebView
        if (_isWebViewLoading)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    'جاري التحميل... ${(_webViewProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
