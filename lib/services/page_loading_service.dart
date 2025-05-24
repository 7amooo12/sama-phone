import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartbiztracker_new/services/cache_service.dart';

class PageLoadingService {
  static const Duration _defaultLoadingDelay = Duration(milliseconds: 300);
  
  static Future<void> preloadPage({
    required BuildContext context,
    required Widget page,
    Duration? loadingDelay,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Add artificial delay to prevent flickering
      await Future.delayed(loadingDelay ?? _defaultLoadingDelay);

      // Preload page data
      if (page is StatefulWidget) {
        final state = (page as StatefulWidget).createState();
        if (state is State) {
          await state.initState();
        }
      }

      // Remove loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error preloading page: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  static Future<void> preloadImages(List<String> imageUrls) async {
    try {
      for (final url in imageUrls) {
        final cachedImage = await CacheService.getData('image_$url');
        if (cachedImage == null) {
          // Preload image
          final image = NetworkImage(url);
          final imageStream = image.resolve(ImageConfiguration.empty);
          await imageStream.first;
          
          // Cache the image
          await CacheService.setData('image_$url', url);
        }
      }
    } catch (e) {
      debugPrint('Error preloading images: $e');
    }
  }

  static Future<void> preloadData(String key, Future<dynamic> Function() dataLoader) async {
    try {
      final cachedData = await CacheService.getData(key);
      if (cachedData == null) {
        final data = await dataLoader();
        await CacheService.setData(key, data);
      }
    } catch (e) {
      debugPrint('Error preloading data: $e');
    }
  }

  static void setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
} 