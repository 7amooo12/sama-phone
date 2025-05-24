import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/productivity_model.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/utils/chart_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/models/chart_models.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class ProductivityScreen extends StatefulWidget {
  const ProductivityScreen({super.key});

  @override
  State<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends State<ProductivityScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<ProductivityModel>? _productivityData;
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWorker;

  @override
  void initState() {
    super.initState();
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _fetchProductivityData();
  }

  // Fetch productivity data
  void _fetchProductivityData() {
    setState(() {
      _isLoading = true;
    });

    try {
      _databaseService.getAllWorkersProductivity().listen((data) {
        setState(() {
          _productivityData = data;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filter data based on date range and worker
  List<ProductivityModel> _getFilteredData() {
    if (_productivityData == null) return [];

    return _productivityData!.where((data) {
      // Filter by date range
      bool isInDateRange = true;
      if (_startDate != null) {
        isInDateRange = isInDateRange && data.date.isAfter(_startDate!);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        isInDateRange = isInDateRange && data.date.isBefore(endOfDay);
      }

      // Filter by selected worker
      bool isSelectedWorker = true;
      if (_selectedWorker != null && _selectedWorker!.isNotEmpty) {
        isSelectedWorker = data.workerName == _selectedWorker;
      }

      return isInDateRange && isSelectedWorker;
    }).toList();
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

  // Get unique worker names
  List<String> _getUniqueWorkers() {
    if (_productivityData == null) return [];

    final workerNames =
        _productivityData!.map((data) => data.workerName).toSet().toList();
    workerNames.sort();
    return workerNames;
  }

  Widget _buildProductivityChart(
      List<ProductivityChartData> data, String title) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    maxY: data
                            .map((e) => e.value)
                            .reduce((a, b) => a > b ? a : b) *
                        1.2,
                    barGroups: data.asMap().entries.map((entry) {
                      return ChartUtils.generateBarGroup(
                        entry.key,
                        entry.value.value,
                        context,
                      );
                    }).toList(),
                    titlesData: ChartUtils.getTitlesData(
                      context,
                      bottomTitles: data.map((e) => e.name).toList(),
                    ),
                    borderData: ChartUtils.getBorderData(),
                    gridData: ChartUtils.getGridData(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${data[group.x].name}\n${rod.toY.toStringAsFixed(1)}',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredData();
    final dateFormat = DateFormat('yyyy/MM/dd');

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

                  // Chart section
                  if (_productivityData != null &&
                      _productivityData!.isNotEmpty)
                    _buildProductivityChart(
                      _getFilteredData()
                          .map((data) => ProductivityChartData(
                                name: DateFormat('MM/dd').format(data.date),
                                value: data.producedQuantity.toDouble(),
                              ))
                          .toList(),
                      'إنتاجية العمال',
                    ),
                ],
              ),
            ),

            // Results list
            Expanded(
              child: _productivityData == null
                  ? const Center(child: CircularProgressIndicator())
                  : filteredData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_off,
                                size: 80,
                                color: Colors.grey.safeOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد بيانات إنتاجية للفترة المحددة',
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
                            _fetchProductivityData();
                            return;
                          },
                          child: AnimationLimiter(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final data = filteredData[index];
                                final dateFormat =
                                    DateFormat('yyyy/MM/dd - hh:mm a');
                                final formattedDate =
                                    dateFormat.format(data.date);

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
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                Theme.of(context).primaryColor,
                                            radius: 25,
                                            child: Text(
                                              data.producedQuantity.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            data.itemName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                  'العامل: ${data.workerName}'),
                                              const SizedBox(height: 4),
                                              Text('التاريخ: $formattedDate'),
                                              if (data.notes != null &&
                                                  data.notes!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text('ملاحظات: ${data.notes}'),
                                              ],
                                            ],
                                          ),
                                          trailing:
                                              const Icon(Icons.trending_up),
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
}
