import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/theme_provider_new.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/common/theme_switch.dart';
import 'package:smartbiztracker_new/widgets/common/animated_screen.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/screens/debug/logs_viewer_screen.dart';
import 'package:smartbiztracker_new/widgets/animated_loading.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _notificationsEnabled = true;
  String _currentLanguage = 'ar';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _notificationsEnabled =
              prefs.getBool('notifications_enabled') ?? true;
          _currentLanguage = prefs.getString('language') ?? 'ar';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Handle error
        debugPrint('Error loading settings: $error');
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setString('language', _currentLanguage);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    
    final supabaseUser = supabaseProvider.user;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = supabaseUser ?? authProvider.user;
    
    final themeProvider = Provider.of<ThemeProviderNew>(context);
    
    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'الإعدادات',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.settings,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedScreen(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Theme Section
                  _buildSectionHeader('المظهر', Icons.color_lens),
                  _buildThemeSelector(theme, themeProvider),
                  const SizedBox(height: 24),

                  // Notifications Section
                  _buildSectionHeader('الإشعارات', Icons.notifications),
                  _buildNotificationSettings(theme),
                  const SizedBox(height: 24),

                  // Language Section
                  _buildSectionHeader('اللغة', Icons.language),
                  _buildLanguageSelector(theme),
                  const SizedBox(height: 24),

                  // Privacy & Security Section
                  _buildSectionHeader('الخصوصية والأمان', Icons.security),
                  _buildPrivacySettings(theme),
                  const SizedBox(height: 24),

                  // About Section
                  _buildSectionHeader('حول التطبيق', Icons.info),
                  _buildAboutSection(theme),
                  const SizedBox(height: 24),
                  
                  // Developer Tools Section
                  _buildSectionHeader('أدوات المطور', Icons.developer_mode),
                  _buildDeveloperTools(theme),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('حفظ الإعدادات'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(ThemeData theme, ThemeProviderNew themeProvider) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'وضع السمة',
              style: StyleSystem.titleMedium,
            ),
            const SizedBox(height: 16),

            // مفتاح تبديل السمة المتحرك
            Center(
              child: AnimationSystem.fadeInWithDelay(
                AnimatedThemeSwitch(
                  size: 80,
                  showText: true,
                  lightModeColor: Colors.amber,
                  darkModeColor: Colors.indigo,
                  elevation: 3,
                  animationDuration: const Duration(milliseconds: 800),
                  lightModeText: 'الوضع الفاتح',
                  darkModeText: 'الوضع الداكن',
                ),
                duration: AnimationSystem.medium,
                delay: AnimationSystem.shortDelay,
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // خيارات السمة التفصيلية
            Text(
              'خيارات السمة',
              style: StyleSystem.titleSmall,
            ),
            const SizedBox(height: 8),

            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(
                    Icons.wb_sunny,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('فاتح'),
                ],
              ),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setLightMode();
                }
              },
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(
                    Icons.nightlight_round,
                    color: Colors.indigo,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('داكن'),
                ],
              ),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setDarkMode();
                }
              },
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(
                    Icons.settings_system_daydream,
                    color: StyleSystem.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('تلقائي (حسب نظام الجهاز)'),
                ],
              ),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                }
              },
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('تفعيل الإشعارات'),
              subtitle: const Text('اسمح للتطبيق بإرسال إشعارات لك'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const ListTile(
              title: Text('أنواع الإشعارات'),
              subtitle: Text('اختر أنواع الإشعارات التي ترغب في تلقيها'),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('تحديثات الطلبات'),
              value: true,
              onChanged: _notificationsEnabled ? (value) {} : null,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('تحديثات المنتجات'),
              value: true,
              onChanged: _notificationsEnabled ? (value) {} : null,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('تنبيهات النظام'),
              value: true,
              onChanged: _notificationsEnabled ? (value) {} : null,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لغة التطبيق'),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('العربية'),
              value: 'ar',
              groupValue: _currentLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentLanguage = value;
                  });
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              title: const Text('الإنجليزية'),
              value: 'en',
              groupValue: _currentLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentLanguage = value;
                  });
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettings(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('تغيير كلمة المرور'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to change password screen
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('سياسة الخصوصية'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to privacy policy screen
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('الأمان'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to security settings screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('عن التطبيق'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show about dialog
              showAboutDialog(
                context: context,
                applicationName: 'تطبيق إدارة الأعمال الذكي',
                applicationVersion: 'الإصدار 1.0.0',
                applicationIcon: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 50,
                  height: 50,
                ),
                children: [
                  const Text(
                    'تطبيق متكامل لإدارة الأعمال مع دعم لأدوار متعددة: المدير، العميل، العامل، وصاحب العمل.',
                  ),
                ],
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('التواصل معنا'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to contact us screen
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('تقييم التطبيق'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open app store rating
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperTools(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.text_snippet),
            title: const Text('عرض سجلات التطبيق'),
            subtitle: const Text('مشاهدة وتصدير ملفات السجلات'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LogsViewerScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('وضع المطور'),
            subtitle: const Text('تفعيل ميزات وخيارات إضافية للتطوير'),
            trailing: Switch(
              value: false, // استخدم قيمة من مزود الحالة
              onChanged: (value) {
                // تحديث حالة وضع المطور
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تفعيل وضع المطور'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
