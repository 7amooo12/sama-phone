import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/profile_storage_service.dart';
import '../../utils/logger.dart';

/// مثال عملي لشاشة تحديث الصورة الشخصية
class ProfileImageUpdateScreen extends StatefulWidget {

  const ProfileImageUpdateScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.currentImageUrl,
  });
  final String userId;
  final String userName;
  final String? currentImageUrl;

  @override
  State<ProfileImageUpdateScreen> createState() => _ProfileImageUpdateScreenState();
}

class _ProfileImageUpdateScreenState extends State<ProfileImageUpdateScreen> {
  final _profileStorageService = ProfileStorageService();
  final _imagePicker = ImagePicker();

  String? _currentImageUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.currentImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديث الصورة الشخصية'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_currentImageUrl != null)
            IconButton(
              onPressed: _isLoading ? null : _removeProfileImage,
              icon: const Icon(Icons.delete),
              tooltip: 'حذف الصورة',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // عرض الخطأ إن وجد
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // عرض الصورة الحالية
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(),
                    ),
                  ),
                  
                  // مؤشر التحميل
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // معلومات المستخدم
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'ID: ${widget.userId}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // أزرار التحديث
            Column(
              children: [
                // اختيار من المعرض
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _updateImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('اختيار من المعرض'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // التقاط صورة
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _updateImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('التقاط صورة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // إنشاء صورة افتراضية
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _createDefaultImage,
                    icon: const Icon(Icons.person),
                    label: const Text('إنشاء صورة افتراضية'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // معلومات إضافية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نصائح:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• استخدم صورة واضحة ومضيئة\n'
                    '• تجنب الخلفيات المعقدة\n'
                    '• الصورة ستكون مربعة الشكل\n'
                    '• الحد الأقصى للحجم: 50 ميجابايت',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء عنصر الصورة الشخصية
  Widget _buildProfileImage() {
    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _currentImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => _buildDefaultAvatar(),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  /// بناء الصورة الافتراضية
  Widget _buildDefaultAvatar() {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Center(
        child: Text(
          _getInitials(widget.userName),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// الحصول على الأحرف الأولى من الاسم
  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return 'U';
    
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : 'U';
    }
    
    return (words[0].isNotEmpty ? words[0][0] : '') +
           (words[1].isNotEmpty ? words[1][0] : '');
  }

  /// تحديث الصورة
  Future<void> _updateImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // اختيار الصورة
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // تحديث الصورة
      final imageUrl = await _profileStorageService.updateProfileImage(
        widget.userId,
        File(pickedFile.path),
      );

      if (imageUrl != null) {
        setState(() {
          _currentImageUrl = imageUrl;
        });

        AppLogger.info('تم تحديث الصورة الشخصية: $imageUrl');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الصورة الشخصية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showErrorMessage('فشل في تحديث الصورة الشخصية');
      }
    } catch (e) {
      AppLogger.error('خطأ في تحديث الصورة: $e');
      _showErrorMessage('حدث خطأ أثناء تحديث الصورة: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// إنشاء صورة افتراضية
  Future<void> _createDefaultImage() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // إنشاء صورة افتراضية
      final defaultImageBytes = await _profileStorageService.generateDefaultProfileImage(widget.userName);
      
      // رفع الصورة الافتراضية
      final imageUrl = await _profileStorageService.updateProfileImageFromBytes(
        widget.userId,
        defaultImageBytes,
      );

      if (imageUrl != null) {
        setState(() {
          _currentImageUrl = imageUrl;
        });

        AppLogger.info('تم إنشاء الصورة الافتراضية: $imageUrl');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الصورة الافتراضية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showErrorMessage('فشل في إنشاء الصورة الافتراضية');
      }
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الصورة الافتراضية: $e');
      _showErrorMessage('حدث خطأ أثناء إنشاء الصورة: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// حذف الصورة الشخصية
  Future<void> _removeProfileImage() async {
    // تأكيد الحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف الصورة الشخصية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success = await _profileStorageService.removeProfileImage(widget.userId);

      if (success) {
        setState(() {
          _currentImageUrl = null;
        });

        AppLogger.info('تم حذف الصورة الشخصية');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الصورة الشخصية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showErrorMessage('فشل في حذف الصورة الشخصية');
      }
    } catch (e) {
      AppLogger.error('خطأ في حذف الصورة: $e');
      _showErrorMessage('حدث خطأ أثناء حذف الصورة: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// عرض رسالة خطأ
  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
  }
}
