import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartbiztracker_new/services/ar_service.dart';
import 'package:smartbiztracker_new/services/image_processing_service.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with WidgetsBindingObserver {
  final ARService _arService = ARService();
  final ImageProcessingService _imageProcessingService = ImageProcessingService();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  File? _capturedRoomImage;
  String _currentStep = 'camera'; // camera, room_captured, product_selection, ar_view

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAR();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _arService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      _arService.cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeAR();
    }
  }

  Future<void> _initializeAR() async {
    setState(() => _isLoading = true);
    
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        _showPermissionDialog();
        return;
      }

      // Initialize AR service
      final success = await _arService.initialize();
      if (success) {
        setState(() {
          _isInitialized = true;
          _currentStep = 'camera';
        });
      } else {
        _showErrorDialog('فشل في تهيئة الكاميرا');
      }
    } catch (e) {
      _showErrorDialog('خطأ في تهيئة AR: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _captureRoomPhoto() async {
    if (!_isInitialized) return;
    
    setState(() => _isLoading = true);
    
    try {
      final photo = await _arService.capturePhoto();
      if (photo != null) {
        setState(() {
          _capturedRoomImage = photo;
          _currentStep = 'room_captured';
        });
        
        // Provide haptic feedback
        HapticFeedback.mediumImpact();
        
        _showSuccessSnackBar('تم التقاط صورة المساحة بنجاح!');
      } else {
        _showErrorDialog('فشل في التقاط الصورة');
      }
    } catch (e) {
      _showErrorDialog('خطأ في التقاط الصورة: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      
      if (image != null) {
        setState(() {
          _capturedRoomImage = File(image.path);
          _currentStep = 'room_captured';
        });
        
        _showSuccessSnackBar('تم اختيار صورة المساحة بنجاح!');
      }
    } catch (e) {
      _showErrorDialog('خطأ في اختيار الصورة: $e');
    }
  }

  void _proceedToProductSelection() {
    Navigator.pushNamed(
      context,
      AppRoutes.clientARProductSelection,
      arguments: {
        'roomImage': _capturedRoomImage,
      },
    );
  }

  void _retakePhoto() {
    setState(() {
      _capturedRoomImage = null;
      _currentStep = 'camera';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'تجربة AR للنجف',
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _buildMainContent(theme),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'جاري التحضير...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    switch (_currentStep) {
      case 'camera':
        return _buildCameraView();
      case 'room_captured':
        return _buildRoomCapturedView(theme);
      default:
        return _buildCameraView();
    }
  }

  Widget _buildCameraView() {
    if (!_isInitialized || _arService.cameraController == null) {
      return _buildCameraError();
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_arService.cameraController!),
        ),
        
        // Overlay with instructions
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        
        // Instructions
        Positioned(
          top: 50,
          left: 20,
          right: 20,
          child: AnimationConfiguration.synchronized(
            child: SlideAnimation(
              verticalOffset: -50,
              child: FadeInAnimation(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'صوّر المساحة التي تريد وضع النجفة فيها',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'تأكد من وضوح الإضاءة وظهور السقف',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Bottom controls
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: AnimationConfiguration.synchronized(
            child: SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    _buildControlButton(
                      icon: Icons.photo_library,
                      label: 'المعرض',
                      onTap: _selectFromGallery,
                    ),
                    
                    // Capture button
                    GestureDetector(
                      onTap: _captureRoomPhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                    ),
                    
                    // Switch camera button (placeholder)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      label: 'تبديل',
                      onTap: () {
                        // TODO: Implement camera switching
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.7),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'فشل في تشغيل الكاميرا',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'تأكد من منح الأذونات المطلوبة',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeAR,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCapturedView(ThemeData theme) {
    return Column(
      children: [
        // Image preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _capturedRoomImage!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),
        
        // Action buttons
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Text(
                'هل أنت راضٍ عن صورة المساحة؟',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retakePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة التصوير'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _proceedToProductSelection,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('اختيار النجفة'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إذن الكاميرا مطلوب'),
        content: const Text('يحتاج التطبيق إلى إذن الكاميرا لتجربة AR'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('الإعدادات'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
