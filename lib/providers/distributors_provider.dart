import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/distribution_center_model.dart';
import '../models/distributor_model.dart';
import '../services/database_service.dart';
import '../utils/app_logger.dart';

/// Provider for managing distributors and distribution centers
class DistributorsProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // State variables
  List<DistributionCenterModel> _distributionCenters = [];
  List<DistributorModel> _distributors = [];
  Map<String, List<DistributorModel>> _distributorsByCenter = {};
  Map<String, DistributionCenterStatistics> _centerStatistics = {};
  
  bool _isLoading = false;
  bool _isLoadingCenters = false;
  bool _isLoadingDistributors = false;
  String? _error;

  // Getters
  List<DistributionCenterModel> get distributionCenters => _distributionCenters;
  List<DistributorModel> get distributors => _distributors;
  Map<String, List<DistributorModel>> get distributorsByCenter => _distributorsByCenter;
  Map<String, DistributionCenterStatistics> get centerStatistics => _centerStatistics;
  
  bool get isLoading => _isLoading;
  bool get isLoadingCenters => _isLoadingCenters;
  bool get isLoadingDistributors => _isLoadingDistributors;
  String? get error => _error;

  /// Gets distributors for a specific center
  List<DistributorModel> getDistributorsForCenter(String centerId) {
    return _distributorsByCenter[centerId] ?? [];
  }

  /// Gets statistics for a specific center
  DistributionCenterStatistics? getCenterStatistics(String centerId) {
    return _centerStatistics[centerId];
  }

  /// Clears any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Fetches all distribution centers with distributor counts
  Future<void> fetchDistributionCenters() async {
    _isLoadingCenters = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch centers with distributor counts using a join query
      final response = await _supabase
          .from('distribution_centers')
          .select('''
            *,
            distributors!distribution_center_id(count)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _distributionCenters = (response as List).map((centerData) {
        // Calculate distributor count from the join
        final distributorsData = centerData['distributors'] as List?;
        final distributorCount = distributorsData?.length ?? 0;
        
        // Create center model with count
        final centerMap = Map<String, dynamic>.from(centerData);
        centerMap['distributors_count'] = distributorCount;
        centerMap.remove('distributors'); // Remove the join data
        
        return DistributionCenterModel.fromSupabaseWithCount(centerMap);
      }).toList();

      AppLogger.info('Fetched ${_distributionCenters.length} distribution centers');
    } catch (e) {
      _error = 'فشل في تحميل مراكز التوزيع: ${e.toString()}';
      AppLogger.error('Error fetching distribution centers: $e');
    } finally {
      _isLoadingCenters = false;
      notifyListeners();
    }
  }

  /// Fetches all distributors
  Future<void> fetchDistributors() async {
    _isLoadingDistributors = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('distributors')
          .select('''
            *,
            distribution_centers!distribution_center_id(name)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _distributors = (response as List).map((distributorData) {
        // Add center name to distributor data
        final centerData = distributorData['distribution_centers'] as Map<String, dynamic>?;
        final distributorMap = Map<String, dynamic>.from(distributorData);
        distributorMap['center_name'] = centerData?['name'];
        distributorMap.remove('distribution_centers'); // Remove the join data
        
        return DistributorModel.fromJson(distributorMap);
      }).toList();

      // Group distributors by center
      _distributorsByCenter.clear();
      for (final distributor in _distributors) {
        final centerId = distributor.distributionCenterId;
        if (!_distributorsByCenter.containsKey(centerId)) {
          _distributorsByCenter[centerId] = [];
        }
        _distributorsByCenter[centerId]!.add(distributor);
      }

      AppLogger.info('Fetched ${_distributors.length} distributors');
    } catch (e) {
      _error = 'فشل في تحميل الموزعين: ${e.toString()}';
      AppLogger.error('Error fetching distributors: $e');
    } finally {
      _isLoadingDistributors = false;
      notifyListeners();
    }
  }

  /// Fetches distributors for a specific center
  Future<void> fetchDistributorsForCenter(String centerId) async {
    _isLoadingDistributors = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('distributors')
          .select('*')
          .eq('distribution_center_id', centerId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final distributors = (response as List)
          .map((data) => DistributorModel.fromJson(data))
          .toList();

      _distributorsByCenter[centerId] = distributors;

      AppLogger.info('Fetched ${distributors.length} distributors for center $centerId');
    } catch (e) {
      _error = 'فشل في تحميل موزعي المركز: ${e.toString()}';
      AppLogger.error('Error fetching distributors for center: $e');
    } finally {
      _isLoadingDistributors = false;
      notifyListeners();
    }
  }

  /// Creates a new distribution center
  Future<bool> createDistributionCenter(DistributionCenterModel center) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate the center data
      final validationErrors = center.validate();
      if (validationErrors.isNotEmpty) {
        _error = validationErrors.first;
        return false;
      }

      // Get current user ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _error = 'يجب تسجيل الدخول أولاً';
        return false;
      }

      // Create center with current user as creator
      final centerData = center.toInsertJson();
      centerData['created_by'] = currentUser.id;

      final response = await _supabase
          .from('distribution_centers')
          .insert(centerData)
          .select()
          .single();

      // Create new center model with returned data
      final newCenter = DistributionCenterModel.fromJson(response);
      _distributionCenters.insert(0, newCenter);

      AppLogger.info('Created distribution center: ${newCenter.name}');
      return true;
    } catch (e) {
      _error = 'فشل في إنشاء مركز التوزيع: ${e.toString()}';
      AppLogger.error('Error creating distribution center: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing distribution center
  Future<bool> updateDistributionCenter(DistributionCenterModel center) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate the center data
      final validationErrors = center.validate();
      if (validationErrors.isNotEmpty) {
        _error = validationErrors.first;
        return false;
      }

      // Get current user ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _error = 'يجب تسجيل الدخول أولاً';
        return false;
      }

      // Update center with current user as updater
      final centerData = center.toJson();
      centerData['updated_by'] = currentUser.id;
      centerData.remove('created_at'); // Don't update creation time
      centerData.remove('created_by'); // Don't update creator

      await _supabase
          .from('distribution_centers')
          .update(centerData)
          .eq('id', center.id);

      // Update local list
      final index = _distributionCenters.indexWhere((c) => c.id == center.id);
      if (index != -1) {
        _distributionCenters[index] = center.copyWith(
          updatedAt: DateTime.now(),
          updatedBy: currentUser.id,
        );
      }

      AppLogger.info('Updated distribution center: ${center.name}');
      return true;
    } catch (e) {
      _error = 'فشل في تحديث مركز التوزيع: ${e.toString()}';
      AppLogger.error('Error updating distribution center: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a distribution center
  Future<bool> deleteDistributionCenter(String centerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if center has distributors
      final distributors = getDistributorsForCenter(centerId);
      if (distributors.isNotEmpty) {
        _error = 'لا يمكن حذف المركز لأنه يحتوي على موزعين';
        return false;
      }

      // Soft delete by setting is_active to false
      await _supabase
          .from('distribution_centers')
          .update({'is_active': false})
          .eq('id', centerId);

      // Remove from local list
      _distributionCenters.removeWhere((center) => center.id == centerId);
      _distributorsByCenter.remove(centerId);
      _centerStatistics.remove(centerId);

      AppLogger.info('Deleted distribution center: $centerId');
      return true;
    } catch (e) {
      _error = 'فشل في حذف مركز التوزيع: ${e.toString()}';
      AppLogger.error('Error deleting distribution center: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new distributor
  Future<bool> createDistributor(DistributorModel distributor) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate the distributor data
      final validationErrors = distributor.validate();
      if (validationErrors.isNotEmpty) {
        _error = validationErrors.first;
        return false;
      }

      // Get current user ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _error = 'يجب تسجيل الدخول أولاً';
        return false;
      }

      // Create distributor with current user as creator
      final distributorData = distributor.toInsertJson();
      distributorData['created_by'] = currentUser.id;

      final response = await _supabase
          .from('distributors')
          .insert(distributorData)
          .select()
          .single();

      // Create new distributor model with returned data
      final newDistributor = DistributorModel.fromJson(response);
      
      // Add to local lists
      _distributors.insert(0, newDistributor);
      final centerId = newDistributor.distributionCenterId;
      if (!_distributorsByCenter.containsKey(centerId)) {
        _distributorsByCenter[centerId] = [];
      }
      _distributorsByCenter[centerId]!.insert(0, newDistributor);

      // Update center distributor count
      final centerIndex = _distributionCenters.indexWhere((c) => c.id == centerId);
      if (centerIndex != -1) {
        final center = _distributionCenters[centerIndex];
        _distributionCenters[centerIndex] = center.copyWith(
          distributorCount: center.distributorCount + 1,
        );
      }

      AppLogger.info('Created distributor: ${newDistributor.name}');
      return true;
    } catch (e) {
      _error = 'فشل في إنشاء الموزع: ${e.toString()}';
      AppLogger.error('Error creating distributor: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing distributor
  Future<bool> updateDistributor(DistributorModel distributor) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate the distributor data
      final validationErrors = distributor.validate();
      if (validationErrors.isNotEmpty) {
        _error = validationErrors.first;
        return false;
      }

      // Get current user ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _error = 'يجب تسجيل الدخول أولاً';
        return false;
      }

      // Update distributor with current user as updater
      final distributorData = distributor.toJson();
      distributorData['updated_by'] = currentUser.id;
      distributorData.remove('created_at'); // Don't update creation time
      distributorData.remove('created_by'); // Don't update creator

      await _supabase
          .from('distributors')
          .update(distributorData)
          .eq('id', distributor.id);

      // Update local lists
      final index = _distributors.indexWhere((d) => d.id == distributor.id);
      if (index != -1) {
        _distributors[index] = distributor.copyWith(
          updatedAt: DateTime.now(),
          updatedBy: currentUser.id,
        );
      }

      // Update center-specific list
      final centerId = distributor.distributionCenterId;
      final centerDistributors = _distributorsByCenter[centerId];
      if (centerDistributors != null) {
        final centerIndex = centerDistributors.indexWhere((d) => d.id == distributor.id);
        if (centerIndex != -1) {
          centerDistributors[centerIndex] = distributor.copyWith(
            updatedAt: DateTime.now(),
            updatedBy: currentUser.id,
          );
        }
      }

      AppLogger.info('Updated distributor: ${distributor.name}');
      return true;
    } catch (e) {
      _error = 'فشل في تحديث الموزع: ${e.toString()}';
      AppLogger.error('Error updating distributor: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a distributor
  Future<bool> deleteDistributor(String distributorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find the distributor to get center ID
      final distributor = _distributors.firstWhere((d) => d.id == distributorId);
      final centerId = distributor.distributionCenterId;

      // Soft delete by setting is_active to false
      await _supabase
          .from('distributors')
          .update({'is_active': false})
          .eq('id', distributorId);

      // Remove from local lists
      _distributors.removeWhere((d) => d.id == distributorId);
      _distributorsByCenter[centerId]?.removeWhere((d) => d.id == distributorId);

      // Update center distributor count
      final centerIndex = _distributionCenters.indexWhere((c) => c.id == centerId);
      if (centerIndex != -1) {
        final center = _distributionCenters[centerIndex];
        _distributionCenters[centerIndex] = center.copyWith(
          distributorCount: center.distributorCount - 1,
        );
      }

      AppLogger.info('Deleted distributor: $distributorId');
      return true;
    } catch (e) {
      _error = 'فشل في حذف الموزع: ${e.toString()}';
      AppLogger.error('Error deleting distributor: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches statistics for a specific center
  Future<void> fetchCenterStatistics(String centerId) async {
    try {
      final response = await _supabase.rpc('get_center_statistics', params: {
        'center_id': centerId,
      });

      if (response != null) {
        _centerStatistics[centerId] = DistributionCenterStatistics.fromJson(response);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error fetching center statistics: $e');
    }
  }

  /// Searches distributors by name, showroom name, or phone
  Future<List<DistributorModel>> searchDistributors(String searchTerm) async {
    if (searchTerm.trim().isEmpty) {
      return _distributors;
    }

    try {
      final response = await _supabase.rpc('search_distributors', params: {
        'search_term': searchTerm.trim(),
      });

      return (response as List)
          .map((data) => DistributorModel.fromJson(data))
          .toList();
    } catch (e) {
      AppLogger.error('Error searching distributors: $e');
      return [];
    }
  }

  /// Refreshes all data
  Future<void> refreshAll() async {
    await Future.wait([
      fetchDistributionCenters(),
      fetchDistributors(),
    ]);
  }

  /// Clears all data
  void clearData() {
    _distributionCenters.clear();
    _distributors.clear();
    _distributorsByCenter.clear();
    _centerStatistics.clear();
    _error = null;
    notifyListeners();
  }

  /// Gets a distribution center by ID
  DistributionCenterModel? getCenterById(String centerId) {
    try {
      return _distributionCenters.firstWhere((center) => center.id == centerId);
    } catch (e) {
      return null;
    }
  }

  /// Gets a distributor by ID
  DistributorModel? getDistributorById(String distributorId) {
    try {
      return _distributors.firstWhere((distributor) => distributor.id == distributorId);
    } catch (e) {
      return null;
    }
  }

  /// Gets distributors by status
  List<DistributorModel> getDistributorsByStatus(DistributorStatus status) {
    return _distributors.where((distributor) => distributor.status == status).toList();
  }

  /// Gets active distributors count
  int get activeDistributorsCount {
    return _distributors.where((d) => d.status == DistributorStatus.active).length;
  }

  /// Gets total distributors count
  int get totalDistributorsCount => _distributors.length;

  /// Gets total centers count
  int get totalCentersCount => _distributionCenters.length;

  /// Adds a new distributor (alias for createDistributor for compatibility)
  Future<bool> addDistributor(DistributorModel distributor) async {
    return await createDistributor(distributor);
  }

  /// Updates distributor status
  Future<bool> updateDistributorStatus(String distributorId, DistributorStatus newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get current user ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _error = 'يجب تسجيل الدخول أولاً';
        return false;
      }

      // Update status in database
      await _supabase
          .from('distributors')
          .update({
            'status': newStatus.value,
            'updated_by': currentUser.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', distributorId);

      // Update local lists
      final distributorIndex = _distributors.indexWhere((d) => d.id == distributorId);
      if (distributorIndex != -1) {
        final updatedDistributor = _distributors[distributorIndex].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
          updatedBy: currentUser.id,
        );
        _distributors[distributorIndex] = updatedDistributor;

        // Update center-specific list
        final centerId = updatedDistributor.distributionCenterId;
        final centerDistributors = _distributorsByCenter[centerId];
        if (centerDistributors != null) {
          final centerIndex = centerDistributors.indexWhere((d) => d.id == distributorId);
          if (centerIndex != -1) {
            centerDistributors[centerIndex] = updatedDistributor;
          }
        }
      }

      AppLogger.info('Updated distributor status: $distributorId to ${newStatus.displayName}');
      return true;
    } catch (e) {
      _error = 'فشل في تحديث حالة الموزع: ${e.toString()}';
      AppLogger.error('Error updating distributor status: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
