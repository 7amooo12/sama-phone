import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/services/invoice_service.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// هذا الملف يحتوي على مثال لكيفية استخدام API الفواتير للمحاسبين
/// يمكن استخدام هذا الكود كمرجع لتنفيذ شاشات المحاسب

class InvoiceApiExample extends StatefulWidget {
  const InvoiceApiExample({Key? key}) : super(key: key);

  @override
  State<InvoiceApiExample> createState() => _InvoiceApiExampleState();
}

class _InvoiceApiExampleState extends State<InvoiceApiExample> {
  final FlaskApiService _apiService = FlaskApiService();
  final InvoiceService _invoiceService = InvoiceService();
  final storage = const FlutterSecureStorage();
  
  bool _isLoading = false;
  String _errorMessage = '';
  List<FlaskInvoiceModel> _invoices = [];
  FlaskInvoiceModel? _selectedInvoice;
  
  @override
  void initState() {
    super.initState();
    // عند بدء الشاشة، تأكد من تسجيل الدخول ثم احصل على الفواتير
    _initializeAndLoadInvoices();
  }
  
  // تهيئة الخدمة وتحميل الفواتير
  Future<void> _initializeAndLoadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // تهيئة خدمة API
      await _apiService.init();
      
      // التحقق من تسجيل الدخول (إذا كان مسجلاً بالفعل، سيقوم بالتحقق من التوكن)
      if (!_apiService.isAuthenticated) {
        // إذا لم يكن مسجلاً، قم بتسجيل الدخول
        final loginResult = await _apiService.login('hima@sama.com', 'hima@123');
        
        if (!loginResult.isAuthenticated) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'فشل تسجيل الدخول: ${loginResult.error}';
          });
          return;
        }
      }
      
      // عند نجاح تسجيل الدخول، قم بالحصول على الفواتير
      await _loadInvoices();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ: ${e.toString()}';
      });
    }
  }
  
  // تحميل الفواتير
  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // استخدام خدمة الفواتير للحصول على جميع الفواتير
      final invoices = await _invoiceService.getInvoices();
      
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل تحميل الفواتير: ${e.toString()}';
      });
    }
  }
  
  // البحث عن فواتير
  Future<void> _searchInvoices(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // استخدام خدمة الفواتير للبحث عن الفواتير
      final invoices = await _invoiceService.searchInvoices(query);
      
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل البحث عن الفواتير: ${e.toString()}';
      });
    }
  }
  
  // الحصول على تفاصيل فاتورة محددة
  Future<void> _loadInvoiceDetails(int invoiceId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // استخدام خدمة الفواتير للحصول على تفاصيل فاتورة محددة
      final invoice = await _invoiceService.getInvoice(invoiceId);
      
      setState(() {
        _selectedInvoice = invoice;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل تحميل تفاصيل الفاتورة: ${e.toString()}';
      });
    }
  }
  
  // الحصول على حركة منتج
  Future<List<Map<String, dynamic>>> _getProductMovement(int productId) async {
    try {
      // استخدام خدمة الفواتير للحصول على حركة المنتج
      return await _invoiceService.getProductMovement(productId);
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تحميل حركة المنتج: ${e.toString()}';
      });
      return [];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مثال على استخدام API الفواتير'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeAndLoadInvoices,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // شريط البحث
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'البحث في الفواتير',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _searchInvoices(value);
                          } else {
                            _loadInvoices();
                          }
                        },
                      ),
                    ),
                    
                    // عدد الفواتير
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'عدد الفواتير: ${_invoices.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    
                    // قائمة الفواتير
                    Expanded(
                      child: _invoices.isEmpty
                          ? const Center(
                              child: Text('لا توجد فواتير'),
                            )
                          : ListView.builder(
                              itemCount: _invoices.length,
                              itemBuilder: (context, index) {
                                final invoice = _invoices[index];
                                return Card(
                                  margin: const EdgeInsets.all(8.0),
                                  child: ListTile(
                                    title: Text(
                                      'فاتورة #${invoice.id} - ${invoice.customerName}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('التاريخ: ${invoice.createdAt.toString().substring(0, 10)}'),
                                        Text('المبلغ: ${invoice.finalAmount}'),
                                        Text('الحالة: ${invoice.status}'),
                                      ],
                                    ),
                                    trailing: ElevatedButton(
                                      child: const Text('التفاصيل'),
                                      onPressed: () => _loadInvoiceDetails(invoice.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // تفاصيل الفاتورة المحددة
                    if (_selectedInvoice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16.0),
                            topRight: Radius.circular(16.0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'تفاصيل الفاتورة #${_selectedInvoice!.id}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _selectedInvoice = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(),
                            Text('العميل: ${_selectedInvoice!.customerName}'),
                            if (_selectedInvoice!.customerPhone != null)
                              Text('الهاتف: ${_selectedInvoice!.customerPhone}'),
                            if (_selectedInvoice!.customerEmail != null)
                              Text('البريد الإلكتروني: ${_selectedInvoice!.customerEmail}'),
                            Text('الإجمالي: ${_selectedInvoice!.totalAmount}'),
                            Text('الخصم: ${_selectedInvoice!.discount}'),
                            Text('المبلغ النهائي: ${_selectedInvoice!.finalAmount}'),
                            Text('الحالة: ${_selectedInvoice!.status}'),
                            Text('التاريخ: ${_selectedInvoice!.createdAt.toString()}'),
                            const SizedBox(height: 16),
                            const Text(
                              'المنتجات:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedInvoice!.items == null || _selectedInvoice!.items!.isEmpty)
                              const Text('لا توجد منتجات')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _selectedInvoice!.items!.length,
                                itemBuilder: (context, index) {
                                  final item = _selectedInvoice!.items![index];
                                  return ListTile(
                                    title: Text(item.productName),
                                    subtitle: Text('الكمية: ${item.quantity}'),
                                    trailing: Text('السعر: ${item.price}'),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

/*
  كيفية استخدام هذا المثال في المشروع:
  
  1. قم بتضمين هذا الملف في المشروع (تم وضعه في مجلد examples)
  2. استخدم الدالة `_initializeAndLoadInvoices()` لتسجيل الدخول وتحميل الفواتير
  3. استخدم الدالة `_loadInvoices()` لتحميل جميع الفواتير
  4. استخدم الدالة `_searchInvoices(query)` للبحث في الفواتير
  5. استخدم الدالة `_loadInvoiceDetails(invoiceId)` لتحميل تفاصيل فاتورة محددة
  6. استخدم الدالة `_getProductMovement(productId)` للحصول على حركة منتج
  
  ملاحظات هامة:
  - تأكد من أن المستخدم مسجل الدخول بصلاحيات محاسب
  - تأكد من وجود اتصال بالإنترنت
  - تعامل مع الأخطاء بشكل مناسب
  - استخدم `setState()` لتحديث واجهة المستخدم
*/ 