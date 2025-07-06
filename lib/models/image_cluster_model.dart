import 'dart:math';
import 'package:collection/collection.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class ImageCluster {

  ImageCluster({
    required this.id,
    required this.productIds,
    required this.centroid,
  });

  factory ImageCluster.fromJson(Map<String, dynamic> json) {
    return ImageCluster(
      id: (json['id'] as int?) ?? 0,
      productIds: List<String>.from((json['productIds'] as Iterable?) ?? []),
      centroid: List<double>.from((json['centroid'] as Iterable?) ?? []),
    );
  }
  final int id;
  final List<String> productIds;
  final List<double> centroid;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productIds': productIds,
      'centroid': centroid,
    };
  }
}

class ProductClustering {
  // K-means clustering for product feature vectors
  static List<ImageCluster> kMeansClustering({
    required Map<String, List<double>> productVectors,
    int k = 5,
    int maxIterations = 10,
  }) {
    if (productVectors.isEmpty) {
      return [];
    }

    if (productVectors.length <= k) {
      // If we have fewer products than clusters, each product gets its own cluster
      return productVectors.entries.mapIndexed((index, entry) =>
        ImageCluster(
          id: index,
          productIds: [entry.key],
          centroid: List<double>.from(entry.value),
        )
      ).toList();
    }

    try {
      AppLogger.info('Starting K-means clustering with k=$k');

      // Initialize random centroids by picking k random products
      final random = Random();
      final allProducts = productVectors.keys.toList();
      final allVectors = productVectors.values.toList();
      final vectorLength = allVectors.first.length;

      // Initialize centroids with random products
      final List<List<double>> centroids = [];
      for (int i = 0; i < k; i++) {
        final randomIndex = random.nextInt(allProducts.length);
        centroids.add(List<double>.from(allVectors[randomIndex]));
      }

      // Map to track product assignments to clusters
      Map<int, List<String>> assignments = {};
      Map<int, List<String>> prevAssignments = {};

      // Perform K-means iteratively
      int iterations = 0;
      bool hasConverged = false;

      while (!hasConverged && iterations < maxIterations) {
        // Reset assignments
        assignments = {};
        for (int i = 0; i < k; i++) {
          assignments[i] = [];
        }

        // Assign each product to the nearest centroid
        productVectors.forEach((productId, vector) {
          final int nearestCentroidIndex = _findNearestCentroidIndex(vector, centroids);
          assignments[nearestCentroidIndex]!.add(productId);
        });

        // Check for convergence
        if (_areAssignmentsEqual(assignments, prevAssignments)) {
          hasConverged = true;
          break;
        }

        // Update centroids
        for (int i = 0; i < k; i++) {
          if (assignments[i]!.isEmpty) {
            // Reinitialize empty clusters
            final randomIndex = random.nextInt(allProducts.length);
            centroids[i] = List<double>.from(allVectors[randomIndex]);
          } else {
            // Calculate mean of all vectors in this cluster
            final List<double> sum = List<double>.filled(vectorLength, 0.0);

            for (final productId in assignments[i]!) {
              final vector = productVectors[productId]!;
              for (int j = 0; j < vectorLength; j++) {
                sum[j] += vector[j];
              }
            }

            for (int j = 0; j < vectorLength; j++) {
              centroids[i][j] = sum[j] / assignments[i]!.length;
            }
          }
        }

        // Copy current assignments for next comparison
        prevAssignments = Map.from(assignments);
        prevAssignments.forEach((key, value) {
          prevAssignments[key] = List<String>.from(value);
        });

        iterations++;
      }

      AppLogger.info('K-means clustering completed in $iterations iterations. Converged: $hasConverged');

      // Create cluster objects
      final List<ImageCluster> clusters = [];
      for (int i = 0; i < k; i++) {
        clusters.add(ImageCluster(
          id: i,
          productIds: assignments[i] ?? [],
          centroid: centroids[i],
        ));
      }

      return clusters;
    } catch (e) {
      AppLogger.error('Error during clustering', e);
      return [];
    }
  }

  // Find the nearest centroid to a given vector
  static int _findNearestCentroidIndex(List<double> vector, List<List<double>> centroids) {
    int nearestIndex = 0;
    double minDistance = _calculateCosineSimilarity(vector, centroids[0]);

    for (int i = 1; i < centroids.length; i++) {
      final distance = _calculateCosineSimilarity(vector, centroids[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  // Calculate cosine similarity between two vectors
  static double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw Exception('Vector dimensions do not match');
    }

    double dotProduct = 0.0;
    double magnitudeA = 0.0;
    double magnitudeB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    magnitudeA = sqrt(magnitudeA);
    magnitudeB = sqrt(magnitudeB);

    if (magnitudeA == 0 || magnitudeB == 0) {
      return 0.0;
    }

    // Return the distance (1 - similarity) so lower is better
    return 1.0 - (dotProduct / (magnitudeA * magnitudeB));
  }

  // Check if two assignment maps are equal
  static bool _areAssignmentsEqual(Map<int, List<String>> a, Map<int, List<String>> b) {
    if (a.length != b.length) return false;

    for (final entry in a.entries) {
      final key = entry.key;
      if (!b.containsKey(key)) return false;

      final aList = a[key]!..sort();
      final bList = b[key]!..sort();

      if (aList.length != bList.length) return false;

      for (int i = 0; i < aList.length; i++) {
        if (aList[i] != bList[i]) return false;
      }
    }

    return true;
  }
}