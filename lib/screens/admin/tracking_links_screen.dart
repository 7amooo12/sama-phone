import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingLinksScreen extends StatefulWidget {
  const TrackingLinksScreen({super.key});

  @override
  State<TrackingLinksScreen> createState() => _TrackingLinksScreenState();
}

class _TrackingLinksScreenState extends State<TrackingLinksScreen> {
  final Map<String, TextEditingController> _controllers = {};
  List<UserModel>? _clientUsers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClientUsers();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Fetch all client users
  Future<void> _fetchClientUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get client users from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: UserRole.client.value)
          .get();

      setState(() {
        _clientUsers = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList();
        _isLoading = false;

        // Initialize controllers for each user
        for (final user in _clientUsers!) {
          if (!_controllers.containsKey(user.id)) {
            _controllers[user.id] =
                TextEditingController(text: user.trackingLink ?? '');
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update tracking link for user
  Future<void> _updateTrackingLink(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final controller = _controllers[userId];

    if (controller != null && controller.text.trim().isNotEmpty) {
      final trackingLink = controller.text.trim();

      // Validate URL format
      if (!_isValidUrl(trackingLink)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال رابط صالح (يجب أن يبدأ بـ http:// أو https://)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await authProvider.updateUserTrackingLink(
        userId,
        trackingLink,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث رابط التتبع بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال رابط التتبع'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validate URL format
  bool _isValidUrl(String url) {
    if (url.isEmpty || url == 'null') return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Copy link to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: 'تم نسخ الرابط',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Stack(
          children: [
            // Content
            _clientUsers == null || _clientUsers!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 80,
                          color: Colors.grey.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد عملاء مسجلين',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchClientUsers,
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clientUsers!.length,
                        itemBuilder: (context, index) {
                          final user = _clientUsers![index];
                          final controller =
                              _controllers[user.id] ?? TextEditingController();

                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // User information
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                Theme.of(context).primaryColor,
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(
                                            user.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          subtitle: Text(user.email),
                                        ),
                                        const Divider(),

                                        // Tracking link field
                                        const Text(
                                          'رابط التتبع:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CustomTextField(
                                                controller: controller,
                                                labelText: 'أدخل رابط التتبع',
                                                prefixIcon: Icons.link,
                                                keyboardType: TextInputType.url,
                                              ),
                                            ),
                                            if (controller.text.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.copy),
                                                onPressed: () =>
                                                    _copyToClipboard(
                                                        controller.text),
                                                tooltip: 'نسخ الرابط',
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Update button
                                        CustomButton(
                                          text: 'تحديث الرابط',
                                          onPressed: () =>
                                              _updateTrackingLink(user.id),
                                          isLoading: authProvider.isLoading,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

            // Loading indicator
            if (_isLoading || authProvider.isLoading) const CustomLoader(),
          ],
        );
      },
    );
  }
}
