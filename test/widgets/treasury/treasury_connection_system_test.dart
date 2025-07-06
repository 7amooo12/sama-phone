import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/widgets/treasury/treasury_connection_painter.dart';
import '../../../lib/models/treasury_models.dart';

void main() {
  group('Treasury Connection System Tests', () {
    late List<TreasuryVault> mockTreasuries;
    late List<TreasuryConnection> mockConnections;

    setUp(() {
      // Create mock treasury vaults
      mockTreasuries = [
        TreasuryVault(
          id: 'main_treasury',
          name: 'Main Treasury',
          currency: 'EGP',
          currencySymbol: 'ج.م',
          currencyFlag: '🇪🇬',
          balance: 50000.0,
          exchangeRateToEgp: 1.0,
          isMainTreasury: true,
        ),
        TreasuryVault(
          id: 'sub_treasury_1',
          name: 'Sub Treasury 1',
          currency: 'USD',
          currencySymbol: '\$',
          currencyFlag: '🇺🇸',
          balance: 1000.0,
          exchangeRateToEgp: 30.0,
          isMainTreasury: false,
        ),
      ];

      // Create mock connections
      mockConnections = [
        TreasuryConnection(
          id: 'connection_1',
          sourceTreasuryId: 'main_treasury',
          targetTreasuryId: 'sub_treasury_1',
          connectionAmount: 1000.0,
          exchangeRateUsed: 30.0,
          createdAt: DateTime.now(),
          sourceConnectionPoint: ConnectionPoint.bottom,
          targetConnectionPoint: ConnectionPoint.top,
        ),
      ];
    });

    group('Connection System Validation', () {
      test('TreasuryConnectionPainter can be instantiated', () {
        final painter = TreasuryConnectionPainter(
          treasuries: mockTreasuries,
          connections: mockConnections,
          connectionAnimation: 1.0,
          particleAnimation: 0.0,
          isConnectionMode: false,
          scrollOffset: 0.0,
        );

        expect(painter.runtimeType, TreasuryConnectionPainter);
      });

      test('Connection data is properly structured', () {
        expect(mockConnections.length, 1);
        expect(mockConnections.first.sourceTreasuryId, 'main_treasury');
        expect(mockConnections.first.targetTreasuryId, 'sub_treasury_1');
        expect(mockConnections.first.sourceConnectionPoint, ConnectionPoint.bottom);
        expect(mockConnections.first.targetConnectionPoint, ConnectionPoint.top);
      });

      test('Treasury data is properly structured', () {
        expect(mockTreasuries.length, 2);

        final mainTreasury = mockTreasuries.firstWhere((t) => t.isMainTreasury);
        expect(mainTreasury.id, 'main_treasury');
        expect(mainTreasury.isMainTreasury, true);

        final subTreasury = mockTreasuries.firstWhere((t) => !t.isMainTreasury);
        expect(subTreasury.id, 'sub_treasury_1');
        expect(subTreasury.isMainTreasury, false);
      });
    });

    group('Connection System Integration', () {
      test('Painter handles empty connections gracefully', () {
        final painter = TreasuryConnectionPainter(
          treasuries: mockTreasuries,
          connections: [], // Empty connections
          connectionAnimation: 1.0,
          particleAnimation: 0.0,
          isConnectionMode: false,
          scrollOffset: 0.0,
        );

        expect(painter.runtimeType, TreasuryConnectionPainter);
      });

      test('Painter handles connection mode correctly', () {
        final painter = TreasuryConnectionPainter(
          treasuries: mockTreasuries,
          connections: mockConnections,
          connectionAnimation: 1.0,
          particleAnimation: 0.0,
          isConnectionMode: true,
          selectedTreasuryId: 'main_treasury',
          scrollOffset: 0.0,
        );

        expect(painter.runtimeType, TreasuryConnectionPainter);
      });

      test('Connection points enum values are valid', () {
        expect(ConnectionPoint.values.length, 5);
        expect(ConnectionPoint.values.contains(ConnectionPoint.top), true);
        expect(ConnectionPoint.values.contains(ConnectionPoint.bottom), true);
        expect(ConnectionPoint.values.contains(ConnectionPoint.left), true);
        expect(ConnectionPoint.values.contains(ConnectionPoint.right), true);
        expect(ConnectionPoint.values.contains(ConnectionPoint.center), true);
      });
    });
  });
}
