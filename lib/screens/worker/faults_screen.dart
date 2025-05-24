import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/models/fault_model.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:smartbiztracker_new/widgets/common/material_wrapper.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';

class FaultsScreen extends StatefulWidget {
  const FaultsScreen({super.key});

  @override
  State<FaultsScreen> createState() => _FaultsScreenState();
}

class _FaultsScreenState extends State<FaultsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<FaultModel>? _faults;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFaults();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch faults
  void _fetchFaults() {
    setState(() {
      _isLoading = true;
    });

    try {
      _databaseService.getAllFaultReports().listen((faults) {
        setState(() {
          _faults = faults;
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

  @override
  Widget build(BuildContext context) {
    return MaterialWrapper(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white,
              tabs: [
                Tab(
                  icon: const Icon(Icons.build),
                  text: 'قيد الإصلاح (${_faults?.where((fault) => !fault.isResolved).length ?? 0})',
                ),
                Tab(
                  icon: const Icon(Icons.check_circle),
                  text: 'تم الإصلاح (${_faults?.where((fault) => fault.isResolved).length ?? 0})',
                ),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Pending faults tab
                  _buildFaultsList(_faults?.where((fault) => !fault.isResolved).toList() ?? [], false),

                  // Resolved faults tab
                  _buildFaultsList(_faults?.where((fault) => fault.isResolved).toList() ?? [], true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build faults list
  Widget _buildFaultsList(List<FaultModel> faults, bool isResolved) {
    return Stack(
      children: [
        _faults == null
            ? const Center(child: CircularProgressIndicator())
            : faults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isResolved
                              ? Icons.check_circle_outline
                              : Icons.build_outlined,
                          size: 80,
                          color: Colors.grey.withAlpha(118),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isResolved
                              ? 'لا توجد أعطال تم إصلاحها'
                              : 'لا توجد أعطال قيد الإصلاح',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _fetchFaults();
                    },
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: faults.length,
                        itemBuilder: (context, index) {
                          final fault = faults[index];
                          final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
                          final formattedDate =
                              dateFormat.format(fault.createdAt);

                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: fault.isResolved
                                          ? Border.all(
                                              color: Colors.green, width: 2)
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Fault header
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.build,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'عطل: ${fault.itemName}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: fault.isResolved
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  fault.isResolved
                                                      ? 'تم الإصلاح'
                                                      : 'قيد الإصلاح',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Fault details
                                          _buildDetailRow(
                                              'العميل:', fault.clientName),
                                          _buildDetailRow(
                                              'المنتج:', fault.itemName),
                                          _buildDetailRow('الكمية:',
                                              fault.quantity.toString()),
                                          _buildDetailRow(
                                              'نوع العطل:', fault.faultType),
                                          _buildDetailRow(
                                              'التفاصيل:', fault.details),
                                          _buildDetailRow(
                                              'التاريخ:', formattedDate),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

        // Loading indicator
        if (_isLoading) const CustomLoader(),
      ],
    );
  }

  // Helper to build detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
