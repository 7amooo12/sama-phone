import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/return_model.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class AdminReturnsScreen extends StatefulWidget {
  const AdminReturnsScreen({super.key});

  @override
  State<AdminReturnsScreen> createState() => _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends State<AdminReturnsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<ReturnModel>? _returns;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReturns();
  }

  // Fetch returns
  void _fetchReturns() {
    setState(() {
      _isLoading = true;
    });

    try {
      _databaseService.getAllReturnReports().listen((returns) {
        setState(() {
          _returns = returns;
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

  // Mark return as processed
  Future<void> _markAsProcessed(String returnId, bool isProcessed) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _databaseService.updateReturnProcessStatus(
        returnId,
        isProcessed,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isProcessed
                ? 'تم معالجة المرتجع بنجاح'
                : 'تم إلغاء معالجة المرتجع'),
            backgroundColor: isProcessed ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content
        _returns == null
            ? const Center(child: CircularProgressIndicator())
            : _returns!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_return_outlined,
                          size: 80,
                          color: Colors.grey.safeOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد مرتجعات',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _fetchReturns();
                      return;
                    },
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _returns!.length,
                        itemBuilder: (context, index) {
                          final returnItem = _returns![index];
                          final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
                          final formattedDate =
                              dateFormat.format(returnItem.date);

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
                                      border: returnItem.isProcessed
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
                                          // Return header
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.assignment_return,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'مرتجع: ${returnItem.itemName}',
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
                                                  color: returnItem.isProcessed
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  returnItem.isProcessed
                                                      ? 'تمت المعالجة'
                                                      : 'قيد الانتظار',
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

                                          // Return details
                                          _buildDetailRow(
                                              'العميل:', returnItem.clientName),
                                          _buildDetailRow(
                                              'المنتج:', returnItem.itemName),
                                          _buildDetailRow('الكمية:',
                                              returnItem.quantity.toString()),
                                          _buildDetailRow(
                                              'السبب:', returnItem.reason),
                                          _buildDetailRow(
                                              'التاريخ:', formattedDate),

                                          const Divider(height: 24),

                                          // Actions
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton.icon(
                                                icon: Icon(
                                                  returnItem.isProcessed
                                                      ? Icons.close
                                                      : Icons.check,
                                                ),
                                                label: Text(
                                                  returnItem.isProcessed
                                                      ? 'إلغاء المعالجة'
                                                      : 'معالجة المرتجع',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      returnItem.isProcessed
                                                          ? Colors.orange
                                                          : Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    _markAsProcessed(
                                                  returnItem.id,
                                                  !returnItem.isProcessed,
                                                ),
                                              ),
                                            ],
                                          ),
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
