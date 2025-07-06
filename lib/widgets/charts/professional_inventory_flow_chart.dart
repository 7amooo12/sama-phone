import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../models/product_movement_model.dart';

/// Professional inventory flow chart widget using fl_chart
/// Features responsive design, interactive tooltips, and professional styling
class ProfessionalInventoryFlowChart extends StatefulWidget {
  final ProductMovementModel productMovement;
  final double? height;
  final bool showLegend;
  final bool enableInteraction;
  final VoidCallback? onChartTap;

  const ProfessionalInventoryFlowChart({
    super.key,
    required this.productMovement,
    this.height,
    this.showLegend = true,
    this.enableInteraction = true,
    this.onChartTap,
  });

  @override
  State<ProfessionalInventoryFlowChart> createState() => _ProfessionalInventoryFlowChartState();
}

class _ProfessionalInventoryFlowChartState extends State<ProfessionalInventoryFlowChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  int? _touchedIndex;
  Map<DateTime, double> _inventoryFlow = {};
  Map<DateTime, Map<String, dynamic>> _dataPointInfo = {}; // Store customer info for each data point
  double _maxValue = 0;
  double _minValue = 0;
  bool _isZoomed = false;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _calculateInventoryFlow();
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Calculate opening balance by working backwards from current stock through sales history
  /// This represents the actual starting inventory before any sales transactions occurred
  int _calculateOpeningBalance() {
    try {
      final movementData = widget.productMovement.movementData;
      final salesData = widget.productMovement.salesData;
      final currentStock = widget.productMovement.statistics.currentStock;

      AppLogger.info('🔍 DEBUG: بدء حساب الرصيد الافتتاحي');
      AppLogger.info('🔍 DEBUG: المخزون الحالي: $currentStock');
      AppLogger.info('🔍 DEBUG: عدد حركات المخزون: ${movementData.length}');
      AppLogger.info('🔍 DEBUG: عدد المبيعات: ${salesData.length}');

      if (salesData.isEmpty) {
        // If no sales transactions, opening balance equals current stock
        AppLogger.info('🔍 DEBUG: لا توجد مبيعات - الرصيد الافتتاحي = المخزون الحالي: $currentStock');
        return currentStock;
      }

      // FIXED APPROACH: Calculate opening balance by adding back all sales to current stock
      // This represents the stock level before any sales occurred
      // Formula: Opening Balance = Current Stock + Total Sales
      // This eliminates the double-counting issue and provides the actual starting inventory

      final totalSoldQuantity = widget.productMovement.statistics.totalSoldQuantity;

      // Simple and correct calculation: add back all sales to get the original stock level
      final openingBalance = currentStock + totalSoldQuantity;

      AppLogger.info('� DEBUG: حساب الرصيد الافتتاحي:');
      AppLogger.info('🔍 DEBUG: المخزون الحالي: $currentStock');
      AppLogger.info('🔍 DEBUG: إجمالي المبيعات: $totalSoldQuantity');
      AppLogger.info('🔍 DEBUG: الرصيد الافتتاحي = $currentStock + $totalSoldQuantity = $openingBalance');

      // Validation: The chart should flow from opening balance → through sales → to current stock
      AppLogger.info('🔍 DEBUG: التحقق من التدفق المنطقي:');
      AppLogger.info('🔍 DEBUG: البداية: $openingBalance وحدة');
      AppLogger.info('🔍 DEBUG: بعد بيع $totalSoldQuantity وحدة: ${openingBalance - totalSoldQuantity} وحدة');
      AppLogger.info('🔍 DEBUG: النهاية (المخزون الحالي): $currentStock وحدة');

      if ((openingBalance - totalSoldQuantity) == currentStock) {
        AppLogger.info('✅ DEBUG: التدفق المنطقي صحيح!');
      } else {
        AppLogger.warning('⚠️ DEBUG: خطأ في التدفق المنطقي!');
      }

      // Ensure opening balance is not negative
      return openingBalance > 0 ? openingBalance : currentStock;
    } catch (e) {
      AppLogger.error('❌ خطأ في حساب الرصيد الافتتاحي: $e');
      // Fallback to current stock if calculation fails
      return widget.productMovement.statistics.currentStock;
    }
  }

  /// Calculate inventory flow over time from movement and sales data
  void _calculateInventoryFlow() {
    try {
      final movementData = widget.productMovement.movementData;
      final salesData = widget.productMovement.salesData;
      final currentStock = widget.productMovement.statistics.currentStock;
      final totalSoldQuantity = widget.productMovement.statistics.totalSoldQuantity;

      AppLogger.info('🔄 بدء حساب تدفق المخزون - المخزون الحالي: $currentStock، إجمالي المبيعات: $totalSoldQuantity');
      AppLogger.info('📊 عدد حركات المخزون: ${movementData.length}، عدد المبيعات: ${salesData.length}');

      // CRITICAL DEBUG: Investigate sales data truncation issue
      AppLogger.info('🔍 CRITICAL DEBUG: تحليل بيانات المبيعات الكاملة:');
      AppLogger.info('🔍 CRITICAL DEBUG: عدد المبيعات في salesData: ${salesData.length}');
      AppLogger.info('🔍 CRITICAL DEBUG: إجمالي المبيعات من الإحصائيات: $totalSoldQuantity');

      if (salesData.length < 10) {
        AppLogger.warning('⚠️ CRITICAL: عدد المبيعات قليل جداً! هل يتم عرض جميع المبيعات؟');
        AppLogger.warning('⚠️ CRITICAL: المتوقع: جميع المبيعات، الفعلي: ${salesData.length} مبيعات فقط');
      }

      // Log all sales data to verify completeness
      AppLogger.info('🔍 CRITICAL DEBUG: تفاصيل جميع المبيعات:');
      for (int i = 0; i < salesData.length; i++) {
        final sale = salesData[i];
        AppLogger.info('🔍 CRITICAL DEBUG: مبيعة ${i + 1}/${salesData.length}: التاريخ=${sale.saleDate}, الكمية=${sale.quantity}, العميل=${sale.customerName}, الفاتورة=${sale.invoiceId}');
      }

      // Data validation
      assert(currentStock >= 0, 'Current stock cannot be negative: $currentStock');
      assert(totalSoldQuantity >= 0, 'Total sold quantity cannot be negative: $totalSoldQuantity');

      // Calculate opening balance using the same method as comprehensive reports
      final openingBalance = _calculateOpeningBalance();
      AppLogger.info('📊 الرصيد الافتتاحي المحسوب: $openingBalance');

      // Additional validation for expected values
      AppLogger.info('🔍 DEBUG: التحقق النهائي من القيم:');
      AppLogger.info('🔍 DEBUG: المخزون الحالي من الإحصائيات: ${widget.productMovement.statistics.currentStock}');
      AppLogger.info('🔍 DEBUG: إجمالي المبيعات من الإحصائيات: ${widget.productMovement.statistics.totalSoldQuantity}');
      AppLogger.info('🔍 DEBUG: الرصيد الافتتاحي المحسوب: $openingBalance');

      if (widget.productMovement.statistics.currentStock == 49 &&
          widget.productMovement.statistics.totalSoldQuantity == 11 &&
          openingBalance != 60) {
        AppLogger.error('❌ DEBUG: خطأ في حساب الرصيد الافتتاحي! المتوقع: 60, الفعلي: $openingBalance');
      }

      // CRITICAL FIX: Focus only on sales transactions for data points
      // Based on user requirements: "Only create data points when an actual sales transaction occurred"
      AppLogger.info('🔍 CRITICAL FIX: إنشاء نقاط البيانات للمبيعات فقط');

      // Create transactions list with only sales (no stock movements for chart points)
      final salesTransactions = <Map<String, dynamic>>[];

      // Add only sales transactions ('بيع') - these are the only ones that should create data points
      AppLogger.info('� CRITICAL FIX: معالجة جميع المبيعات:');
      for (int i = 0; i < salesData.length; i++) {
        final sale = salesData[i];
        salesTransactions.add({
          'date': sale.saleDate,
          'quantity': sale.quantity,
          'type': 'بيع', // Sale type
          'customer': sale.customerName,
          'invoiceId': sale.invoiceId,
          'index': i + 1, // For tracking
        });
        AppLogger.info('� CRITICAL FIX: مبيعة ${i + 1}/${salesData.length}: ${sale.saleDate} - ${sale.quantity} - ${sale.customerName} - فاتورة ${sale.invoiceId}');
      }

      // Sort sales by date chronologically
      salesTransactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      AppLogger.info('🔍 CRITICAL FIX: إجمالي المبيعات المرتبة: ${salesTransactions.length}');
      AppLogger.info('🔍 CRITICAL FIX: التحقق من اكتمال البيانات:');
      AppLogger.info('🔍 CRITICAL FIX: عدد المبيعات الأصلي: ${salesData.length}');
      AppLogger.info('🔍 CRITICAL FIX: عدد المبيعات المعالجة: ${salesTransactions.length}');

      if (salesTransactions.length != salesData.length) {
        AppLogger.error('❌ CRITICAL ERROR: فقدان بيانات المبيعات أثناء المعالجة!');
      }

      final flow = <DateTime, double>{};
      final dataPointInfo = <DateTime, Map<String, dynamic>>{};

      // CRITICAL FIX: Use the same logic as comprehensive reports
      // Start with opening balance as the first data point
      double runningBalance = openingBalance.toDouble();

      if (salesTransactions.isEmpty) {
        // If no sales transactions, show current stock at the date of the last purchase
        // Determine the end date based on the last purchase transaction
        DateTime endDate;
        if (movementData.isNotEmpty) {
          // Find the most recent purchase transaction
          final sortedMovements = movementData.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          endDate = sortedMovements.first.createdAt;
        } else {
          // No purchases - use current time as fallback
          endDate = DateTime.now();
        }
        flow[endDate] = currentStock.toDouble();
        dataPointInfo[endDate] = {
          'type': 'current_stock',
          'label': 'المخزون الحالي',
          'quantity': currentStock,
        };
        AppLogger.info('� لا توجد مبيعات - عرض المخزون الحالي فقط: $currentStock');
      } else {
        // Add opening balance as first data point (before any sales)
        final firstTransactionDate = salesTransactions.first['date'] as DateTime;
        // Use a date slightly before the first transaction for opening balance
        final openingDate = firstTransactionDate.subtract(const Duration(hours: 1));
        flow[openingDate] = runningBalance;
        dataPointInfo[openingDate] = {
          'type': 'opening_balance',
          'label': 'الرصيد الافتتاحي',
          'quantity': runningBalance.toInt(),
        };
        AppLogger.info('📈 نقطة البداية (الرصيد الافتتاحي): ${DateFormat('yyyy-MM-dd HH:mm').format(openingDate)} - الرصيد: ${runningBalance.toInt()}');

        // CRITICAL FIX: Process only sales transactions for data points
        // Stock movements don't create chart points, only affect the opening balance calculation
        AppLogger.info('🔍 CRITICAL FIX: معالجة المبيعات لإنشاء نقاط البيانات:');

        for (int i = 0; i < salesTransactions.length; i++) {
          final sale = salesTransactions[i];
          final date = sale['date'] as DateTime;
          final quantity = (sale['quantity'] as int).toDouble();
          final customer = sale['customer'] as String;
          final invoiceId = sale['invoiceId'] as int;
          final index = sale['index'] as int;

          // Sales transaction - decrease from running balance
          runningBalance -= quantity;

          // Add data point AFTER the sale (showing the result)
          flow[date] = runningBalance;

          // Store customer information for this data point
          dataPointInfo[date] = {
            'type': 'sale',
            'customer': customer,
            'quantity': quantity.toInt(),
            'invoiceId': invoiceId,
            'label': 'بيع للعميل: $customer',
          };

          AppLogger.info('📈 CRITICAL FIX: نقطة بيانات ${i + 1}/${salesTransactions.length}: ${DateFormat('yyyy-MM-dd HH:mm').format(date)} - مبيعة للعميل: $customer - الكمية: $quantity - الرصيد بعد البيع: ${runningBalance.toInt()} - فاتورة: $invoiceId');
        }

        AppLogger.info('🔍 CRITICAL FIX: تم إنشاء ${flow.length} نقطة بيانات (الرصيد الافتتاحي + ${salesTransactions.length} مبيعة)');
      }

      _inventoryFlow = flow;
      _dataPointInfo = dataPointInfo;

      // Log customer information for debugging
      AppLogger.info('🔍 معلومات العملاء في نقاط البيانات:');
      dataPointInfo.forEach((date, info) {
        if (info['type'] == 'sale') {
          AppLogger.info('📅 ${DateFormat('yyyy-MM-dd HH:mm').format(date)}: العميل ${info['customer']} - ${info['quantity']} قطعة');
        }
      });

      // CRITICAL VALIDATION: Check if final balance matches current stock (with tolerance)
      if (salesTransactions.isNotEmpty) {
        final sortedFlow = flow.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        final finalBalance = sortedFlow.isNotEmpty ? sortedFlow.last.value : openingBalance.toDouble();
        final balanceDifference = (finalBalance - currentStock).abs();

        AppLogger.info('🔍 CRITICAL VALIDATION: التحقق من صحة الحسابات:');
        AppLogger.info('🔍 CRITICAL VALIDATION: الرصيد النهائي المحسوب: ${finalBalance.toInt()}');
        AppLogger.info('🔍 CRITICAL VALIDATION: المخزون الحالي الفعلي: $currentStock');
        AppLogger.info('🔍 CRITICAL VALIDATION: الفرق: ${balanceDifference.toInt()}');

        if (balanceDifference > 1) {
          AppLogger.warning('⚠️ CRITICAL WARNING: عدم تطابق الرصيد النهائي! المحسوب=$finalBalance, الفعلي=$currentStock, الفرق=$balanceDifference');
        } else {
          AppLogger.info('✅ CRITICAL SUCCESS: تطابق الرصيد النهائي! المحسوب=${finalBalance.toInt()}, الفعلي=$currentStock');
        }

        // Log all calculated flow points for debugging
        AppLogger.info('� CRITICAL VALIDATION: جميع نقاط التدفق المحسوبة:');
        for (int i = 0; i < sortedFlow.length; i++) {
          final entry = sortedFlow[i];
          final isOpening = i == 0;
          final pointType = isOpening ? '(الرصيد الافتتاحي)' : '(بعد مبيعة ${i})';
          AppLogger.info('� CRITICAL VALIDATION: نقطة ${i + 1}/${sortedFlow.length}: ${DateFormat('yyyy-MM-dd HH:mm').format(entry.key)} - الرصيد: ${entry.value.toInt()} $pointType');
        }

        AppLogger.info('🔍 CRITICAL VALIDATION: ملخص النتائج:');
        AppLogger.info('🔍 CRITICAL VALIDATION: عدد نقاط البيانات: ${flow.length}');
        AppLogger.info('🔍 CRITICAL VALIDATION: عدد المبيعات: ${salesTransactions.length}');
        AppLogger.info('🔍 CRITICAL VALIDATION: المتوقع: ${salesTransactions.length + 1} نقطة (الرصيد الافتتاحي + المبيعات)');

        if (flow.length != salesTransactions.length + 1) {
          AppLogger.error('❌ CRITICAL ERROR: عدد نقاط البيانات غير صحيح! المتوقع: ${salesTransactions.length + 1}, الفعلي: ${flow.length}');
        }
      }

      // Validate the calculated flow data
      _validateInventoryFlow();

      // CRITICAL FIX: Calculate correct maximum Y-axis value using memory formula
      // Formula: maxValue = currentStock + totalSoldQuantity (theoretical maximum if no sales occurred)
      final theoreticalMaxStock = currentStock + totalSoldQuantity;
      AppLogger.info('📊 الحد الأقصى النظري للمخزون: $theoreticalMaxStock (المخزون الحالي: $currentStock + إجمالي المبيعات: $totalSoldQuantity)');

      // Calculate min/max values with proper business logic
      if (_inventoryFlow.isNotEmpty) {
        final values = _inventoryFlow.values.toList();
        final actualMinValue = values.reduce((a, b) => a < b ? a : b);
        final actualMaxValue = values.reduce((a, b) => a > b ? a : b);

        // Use the higher of actual max or theoretical max for better visualization
        final businessMaxValue = [actualMaxValue, theoreticalMaxStock.toDouble()].reduce((a, b) => a > b ? a : b);

        // Set min value (never below 0)
        _minValue = (actualMinValue * 0.9).clamp(0, double.infinity);

        // Set max value with 10% padding for better visualization
        _maxValue = businessMaxValue * 1.1;

        AppLogger.info('📊 قيم المحاور - الحد الأدنى: ${_minValue.toInt()}، الحد الأقصى: ${_maxValue.toInt()}');
        AppLogger.info('✅ تم حساب تدفق المخزون بنجاح - ${_inventoryFlow.length} نقطة بيانات');
      } else {
        AppLogger.warning('⚠️ لا توجد بيانات تدفق مخزون');
        _minValue = 0;
        _maxValue = (currentStock * 1.2).clamp(10, double.infinity);
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في حساب تدفق المخزون: $e');
      AppLogger.error('Stack trace: $stackTrace');

      // Fallback values to prevent chart crash
      final fallbackDate = DateTime.now();
      _inventoryFlow = {fallbackDate: widget.productMovement.statistics.currentStock.toDouble()};
      _dataPointInfo = {
        fallbackDate: {
          'type': 'current_stock',
          'label': 'المخزون الحالي',
          'quantity': widget.productMovement.statistics.currentStock,
        }
      };
      _minValue = 0;
      _maxValue = widget.productMovement.statistics.currentStock * 1.2;
    }
  }

  /// Validate inventory flow calculations for data accuracy
  void _validateInventoryFlow() {
    try {
      final currentStock = widget.productMovement.statistics.currentStock;
      final movementData = widget.productMovement.movementData;
      final salesData = widget.productMovement.salesData;

      AppLogger.info('🔍 بدء التحقق من دقة البيانات');

      // CRITICAL FIX: Check if we have the expected number of data points (sales-only approach)
      // Expected: opening balance + number of sales transactions (only sales create data points)
      final totalSalesTransactions = salesData.length;
      final expectedDataPoints = totalSalesTransactions > 0 ? totalSalesTransactions + 1 : 1; // +1 for opening balance
      final actualDataPoints = _inventoryFlow.length;

      AppLogger.info('🔍 CRITICAL VALIDATION: إجمالي المبيعات: $totalSalesTransactions');
      AppLogger.info('🔍 CRITICAL VALIDATION: نقاط البيانات المتوقعة: $expectedDataPoints، الفعلية: $actualDataPoints');
      AppLogger.info('🔍 CRITICAL VALIDATION: المنطق: الرصيد الافتتاحي (1) + المبيعات ($totalSalesTransactions) = $expectedDataPoints');

      // Verify current stock matches the most recent flow value (if sales exist)
      if (_inventoryFlow.isNotEmpty && totalSalesTransactions > 0) {
        final sortedFlow = _inventoryFlow.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        final mostRecentFlowValue = sortedFlow.last.value;

        if ((mostRecentFlowValue - currentStock).abs() > 0.1) {
          AppLogger.warning('⚠️ تضارب في المخزون الحالي: القيمة المحسوبة ${mostRecentFlowValue.toInt()}، القيمة الفعلية: $currentStock');
        } else {
          AppLogger.info('✅ المخزون الحالي متطابق: ${mostRecentFlowValue.toInt()}');
        }

        // Check for any impossible values (negative stock)
        for (final entry in sortedFlow) {
          if (entry.value < 0) {
            AppLogger.warning('⚠️ رصيد سالب في التاريخ ${entry.key}: ${entry.value.toInt()}');
          }
        }

        // Log summary of flow values
        AppLogger.info('🔍 ملخص قيم التدفق:');
        AppLogger.info('🔍 أقل قيمة: ${sortedFlow.map((e) => e.value).reduce((a, b) => a < b ? a : b).toInt()}');
        AppLogger.info('🔍 أعلى قيمة: ${sortedFlow.map((e) => e.value).reduce((a, b) => a > b ? a : b).toInt()}');
        AppLogger.info('🔍 القيمة الأولى (الرصيد الافتتاحي): ${sortedFlow.first.value.toInt()}');
        AppLogger.info('🔍 القيمة الأخيرة (المخزون الحالي): ${sortedFlow.last.value.toInt()}');

        // Validate opening balance calculation
        final openingBalance = _calculateOpeningBalance();
        final firstFlowValue = sortedFlow.first.value;
        if ((firstFlowValue - openingBalance).abs() > 0.1) {
          AppLogger.warning('⚠️ تضارب في الرصيد الافتتاحي: القيمة المحسوبة ${firstFlowValue.toInt()}، المتوقعة: $openingBalance');
        } else {
          AppLogger.info('✅ الرصيد الافتتاحي متطابق: ${firstFlowValue.toInt()}');
        }
      } else if (totalSalesTransactions == 0) {
        // No sales transactions - should only show current stock
        AppLogger.info('🔍 CRITICAL VALIDATION: لا توجد مبيعات - عرض المخزون الحالي فقط');
      }

      AppLogger.info('✅ انتهى التحقق من دقة البيانات');
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من دقة البيانات: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? _getResponsiveHeight(context),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildChart(),
          ),
          if (widget.showLegend) ...[
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  /// Build chart header with title and description
  Widget _buildChartHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up,
              color: AccountantThemeConfig.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تدفق المخزون عبر الزمن',
                style: AccountantThemeConfig.headlineMedium.copyWith(fontSize: 18),
              ),
            ),
            if (widget.enableInteraction) ...[
              // Zoom controls
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isZoomed ? _pulseAnimation.value : 1.0,
                    child: IconButton(
                      onPressed: _toggleZoom,
                      icon: Icon(
                        _isZoomed ? Icons.zoom_out : Icons.zoom_in,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 20,
                      ),
                      tooltip: _isZoomed ? 'تصغير' : 'تكبير',
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: _showFullscreenChart,
                icon: Icon(
                  Icons.fullscreen,
                  color: AccountantThemeConfig.accentBlue,
                  size: 20,
                ),
                tooltip: 'عرض بملء الشاشة',
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'تتبع مستويات المخزون من المشتريات والمبيعات والتعديلات',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build the main chart using fl_chart
  Widget _buildChart() {
    try {
      // Data validation
      if (_inventoryFlow.isEmpty) {
        AppLogger.warning('⚠️ لا توجد بيانات تدفق مخزون لعرضها');
        return _buildEmptyState();
      }

      // Validate min/max values
      assert(_maxValue > _minValue, 'Max value ($_maxValue) must be greater than min value ($_minValue)');
      assert(_maxValue >= 0, 'Max value cannot be negative: $_maxValue');
      assert(_minValue >= 0, 'Min value cannot be negative: $_minValue');

      AppLogger.info('📊 بناء المخطط - نقاط البيانات: ${_inventoryFlow.length}، الحد الأدنى: ${_minValue.toInt()}، الحد الأقصى: ${_maxValue.toInt()}');

      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return LineChart(
            _buildLineChartData(),
            duration: const Duration(milliseconds: 250),
          );
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في بناء المخطط: $e');
      AppLogger.error('Stack trace: $stackTrace');
      return _buildEmptyState();
    }
  }

  /// Build line chart data configuration
  LineChartData _buildLineChartData() {
    final sortedEntries = _inventoryFlow.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[];
    for (int i = 0; i < sortedEntries.length; i++) {
      final value = sortedEntries[i].value * _animation.value;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return LineChartData(
      gridData: _buildGridData(),
      titlesData: _buildTitlesData(sortedEntries),
      borderData: _buildBorderData(),
      lineBarsData: [_buildLineBarData(spots)],
      minX: 0,
      maxX: (sortedEntries.length - 1).toDouble(),
      minY: _minValue,
      maxY: _maxValue,
      lineTouchData: _buildTouchData(sortedEntries),
      backgroundColor: Colors.transparent,
    );
  }

  /// Build grid configuration
  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: (_maxValue - _minValue) / 5,
      verticalInterval: 1,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.white.withOpacity(0.1),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Colors.white.withOpacity(0.1),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }

  /// Build titles configuration for axes
  FlTitlesData _buildTitlesData(List<MapEntry<DateTime, double>> sortedEntries) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: (sortedEntries.length / 4).clamp(1, double.infinity),
          getTitlesWidget: (value, meta) => _buildBottomTitle(value, sortedEntries),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          interval: (_maxValue - _minValue) / 4,
          getTitlesWidget: (value, meta) => _buildLeftTitle(value),
        ),
      ),
    );
  }

  /// Build bottom axis title (dates)
  Widget _buildBottomTitle(double value, List<MapEntry<DateTime, double>> sortedEntries) {
    final index = value.toInt();
    if (index < 0 || index >= sortedEntries.length) {
      return const SizedBox.shrink();
    }

    final date = sortedEntries[index].key;
    final formatter = DateFormat('MM/dd');
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        formatter.format(date),
        style: GoogleFonts.cairo(
          fontSize: 10,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build left axis title (quantities)
  Widget _buildLeftTitle(double value) {
    return Text(
      value.toInt().toString(),
      style: GoogleFonts.cairo(
        fontSize: 10,
        color: Colors.white70,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Build border configuration
  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    );
  }

  /// Build line bar data with gradient and styling
  LineChartBarData _buildLineBarData(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: AccountantThemeConfig.primaryGreen,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          // Highlight touched point
          final isHighlighted = _touchedIndex == index;
          return FlDotCirclePainter(
            radius: isHighlighted ? 6 : 4,
            color: isHighlighted
                ? AccountantThemeConfig.accentBlue
                : AccountantThemeConfig.primaryGreen,
            strokeWidth: isHighlighted ? 3 : 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.4),
            AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            AccountantThemeConfig.primaryGreen.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      shadow: Shadow(
        color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    );
  }

  /// Build touch interaction data
  LineTouchData _buildTouchData(List<MapEntry<DateTime, double>> sortedEntries) {
    return LineTouchData(
      enabled: widget.enableInteraction,
      touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
        setState(() {
          if (touchResponse != null && touchResponse.lineBarSpots != null) {
            _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex;
          } else {
            _touchedIndex = null;
          }
        });
      },
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: AccountantThemeConfig.cardBackground1.withOpacity(0.95),
        tooltipRoundedRadius: 16,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tooltipMargin: 12,
        tooltipBorder: BorderSide(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
          width: 1.5,
        ),
        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
          return touchedBarSpots.map((barSpot) {
            final index = barSpot.spotIndex;
            if (index >= 0 && index < sortedEntries.length) {
              final entry = sortedEntries[index];
              final date = entry.key;
              final quantity = entry.value;

              // Get customer information for this data point
              final pointInfo = _dataPointInfo[date];

              String mainText;
              String customerText = '';
              Color customerColor = AccountantThemeConfig.accentBlue;

              if (pointInfo != null) {
                switch (pointInfo['type']) {
                  case 'sale':
                    mainText = '� ${pointInfo['customer']}\n�📅 ${DateFormat('yyyy/MM/dd').format(date)}\n📦 ${quantity.toInt()} قطعة متبقية';
                    customerText = '\n� تم بيع ${pointInfo['quantity']} قطعة\n� فاتورة رقم ${pointInfo['invoiceId']}';
                    customerColor = AccountantThemeConfig.accentBlue;
                    break;
                  case 'opening_balance':
                    mainText = '📅 ${DateFormat('yyyy/MM/dd').format(date)}\n📦 ${quantity.toInt()} قطعة\n🏁 ${pointInfo['label']}';
                    break;
                  case 'current_stock':
                    mainText = '📅 ${DateFormat('yyyy/MM/dd').format(date)}\n📦 ${quantity.toInt()} قطعة\n📊 ${pointInfo['label']}';
                    break;
                  default:
                    mainText = '📅 ${DateFormat('yyyy/MM/dd').format(date)}\n� ${quantity.toInt()} قطعة';
                }
              } else {
                mainText = '📅 ${DateFormat('yyyy/MM/dd').format(date)}\n📦 ${quantity.toInt()} قطعة';
              }

              return LineTooltipItem(
                mainText,
                GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '\n⏰ ${DateFormat('HH:mm').format(date)}',
                    style: GoogleFonts.cairo(
                      color: AccountantThemeConfig.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (customerText.isNotEmpty)
                    TextSpan(
                      text: customerText,
                      style: GoogleFonts.cairo(
                        color: customerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );
            }
            return null;
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
      getTouchLineStart: (data, index) => 0,
      getTouchLineEnd: (data, index) => double.infinity,
      touchSpotThreshold: 20,
    );
  }

  /// Build empty state when no data is available
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات كافية لعرض المخطط',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم عرض المخطط عند توفر حركات مخزون أو مبيعات',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// Build legend showing chart information
  Widget _buildLegend() {
    final stats = widget.productMovement.statistics;
    final movementData = widget.productMovement.movementData;
    final salesData = widget.productMovement.salesData;

    // DEBUG: Understand what the user expects for movement count
    AppLogger.info('🔍 DEBUG: تحليل عدد الحركات في الأسطورة:');
    AppLogger.info('🔍 DEBUG: عدد حركات المخزون: ${movementData.length}');
    AppLogger.info('🔍 DEBUG: عدد المبيعات: ${salesData.length}');
    AppLogger.info('🔍 DEBUG: الإجمالي (حركات + مبيعات): ${movementData.length + salesData.length}');
    AppLogger.info('� DEBUG: المتوقع من المستخدم: عدد المبيعات فقط = 4');
    AppLogger.info('🔍 DEBUG: الفعلي المعروض: ${movementData.length + salesData.length}');

    // Based on user feedback, they expect only sales count (4), not sales + movements (8)
    // Let's use only sales count as the movement count
    final totalMovements = salesData.length; // Only count sales transactions
    AppLogger.info('🔍 DEBUG: تصحيح عدد الحركات - استخدام المبيعات فقط: $totalMovements');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Legend title
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: AccountantThemeConfig.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'ملخص البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend items
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  'المخزون الحالي',
                  '${stats.currentStock} قطعة',
                  Icons.inventory,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLegendItem(
                  'إجمالي المبيعات',
                  '${stats.totalSoldQuantity} قطعة',
                  Icons.trending_down,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLegendItem(
                  'عدد المبيعات',
                  '$totalMovements مبيعة',
                  Icons.shopping_cart,
                  AccountantThemeConfig.warningOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual legend item
  Widget _buildLegendItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Get transaction information for a specific date
  String _getTransactionInfo(DateTime date) {
    try {
      final movementData = widget.productMovement.movementData;
      final salesData = widget.productMovement.salesData;

      // Data validation
      assert(movementData != null, 'Movement data cannot be null');
      assert(salesData != null, 'Sales data cannot be null');

      // Check for movements on this date (purchases)
      final movement = movementData.where((m) =>
        m.createdAt.year == date.year &&
        m.createdAt.month == date.month &&
        m.createdAt.day == date.day
      ).firstOrNull;

      if (movement != null) {
        AppLogger.info('📋 معلومات المعاملة: شراء في ${date.toIso8601String()} - ${movement.reason} (+${movement.quantity})');
        return '� شراء: ${movement.reason} (+${movement.quantity})';
      }

      // Check for sales on this date
      final sale = salesData.where((s) =>
        s.saleDate.year == date.year &&
        s.saleDate.month == date.month &&
        s.saleDate.day == date.day
      ).firstOrNull;

      if (sale != null) {
        AppLogger.info('🛒 معلومات المعاملة: بيع في ${date.toIso8601String()} - ${sale.customerName} (-${sale.quantity})');
        return '🛒 بيع: ${sale.customerName} (-${sale.quantity})';
      }

      return '';
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على معلومات المعاملة: $e');
      return '';
    }
  }

  /// Show fullscreen chart dialog
  void _showFullscreenChart() {
    try {
      AppLogger.info('📊 عرض المخطط بملء الشاشة');

      // Call the provided callback if available
      if (widget.onChartTap != null) {
        widget.onChartTap!();
        return;
      }

      // Default fullscreen implementation - show chart in a fullscreen dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(8),
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: Column(
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: AccountantThemeConfig.primaryGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تدفق المخزون عبر الزمن - عرض مكبر',
                            style: AccountantThemeConfig.headlineMedium.copyWith(fontSize: 18),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                  ),
                  // Fullscreen chart - use the same chart data but larger
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _inventoryFlow.isEmpty
                        ? _buildEmptyState()
                        : LineChart(
                            _buildLineChartData(),
                            duration: const Duration(milliseconds: 250),
                          ),
                    ),
                  ),
                  // Legend in fullscreen
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildLegend(),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في عرض المخطط بملء الشاشة: $e');
    }
  }

  /// Toggle zoom functionality
  void _toggleZoom() {
    setState(() {
      _isZoomed = !_isZoomed;
      _zoomLevel = _isZoomed ? 1.5 : 1.0;
    });

    // Animate zoom transition
    _animationController.reset();
    _animationController.forward();
  }

  /// Get responsive height based on screen size
  double _getResponsiveHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Apply zoom factor
    double baseHeight;

    // Responsive height calculation
    if (screenWidth < 600) {
      // Mobile
      baseHeight = (screenHeight * 0.35).clamp(250, 350);
    } else if (screenWidth < 1200) {
      // Tablet
      baseHeight = (screenHeight * 0.4).clamp(300, 400);
    } else {
      // Desktop
      baseHeight = (screenHeight * 0.45).clamp(350, 500);
    }

    return baseHeight * _zoomLevel;
  }
}
