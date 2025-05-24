import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartbiztracker_new/models/waste_model.dart' as waste_models;
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/models/damaged_item_model.dart';

class WasteScreen extends StatefulWidget {
  const WasteScreen({super.key});

  @override
  State<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends State<WasteScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<DamagedItemModel>? _wasteItems;
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWorker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _fetchWasteData();
  }

  void _fetchWasteData() {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<StockWarehouseApiService>(context, listen: false);
      
      // First ensure we're logged in
      apiService.login('admin', 'NewPassword123').then((loginSuccess) {
        // Get damaged items data
        apiService.getDamagedItems().then((damagedItems) {
          setState(() {
            _wasteItems = damagedItems;
            _isLoading = false;
          });
        }).catchError((error) {
          setState(() => _isLoading = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ في جلب البيانات: $error'), backgroundColor: Colors.red),
            );
          }
        });
      }).catchError((error) {
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ في تسجيل الدخول: $error'), backgroundColor: Colors.red),
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<DamagedItemModel> _getFilteredData() {
    if (_wasteItems == null) return [];
    return _wasteItems!.where((waste) {
      bool isInDateRange = true;
      if (_startDate != null) {
        isInDateRange &= waste.reportedDate.isAfter(_startDate!);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        isInDateRange &= waste.reportedDate.isBefore(endOfDay);
      }
      final bool isSelectedWorker = _selectedWorker == null ||
          _selectedWorker!.isEmpty ||
          waste.reportedBy == _selectedWorker;
      return isInDateRange && isSelectedWorker;
    }).toList();
  }

  double _calculateTotalWaste() =>
      _getFilteredData().fold(0.0, (sum, w) => sum + w.quantity);

  List<BarChartGroupData> _buildBarChartData(List<_WasteChartData> data) {
    return List.generate(data.length, (index) {
      final entry = data[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.quantity.toDouble(),
            color: entry.color,
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  List<_WasteChartData> _getChartDataByWorker() {
    final map = <String, double>{};
    for (var waste in _getFilteredData()) {
      if (waste.reportedBy != null) {
        map[waste.reportedBy!] = (map[waste.reportedBy!] ?? 0) + waste.quantity;
      }
    }
    return map.entries
        .map((e) => _WasteChartData(e.key, e.value, Colors.blue))
        .toList();
  }

  List<_WasteChartData> _getChartDataByItem() {
    final map = <String, double>{};
    for (var waste in _getFilteredData()) {
      map[waste.productName] = (map[waste.productName] ?? 0) + waste.quantity;
    }
    return map.entries
        .map((e) => _WasteChartData(e.key, e.value, Colors.red))
        .toList();
  }

  Widget _buildChart(String title, List<_WasteChartData> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              barGroups: _buildBarChartData(data),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(data[idx].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  // Get unique worker names
  List<String> _getUniqueWorkers() {
    if (_wasteItems == null) return [];

    final workerNames =
        _wasteItems!.map((waste) => waste.reportedBy).toSet().toList();
    workerNames.sort();
    return workerNames;
  }

  // Show date picker
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate =
        isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredData();
    final dateFormat = DateFormat('yyyy/MM/dd');
    final totalWaste = _calculateTotalWaste();

    return Stack(
      children: [
        Column(
          children: [
            // Filters section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.safeOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تصفية البيانات:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date range filters
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _startDate != null
                                      ? dateFormat.format(_startDate!)
                                      : 'تاريخ البداية',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _endDate != null
                                      ? dateFormat.format(_endDate!)
                                      : 'تاريخ النهاية',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Worker filter
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'اختر العامل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedWorker,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('جميع العمال'),
                      ),
                      ..._getUniqueWorkers().map((workerName) {
                        return DropdownMenuItem<String>(
                          value: workerName,
                          child: Text(workerName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedWorker = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Total waste summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.safeOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إجمالي الهالك',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'عدد: $totalWaste قطعة',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Charts section
                  if (_wasteItems != null && _wasteItems!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إحصائيات الهالك:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Worker chart
                        Container(
                          height: 250,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildChart(
                              'الهالك حسب العامل', _getChartDataByWorker()),
                        ),

                        const SizedBox(height: 16),

                        // Item chart
                        Container(
                          height: 250,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildChart(
                              'الهالك حسب المنتج', _getChartDataByItem()),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Results list
            Expanded(
              child: _wasteItems == null
                  ? const Center(child: CircularProgressIndicator())
                  : filteredData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 80,
                                color: Colors.grey.safeOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد بيانات هالك للفترة المحددة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            _fetchWasteData();
                          },
                          child: AnimationLimiter(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final waste = filteredData[index];
                                final dateFormat =
                                    DateFormat('yyyy/MM/dd - hh:mm a');
                                final formattedDate =
                                    dateFormat.format(waste.reportedDate);

                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 375),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: Card(
                                        elevation: 3,
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                          ),
                                          title: Text(
                                            waste.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                  'العامل: ${waste.reportedBy ?? "غير معروف"}'),
                                              const SizedBox(height: 4),
                                              Text('التاريخ: $formattedDate'),
                                              const SizedBox(height: 4),
                                              Text('الكمية: ${waste.quantity}'),
                                            ],
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(waste.status),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              waste.status,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('تفاصيل الهدر'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                          'المنتج: ${waste.productName}'),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          'سبب الهدر: ${waste.reason}'),
                                                      const SizedBox(height: 8),
                                                      if (waste.notes != null) ...[
                                                        Text(
                                                            'ملاحظات: ${waste.notes}'),
                                                        const SizedBox(height: 8),
                                                      ],
                                                      Text(
                                                          'الكمية: ${waste.quantity}'),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          'الحالة: ${waste.status}'),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          'الخسارة المالية: ${waste.lossAmount?.toStringAsFixed(2) ?? "غير محدد"}'),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          'تاريخ التسجيل: $formattedDate'),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('إغلاق'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),

        // Loading indicator
        if (_isLoading) const CustomLoader(),
      ],
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status == 'pending' || status == 'قيد الانتظار' || status == 'مُبلغ عنه') {
      return Colors.orange;
    } else if (status == 'resolved' || status == 'تمت معالجته' || status == 'مكتمل') {
      return Colors.green;
    } else if (status == 'rejected' || status == 'مرفوض') {
      return Colors.red;
    } else if (status == 'under review' || status == 'قيد المراجعة') {
      return Colors.blue;
    }
    return Colors.grey;
  }
}

class _WasteChartData {
  const _WasteChartData(this.label, this.quantity, this.color);
  final String label;
  final double quantity;
  final Color color;
}
