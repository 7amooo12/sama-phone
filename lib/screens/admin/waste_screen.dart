import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/models/damaged_item_model.dart';

// Adding WasteScreen wrapper for routes
class WasteScreen extends StatefulWidget {
  const WasteScreen({super.key});

  @override
  State<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends State<WasteScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'تقارير الهالك',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          hideStatusBarHeader: true,
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.waste,
      ),
      body: const AdminWasteScreen(),
    );
  }
}

class AdminWasteScreen extends StatefulWidget {
  const AdminWasteScreen({super.key});

  @override
  State<AdminWasteScreen> createState() => _AdminWasteScreenState();
}

class _AdminWasteScreenState extends State<AdminWasteScreen> {
  List<DamagedItemModel>? _wasteItems;
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
    _fetchWasteData();
  }

  // Fetch waste data
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

  // Filter data based on date range and worker
  List<DamagedItemModel> _getFilteredData() {
    if (_wasteItems == null) return [];

    return _wasteItems!.where((waste) {
      // Filter by date range
      bool isInDateRange = true;
      if (_startDate != null) {
        isInDateRange = isInDateRange && waste.reportedDate.isAfter(_startDate!);
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        isInDateRange = isInDateRange && waste.reportedDate.isBefore(endOfDay);
      }

      // Filter by selected worker
      bool isSelectedWorker = true;
      if (_selectedWorker != null && _selectedWorker!.isNotEmpty) {
        isSelectedWorker = waste.reportedBy == _selectedWorker;
      }

      return isInDateRange && isSelectedWorker;
    }).toList();
  }

  // Show date picker - إصلاح مشاكل الألوان البيضاء وجعله احترافي
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate =
        isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: const Color(0xFF10B981), // أخضر احترافي
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E293B), // خلفية داكنة احترافية
                    onSurface: Colors.white, // نص أبيض على الخلفية الداكنة
                    onSurfaceVariant: Colors.white70, // نص ثانوي
                    outline: const Color(0xFF10B981).withOpacity(0.3),
                    surfaceContainerHighest: const Color(0xFF334155),
                  )
                : ColorScheme.light(
                    primary: const Color(0xFF10B981), // أخضر احترافي
                    onPrimary: Colors.white,
                    surface: Colors.white, // خلفية بيضاء
                    onSurface: Colors.black, // نص أسود على الخلفية البيضاء
                    onSurfaceVariant: Colors.black87, // نص ثانوي
                    outline: const Color(0xFF10B981).withOpacity(0.3),
                    surfaceContainerHighest: const Color(0xFFF8FAFC),
                  ),
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineLarge: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
              headlineMedium: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
              bodyLarge: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontFamily: 'Cairo',
              ),
              bodyMedium: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontFamily: 'Cairo',
              ),
              labelLarge: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            dialogTheme: DialogTheme(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
              contentTextStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontFamily: 'Cairo',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
    if (_wasteItems == null) return [];

    final workerNames = _wasteItems!
        .map((waste) => waste.reporterName)
        .where((name) => name != 'غير محدد')
        .toSet()
        .toList();
    workerNames.sort();
    return workerNames;
  }

  // Calculate total waste quantity
  int _calculateTotalWaste() {
    final filteredData = _getFilteredData();
    return filteredData.fold(0, (sum, waste) => sum + waste.quantity);
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

                  // Date range filters - تحسين التصميم
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.1),
                                    const Color(0xFF10B981).withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _startDate != null
                                          ? dateFormat.format(_startDate!)
                                          : 'تاريخ البداية',
                                      style: TextStyle(
                                        color: _startDate != null
                                            ? Colors.black
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.1),
                                    const Color(0xFF10B981).withOpacity(0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _endDate != null
                                          ? dateFormat.format(_endDate!)
                                          : 'تاريخ النهاية',
                                      style: TextStyle(
                                        color: _endDate != null
                                            ? Colors.black
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                                color: Colors.grey.safeOpacity(0.7),
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
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                Colors.red.shade700,
                                            radius: 25,
                                            child: Text(
                                              waste.quantity.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            waste.productName,
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
                                                  'العامل: ${waste.reportedBy ?? "غير معروف"}'),
                                              const SizedBox(height: 4),
                                              Text('التاريخ: $formattedDate'),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'التفاصيل: ${waste.notes ?? waste.reason}'),
                                            ],
                                          ),
                                          trailing: const Icon(Icons.delete),
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

// Adding WasteDetailsScreen placeholder for routes
class WasteDetailsScreen extends StatelessWidget {
  const WasteDetailsScreen({super.key, required this.wasteId});
  final String wasteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الهالك'),
      ),
      body: Center(
        child: Text('تفاصيل الهالك: $wasteId'),
      ),
    );
  }
}

// Adding ReportWasteScreen placeholder for routes
class ReportWasteScreen extends StatelessWidget {
  const ReportWasteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة تقرير هالك'),
      ),
      body: const Center(
        child: Text('نموذج إضافة تقرير هالك'),
      ),
    );
  }
}
