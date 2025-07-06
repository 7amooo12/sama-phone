import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../models/treasury_models.dart';
import '../../utils/accountant_theme_config.dart';

/// Helper class to hold optimized connection point results
class OptimizedConnectionPoints {
  final Offset sourcePoint;
  final Offset targetPoint;
  final ConnectionPoint sourceConnectionPoint;
  final ConnectionPoint targetConnectionPoint;

  const OptimizedConnectionPoints({
    required this.sourcePoint,
    required this.targetPoint,
    required this.sourceConnectionPoint,
    required this.targetConnectionPoint,
  });
}

class TreasuryConnectionPainter extends CustomPainter {
  final List<TreasuryVault> treasuries;
  final List<TreasuryConnection> connections;
  final double connectionAnimation;
  final double particleAnimation;
  final bool isConnectionMode;
  final String? selectedTreasuryId;
  final double scrollOffset;

  // Cache for optimized routing paths to avoid recalculation
  final Map<String, List<Offset>> _pathCache = {};

  // Track existing paths for collision avoidance
  final List<List<Offset>> _existingPaths = [];

  TreasuryConnectionPainter({
    required this.treasuries,
    required this.connections,
    required this.connectionAnimation,
    required this.particleAnimation,
    required this.isConnectionMode,
    this.selectedTreasuryId,
    this.scrollOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (connections.isEmpty && !isConnectionMode) return;

    // Clear existing paths for fresh calculation
    _existingPaths.clear();
    _pathCache.clear();

    // Pre-calculate all card obstacles for intelligent routing
    final obstacles = _getAllCardObstacles(size);

    // Draw existing connections with intelligent path routing
    for (int i = 0; i < connections.length; i++) {
      final connection = connections[i];
      _drawIntelligentConnection(canvas, size, connection, obstacles, i);
    }

    // Draw potential connections in connection mode
    if (isConnectionMode && selectedTreasuryId != null) {
      _drawPotentialConnections(canvas, size);
    }
  }

  /// Draw intelligent connection with precise card attachment and smart routing
  void _drawIntelligentConnection(Canvas canvas, Size size, TreasuryConnection connection, List<Rect> obstacles, int connectionIndex) {
    // Get precise card center positions
    Offset? sourceCenterPos;
    Offset? targetCenterPos;

    // Handle source position with exact card positioning
    if (connection.sourceTreasuryId == 'client_wallets' || connection.sourceTreasuryId == 'electronic_wallets') {
      sourceCenterPos = _getWalletSummaryPosition(connection.sourceTreasuryId, size);
    } else {
      final sourceTreasury = treasuries.firstWhere(
        (t) => t.id == connection.sourceTreasuryId,
        orElse: () => treasuries.first,
      );
      sourceCenterPos = _getTreasuryPosition(sourceTreasury, size);
    }

    // Handle target position with exact card positioning
    if (connection.targetTreasuryId == 'client_wallets' || connection.targetTreasuryId == 'electronic_wallets') {
      targetCenterPos = _getWalletSummaryPosition(connection.targetTreasuryId, size);
    } else {
      final targetTreasury = treasuries.firstWhere(
        (t) => t.id == connection.targetTreasuryId,
        orElse: () => treasuries.first,
      );
      targetCenterPos = _getTreasuryPosition(targetTreasury, size);
    }

    if (sourceCenterPos == null || targetCenterPos == null) return;

    // Calculate optimal connection points on card edges
    final connectionPoints = _calculateOptimalConnectionPoints(sourceCenterPos, targetCenterPos, size);
    final sourceEdgePoint = _getConnectionPointPosition(
      sourceCenterPos,
      connectionPoints.sourcePoint,
      null,
      size
    );
    final targetEdgePoint = _getConnectionPointPosition(
      targetCenterPos,
      connectionPoints.targetPoint,
      null,
      size
    );

    // Generate unique cache key for this connection
    final cacheKey = '${connection.sourceTreasuryId}-${connection.targetTreasuryId}-$scrollOffset';

    // Calculate intelligent routing path with collision avoidance
    List<Offset> routingPath;
    if (_pathCache.containsKey(cacheKey)) {
      routingPath = _pathCache[cacheKey]!;
    } else {
      routingPath = _calculateIntelligentRoute(
        sourceEdgePoint,
        targetEdgePoint,
        obstacles,
        connectionIndex,
        size
      );
      _pathCache[cacheKey] = routingPath;
    }

    // Add this path to existing paths for future collision detection
    _existingPaths.add(routingPath);

    // Create path from routing points
    final path = _createPathFromPoints(routingPath);

    // Draw connection line with enhanced styling
    _drawEnhancedConnectionLine(canvas, path, connectionIndex);

    // Draw flowing particles with directional colors
    _drawDirectionalFlowingParticles(canvas, path, connection);

    // Draw connection points with enhanced visibility showing precise attachment
    _drawEnhancedConnectionPoints(canvas, sourceEdgePoint, targetEdgePoint, connectionIndex);
  }

  void _drawPotentialConnections(Canvas canvas, Size size) {
    Offset? selectedPos;

    // Handle selected position (treasury vault or wallet summary)
    if (selectedTreasuryId == 'client_wallets' || selectedTreasuryId == 'electronic_wallets') {
      selectedPos = _getWalletSummaryPosition(selectedTreasuryId!, size);
    } else {
      final selectedTreasury = treasuries.firstWhere(
        (t) => t.id == selectedTreasuryId,
        orElse: () => treasuries.first,
      );
      selectedPos = _getTreasuryPosition(selectedTreasury, size);
    }

    if (selectedPos == null) return;

    // Draw potential connection lines to other treasuries
    for (final treasury in treasuries) {
      if (treasury.id == selectedTreasuryId) continue;

      final targetPos = _getTreasuryPosition(treasury, size);
      if (targetPos == null) continue;

      // Check if connection is valid
      if (_canConnect(selectedTreasuryId!, treasury.id)) {
        _drawPotentialConnectionLine(canvas, selectedPos, targetPos);
      }
    }

    // Draw potential connections to wallet summaries if not already selected
    if (selectedTreasuryId != 'client_wallets') {
      final clientWalletsPos = _getWalletSummaryPosition('client_wallets', size);
      if (clientWalletsPos != null && _canConnect(selectedTreasuryId!, 'client_wallets')) {
        _drawPotentialConnectionLine(canvas, selectedPos, clientWalletsPos);
      }
    }

    if (selectedTreasuryId != 'electronic_wallets') {
      final electronicWalletsPos = _getWalletSummaryPosition('electronic_wallets', size);
      if (electronicWalletsPos != null && _canConnect(selectedTreasuryId!, 'electronic_wallets')) {
        _drawPotentialConnectionLine(canvas, selectedPos, electronicWalletsPos);
      }
    }
  }

  Offset? _getTreasuryPosition(TreasuryVault treasury, Size size) {
    if (treasury.isMainTreasury) {
      // Main treasury is centered horizontally and positioned below wallet cards
      // Apply scroll offset and account for responsive spacing
      final isTablet = size.width > 768;
      final isDesktop = size.width > 1200;

      // Get actual responsive values that match the main screen
      final padding = isDesktop ? 32.0 : isTablet ? 24.0 : 16.0;
      final spacing = _getResponsiveSpacingForPainter(isTablet, isDesktop);
      final walletCardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);

      // Main treasury Y position: padding + wallet cards height + spacing + main treasury center (90px = half of 180px height)
      final mainTreasuryY = padding + walletCardHeight + spacing + 90.0;

      return Offset(size.width * 0.5, mainTreasuryY - scrollOffset);
    } else {
      // Sub-treasuries use exact same tree layout positioning as main screen
      final subTreasuries = treasuries.where((t) => !t.isMainTreasury).toList();
      final index = subTreasuries.indexWhere((t) => t.id == treasury.id);

      if (index == -1) return null;

      // Use exact same calculation as main screen _calculateTreePositions
      final isTablet = size.width > 768;
      final isDesktop = size.width > 1200;
      final padding = isDesktop ? 32.0 : isTablet ? 24.0 : 16.0;
      final cardWidth = _getCardWidthForPainter(size.width, isTablet, isDesktop);
      final cardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);
      final spacing = _getResponsiveSpacingForPainter(isTablet, isDesktop);
      final verticalSpacing = cardHeight + spacing;
      final horizontalMargin = cardWidth * 0.05;

      // Calculate position using EXACT same logic as main screen _calculateTreePositions
      final level = (index / 2).floor();
      final isLeft = index % 2 == 0;

      double x, y;

      // Use the same positioning logic as the main screen
      final totalSubTreasuries = subTreasuries.length;
      if (totalSubTreasuries == 1) {
        // Single treasury: center it
        x = size.width * 0.5; // Center of card
        y = 0;
      } else if (totalSubTreasuries == 2) {
        // Two treasuries: left and right
        if (index == 0) {
          x = size.width * 0.3; // Left position center
          y = 0;
        } else {
          x = size.width * 0.7; // Right position center
          y = 0;
        }
      } else if (totalSubTreasuries == 3) {
        // Three treasuries: top center, bottom left, bottom right
        if (index == 0) {
          x = size.width * 0.5; // Top center
          y = 0;
        } else if (index == 1) {
          x = size.width * 0.25; // Bottom left center
          y = verticalSpacing;
        } else {
          x = size.width * 0.75; // Bottom right center
          y = verticalSpacing;
        }
      } else if (totalSubTreasuries == 4) {
        // Four treasuries: 2x2 grid
        final row = index ~/ 2;
        final col = index % 2;
        x = size.width * (col == 0 ? 0.25 : 0.75);
        y = row * verticalSpacing;
      } else {
        // Five or more treasuries: use grid layout
        final columns = _calculateOptimalColumnsForPainter(totalSubTreasuries, size.width, cardWidth);
        final row = index ~/ columns;
        final col = index % columns;

        // Calculate horizontal spacing to distribute cards evenly
        final horizontalMargin = cardWidth * 0.05;
        final availableWidth = size.width - (2 * horizontalMargin);
        final totalCardWidth = columns * cardWidth;
        final totalSpacing = availableWidth - totalCardWidth;
        final spacingBetweenCards = totalSpacing / (columns + 1);

        x = horizontalMargin + spacingBetweenCards + (col * (cardWidth + spacingBetweenCards)) + cardWidth / 2;
        y = row * verticalSpacing;
      }

      // Apply same bounds clamping as main screen (EXACT match)
      final horizontalMarginForClamping = cardWidth * 0.05;
      x = x.clamp(horizontalMarginForClamping + cardWidth / 2, size.width - horizontalMarginForClamping - cardWidth / 2);

      // Apply absolute positioning: EXACT match with main screen layout structure
      // Layout: padding + wallet cards + spacing + main treasury + spacing * 0.75 + sub-treasury relative Y
      final walletCardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);
      const mainTreasuryHeight = 180.0; // Actual main treasury height

