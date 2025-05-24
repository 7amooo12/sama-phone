import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/damaged_item_model.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:smartbiztracker_new/widgets/error_widget.dart';
import 'package:smartbiztracker_new/widgets/loading_widget.dart';
import 'package:smartbiztracker_new/utils/logger.dart';

class DamagedItemsScreen extends StatefulWidget {
  const DamagedItemsScreen({Key? key}) : super(key: key);

  @override
  _DamagedItemsScreenState createState() => _DamagedItemsScreenState();
}

class _DamagedItemsScreenState extends State<DamagedItemsScreen> {
  late Future<List<DamagedItemModel>> _damagedItemsFuture;
  final AppLogger logger = AppLogger();
  String? _searchQuery;
  int? _selectedWarehouseId;
  int _days = 90;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _warehouses;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDamagedItems();
  }

  void _loadDamagedItems() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final apiService = Provider.of<StockWarehouseApiService>(context, listen: false);
    
    // Use the updated method with parameters
    _damagedItemsFuture = apiService.getDamagedItems(
      days: _days,
      search: _searchQuery,
      warehouseId: _selectedWarehouseId,
    );
    
    // Handle completion
    _damagedItemsFuture.then((damagedItems) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (damagedItems.isEmpty) {
            _errorMessage = 'لم يتم العثور على عناصر تالفة';
          }
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خطأ في جلب العناصر التالفة: ${error.toString()}';
          logger.e("خطأ أثناء جلب العناصر التالفة: $error");
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('damaged_items') ?? 'العناصر التالفة/الهوالك'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
                _loadDamagedItems();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters section
          _buildFiltersSection(context),
          
          // List of damaged items
          Expanded(
            child: _isLoading 
                ? const LoadingWidget()
                : _errorMessage != null
                    ? AppErrorWidget(
                        error: _errorMessage!,
                        onRetry: () {
                          _loadDamagedItems();
                        },
                      )
                    : FutureBuilder<List<DamagedItemModel>>(
        future: _damagedItemsFuture,
        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
            return Center(
              child: Text(
                                appLocalizations.translate('loading_damaged_items') ?? 'جاري تحميل العناصر التالفة...',
                style: const TextStyle(fontSize: 18),
              ),
            );
          }
          
          final damagedItems = snapshot.data!;
                          
                          if (damagedItems.isEmpty) {
                            return Center(
                              child: Text(
                                appLocalizations.translate('no_damaged_items_found') ?? 'لم يتم العثور على عناصر تالفة',
                                style: const TextStyle(fontSize: 18),
                              ),
                            );
                          }
          
          return ListView.builder(
            itemCount: damagedItems.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = damagedItems[index];
              
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // صورة المنتج
                          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                    Container(
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.image_not_supported, color: Colors.grey.shade400),
                                    ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade200,
                              ),
                              child: Icon(Icons.inventory_2, color: Colors.grey.shade500, size: 40),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${appLocalizations.translate('quantity') ?? 'الكمية'}: ${item.quantity}',
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.warehouseName,
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'تالف / هوالك',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                                  _formatDate(item.createdAt),
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      if (item.orderNumber != 'غير مرتبط بطلب') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.shopping_bag, size: 16, color: theme.colorScheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              item.orderNumber,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                                        '${appLocalizations.translate('reason') ?? 'السبب'}:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.reason),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                                    _viewDamagedItemDetails(item);
                            },
                            icon: const Icon(Icons.visibility),
                                            label: Text(appLocalizations.translate('view_details') ?? 'عرض التفاصيل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle reporting new damaged item
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appLocalizations.translate('report_damaged_feature_coming_soon') ?? 'قريباً: إمكانية تسجيل العناصر التالفة'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: appLocalizations.translate('report_damaged_item') ?? 'تسجيل عنصر تالف',
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'البحث عن منتج...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  ),
                  onChanged: (value) {
                    _searchQuery = value.isNotEmpty ? value : null;
                  },
                  onSubmitted: (value) {
                    _searchQuery = value.isNotEmpty ? value : null;
                    _loadDamagedItems();
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _loadDamagedItems,
                child: const Text('بحث'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('الفترة: '),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('آخر 30 يوم'),
                selected: _days == 30,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _days = 30;
                      _loadDamagedItems();
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('آخر 90 يوم'),
                selected: _days == 90,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _days = 90;
                      _loadDamagedItems();
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('سنة كاملة'),
                selected: _days == 365,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _days = 365;
                      _loadDamagedItems();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewDamagedItemDetails(DamagedItemModel item) {
    final apiService = Provider.of<StockWarehouseApiService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<DamagedItemModel>(
          future: apiService.getDamagedItemDetail(item.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return SizedBox(
                height: 300,
                child: Center(child: Text('خطأ: ${snapshot.error}')),
              );
            } else if (!snapshot.hasData) {
              return const SizedBox(
                height: 300,
                child: Center(child: Text('لا توجد بيانات')),
              );
            }
            
            final details = snapshot.data!;
            
            return Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.productName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('تفاصيل العنصر التالف رقم: ${details.id}'),
                  const Divider(),
                  // Display other details
                  Expanded(
                    child: ListView(
                      children: [
                        // Image if available
                        if (details.imageUrl != null && details.imageUrl!.isNotEmpty) ...[
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                details.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 220,
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error, size: 48, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text('فشل تحميل الصورة', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        _buildDetailItem('العنصر', details.productName),
                        _buildDetailItem('الكمية', details.quantity.toString()),
                        _buildDetailItem('سبب التلف', details.reason),
                        _buildDetailItem('تاريخ التسجيل', _formatDate(details.createdAt)),
                        _buildDetailItem('المستودع', details.warehouseName),
                        _buildDetailItem('رقم الطلب', details.orderNumber),
                        _buildDetailItem('تم التسجيل بواسطة', details.reporterName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('إغلاق'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 