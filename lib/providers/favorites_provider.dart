import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/product.dart';
import '../utils/logger.dart';

class FavoritesProvider with ChangeNotifier {
  List<Product> _favorites = [];
  bool _isLoading = false;

  List<Product> get favorites => _favorites;
  bool get isLoading => _isLoading;

  // Check if a product is in favorites
  bool isFavorite(int productId) {
    return _favorites.any((product) => product.id == productId);
  }

  // Toggle favorite status
  void toggleFavorite(Product product) {
    final isExisting = _favorites.any((item) => item.id == product.id);
    
    if (isExisting) {
      _favorites.removeWhere((item) => item.id == product.id);
    } else {
      _favorites.add(product);
    }
    
    _saveFavoritesToPrefs();
    notifyListeners();
  }

  // Add to favorites
  void addToFavorites(Product product) {
    if (!isFavorite(product.id)) {
      _favorites.add(product);
      _saveFavoritesToPrefs();
      notifyListeners();
    }
  }

  // Remove from favorites
  void removeFromFavorites(int productId) {
    _favorites.removeWhere((product) => product.id == productId);
    _saveFavoritesToPrefs();
    notifyListeners();
  }

  // Clear all favorites
  void clearFavorites() {
    _favorites = [];
    _saveFavoritesToPrefs();
    notifyListeners();
  }

  // Load favorites from SharedPreferences
  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesData = prefs.getString('favorites');

      if (favoritesData != null) {
        final List<dynamic> decodedData = json.decode(favoritesData);
        _favorites = decodedData
            .map((item) => Product.fromJson(item))
            .toList();
      }
    } catch (e) {
      AppLogger.error('Error loading favorites', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save favorites to SharedPreferences
  Future<void> _saveFavoritesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesData = json.encode(_favorites.map((product) => product.toJson()).toList());
      await prefs.setString('favorites', favoritesData);
    } catch (e) {
      AppLogger.error('Error saving favorites', e);
    }
  }
}
