import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class Helpers {
  static Future<File?> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error picking image', e);
      return null;
    }
  }

  static Future<List<File>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );

      if (result != null) {
        return result.files.map((file) => File(file.path!)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error picking files', e);
      return [];
    }
  }

  static Future<bool> launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri);
    } catch (e) {
      AppLogger.error('Error launching URL', e);
      return false;
    }
  }

  static Future<void> shareContent({
    required String text,
    String? subject,
    List<String>? imagePaths,
  }) async {
    try {
      if (imagePaths != null && imagePaths.isNotEmpty) {
        final files = imagePaths.map((path) => XFile(path)).toList();
        await Share.shareXFiles(
          files,
          text: text,
          subject: subject,
        );
      } else {
        await Share.share(
          text,
          subject: subject,
        );
      }
    } catch (e) {
      AppLogger.error('Error sharing content', e);
    }
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? AppConstants.errorColor : AppConstants.successColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.errorColor,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  static String generateId() {
    const uuid = Uuid();
    return uuid.v4(); // Generate proper UUID instead of timestamp
  }

  static bool isValidFileType(String filePath, List<String> allowedExtensions) {
    final extension =
        path.extension(filePath).toLowerCase().replaceAll('.', '');
    return allowedExtensions.contains(extension);
  }

  static bool isValidFileSize(File file, int maxSizeInMB) {
    return file.lengthSync() <= maxSizeInMB * 1024 * 1024;
  }

  static String getFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return 'image';
      case '.pdf':
        return 'pdf';
      case '.doc':
      case '.docx':
        return 'document';
      case '.xls':
      case '.xlsx':
        return 'spreadsheet';
      case '.txt':
        return 'text';
      default:
        return 'other';
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppConstants.warningColor;
      case 'in progress':
      case 'processing':
        return AppConstants.infoColor;
      case 'completed':
      case 'resolved':
      case 'approved':
        return AppConstants.successColor;
      case 'cancelled':
      case 'rejected':
        return AppConstants.errorColor;
      default:
        return Colors.grey;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'in progress':
      case 'processing':
        return Icons.sync;
      case 'completed':
      case 'resolved':
      case 'approved':
        return Icons.check_circle;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  static bool isEmailValid(String email) {
    return RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(email);
  }

  static bool isPasswordValid(String password) {
    return password.length >= 6;
  }

  static bool isPhoneValid(String phone) {
    return RegExp(r'^\+?[0-9]{10,}$').hasMatch(phone);
  }
}