      // Calculate sub-treasury container start position (matches main screen Column layout)
      final subTreasuryContainerStartY = padding + walletCardHeight + spacing + mainTreasuryHeight + (spacing * 0.75);

      // Add relative position within sub-treasury container + half card height for center point
      final subTreasuryAbsoluteY = subTreasuryContainerStartY + y + (cardHeight / 2);

      return Offset(x, subTreasuryAbsoluteY - scrollOffset);
    }
  }

  /// Get position for wallet summary cards using exact same layout as main screen
  /// This method calculates positions based on the Row layout used in the main screen
  Offset? _getWalletSummaryPosition(String walletId, Size size) {
    final isTablet = size.width > 768;
    final isDesktop = size.width > 1200;
    final spacing = _getResponsiveSpacingForPainter(isTablet, isDesktop);

    // Use exact same calculation as main screen _buildWalletSummaryCards
    // Wallet cards are positioned at the top with responsive padding
    final padding = isDesktop ? 32.0 : isTablet ? 24.0 : 16.0;

    // Calculate available width for wallet cards (accounting for padding)
    final availableWidth = size.width - (padding * 2);

    // Each wallet card takes half the available width with spacing between
    final cardWidth = (availableWidth - spacing) / 2;

    // Get actual wallet card height that matches the main screen
    final walletCardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);

    // Wallet summary Y position at top of layout with card center offset (half of actual card height)
    final walletSummaryY = padding + (walletCardHeight / 2) - scrollOffset;

    if (walletId == 'client_wallets') {
      // Client wallets: left side of the row
      final leftCardCenterX = padding + (cardWidth / 2);
      return Offset(leftCardCenterX, walletSummaryY);
    } else if (walletId == 'electronic_wallets') {
      // Electronic wallets: right side of the row
      final rightCardCenterX = padding + cardWidth + spacing + (cardWidth / 2);
      return Offset(rightCardCenterX, walletSummaryY);
    }

    return null;
  }

  /// Get responsive spacing for painter (matches main screen logic)
  double _getResponsiveSpacingForPainter(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return 40.0;
    } else if (isTablet) {
      return 30.0;
    } else {
      return 20.0;
    }
  }

  /// Calculate optimal columns for grid layout (matches main screen logic)
  int _calculateOptimalColumnsForPainter(int totalCount, double screenWidth, double cardWidth) {
    final horizontalMargin = cardWidth * 0.05;
    final availableWidth = screenWidth - (2 * horizontalMargin);

    // Calculate maximum possible columns based on screen width
    final maxColumns = (availableWidth / (cardWidth * 1.1)).floor(); // 1.1 for spacing

    // For different counts, choose optimal column layout
    if (totalCount <= 3) return totalCount;
    if (totalCount == 4) return 2;
    if (totalCount <= 6) return 3;
    if (totalCount <= 8) return 4;

    // For larger counts, use maximum columns but cap at 4 for readability
    return maxColumns.clamp(2, 4);
  }

  /// Get responsive card height for painter (matches main screen logic)
  double _getResponsiveCardHeightForPainter(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return 200.0; // Same as main screen
    } else if (isTablet) {
      return 180.0; // Same as main screen
    } else {
      return 160.0; // Same as main screen
    }
  }

  double _getCardWidthForPainter(double screenWidth, bool isTablet, bool isDesktop) {
    // Updated to match the increased card width percentages from main screen
    if (isDesktop) {
      return screenWidth * 0.28; // Increased from 22% to 28% to match main screen
    } else if (isTablet) {
      return screenWidth * 0.38; // Increased from 30% to 38% to match main screen
    } else {
      return screenWidth * 0.48; // Increased from 42% to 48% to match main screen
    }
  }

  /// Calculate intelligent routing path with collision avoidance
  List<Offset> _calculateIntelligentRoute(
    Offset start,
    Offset end,
    List<Rect> obstacles,
    int connectionIndex,
    Size size
  ) {
    // Calculate base routing path using exact connection points
    final baseRoute = _calculateAdvancedManhattanRoute(start, end, obstacles);

    // Apply collision avoidance with existing paths while preserving start/end points
    final optimizedRoute = _avoidExistingPathsPreservingEndpoints(baseRoute, connectionIndex, start, end);

    // Ensure the route always starts and ends at the exact connection points
    final finalRoute = _ensureExactEndpoints(optimizedRoute, start, end);

    return finalRoute;
  }

  /// Ensure the route starts and ends at exact connection points
  List<Offset> _ensureExactEndpoints(List<Offset> route, Offset exactStart, Offset exactEnd) {
    if (route.isEmpty) return [exactStart, exactEnd];

    final adjustedRoute = <Offset>[];

    // Always start with the exact connection point
    adjustedRoute.add(exactStart);

    // Add intermediate points (skip first and last if they exist)
    for (int i = 1; i < route.length - 1; i++) {
      adjustedRoute.add(route[i]);
    }

    // Always end with the exact connection point
    adjustedRoute.add(exactEnd);

    return adjustedRoute;
  }

  /// Create Path object from list of routing points
  Path _createPathFromPoints(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    return path;
  }

  /// Create professional Manhattan-style routing path with straight lines and 90-degree turns
  Path _createManhattanPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Get all card obstacles for intelligent routing
    final obstacles = _getAllCardObstacles(const Size(1000, 800)); // Use reasonable default size

    // Calculate optimal routing path avoiding obstacles
    final routingPoints = _calculateManhattanRoute(start, end, obstacles);

    // Create path with straight line segments
    for (final point in routingPoints) {
      path.lineTo(point.dx, point.dy);
    }

    return path;
  }

  /// Advanced Manhattan routing with intelligent path selection
  List<Offset> _calculateAdvancedManhattanRoute(Offset start, Offset end, List<Rect> obstacles) {
    // Try multiple routing strategies and select the best one
    final strategies = [
      () => _createHorizontalFirstRoute(start, end, obstacles),
      () => _createVerticalFirstRoute(start, end, obstacles),
      () => _createSteppedRoute(start, end, obstacles),
      () => _createPerimeterRoute(start, end, obstacles),
    ];

    List<Offset> bestRoute = [start, end];
    double bestScore = double.infinity;

    for (final strategy in strategies) {
      try {
        final route = strategy();
        final score = _evaluateRouteQuality(route, obstacles);
        if (score < bestScore) {
          bestScore = score;
          bestRoute = route;
        }
      } catch (e) {
        // Strategy failed, continue with next
        continue;
      }
    }

    return bestRoute;
  }

  /// Avoid collisions with existing connection paths while preserving exact endpoints
  List<Offset> _avoidExistingPathsPreservingEndpoints(
    List<Offset> baseRoute,
    int connectionIndex,
    Offset exactStart,
    Offset exactEnd
  ) {
    if (_existingPaths.isEmpty) return baseRoute;

    final adjustedRoute = <Offset>[];

    for (int i = 0; i < baseRoute.length; i++) {
      Offset point = baseRoute[i];

      // Preserve exact start and end points - never modify them
      if (i == 0) {
        adjustedRoute.add(exactStart);
        continue;
      }
      if (i == baseRoute.length - 1) {
        adjustedRoute.add(exactEnd);
        continue;
      }

      // Only adjust intermediate points for collision avoidance
      for (final existingPath in _existingPaths) {
        if (_pointNearPath(point, existingPath)) {
          // Adjust point to avoid collision
          point = _findAlternativePoint(point, existingPath, connectionIndex);
        }
      }

      adjustedRoute.add(point);
    }

    return adjustedRoute;
  }

  /// Avoid collisions with existing connection paths
  List<Offset> _avoidExistingPaths(List<Offset> baseRoute, int connectionIndex) {
    if (_existingPaths.isEmpty) return baseRoute;

    final adjustedRoute = <Offset>[];

    for (int i = 0; i < baseRoute.length; i++) {
      Offset point = baseRoute[i];

      // Check for collisions with existing paths
      for (final existingPath in _existingPaths) {
        if (_pointNearPath(point, existingPath)) {
          // Adjust point to avoid collision
          point = _findAlternativePoint(point, existingPath, connectionIndex);
        }
      }

      adjustedRoute.add(point);
    }

    return adjustedRoute;
  }

  /// Calculate Manhattan routing points that avoid card obstacles
  List<Offset> _calculateManhattanRoute(Offset start, Offset end, List<Rect> obstacles) {
    final routingPoints = <Offset>[];

    // Choose routing strategy based on layout hierarchy and distance
    if (_shouldUseHorizontalFirstRouting(start, end, obstacles)) {
      routingPoints.addAll(_createHorizontalFirstRoute(start, end, obstacles));
    } else {
      routingPoints.addAll(_createVerticalFirstRoute(start, end, obstacles));
    }

    return routingPoints;
  }

  /// Determine optimal routing strategy based on card positions and layout
  bool _shouldUseHorizontalFirstRouting(Offset start, Offset end, List<Rect> obstacles) {
    // For wallet-to-treasury connections, prefer vertical-first routing
    if (_isWalletToTreasuryConnection(start, end)) {
      return false;
    }

    // For treasury-to-treasury connections, prefer horizontal-first routing
    if (_isTreasuryToTreasuryConnection(start, end)) {
      return true;
    }

    // Default: choose based on distance ratio
    final horizontalDistance = (end.dx - start.dx).abs();
    final verticalDistance = (end.dy - start.dy).abs();
    return horizontalDistance > verticalDistance;
  }

  /// Create horizontal-first routing path (horizontal segment first, then vertical)
  List<Offset> _createHorizontalFirstRoute(Offset start, Offset end, List<Rect> obstacles) {
    final routingPoints = <Offset>[];

    // Always start with the exact start point
    routingPoints.add(start);

    // Calculate intermediate point for horizontal-first routing
    final intermediateY = _findOptimalHorizontalRoutingY(start, end, obstacles);
    final intermediatePoint = Offset(end.dx, intermediateY);

    // Add routing points only if they create meaningful segments
    if (intermediateY != start.dy) {
      routingPoints.add(Offset(start.dx, intermediateY));
    }
    if (intermediatePoint.dx != start.dx && intermediatePoint != routingPoints.last) {
      routingPoints.add(intermediatePoint);
    }

    // Always end with the exact end point
    if (end != routingPoints.last) {
      routingPoints.add(end);
    }

    return routingPoints;
  }

  /// Create vertical-first routing path (vertical segment first, then horizontal)
  List<Offset> _createVerticalFirstRoute(Offset start, Offset end, List<Rect> obstacles) {
    final routingPoints = <Offset>[];

    // Always start with the exact start point
    routingPoints.add(start);

    // Calculate intermediate point for vertical-first routing
    final intermediateX = _findOptimalVerticalRoutingX(start, end, obstacles);
    final intermediatePoint = Offset(intermediateX, end.dy);

    // Add routing points only if they create meaningful segments
    if (intermediateX != start.dx) {
      routingPoints.add(Offset(intermediateX, start.dy));
    }
    if (intermediatePoint.dy != start.dy && intermediatePoint != routingPoints.last) {
      routingPoints.add(intermediatePoint);
    }

    // Always end with the exact end point
    if (end != routingPoints.last) {
      routingPoints.add(end);
    }

    return routingPoints;
  }

  /// Find optimal Y coordinate for horizontal-first routing that avoids obstacles
  double _findOptimalHorizontalRoutingY(Offset start, Offset end, List<Rect> obstacles) {
    // Try direct horizontal routing first
    if (!_lineIntersectsObstacles(start, Offset(end.dx, start.dy), obstacles)) {
      return start.dy;
    }

    // Find alternative Y coordinate that avoids obstacles
    final candidateYs = _generateCandidateYCoordinates(start, end, obstacles);

    for (final y in candidateYs) {
      final horizontalSegment = Offset(end.dx, y);
      final verticalSegment1 = Offset(start.dx, y);
      final verticalSegment2 = Offset(end.dx, end.dy);

      if (!_lineIntersectsObstacles(start, verticalSegment1, obstacles) &&
          !_lineIntersectsObstacles(verticalSegment1, horizontalSegment, obstacles) &&
          !_lineIntersectsObstacles(horizontalSegment, verticalSegment2, obstacles)) {
        return y;
      }
    }

    // Fallback: use midpoint Y
    return (start.dy + end.dy) / 2;
  }

  /// Find optimal X coordinate for vertical-first routing that avoids obstacles
  double _findOptimalVerticalRoutingX(Offset start, Offset end, List<Rect> obstacles) {
    // Try direct vertical routing first
    if (!_lineIntersectsObstacles(start, Offset(start.dx, end.dy), obstacles)) {
      return start.dx;
    }

    // Find alternative X coordinate that avoids obstacles
    final candidateXs = _generateCandidateXCoordinates(start, end, obstacles);

    for (final x in candidateXs) {
      final verticalSegment = Offset(x, end.dy);
      final horizontalSegment1 = Offset(x, start.dy);
      final horizontalSegment2 = Offset(end.dx, end.dy);

      if (!_lineIntersectsObstacles(start, horizontalSegment1, obstacles) &&
          !_lineIntersectsObstacles(horizontalSegment1, verticalSegment, obstacles) &&
          !_lineIntersectsObstacles(verticalSegment, horizontalSegment2, obstacles)) {
        return x;
      }
    }

    // Fallback: use midpoint X
    return (start.dx + end.dx) / 2;
  }

  /// Get all card positions as obstacles for routing calculations
  List<Rect> _getAllCardObstacles(Size size) {
    final obstacles = <Rect>[];
    final isTablet = size.width > 768;
    final isDesktop = size.width > 1200;

    // Add wallet summary card obstacles
    obstacles.addAll(_getWalletSummaryObstacles(isTablet, isDesktop, size));

    // Add treasury card obstacles
    obstacles.addAll(_getTreasuryCardObstacles(isTablet, isDesktop, size));

    return obstacles;
  }

  /// Get wallet summary cards as obstacles
  List<Rect> _getWalletSummaryObstacles(bool isTablet, bool isDesktop, Size size) {
    final obstacles = <Rect>[];
    final cardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);

    // Calculate actual wallet card width (matches main screen layout)
    final padding = isDesktop ? 32.0 : isTablet ? 24.0 : 16.0;
    final spacing = _getResponsiveSpacingForPainter(isTablet, isDesktop);
    final availableWidth = size.width - (padding * 2);
    final cardWidth = (availableWidth - spacing) / 2;

    // Client wallets obstacle
    final clientWalletsPos = _getWalletSummaryPosition('client_wallets', size);
    if (clientWalletsPos != null) {
      obstacles.add(Rect.fromCenter(
        center: clientWalletsPos,
        width: cardWidth,
        height: cardHeight,
      ));
    }

    // Electronic wallets obstacle
    final electronicWalletsPos = _getWalletSummaryPosition('electronic_wallets', size);
    if (electronicWalletsPos != null) {
      obstacles.add(Rect.fromCenter(
        center: electronicWalletsPos,
        width: cardWidth,
        height: cardHeight,
      ));
    }

    return obstacles;
  }

  /// Get treasury cards as obstacles
  List<Rect> _getTreasuryCardObstacles(bool isTablet, bool isDesktop, Size size) {
    final obstacles = <Rect>[];

    for (final treasury in treasuries) {
      final position = _getTreasuryPosition(treasury, size);
      if (position != null) {
        double cardWidth, cardHeight;

        if (treasury.isMainTreasury) {
          // Main treasury card - use actual main treasury dimensions
          cardWidth = size.width * (isDesktop ? 0.7 : isTablet ? 0.8 : 0.9) - 32; // Account for margin
          cardHeight = 180.0; // Actual main treasury height
        } else {
          // Sub-treasury cards - use actual sub-treasury dimensions
          cardWidth = _getCardWidthForPainter(size.width, isTablet, isDesktop);
          cardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);
        }

        obstacles.add(Rect.fromCenter(
          center: position,
          width: cardWidth,
          height: cardHeight,
        ));
      }
    }

    return obstacles;
  }

  /// Check if connection is from wallet to treasury
  bool _isWalletToTreasuryConnection(Offset start, Offset end) {
    // Wallet cards are at Y=120, treasury cards are at Y>=280
    return (start.dy <= 150 && end.dy >= 250) || (start.dy >= 250 && end.dy <= 150);
  }

  /// Check if connection is between treasury cards
  bool _isTreasuryToTreasuryConnection(Offset start, Offset end) {
    // Both points are at treasury level (Y>=250)
    return start.dy >= 250 && end.dy >= 250;
  }

  /// Check if a line segment intersects with any obstacles
  bool _lineIntersectsObstacles(Offset start, Offset end, List<Rect> obstacles) {
    for (final obstacle in obstacles) {
      if (_lineIntersectsRect(start, end, obstacle)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a line segment intersects with a rectangle
  bool _lineIntersectsRect(Offset start, Offset end, Rect rect) {
    // Expand rect slightly to provide clearance around cards
    final expandedRect = rect.inflate(10.0);

    // Check if line endpoints are inside the rectangle
    if (expandedRect.contains(start) || expandedRect.contains(end)) {
      return true;
    }

    // Check line-rectangle intersection using parametric line equation
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    if (dx == 0 && dy == 0) return false; // Point, not a line

    // Calculate intersection parameters for each rectangle edge
    final tLeft = dx != 0 ? (expandedRect.left - start.dx) / dx : double.negativeInfinity;
    final tRight = dx != 0 ? (expandedRect.right - start.dx) / dx : double.infinity;
    final tTop = dy != 0 ? (expandedRect.top - start.dy) / dy : double.negativeInfinity;
    final tBottom = dy != 0 ? (expandedRect.bottom - start.dy) / dy : double.infinity;

    final tMin = [tLeft, tRight, tTop, tBottom].where((t) => t >= 0 && t <= 1).fold<double?>(null, (min, t) => min == null || t < min ? t : min);
    final tMax = [tLeft, tRight, tTop, tBottom].where((t) => t >= 0 && t <= 1).fold<double?>(null, (max, t) => max == null || t > max ? t : max);

    return tMin != null && tMax != null && tMin <= tMax;
  }

  /// Generate candidate Y coordinates for horizontal-first routing
  List<double> _generateCandidateYCoordinates(Offset start, Offset end, List<Rect> obstacles) {
    final candidates = <double>[];

    // Add key layout Y coordinates
    candidates.add(120.0); // Wallet summary level
    candidates.add(200.0); // Between wallets and main treasury
    candidates.add(280.0); // Main treasury level
    candidates.add(370.0); // Between main and sub-treasuries
    candidates.add(460.0); // Sub-treasury level

    // Add obstacle-based candidates (above and below each obstacle)
    for (final obstacle in obstacles) {
      candidates.add(obstacle.top - 20.0); // Above obstacle
      candidates.add(obstacle.bottom + 20.0); // Below obstacle
    }

    // Add start and end Y coordinates
    candidates.add(start.dy);
    candidates.add(end.dy);

    // Sort and filter valid candidates
    candidates.sort();
    return candidates.where((y) => y >= 50 && y <= 800).toList(); // Reasonable bounds
  }

  /// Generate candidate X coordinates for vertical-first routing
  List<double> _generateCandidateXCoordinates(Offset start, Offset end, List<Rect> obstacles) {
    final candidates = <double>[];

    // Add key layout X coordinates based on treasury positioning
    candidates.add(100.0); // Left margin
    candidates.add(200.0); // Left side positions
    candidates.add(400.0); // Center-left
    candidates.add(500.0); // Center
    candidates.add(600.0); // Center-right
    candidates.add(800.0); // Right side positions
    candidates.add(900.0); // Right margin

    // Add obstacle-based candidates (left and right of each obstacle)
    for (final obstacle in obstacles) {
      candidates.add(obstacle.left - 20.0); // Left of obstacle
      candidates.add(obstacle.right + 20.0); // Right of obstacle
    }

    // Add start and end X coordinates
    candidates.add(start.dx);
    candidates.add(end.dx);

    // Sort and filter valid candidates
    candidates.sort();
    return candidates.where((x) => x >= 50 && x <= 1000).toList(); // Reasonable bounds
  }

  /// Create stepped routing path for complex navigation
  List<Offset> _createSteppedRoute(Offset start, Offset end, List<Rect> obstacles) {
    final routingPoints = <Offset>[];

    // Always start with the exact start point
    routingPoints.add(start);

    // Create a stepped path that moves in small increments
    const steps = 3;
    final deltaX = (end.dx - start.dx) / steps;
    final deltaY = (end.dy - start.dy) / steps;

    for (int i = 1; i <= steps; i++) {
      final stepX = start.dx + (deltaX * i);
      final stepY = start.dy + (deltaY * i);

      // Alternate between horizontal and vertical movement
      if (i % 2 == 1) {
        routingPoints.add(Offset(stepX, start.dy + (deltaY * (i - 1))));
        routingPoints.add(Offset(stepX, stepY));
      } else {
        routingPoints.add(Offset(start.dx + (deltaX * (i - 1)), stepY));
        routingPoints.add(Offset(stepX, stepY));
      }
    }

    // Always end with the exact end point
    if (end != routingPoints.last) {
      routingPoints.add(end);
    }

    return routingPoints;
  }

  /// Create perimeter routing path that goes around obstacles
  List<Offset> _createPerimeterRoute(Offset start, Offset end, List<Rect> obstacles) {
    final routingPoints = <Offset>[];

    // Always start with the exact start point
    routingPoints.add(start);

    // Find the largest obstacle between start and end
    Rect? majorObstacle;
    for (final obstacle in obstacles) {
      if (_lineIntersectsRect(start, end, obstacle)) {
        majorObstacle = obstacle;
        break;
      }
    }

    if (majorObstacle != null) {
      // Route around the obstacle
      final goLeft = start.dx < majorObstacle.center.dx;
      if (goLeft) {
        routingPoints.add(Offset(majorObstacle.left - 20, start.dy));
        routingPoints.add(Offset(majorObstacle.left - 20, end.dy));
      } else {
        routingPoints.add(Offset(majorObstacle.right + 20, start.dy));
        routingPoints.add(Offset(majorObstacle.right + 20, end.dy));
      }
    }

    // Always end with the exact end point
    if (end != routingPoints.last) {
      routingPoints.add(end);
    }

    return routingPoints;
  }

  /// Evaluate the quality of a routing path
  double _evaluateRouteQuality(List<Offset> route, List<Rect> obstacles) {
    double score = 0.0;

    // Calculate total path length
    for (int i = 1; i < route.length; i++) {
      final distance = (route[i] - route[i - 1]).distance;
      score += distance;
    }

    // Penalize paths that go through obstacles
    for (int i = 1; i < route.length; i++) {
      if (_lineIntersectsObstacles(route[i - 1], route[i], obstacles)) {
        score += 1000.0; // Heavy penalty
      }
    }

    // Penalize paths with too many turns
    score += (route.length - 2) * 50.0;

    return score;
  }

  /// Check if a point is near an existing path
  bool _pointNearPath(Offset point, List<Offset> path) {
    const threshold = 25.0; // Minimum distance between paths

    for (int i = 1; i < path.length; i++) {
      final distance = _distanceFromPointToLineSegment(point, path[i - 1], path[i]);
      if (distance < threshold) {
        return true;
      }
    }

    return false;
  }

  /// Find alternative point to avoid collision
  Offset _findAlternativePoint(Offset original, List<Offset> existingPath, int connectionIndex) {
    const offsetDistance = 30.0;
    final offsets = [
      Offset(offsetDistance, 0),
      Offset(-offsetDistance, 0),
      Offset(0, offsetDistance),
      Offset(0, -offsetDistance),
    ];

    for (final offset in offsets) {
      final candidate = original + offset;
      if (!_pointNearPath(candidate, existingPath)) {
        return candidate;
      }
    }

    // Fallback: use connection index to create unique offset
    final uniqueOffset = connectionIndex * 15.0;
    return Offset(original.dx + uniqueOffset, original.dy);
  }

  /// Calculate distance from point to line segment
  double _distanceFromPointToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final A = point.dx - lineStart.dx;
    final B = point.dy - lineStart.dy;
    final C = lineEnd.dx - lineStart.dx;
    final D = lineEnd.dy - lineStart.dy;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) return (point - lineStart).distance;

    final param = dot / lenSq;

    Offset closestPoint;
    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = Offset(lineStart.dx + param * C, lineStart.dy + param * D);
    }

    return (point - closestPoint).distance;
  }

  /// Draw enhanced connection line with unique styling per connection
  void _drawEnhancedConnectionLine(Canvas canvas, Path path, int connectionIndex) {
    // Use different colors/styles for different connections to improve visibility
    final colors = [
      AccountantThemeConfig.primaryGreen,
      AccountantThemeConfig.accentBlue,
      AccountantThemeConfig.white70,
    ];

    final color = colors[connectionIndex % colors.length];

    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);

    // Draw main line
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, mainPaint);

    // Draw highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, highlightPaint);
  }

  /// Draw enhanced connection points with unique styling and clear attachment indicators
  void _drawEnhancedConnectionPoints(Canvas canvas, Offset start, Offset end, int connectionIndex) {
    final colors = [
      AccountantThemeConfig.primaryGreen,
      AccountantThemeConfig.accentBlue,
      AccountantThemeConfig.white70,
    ];

    final color = colors[connectionIndex % colors.length];

    // Draw connection points with enhanced visibility and card edge indicators
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final edgeIndicatorPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Start point with enhanced visibility and edge indicator
    canvas.drawCircle(start, 10.0, glowPaint);
    canvas.drawCircle(start, 5.0, pointPaint);
    canvas.drawCircle(start, 5.0, borderPaint);
    _drawCardEdgeIndicator(canvas, start, edgeIndicatorPaint);

    // End point with enhanced visibility and edge indicator
    canvas.drawCircle(end, 10.0, glowPaint);
    canvas.drawCircle(end, 5.0, pointPaint);
    canvas.drawCircle(end, 5.0, borderPaint);
    _drawCardEdgeIndicator(canvas, end, edgeIndicatorPaint);

    // Add directional indicator (small arrow pointing from source to target)
    _drawDirectionalIndicator(canvas, start, end, color);
  }

  /// Draw card edge indicator to show precise attachment point
  void _drawCardEdgeIndicator(Canvas canvas, Offset point, Paint paint) {
    // Draw small lines extending from the connection point to indicate card edge attachment
    const indicatorLength = 8.0;

    // Draw cross-hair pattern to indicate precise attachment
    canvas.drawLine(
      Offset(point.dx - indicatorLength, point.dy),
      Offset(point.dx + indicatorLength, point.dy),
      paint,
    );
    canvas.drawLine(
      Offset(point.dx, point.dy - indicatorLength),
      Offset(point.dx, point.dy + indicatorLength),
      paint,
    );
  }

  /// Draw directional indicator to show connection flow
  void _drawDirectionalIndicator(Canvas canvas, Offset start, Offset end, Color color) {
    final direction = (end - start).direction;
    final midPoint = Offset.lerp(start, end, 0.5)!;

    // Create small arrow pointing towards target
    final arrowSize = 8.0;
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(midPoint.dx, midPoint.dy);
    arrowPath.lineTo(
      midPoint.dx - arrowSize * math.cos(direction - math.pi / 6),
      midPoint.dy - arrowSize * math.sin(direction - math.pi / 6),
    );
    arrowPath.lineTo(
      midPoint.dx - arrowSize * math.cos(direction + math.pi / 6),
      midPoint.dy - arrowSize * math.sin(direction + math.pi / 6),
    );
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  /// Get optimized connection points for Manhattan routing
  OptimizedConnectionPoints _getOptimizedConnectionPoints(
    Offset sourceCenterPos,
    Offset targetCenterPos,
    ConnectionPoint sourceConnectionPoint,
    ConnectionPoint targetConnectionPoint,
    Size size,
  ) {
    // If connection points are already specified and not center, use them
    if (sourceConnectionPoint != ConnectionPoint.center &&
        targetConnectionPoint != ConnectionPoint.center) {
      return OptimizedConnectionPoints(
        sourcePoint: _getConnectionPointPosition(sourceCenterPos, sourceConnectionPoint, null, size),
        targetPoint: _getConnectionPointPosition(targetCenterPos, targetConnectionPoint, null, size),
        sourceConnectionPoint: sourceConnectionPoint,
        targetConnectionPoint: targetConnectionPoint,
      );
    }

    // Calculate optimal connection points based on Manhattan routing
    final optimalPoints = _calculateOptimalConnectionPoints(sourceCenterPos, targetCenterPos, size);

    return OptimizedConnectionPoints(
      sourcePoint: _getConnectionPointPosition(sourceCenterPos, optimalPoints.sourcePoint, null, size),
      targetPoint: _getConnectionPointPosition(targetCenterPos, optimalPoints.targetPoint, null, size),
      sourceConnectionPoint: optimalPoints.sourcePoint,
      targetConnectionPoint: optimalPoints.targetPoint,
    );
  }

  /// Calculate optimal connection points for Manhattan routing
  ({ConnectionPoint sourcePoint, ConnectionPoint targetPoint}) _calculateOptimalConnectionPoints(
    Offset sourceCenterPos,
    Offset targetCenterPos,
    Size size,
  ) {
    final dx = targetCenterPos.dx - sourceCenterPos.dx;
    final dy = targetCenterPos.dy - sourceCenterPos.dy;

    // Determine primary direction
    final isHorizontalPrimary = dx.abs() > dy.abs();

    ConnectionPoint sourcePoint;
    ConnectionPoint targetPoint;

    if (isHorizontalPrimary) {
      // Horizontal movement is primary
      if (dx > 0) {
        // Moving right
        sourcePoint = ConnectionPoint.right;
        targetPoint = ConnectionPoint.left;
      } else {
        // Moving left
        sourcePoint = ConnectionPoint.left;
        targetPoint = ConnectionPoint.right;
      }
    } else {
      // Vertical movement is primary
      if (dy > 0) {
        // Moving down
        sourcePoint = ConnectionPoint.bottom;
        targetPoint = ConnectionPoint.top;
      } else {
        // Moving up
        sourcePoint = ConnectionPoint.top;
        targetPoint = ConnectionPoint.bottom;
      }
    }

    // Check for special cases based on layout hierarchy
    sourcePoint = _adjustConnectionPointForLayout(sourceCenterPos, targetCenterPos, sourcePoint, true);
    targetPoint = _adjustConnectionPointForLayout(targetCenterPos, sourceCenterPos, targetPoint, false);

    return (sourcePoint: sourcePoint, targetPoint: targetPoint);
  }

  /// Adjust connection point based on layout hierarchy and card positioning
  ConnectionPoint _adjustConnectionPointForLayout(
    Offset cardPos,
    Offset otherCardPos,
    ConnectionPoint suggestedPoint,
    bool isSource,
  ) {
    // Wallet summary cards (Y ≈ 120) should prefer bottom connections when connecting down
    if (cardPos.dy <= 150 && otherCardPos.dy > 200) {
      return ConnectionPoint.bottom;
    }

    // Main treasury (Y ≈ 280) should prefer top when connecting to wallets, bottom when connecting to sub-treasuries
    if (cardPos.dy >= 250 && cardPos.dy <= 320) {
      if (otherCardPos.dy <= 150) {
        return ConnectionPoint.top; // Connecting to wallet above
      } else if (otherCardPos.dy > 400) {
        return ConnectionPoint.bottom; // Connecting to sub-treasury below
      }
    }

    // Sub-treasuries (Y ≥ 460) should prefer top connections when connecting up
    if (cardPos.dy >= 400 && otherCardPos.dy < 400) {
      return ConnectionPoint.top;
    }

    // For horizontal connections at same level, use left/right based on position
    if ((cardPos.dy - otherCardPos.dy).abs() < 50) {
      if (cardPos.dx < otherCardPos.dx) {
        return ConnectionPoint.right; // Connect to the right
      } else {
        return ConnectionPoint.left; // Connect to the left
      }
    }

    return suggestedPoint; // Use suggested point if no special case applies
  }

  void _drawConnectionLine(Canvas canvas, Path path) {
    // Draw enhanced tree-like connection with multiple layers
    _drawConnectionGlow(canvas, path);
    _drawMainConnectionLine(canvas, path);
    _drawConnectionHighlight(canvas, path);
  }

  void _drawConnectionGlow(Canvas canvas, Path path) {
    // Outer glow for depth
    final outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..color = AccountantThemeConfig.primaryGreen.withValues(alpha: 0.15 * connectionAnimation)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawPath(path, outerGlowPaint);

    // Inner glow for warmth
    final innerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..color = AccountantThemeConfig.primaryGreen.withValues(alpha: 0.25 * connectionAnimation)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(path, innerGlowPaint);
  }

  void _drawMainConnectionLine(Canvas canvas, Path path) {
    // Create enhanced gradient paint
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Create gradient shader with more sophisticated colors
    final pathMetrics = path.computeMetrics().first;
    final startPoint = pathMetrics.getTangentForOffset(0)!.position;
    final endPoint = pathMetrics.getTangentForOffset(pathMetrics.length)!.position;

    paint.shader = ui.Gradient.linear(
      startPoint,
      endPoint,
      [
        AccountantThemeConfig.primaryGreen,
        AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
        AccountantThemeConfig.accentBlue.withValues(alpha: 0.9),
        AccountantThemeConfig.accentBlue,
      ],
      [0.0, 0.3, 0.7, 1.0],
    );

    // Draw main line
    canvas.drawPath(path, paint);
  }

  void _drawConnectionHighlight(Canvas canvas, Path path) {
    // Add animated highlight for professional effect
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.4 * connectionAnimation);

    canvas.drawPath(path, highlightPaint);
  }



  void _drawConnectionPoints(Canvas canvas, Offset start, Offset end) {
    final pointPaint = Paint()
      ..color = AccountantThemeConfig.primaryGreen
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = AccountantThemeConfig.primaryGreen.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Draw connection points with pulsing effect
    final pulseRadius = 6.0 + (2.0 * math.sin(connectionAnimation * 2 * math.pi));

    // Start point
    canvas.drawCircle(start, pulseRadius, glowPaint);
    canvas.drawCircle(start, 4.0, pointPaint);

    // End point
    canvas.drawCircle(end, pulseRadius, glowPaint);
    canvas.drawCircle(end, 4.0, pointPaint);
  }

  void _drawPotentialConnectionLine(Canvas canvas, Offset start, Offset end) {
    final path = _createManhattanPath(start, end);

    // Draw dashed line
    final paint = Paint()
      ..color = AccountantThemeConfig.white60
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    _drawDashedPath(canvas, path, paint, 5.0, 5.0);

    // Draw potential connection points
    final pointPaint = Paint()
      ..color = AccountantThemeConfig.white60
      ..style = PaintingStyle.fill;

    canvas.drawCircle(start, 3.0, pointPaint);
    canvas.drawCircle(end, 3.0, pointPaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    final pathMetrics = path.computeMetrics();
    
    for (final pathMetric in pathMetrics) {
      double distance = 0.0;
      bool draw = true;
      
      while (distance < pathMetric.length) {
        final length = draw ? dashWidth : dashSpace;
        final nextDistance = math.min(distance + length, pathMetric.length);
        
        if (draw) {
          final extractPath = pathMetric.extractPath(distance, nextDistance);
          canvas.drawPath(extractPath, paint);
        }
        
        distance = nextDistance;
        draw = !draw;
      }
    }
  }

  bool _canConnect(String sourceTreasuryId, String targetTreasuryId) {
    // Check if connection already exists
    final existingConnection = connections.any((connection) =>
        (connection.sourceTreasuryId == sourceTreasuryId && connection.targetTreasuryId == targetTreasuryId) ||
        (connection.sourceTreasuryId == targetTreasuryId && connection.targetTreasuryId == sourceTreasuryId));

    if (existingConnection) return false;

    // Check connection limits (max 2 connections per treasury)
    final sourceConnections = connections.where((connection) =>
        connection.sourceTreasuryId == sourceTreasuryId || connection.targetTreasuryId == sourceTreasuryId).length;

    final targetConnections = connections.where((connection) =>
        connection.sourceTreasuryId == targetTreasuryId || connection.targetTreasuryId == targetTreasuryId).length;

    return sourceConnections < 2 && targetConnections < 2;
  }

  /// Calculate connection point position based on selected connection point
  Offset _getConnectionPointPosition(
    Offset centerPos,
    ConnectionPoint connectionPoint,
    TreasuryVault? treasury,
    Size size,
  ) {
    // Get card dimensions that match actual rendered cards
    final isTablet = size.width > 768;
    final isDesktop = size.width > 1200;

    // Use different dimensions based on card type for precise attachment
    double cardWidth, cardHeight;

    // Determine card type based on calculated position ranges (more accurate than hardcoded values)
    final padding = isDesktop ? 32.0 : isTablet ? 24.0 : 16.0;
    final spacing = _getResponsiveSpacingForPainter(isTablet, isDesktop);
    final walletCardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);

    // Calculate position boundaries dynamically
    final walletAreaMaxY = padding + walletCardHeight + scrollOffset;
    final mainTreasuryStartY = padding + walletCardHeight + spacing - scrollOffset;
    final mainTreasuryEndY = mainTreasuryStartY + 180.0; // Main treasury height

    if (centerPos.dy + scrollOffset <= walletAreaMaxY) {
      // Wallet summary cards - use actual wallet card dimensions
      final availableWidth = size.width - (padding * 2);
      cardWidth = (availableWidth - spacing) / 2;
      cardHeight = walletCardHeight;
    } else if (centerPos.dy >= mainTreasuryStartY && centerPos.dy <= mainTreasuryEndY) {
      // Main treasury card - use actual main treasury dimensions
      cardWidth = size.width * (isDesktop ? 0.7 : isTablet ? 0.8 : 0.9) - 32; // Account for margin
      cardHeight = 180.0; // Actual main treasury height
    } else {
      // Sub-treasury cards - use actual sub-treasury dimensions
      cardWidth = _getCardWidthForPainter(size.width, isTablet, isDesktop);
      cardHeight = _getResponsiveCardHeightForPainter(isTablet, isDesktop);
    }

    // Calculate precise offset from center based on connection point
    // Add small inset to ensure visual attachment to card edge
    const edgeInset = 2.0; // Small inset for better visual attachment

    switch (connectionPoint) {
      case ConnectionPoint.top:
        return Offset(centerPos.dx, centerPos.dy - cardHeight / 2 + edgeInset);
      case ConnectionPoint.bottom:
        return Offset(centerPos.dx, centerPos.dy + cardHeight / 2 - edgeInset);
      case ConnectionPoint.left:
        return Offset(centerPos.dx - cardWidth / 2 + edgeInset, centerPos.dy);
      case ConnectionPoint.right:
        return Offset(centerPos.dx + cardWidth / 2 - edgeInset, centerPos.dy);
      case ConnectionPoint.center:
        return centerPos;
    }
  }

  /// Draw flowing particles with directional colors
  void _drawDirectionalFlowingParticles(
    Canvas canvas,
    Path path,
    TreasuryConnection connection,
  ) {
    final pathMetrics = path.computeMetrics().first;
    final pathLength = pathMetrics.length;

    // Determine flow direction and color
    final targetTreasury = treasuries.firstWhere(
      (t) => t.id == connection.targetTreasuryId,
    );

    // Incoming flow (to main treasury) = green, Outgoing flow (from main treasury) = red
    final isIncomingFlow = targetTreasury.isMainTreasury;
    final particleColor = isIncomingFlow
        ? AccountantThemeConfig.primaryGreen
        : Colors.red;

    final particlePaint = Paint()
      ..color = particleColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = particleColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    // Draw multiple particles along the path
    for (int i = 0; i < 3; i++) {
      final progress = ((particleAnimation + (i * 0.33)) % 1.0);
      final distance = progress * pathLength;

      final tangent = pathMetrics.getTangentForOffset(distance);
      if (tangent != null) {
        final position = tangent.position;

        // Draw glow effect
        canvas.drawCircle(position, 6.0, glowPaint);

        // Draw particle
        canvas.drawCircle(position, 3.0, particlePaint);

        // Draw directional arrow
        _drawDirectionalArrow(canvas, position, tangent.angle, particleColor);
      }
    }
  }

  /// Draw directional arrow to indicate flow direction
  void _drawDirectionalArrow(
    Canvas canvas,
    Offset position,
    double angle,
    Color color,
  ) {
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    const arrowSize = 8.0;
    final arrowPath = Path();

    // Create arrow shape
    arrowPath.moveTo(arrowSize, 0);
    arrowPath.lineTo(-arrowSize / 2, -arrowSize / 2);
    arrowPath.lineTo(-arrowSize / 2, arrowSize / 2);
    arrowPath.close();

    // Transform and draw arrow
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);
    canvas.drawPath(arrowPath, arrowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TreasuryConnectionPainter oldDelegate) {
    return oldDelegate.connectionAnimation != connectionAnimation ||
           oldDelegate.particleAnimation != particleAnimation ||
           oldDelegate.isConnectionMode != isConnectionMode ||
           oldDelegate.selectedTreasuryId != selectedTreasuryId ||
           oldDelegate.scrollOffset != scrollOffset ||
           oldDelegate.connections.length != connections.length ||
           oldDelegate.treasuries.length != treasuries.length;
  }
}
