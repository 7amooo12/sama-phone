/// Location Management Widget for Admin Panel
/// 
/// This widget provides an interface for admins to set warehouse locations,
/// define geofence radius, and manage location boundaries for attendance system.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/location_models.dart';
import '../../services/location_service.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../providers/supabase_provider.dart';
import 'package:uuid/uuid.dart';

class LocationManagementWidget extends StatefulWidget {
  const LocationManagementWidget({super.key});

  @override
  State<LocationManagementWidget> createState() => _LocationManagementWidgetState();
}

class _LocationManagementWidgetState extends State<LocationManagementWidget>
    with TickerProviderStateMixin {

  final LocationService _locationService = LocationService();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  
  // Controllers
  final _warehouseNameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // State
  bool _isLoading = false;
  bool _isSaving = false;
  WarehouseLocationSettings? _currentSettings;
  GeofenceSettings _geofenceSettings = GeofenceSettings.defaultSettings();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadCurrentSettings();
    _radiusController.text = _geofenceSettings.defaultRadius.toString();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _warehouseNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _descriptionController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _locationService.getWarehouseLocationSettings(null);
      if (settings != null && mounted) {
        setState(() {
          _currentSettings = settings;
          _warehouseNameController.text = settings.warehouseName;
          _latitudeController.text = settings.latitude.toString();
          _longitudeController.text = settings.longitude.toString();
          _radiusController.text = settings.geofenceRadius.toString();
          _descriptionController.text = settings.description ?? '';
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إعدادات الموقع: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                if (_isLoading) ...[
                  _buildLoadingState(),
                ] else ...[
                  _buildLocationForm(),
                  const SizedBox(height: 30),
                  _buildCurrentLocationCard(),
                  const SizedBox(height: 30),
                  _buildGeofenceSettings(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                      AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة المواقع',
                      style: AccountantThemeConfig.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تحديد مواقع المخازن ونطاقات الحضور',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AccountantThemeConfig.primaryGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل إعدادات الموقع...',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إعدادات موقع المخزن',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // اسم المخزن
            _buildTextField(
              controller: _warehouseNameController,
              label: 'اسم المخزن',
              icon: Icons.business_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم المخزن';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // خط العرض والطول
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _latitudeController,
                    label: 'خط العرض',
                    icon: Icons.my_location_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'مطلوب';
                      }
                      final lat = double.tryParse(value);
                      if (lat == null || lat < -90 || lat > 90) {
                        return 'قيمة غير صحيحة';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _longitudeController,
                    label: 'خط الطول',
                    icon: Icons.place_rounded,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'مطلوب';
                      }
                      final lng = double.tryParse(value);
                      if (lng == null || lng < -180 || lng > 180) {
                        return 'قيمة غير صحيحة';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // نطاق الجيوفنس
            _buildTextField(
              controller: _radiusController,
              label: 'نطاق الحضور (متر)',
              icon: Icons.radio_button_checked_rounded,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال نطاق الحضور';
                }
                final radius = double.tryParse(value);
                if (radius == null || radius < _geofenceSettings.minRadius || 
                    radius > _geofenceSettings.maxRadius) {
                  return 'النطاق يجب أن يكون بين ${_geofenceSettings.minRadius} و ${_geofenceSettings.maxRadius} متر';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // الوصف
            _buildTextField(
              controller: _descriptionController,
              label: 'الوصف (اختياري)',
              icon: Icons.description_rounded,
              maxLines: 3,
            ),
            
            const SizedBox(height: 24),
            
            // أزرار العمل
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'الحصول على الموقع الحالي',
                    icon: Icons.gps_fixed_rounded,
                    color: AccountantThemeConfig.accentBlue,
                    onPressed: _getCurrentLocation,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    label: _isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
                    icon: Icons.save_rounded,
                    color: AccountantThemeConfig.primaryGreen,
                    onPressed: _isSaving ? null : _saveSettings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          color: Colors.white70,
        ),
        prefixIcon: Icon(icon, color: AccountantThemeConfig.primaryGreen),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AccountantThemeConfig.dangerRed),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: AccountantThemeConfig.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    if (_currentSettings == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'الموقع الحالي المحفوظ',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('اسم المخزن:', _currentSettings!.warehouseName),
          _buildInfoRow('خط العرض:', _currentSettings!.latitude.toString()),
          _buildInfoRow('خط الطول:', _currentSettings!.longitude.toString()),
          _buildInfoRow('نطاق الحضور:', '${_currentSettings!.geofenceRadius} متر'),
          if (_currentSettings!.description?.isNotEmpty == true)
            _buildInfoRow('الوصف:', _currentSettings!.description!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_rounded,
                color: AccountantThemeConfig.warningOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'إعدادات الجيوفنس',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('النطاق الافتراضي:', '${_geofenceSettings.defaultRadius} متر'),
          _buildInfoRow('الحد الأدنى:', '${_geofenceSettings.minRadius} متر'),
          _buildInfoRow('الحد الأقصى:', '${_geofenceSettings.maxRadius} متر'),
          _buildInfoRow('مهلة الموقع:', '${_geofenceSettings.locationTimeoutSeconds} ثانية'),
          _buildInfoRow('حد الدقة:', '${_geofenceSettings.accuracyThreshold} متر'),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _latitudeController.text = position.latitude.toString();
          _longitudeController.text = position.longitude.toString();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم الحصول على الموقع الحالي بنجاح'),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحصول على الموقع: $e'),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Get current user from SupabaseProvider
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('لا يمكن الحصول على معلومات المستخدم الحالي');
      }

      final settings = WarehouseLocationSettings(
        id: _uuid.v4(), // Generate proper UUID
        warehouseName: _warehouseNameController.text.trim(),
        latitude: double.parse(_latitudeController.text),
        longitude: double.parse(_longitudeController.text),
        geofenceRadius: double.parse(_radiusController.text),
        isActive: true,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: currentUser.id, // Use actual user UUID
      );

      final success = await _locationService.saveWarehouseLocationSettings(settings);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ إعدادات الموقع بنجاح'),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        await _loadCurrentSettings();
      } else {
        throw Exception('فشل في حفظ الإعدادات');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الإعدادات: $e'),
            backgroundColor: AccountantThemeConfig.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
