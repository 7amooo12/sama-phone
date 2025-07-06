import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';

import 'package:smartbiztracker_new/widgets/admin/order_management_widget.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_invoices_screen.dart';
import 'package:smartbiztracker_new/screens/shared/pending_orders_screen.dart';
import 'package:smartbiztracker_new/screens/admin/electronic_payment_management_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_products_screen.dart';
import 'package:smartbiztracker_new/screens/shared/product_movement_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/models/advance_model.dart';
import 'package:smartbiztracker_new/services/advance_service.dart';
import 'package:smartbiztracker_new/widgets/shared/accounts_tab_widget.dart';
import 'package:smartbiztracker_new/screens/shared/add_advance_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/services/invoice_service.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../shared/store_invoices_screen.dart';
import 'accountant_rewards_management_screen.dart';
import 'package:smartbiztracker_new/widgets/shared/warehouse_dispatch_tab.dart';
import 'package:smartbiztracker_new/screens/attendance/worker_attendance_reports_wrapper.dart';
import 'package:smartbiztracker_new/screens/shared/warehouse_release_orders_screen.dart';

import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/shared/unified_warehouse_interface.dart';
import 'package:smartbiztracker_new/screens/shared/qr_scanner_screen.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/widgets/accountant/enhanced_workers_tab_widget.dart';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime; // لتتبع آخر ضغطة على زر العودة
 // Toggle for sidebar widgets

  // Animation controllers for advance cards flip effect
  final Map<String, AnimationController> _flipControllers = {};
  final Map<String, Animation<double>> _flipAnimations = {};
  final Set<String> _flippedCards = {};

  // بيانات للإحصائيات المالية والرسوم البيانية
  bool _isLoading = true;
  List<dynamic> _recentInvoices = []; // Changed to dynamic to handle API response safely
  Map<String, double> _revenueByCategory = {};
  double _totalRevenue = 0;
  double _totalPending = 0;
  double _totalExpenses = 0; // إجمالي المصروفات
  double _availableBalance = 0; // الرصيد المتاح
  int _pendingInvoices = 0;
  int _paidInvoices = 0;
  int _canceledInvoices = 0;

  // تنسيق العملة والتاريخ
  final _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _invoiceService = InvoiceService();
  final _advanceService = AdvanceService();

  // بيانات العملاء ومديونياتهم
  List<Map<String, dynamic>> _clientDebts = [];
  bool _isLoadingClients = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 13, vsync: this); // تحديث عدد التابات بعد إضافة تاب تقارير الحضور
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });

      // تحميل بيانات العملاء عند فتح تاب الحسابات (index 9)
      if (_tabController.index == 9 && _clientDebts.isEmpty && !_isLoadingClients) {
        _loadClientDebts();
      }

      // تحميل بيانات المخازن عند فتح تاب المخازن (index 7)
      if (_tabController.index == 7) {
        _loadWarehouseDataIfNeeded();
      }
    });

    // تحميل البيانات المالية عند بدء الشاشة
    _loadFinancialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for initial tab index argument
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('initialTabIndex')) {
      final initialTabIndex = arguments['initialTabIndex'] as int?;
      if (initialTabIndex != null && initialTabIndex >= 0 && initialTabIndex < _tabController.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tabController.animateTo(initialTabIndex);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();

    // Dispose all flip animation controllers to prevent memory leaks
    for (var controller in _flipControllers.values) {
      controller.dispose();
    }
    _flipControllers.clear();
    _flipAnimations.clear();
    _flippedCards.clear();

    super.dispose();
  }

  // Helper methods for safe data extraction with type checking
  String _safeExtractString(dynamic source, List<String> fieldNames, String defaultValue) {
    try {
      for (final fieldName in fieldNames) {
        dynamic value;
        if (source is Map<String, dynamic>) {
          value = source[fieldName];
        } else {
          // Try to access as object property
          try {
            // Check if source has a toJson method
            if (source != null) {
              try {
                final jsonMap = source.toJson();
                if (jsonMap is Map<String, dynamic>) {
                  value = jsonMap[fieldName];
                }
              } catch (e) {
                // If toJson fails, try direct property access
                value = null;
              }
            }
          } catch (e) {
            continue;
          }
        }

        if (value != null) {
          return value.toString();
        }
      }
      return defaultValue;
    } catch (e) {
      AppLogger.warning('خطأ في استخراج النص الآمن: $e');
      return defaultValue;
    }
  }

  double _safeExtractDouble(dynamic source, List<String> fieldNames, double defaultValue) {
    try {
      for (final fieldName in fieldNames) {
        dynamic value;
        if (source is Map<String, dynamic>) {
          value = source[fieldName];
        } else {
          try {
            // Check if source has a toJson method
            if (source != null) {
              try {
                final jsonMap = source.toJson();
                if (jsonMap is Map<String, dynamic>) {
                  value = jsonMap[fieldName];
                }
              } catch (e) {
                // If toJson fails, continue to next field
                value = null;
              }
            }
          } catch (e) {
            continue;
          }
        }

        if (value != null) {
          if (value is num) {
            return value.toDouble();
          } else if (value is String) {
            final parsed = double.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
      }
      return defaultValue;
    } catch (e) {
      AppLogger.warning('خطأ في استخراج الرقم الآمن: $e');
      return defaultValue;
    }
  }

  DateTime? _safeExtractDateTime(dynamic source, List<String> fieldNames) {
    try {
      for (final fieldName in fieldNames) {
        dynamic value;
        if (source is Map<String, dynamic>) {
          value = source[fieldName];
        } else {
          try {
            // Check if source has a toJson method
            if (source != null) {
              try {
                final jsonMap = source.toJson();
                if (jsonMap is Map<String, dynamic>) {
                  value = jsonMap[fieldName];
                }
              } catch (e) {
                // If toJson fails, continue to next field
                value = null;
              }
            }
          } catch (e) {
            continue;
          }
        }

        if (value != null) {
          // Handle DateTime object directly
          if (value is DateTime) {
            return value;
          }
          // Handle string representation
          else if (value is String && value.isNotEmpty) {
            final parsed = DateTime.tryParse(value);
            if (parsed != null) return parsed;
          }
          // Handle timestamp (int/double)
          else if (value is num) {
            try {
              return DateTime.fromMillisecondsSinceEpoch(value.toInt());
            } catch (e) {
              // Try as seconds instead of milliseconds
              try {
                return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
              } catch (e2) {
                continue;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      AppLogger.warning('خطأ في استخراج التاريخ الآمن: $e');
      return null;
    }
  }

  // Create or get flip animation controller for advance card
  AnimationController _getFlipController(String advanceId) {
    if (!_flipControllers.containsKey(advanceId)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      _flipControllers[advanceId] = controller;
      _flipAnimations[advanceId] = animation;
    }
    // Safe return with null check
    return _flipControllers[advanceId] ?? AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
  }

  // Toggle flip animation for advance card
  void _toggleAdvanceCardFlip(String advanceId) {
    final controller = _getFlipController(advanceId);

    if (_flippedCards.contains(advanceId)) {
      controller.reverse();
      _flippedCards.remove(advanceId);
    } else {
      controller.forward();
      _flippedCards.add(advanceId);
    }
  }

  // تحميل البيانات المالية من API مع معالجة شاملة للأخطاء
  Future<void> _loadFinancialData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 بدء تحميل البيانات المالية...');

      // جلب الفواتير مع معالجة الأخطاء
      List<dynamic> invoices = [];
      try {
        invoices = await _invoiceService.getInvoices();
        debugPrint('✅ تم جلب ${invoices.length} فاتورة بنجاح');
      } catch (invoiceError) {
        debugPrint('⚠️ خطأ في جلب الفواتير: $invoiceError');
        // استخدام قائمة فارغة كبديل آمن
        invoices = [];
      }

      // حساب الإحصائيات المالية مع قيم افتراضية آمنة
      double totalRevenue = 0;
      double totalPending = 0;
      int pendingCount = 0;
      int paidCount = 0;
      int canceledCount = 0;
      final Map<String, double> categoryRevenue = {};

      // معالجة آمنة للفواتير مع دعم الأنواع الديناميكية
      for (var invoice in invoices) {
        try {
          // التحقق من صحة البيانات قبل المعالجة - دعم كل من FlaskInvoiceModel والبيانات الديناميكية
          double finalAmount = 0.0;
          String status = 'unknown';

          // محاولة الوصول للبيانات بطرق مختلفة
          if (invoice is Map<String, dynamic>) {
            // إذا كانت البيانات من نوع Map
            finalAmount = (invoice['final_amount'] ?? invoice['finalAmount'] ?? invoice['amount'] ?? 0.0).toDouble();
            status = (invoice['status'] ?? 'unknown').toString();
          } else {
            // إذا كانت البيانات من نوع FlaskInvoiceModel أو كائن آخر
            try {
              finalAmount = invoice.finalAmount?.toDouble() ?? 0.0;
              status = invoice.status?.toString() ?? 'unknown';
            } catch (e) {
              // محاولة الوصول كخصائص ديناميكية
              finalAmount = (invoice['final_amount'] ?? invoice['finalAmount'] ?? invoice['amount'] ?? 0.0).toDouble();
              status = (invoice['status'] ?? 'unknown').toString();
            }
          }

          // إجمالي المبيعات
          totalRevenue += finalAmount;

          // إحصاءات حسب الحالة
          switch (status.toLowerCase()) {
            case 'pending':
              pendingCount++;
              totalPending += finalAmount;
              break;
            case 'completed':
            case 'paid':
              paidCount++;
              break;
            case 'cancelled':
            case 'canceled':
              canceledCount++;
              break;
          }

          // تصنيف الإيرادات حسب الفئة (إذا كانت متوفرة)
          try {
            var items;
            if (invoice is Map<String, dynamic>) {
              items = invoice['items'];
            } else {
              items = invoice.items;
            }

            if (items != null && items is List && items.isNotEmpty) {
              for (var item in items) {
                try {
                  String category = 'أخرى';
                  double itemTotal = 0.0;

                  if (item is Map<String, dynamic>) {
                    category = item['category']?.toString() ?? 'أخرى';
                    itemTotal = (item['total'] ?? 0.0).toDouble();
                  } else {
                    category = item.category?.toString() ?? 'أخرى';
                    itemTotal = item.total?.toDouble() ?? 0.0;
                  }

                  categoryRevenue[category] = (categoryRevenue[category] ?? 0) + itemTotal;
                } catch (itemError) {
                  debugPrint('⚠️ خطأ في معالجة عنصر الفاتورة: $itemError');
                  // تجاهل العنصر المعطوب والمتابعة
                  continue;
                }
              }
            }
          } catch (itemsError) {
            debugPrint('⚠️ خطأ في معالجة عناصر الفاتورة: $itemsError');
            // تجاهل عناصر الفاتورة المعطوبة والمتابعة
          }
        } catch (invoiceProcessError) {
          debugPrint('⚠️ خطأ في معالجة فاتورة: $invoiceProcessError');
          // تجاهل الفاتورة المعطوبة والمتابعة
          continue;
        }
      }

      // حساب المصروفات والرصيد (بيانات تجريبية - يمكن ربطها بقاعدة البيانات لاحقاً)
      final double totalExpenses = totalRevenue * 0.3; // افتراض أن المصروفات 30% من الإيرادات
      final double availableBalance = totalRevenue - totalExpenses;

      // إعداد قائمة الفواتير الحديثة بشكل آمن مع دعم الأنواع الديناميكية
      List<dynamic> recentInvoices = [];
      try {
        recentInvoices = List.from(invoices);
        recentInvoices.sort((a, b) {
          try {
            DateTime aDate = DateTime.now();
            DateTime bDate = DateTime.now();

            // محاولة الحصول على التاريخ بطرق مختلفة
            if (a is Map<String, dynamic>) {
              final dateStr = a['created_at'] ?? a['createdAt'];
              if (dateStr != null) {
                aDate = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
              }
            } else {
              try {
                aDate = a.createdAt ?? DateTime.now();
              } catch (e) {
                final dateStr = a['created_at'] ?? a['createdAt'];
                if (dateStr != null) {
                  aDate = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
                }
              }
            }

            if (b is Map<String, dynamic>) {
              final dateStr = b['created_at'] ?? b['createdAt'];
              if (dateStr != null) {
                bDate = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
              }
            } else {
              try {
                bDate = b.createdAt ?? DateTime.now();
              } catch (e) {
                final dateStr = b['created_at'] ?? b['createdAt'];
                if (dateStr != null) {
                  bDate = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
                }
              }
            }

            return bDate.compareTo(aDate);
          } catch (sortError) {
            debugPrint('⚠️ خطأ في ترتيب الفواتير: $sortError');
            return 0;
          }
        });

        if (recentInvoices.length > 5) {
          recentInvoices = recentInvoices.sublist(0, 5);
        }
      } catch (recentInvoicesError) {
        debugPrint('⚠️ خطأ في إعداد الفواتير الحديثة: $recentInvoicesError');
        recentInvoices = [];
      }

      // حفظ البيانات المحسوبة في حالة الـ State مع فحص mounted
      if (mounted) {
        setState(() {
          _recentInvoices = recentInvoices;
          _totalRevenue = totalRevenue;
          _totalPending = totalPending;
          _totalExpenses = totalExpenses;
          _availableBalance = availableBalance;
          _pendingInvoices = pendingCount;
          _paidInvoices = paidCount;
          _canceledInvoices = canceledCount;
          _revenueByCategory = categoryRevenue;
          _isLoading = false;
        });

        debugPrint('✅ تم تحديث البيانات المالية بنجاح');
        debugPrint('📊 إجمالي الإيرادات: $totalRevenue');
        debugPrint('📊 المبالغ المعلقة: $totalPending');
        debugPrint('📊 عدد الفواتير: ${invoices.length}');
      }

    } catch (e, stackTrace) {
      debugPrint('❌ خطأ عام في تحميل البيانات المالية: $e');
      debugPrint('📍 تفاصيل الخطأ: $stackTrace');

      // تعيين قيم افتراضية آمنة في حالة الخطأ
      if (mounted) {
        setState(() {
          _recentInvoices = [];
          _totalRevenue = 0.0;
          _totalPending = 0.0;
          _totalExpenses = 0.0;
          _availableBalance = 0.0;
          _pendingInvoices = 0;
          _paidInvoices = 0;
          _canceledInvoices = 0;
          _revenueByCategory = {};
          _isLoading = false;
        });

        // عرض رسالة خطأ للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تعذر تحميل البيانات المالية. سيتم عرض بيانات افتراضية.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () => _loadFinancialData(),
            ),
          ),
        );
      }
    }
  }

  // تحميل بيانات العملاء ومديونياتهم
  Future<void> _loadClientDebts() async {
    setState(() {
      _isLoadingClients = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final supabase = supabaseProvider.client;

      debugPrint('🔄 بدء تحميل بيانات العملاء...');
      debugPrint('🔐 معرف المستخدم الحالي: ${supabase.auth.currentUser?.id}');

      // التحقق من حالة المصادقة
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ المستخدم غير مسجل الدخول');
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // التحقق من ملف المستخدم الحالي
      final currentUserProfile = await supabase
          .from('user_profiles')
          .select('id, name, role, status')
          .eq('id', currentUser.id)
          .single();

      debugPrint('👤 ملف المستخدم الحالي: ${currentUserProfile.toString()}');

      // أولاً: جلب بيانات العملاء مع تشخيص مفصل
      debugPrint('🔍 محاولة جلب بيانات العملاء...');

      // First, check all clients regardless of status for debugging
      final allClientsResponse = await supabase
          .from('user_profiles')
          .select('id, name, email, phone_number, role, status')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .order('name');

      debugPrint('📊 إجمالي العملاء في النظام: ${allClientsResponse.length}');
      for (var client in allClientsResponse) {
        debugPrint('   👤 ${client['name']} (${client['id']}) - الحالة: ${client['status']}');
      }

      // Now get approved and active clients (support both status values)
      final clientsResponse = await supabase
          .from('user_profiles')
          .select('id, name, email, phone_number, role, status')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .or('status.eq.approved,status.eq.active') // Support both status values
          .order('name');

      debugPrint('📊 العملاء المعتمدون والنشطون: ${clientsResponse.length}');
      debugPrint('📋 بيانات العملاء المعتمدين والنشطين: ${clientsResponse.toString()}');

      // ثانياً: جلب بيانات المحافظ للعملاء
      debugPrint('💰 محاولة جلب بيانات المحافظ...');
      final walletsResponse = await supabase
          .from('wallets')
          .select('user_id, balance, updated_at, status, role')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .eq('status', 'active');

      debugPrint('💳 تم جلب ${walletsResponse.length} محفظة');
      debugPrint('💼 بيانات المحافظ: ${walletsResponse.toString()}');

      debugPrint('💰 تم جلب ${walletsResponse.length} محفظة');

      // إنشاء خريطة للمحافظ للبحث السريع
      final walletsMap = <String, Map<String, dynamic>>{};
      for (final wallet in walletsResponse) {
        final userId = wallet['user_id'] as String;
        walletsMap[userId] = wallet;
        debugPrint('💰 محفظة للمستخدم $userId: ${wallet['balance']} جنيه (حالة: ${wallet['status']})');
      }

      debugPrint('🗂️ تم إنشاء خريطة المحافظ: ${walletsMap.keys.length} محفظة');
      debugPrint('🔑 معرفات المحافظ: ${walletsMap.keys.toList()}');

      // تنسيق البيانات
      final List<Map<String, dynamic>> formattedClients = [];

      for (var client in clientsResponse) {
        final clientId = client['id'] as String;
        final wallet = walletsMap[clientId];

        double balance = 0.0;
        DateTime lastUpdate = DateTime.now();

        if (wallet != null) {
          balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
          lastUpdate = DateTime.tryParse(wallet['updated_at']?.toString() ?? '') ?? DateTime.now();
          debugPrint('✅ العميل ${client['name']} (ID: $clientId) لديه محفظة برصيد: $balance جنيه');
        } else {
          debugPrint('⚠️ العميل ${client['name']} (ID: $clientId) ليس لديه محفظة نشطة');
        }

        formattedClients.add({
          'id': clientId,
          'name': client['name'] ?? 'عميل غير معروف',
          'email': client['email'] ?? '',
          'phone': client['phone_number'] ?? '',
          'balance': balance,
          'lastUpdate': lastUpdate,
          'hasWallet': wallet != null,
        });

        debugPrint('👤 العميل: ${client['name']} - الرصيد: $balance جنيه - الهاتف: ${client['phone_number'] ?? 'غير محدد'}');
      }

      // ترتيب العملاء حسب الرصيد (الأعلى أولاً)
      formattedClients.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

      debugPrint('✅ تم تنسيق بيانات ${formattedClients.length} عميل');

      setState(() {
        _clientDebts = formattedClients;
        _isLoadingClients = false;
      });

      // إظهار رسالة نجاح
      if (mounted && formattedClients.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('تم تحميل ${formattedClients.length} عميل بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e, stackTrace) {
      debugPrint('❌ خطأ في تحميل بيانات العملاء: $e');
      debugPrint('📍 تفاصيل الخطأ: $stackTrace');

      setState(() {
        _isLoadingClients = false;
      });

      // تحديد نوع الخطأ وإظهار رسالة مناسبة
      String errorMessage = 'خطأ غير معروف';
      String errorDetails = '';

      if (e.toString().contains('RLS')) {
        errorMessage = 'خطأ في صلاحيات الوصول للبيانات';
        errorDetails = 'يرجى التأكد من صلاحيات المحاسب في قاعدة البيانات';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'خطأ في الاتصال بقاعدة البيانات';
        errorDetails = 'يرجى التحقق من الاتصال بالإنترنت';
      } else if (e.toString().contains('auth')) {
        errorMessage = 'خطأ في المصادقة';
        errorDetails = 'يرجى تسجيل الدخول مرة أخرى';
      } else {
        errorMessage = 'فشل في تحميل بيانات العملاء';
        errorDetails = e.toString();
      }

      // عرض رسالة خطأ مفصلة للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMessage)),
                  ],
                ),
                if (errorDetails.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorDetails,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        _loadClientDebts(); // إعادة المحاولة
                      },
                      child: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  // Navigate to create new invoice
  void _navigateToAddInvoice() {
    Navigator.of(context).pushNamed(AppRoutes.createInvoice);
  }



  // دالة الاتصال بالعميل
  Future<void> _makePhoneCall(String phoneNumber) async {
    final contextToUse = context;

    if (phoneNumber.isEmpty) {
      if (mounted && contextToUse.mounted) {
        ScaffoldMessenger.of(contextToUse).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Text('رقم الهاتف غير متوفر'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch $phoneUri';
      }
    } catch (e) {
      if (mounted && contextToUse.mounted) {
        ScaffoldMessenger.of(contextToUse).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('لا يمكن فتح تطبيق الهاتف'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }







  // دالة لتحميل بيانات المخازن مع تشخيص شامل للمصادقة
  Future<void> _loadWarehouseDataIfNeeded() async {
    try {
      AppLogger.info('🏢 === بدء تحميل بيانات المخازن للمحاسب ===');

      // التحقق من حالة المصادقة أولاً
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.client.auth.currentUser;

      AppLogger.info('🔍 تشخيص المصادقة للمحاسب:');
      AppLogger.info('  - المستخدم الحالي: ${currentUser?.id ?? 'null'}');
      AppLogger.info('  - البريد الإلكتروني: ${currentUser?.email ?? 'null'}');
      AppLogger.info('  - SupabaseProvider مصادق: ${supabaseProvider.isAuthenticated}');
      AppLogger.info('  - SupabaseProvider المستخدم: ${supabaseProvider.user?.email ?? 'null'}');

      if (currentUser == null) {
        AppLogger.error('❌ المحاسب غير مسجل الدخول - لا يمكن تحميل المخازن');
        return;
      }

      // التحقق من ملف المستخدم
      try {
        final userProfile = await supabaseProvider.client
            .from('user_profiles')
            .select('id, email, role, status, name')
            .eq('id', currentUser.id)
            .single();

        AppLogger.info('👤 ملف المحاسب:');
        AppLogger.info('  - الاسم: ${userProfile['name']}');
        AppLogger.info('  - الدور: ${userProfile['role']}');
        AppLogger.info('  - الحالة: ${userProfile['status']}');

        if (userProfile['role'] != 'accountant') {
          AppLogger.warning('⚠️ دور المستخدم ليس محاسب: ${userProfile['role']}');
        }

        if (userProfile['status'] != 'approved') {
          AppLogger.warning('⚠️ حالة المحاسب ليست معتمدة: ${userProfile['status']}');
        }

      } catch (profileError) {
        AppLogger.error('❌ خطأ في جلب ملف المحاسب: $profileError');
        return;
      }

      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);

      // تحميل المخازن إذا لم تكن محملة مسبقاً
      if (warehouseProvider.warehouses.isEmpty && !warehouseProvider.isLoadingWarehouses) {
        AppLogger.info('📦 بدء تحميل المخازن للمحاسب...');
        await warehouseProvider.loadWarehouses(forceRefresh: true);
        AppLogger.info('✅ انتهى تحميل المخازن - العدد: ${warehouseProvider.warehouses.length}');

        // تسجيل تفصيلي للمخازن المحملة
        for (int i = 0; i < warehouseProvider.warehouses.length && i < 3; i++) {
          final warehouse = warehouseProvider.warehouses[i];
          AppLogger.info('🏢 مخزن ${i + 1}: ${warehouse.name} (${warehouse.id})');
        }
      } else {
        AppLogger.info('📦 المخازن محملة مسبقاً - العدد: ${warehouseProvider.warehouses.length}');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات المخازن للمحاسب: $e');
    }
  }

  // منطق التعامل مع زر العودة
  Future<bool> _onWillPop() async {
    // إذا كان مفتوح الدرج الجانبي، أغلقه عند الضغط على العودة بدلاً من إغلاق التطبيق
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }

    // إذا كنا في شاشة غير الشاشة الرئيسية، عد إلى الشاشة الرئيسية بدلاً من إغلاق التطبيق
    if (_selectedIndex != 0) {
      _tabController.animateTo(0);
      return false;
    }

    // في الشاشة الرئيسية، يتطلب ضغطتين متتاليتين خلال ثانيتين للخروج من التطبيق
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اضغط مرة أخرى للخروج من التطبيق'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A0A), // Professional luxurious black
                Color(0xFF1A1A2E), // Darkened blue-black
                Color(0xFF16213E), // Deep blue-black
                Color(0xFF0F0F23), // Rich dark blue
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar with modern design
                _buildModernAppBar(userModel),

                // Enhanced Tab Bar with luxury styling
                _buildModernTabBar(theme),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 0. الرئيسية (Dashboard) - Priority 1
                      _buildSafeWidget(() => _buildModernDashboardTab(theme, userModel.name)),

                      // 1. المدفوعات (Payments) - Priority 2
                      const ElectronicPaymentManagementScreen(),

                      // 2. الفواتير (Invoices) - Priority 3
                      const AccountantInvoicesScreen(),

                      // 3. فواتير المتجر (Store Invoices) - Priority 4
                      const StoreInvoicesScreen(),

                      // 4. الطلبات المعلقة (Pending Orders) - Priority 5
                      const PendingOrdersScreen(),

                      // 5. الطلبات (Orders) - Priority 6
                      const OrderManagementWidget(
                        userRole: 'accountant',
                        showHeader: false,
                        showSearchBar: true,
                        showFilterOptions: true,
                        showStatusFilters: true,
                        showStatusFilter: true,
                        showDateFilter: true,
                        isEmbedded: true,
                      ),

                      // 6. حركة صنف (Item Movement) - Priority 7
                      const ProductMovementScreen(),

                      // 7. المخازن (Warehouses) - Priority 8
                      const UnifiedWarehouseInterface(userRole: 'accountant'),

                      // 8. المنتجات (Products) - Remaining tabs
                      const AccountantProductsScreen(),

                      // 9. الحسابات (Accounts) - Remaining tabs
                      const AccountsTabWidget(
                        userRole: 'accountant',
                        showHeader: false,
                      ),

                      // 10. العمال (Workers) - Remaining tabs
                      const EnhancedWorkersTabWidget(),

                      // 11. أذون صرف (Warehouse Release Orders) - Remaining tabs
                      const WarehouseReleaseOrdersScreen(
                        userRole: 'accountant', // تمرير دور المحاسب للعرض فقط
                      ),

                      // 12. تقارير الحضور (Worker Attendance Reports) - Remaining tabs
                      const WorkerAttendanceReportsWrapper(userRole: 'accountant'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        drawer: MainDrawer(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          currentRoute: AppRoutes.accountantDashboard,
        ),
      ),
    );
  }



  // Modern App Bar with luxury design
  Widget _buildModernAppBar(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Menu Button with green glow effect
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.green.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Welcome Text with luxury styling
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getWelcomeMessage(),
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFF10B981),
                      Colors.white,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    userModel.name,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // QR Scanner Button
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                  AccountantThemeConfig.secondaryGreen.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.qrScanner);
              },
              icon: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'مسح QR للمنتجات',
            ),
          ),

          // User Avatar with green glow
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userModel.name.isNotEmpty
                    ? userModel.name[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Tab Bar with luxury design
  Widget _buildModernTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.9),
            const Color(0xFF334155).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF10B981),
                Color(0xFF059669),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.all(4),
          tabs: [
            // 1. الرئيسية (Main/Dashboard) - Priority 1
            _buildModernTab(
              icon: Icons.dashboard_rounded,
              text: 'الرئيسية',
              isSelected: _tabController.index == 0,
              gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
            ),
            // 2. المدفوعات (Payments) - Priority 2
            _buildModernTab(
              icon: Icons.payment_rounded,
              text: 'المدفوعات',
              isSelected: _tabController.index == 1,
              gradient: [const Color(0xFF3F51B5), const Color(0xFF303F9F)],
            ),
            // 3. الفواتير (Invoices) - Priority 3
            _buildModernTab(
              icon: Icons.receipt_long_rounded,
              text: 'الفواتير',
              isSelected: _tabController.index == 2,
              gradient: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
            ),
            // 4. فواتير المتجر (Store Invoices) - Priority 4
            _buildModernTab(
              icon: Icons.folder_copy_rounded,
              text: 'فواتير المتجر',
              isSelected: _tabController.index == 3,
              gradient: [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
            ),
            // 5. الطلبات المعلقة (Pending Orders) - Priority 5
            _buildModernTab(
              icon: Icons.pending_actions_rounded,
              text: 'الطلبات المعلقة',
              isSelected: _tabController.index == 4,
              gradient: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            ),
            // 6. الطلبات (Orders) - Priority 6
            _buildModernTab(
              icon: Icons.shopping_cart_rounded,
              text: 'الطلبات',
              isSelected: _tabController.index == 5,
              gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
            // 7. حركة صنف (Item Movement) - Priority 7
            _buildModernTab(
              icon: Icons.analytics_rounded,
              text: 'حركة صنف',
              isSelected: _tabController.index == 6,
              gradient: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
            ),
            // 8. المخازن (Warehouses) - Priority 8
            _buildModernTab(
              icon: Icons.warehouse_rounded,
              text: 'المخازن',
              isSelected: _tabController.index == 7,
              gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
            ),
            // Remaining tabs in their relative order
            _buildModernTab(
              icon: Icons.inventory_2_rounded,
              text: 'المنتجات',
              isSelected: _tabController.index == 8,
              gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
            ),
            _buildModernTab(
              icon: Icons.account_balance_rounded,
              text: 'الحسابات',
              isSelected: _tabController.index == 9,
              gradient: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
            ),
            _buildModernTab(
              icon: Icons.people_rounded,
              text: 'العمال',
              isSelected: _tabController.index == 10,
              gradient: [const Color(0xFF16A085), const Color(0xFF138D75)],
            ),
            _buildModernTab(
              icon: Icons.local_shipping_rounded,
              text: 'أذون صرف',
              isSelected: _tabController.index == 11,
              gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
            ),
            _buildModernTab(
              icon: Icons.access_time_rounded,
              text: 'تقارير الحضور',
              isSelected: _tabController.index == 12,
              gradient: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get welcome message
  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else if (hour < 17) {
      return 'مساء الخير';
    } else {
      return 'مساء الخير';
    }
  }

  // Modern Tab Builder
  Widget _buildModernTab({
    required IconData icon,
    required String text,
    required bool isSelected,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: isSelected
          ? BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Dashboard Tab with luxury design and comprehensive error handling
  Widget _buildModernDashboardTab(ThemeData theme, String userName) {
    return _isLoading
        ? _buildLoadingState()
        : RefreshIndicator(
            onRefresh: _loadFinancialData,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: AnimationLimiter(
                child: Column(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 600),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: [
                      // Welcome message
                      _buildWelcomeMessage(userName),
                      const SizedBox(height: 24),

                      // Financial Overview Cards with error handling
                      _buildSafeWidget(() => _buildFinancialOverviewCards()),
                      const SizedBox(height: 24),

                      // Quick Actions with error handling
                      _buildSafeWidget(() => _buildQuickActionsSection()),
                      const SizedBox(height: 24),

                      // Financial Statistics Chart with error handling
                      _buildSafeWidget(() => _buildFinancialChart()),
                      const SizedBox(height: 24),

                      // Recent Invoices with error handling
                      _buildSafeWidget(() => _buildRecentInvoicesSection()),
                      const SizedBox(height: 24),

                      // Invoice Status Summary with error handling
                      _buildSafeWidget(() => _buildInvoiceStatusSummary()),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  // Safe widget wrapper to prevent crashes
  Widget _buildSafeWidget(Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      debugPrint('⚠️ خطأ في بناء الويدجت: $e');
      return _buildErrorPlaceholder();
    }
  }

  // Error placeholder widget
  Widget _buildErrorPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تعذر تحميل هذا القسم. يرجى المحاولة مرة أخرى.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // Welcome message widget
  Widget _buildWelcomeMessage(String userName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'لوحة تحكم المحاسب',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Missing method: _buildInvoiceStatusSummary
  Widget _buildInvoiceStatusSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A0A),
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            const Color(0xFF0F0F23),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص حالة الفواتير',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInvoiceStatusItem(
                  'مدفوعة',
                  _paidInvoices,
                  const Color(0xFF10B981),
                  Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInvoiceStatusItem(
                  'معلقة',
                  _pendingInvoices,
                  const Color(0xFFF59E0B),
                  Icons.pending_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInvoiceStatusItem(
                  'ملغية',
                  _canceledInvoices,
                  const Color(0xFFEF4444),
                  Icons.cancel_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method for invoice status items
  Widget _buildInvoiceStatusItem(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Safe invoice item builder with comprehensive error handling and type safety
  Widget _buildInvoiceItem(dynamic invoice) {
    try {
      // Enhanced safe data extraction with strict type checking
      final invoiceId = _safeExtractString(invoice, ['id'], 'غير محدد');

      // Safe amount extraction with multiple fallback fields
      final amount = _safeExtractDouble(invoice, ['finalAmount', 'final_amount', 'amount', 'total_amount'], 0.0);

      // Safe status extraction
      final status = _safeExtractString(invoice, ['status'], 'غير محدد');

      // Enhanced DateTime extraction with comprehensive error handling
      final createdAt = _safeExtractDateTime(invoice, ['createdAt', 'created_at', 'date']);

      // Safe customer name extraction
      final customerName = _safeExtractString(invoice, ['customerName', 'customer_name', 'customer'], 'عميل غير معروف');

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فاتورة #$invoiceId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currencyFormat.format(amount)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy').format(createdAt!),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('⚠️ خطأ في بناء عنصر الفاتورة: $e');
      // Return a safe placeholder for broken invoice data
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'فاتورة تالفة - تعذر عرض البيانات',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Helper methods for invoice status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
      case 'مدفوعة':
        return const Color(0xFF10B981);
      case 'pending':
      case 'معلقة':
        return const Color(0xFFF59E0B);
      case 'cancelled':
      case 'ملغية':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return 'مدفوعة';
      case 'pending':
        return 'معلقة';
      case 'cancelled':
        return 'ملغية';
      default:
        return status ?? 'غير محدد';
    }
  }

  // Loading State with modern design
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.3),
                  const Color(0xFF059669).withValues(alpha: 0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل البيانات المالية...',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // Financial Overview Cards with safe error handling
  Widget _buildFinancialOverviewCards() {
    try {
      return Row(
        children: [
          Expanded(
            child: _buildFinancialCard(
              title: 'إجمالي الإيرادات',
              value: _currencyFormat.format(_totalRevenue),
              icon: Icons.trending_up_rounded,
              gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
              change: '+12.5%',
              isPositive: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFinancialCard(
              title: 'المبالغ المعلقة',
              value: _currencyFormat.format(_totalPending),
              icon: Icons.pending_actions_rounded,
              gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
              change: '-5.2%',
              isPositive: false,
            ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('⚠️ خطأ في بناء بطاقات النظرة المالية: $e');
      return _buildErrorPlaceholder();
    }
  }

  // Financial Card Builder
  Widget _buildFinancialCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required String change,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions Section
  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.9),
            const Color(0xFF334155).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'الإجراءات السريعة',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'إضافة فاتورة',
                  Icons.add_chart_rounded,
                  const Color(0xFF10B981),
                  _navigateToAddInvoice,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionButton(
                  'إدارة المحافظ',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF3B82F6),
                  () => Navigator.pushNamed(context, AppRoutes.accountantWalletManagement),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'الخزنة',
                  Icons.account_balance_rounded,
                  const Color(0xFF8B5CF6),
                  () => Navigator.pushNamed(context, AppRoutes.accountantTreasuryManagement),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(), // Placeholder for future quick action
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Financial Chart Section
  Widget _buildFinancialChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.9),
            const Color(0xFF334155).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'توزيع الإيرادات',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPieChart(),
          const SizedBox(height: 20),
          _buildChartLegend(),
        ],
      ),
    );
  }

  // Recent Invoices Section
  Widget _buildRecentInvoicesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.9),
            const Color(0xFF334155).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'أحدث الفواتير',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: Text(
                  'عرض الكل',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentInvoices.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد فواتير حديثة',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ...(_recentInvoices.take(3).map((invoice) {
              try {
                return _buildInvoiceItem(invoice);
              } catch (invoiceError) {
                debugPrint('⚠️ خطأ في عرض فاتورة: $invoiceError');
                return const SizedBox.shrink(); // إخفاء الفاتورة المعطوبة
              }
            }).toList()),
        ],
      ),
    );
  }

  // Modern KPI Card with enhanced design - إصلاح مشاكل الألوان والرؤية


  // Pie Chart for revenue distribution by category
  Widget _buildPieChart() {
    // Generate colors for each category
    final List<Color> colors = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];

    // Extract category data and sort by value (descending)
    final categoryData = _revenueByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate percentages for display
    final double totalRevenue = _totalRevenue > 0 ? _totalRevenue : 1;
    final List<PieChartSectionData> sections = [];

    for (var i = 0; i < categoryData.length; i++) {
      final category = categoryData[i];
      final percentage = (category.value / totalRevenue) * 100;
      final color = colors[i % colors.length];

      sections.add(
        PieChartSectionData(
          value: category.value,
          title: '${percentage.toStringAsFixed(1)}%',
          color: color,
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (sections.isEmpty) {
      // No data case - display empty chart
      sections.add(
        PieChartSectionData(
          value: 1,
          title: '100%',
          color: Colors.grey.withValues(alpha: 0.3),
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 30,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  // Legend for pie chart
  Widget _buildChartLegend() {
    final categoryData = _revenueByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Color> colors = [
      Colors.indigo, Colors.blue, Colors.teal, Colors.green,
      Colors.lime, Colors.orange, Colors.red, Colors.purple,
    ];

    if (categoryData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'لا توجد بيانات متاحة للعرض',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(
        categoryData.length,
        (i) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              categoryData[i].key,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }







  Color _getHealthColor(int percentage) {
    if (percentage > 80) return StyleSystem.successColor;
    if (percentage > 60) return StyleSystem.profitColor;
    if (percentage > 40) return StyleSystem.warningColor;
    return StyleSystem.errorColor;
  }

  String _getHealthText(int percentage) {
    if (percentage > 80) return 'ممتاز';
    if (percentage > 60) return 'جيد';
    if (percentage > 40) return 'متوسط';
    return 'ضعيف';
  }

  // Modern quick action button with enhanced design - إصلاح مشاكل الألوان البيضاء
  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Accounts tab content with sub-tabs - توحيد الاستايل مع المشروع
  Widget _buildAccountsTab() {
    return DefaultTabController(
      length: 3, // ثلاثة تبويبات: الملخص المالي والسلف ومديونية العملاء
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.05),
              Colors.black.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header section - استايل متوافق مع المشروع
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                const Color(0xFF10B981).withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إدارة الحسابات المالية',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متابعة الحسابات والأرصدة والسلف',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sub-tabs - تحسين الاستايل
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF10B981),
                            const Color(0xFF10B981).withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Cairo',
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                          text: 'الملخص المالي',
                        ),
                        Tab(
                          icon: Icon(Icons.payment_rounded, size: 20),
                          text: 'السلف',
                        ),
                        Tab(
                          icon: Icon(Icons.people_alt_rounded, size: 20),
                          text: 'مديونية العملاء',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  _buildFinancialSummaryTab(),
                  _buildAdvancesTab(),
                  _buildClientDebtsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Financial Summary tab
  Widget _buildFinancialSummaryTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Financial Summary Cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAccountCard(
                        'إجمالي الإيرادات',
                        '${_totalRevenue.toStringAsFixed(2)} جنيه',
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAccountCard(
                        'إجمالي المصروفات',
                        '${_totalExpenses.toStringAsFixed(2)} جنيه',
                        Icons.trending_down,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAccountCard(
                        'صافي الربح',
                        '${(_totalRevenue - _totalExpenses).toStringAsFixed(2)} جنيه',
                        Icons.account_balance_wallet,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAccountCard(
                        'الرصيد المتاح',
                        '${_availableBalance.toStringAsFixed(2)} جنيه',
                        Icons.savings,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Recent Transactions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المعاملات الحديثة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                const Color(0xFF10B981).withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'عرض الكل',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTransactionsList(),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  // Advances tab
  Widget _buildAdvancesTab() {
    return FutureBuilder<List<AdvanceModel>>(
      future: _advanceService.getAllAdvances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade900,
                  Colors.black,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF10B981),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري تحميل السلف...',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          // Log the error for debugging
          debugPrint('❌ Error loading advances: ${snapshot.error}');

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade900,
                  Colors.black,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'حدث خطأ أثناء تحميل السلف',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يرجى المحاولة مرة أخرى أو التحقق من الاتصال',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Show detailed error information
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.grey.shade900,
                              title: const Text(
                                'تفاصيل الخطأ',
                                style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                              ),
                              content: Text(
                                snapshot.error.toString(),
                                style: TextStyle(color: Colors.grey.shade300, fontFamily: 'Cairo'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'إغلاق',
                                    style: TextStyle(color: Color(0xFF10B981), fontFamily: 'Cairo'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(Icons.info_outline, color: Colors.grey.shade400),
                        label: Text(
                          'التفاصيل',
                          style: TextStyle(color: Colors.grey.shade400, fontFamily: 'Cairo'),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade600),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final advances = snapshot.data ?? [];
        final statistics = AdvanceStatistics.fromAdvances(advances);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade900,
                Colors.black,
              ],
            ),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
            // Advances Statistics
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAdvanceStatCard(
                            'إجمالي السلف',
                            '${statistics.totalAdvances}',
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAdvanceStatCard(
                            'في الانتظار',
                            '${statistics.pendingAdvances}',
                            Icons.pending,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAdvanceStatCard(
                            'معتمدة',
                            '${statistics.approvedAdvances}',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAdvanceStatCard(
                            'مدفوعة',
                            '${statistics.paidAdvances}',
                            Icons.payment,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Add Advance Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAddAdvance(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'إضافة سلفة جديدة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Advances List
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade800,
                        Colors.grey.shade900,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'قائمة السلف',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${advances.length} سلفة',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAdvancesList(advances),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
        );
      },
    );
  }

  // Navigate to add advance screen
  Future<void> _navigateToAddAdvance() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddAdvanceScreen(),
      ),
    );

    if (result == true) {
      // Refresh the advances tab
      setState(() {});
    }
  }

  // Workers tab content
  Widget _buildWorkersTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            isDark ? Colors.grey.shade800 : Colors.white,
          ],
        ),
      ),
      child: FutureBuilder<List<UserModel>>(
        future: _loadWorkersData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ أثناء تحميل بيانات العمال',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.red,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          final workers = snapshot.data ?? [];
          final activeWorkers = workers.where((w) => w.status == 'approved' || w.status == 'active').toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header section with rewards management button
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10B981),
                        Color(0xFF059669),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.people,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'إدارة العمال والمكافآت',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'متابعة أداء العمال والمهام والمكافآت',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Rewards Management Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to accountant rewards management screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AccountantRewardsManagementScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.card_giftcard, color: Colors.white),
                            label: const Text(
                              'منح مكافآت',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Workers statistics
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إحصائيات العمال',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildWorkerStatCard(
                              'إجمالي العمال',
                              '${workers.length}',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildWorkerStatCard(
                              'العمال النشطين',
                              '${activeWorkers.length}',
                              Icons.people,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, int>>(
                        future: _loadTasksAndRewardsStats(),
                        builder: (context, statsSnapshot) {
                          final stats = statsSnapshot.data ?? {'tasks': 0, 'rewards': 0};
                          return Row(
                            children: [
                              Expanded(
                                child: _buildWorkerStatCard(
                                  'المهام المكتملة',
                                  '${stats['tasks']}',
                                  Icons.task_alt,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildWorkerStatCard(
                                  'المكافآت الممنوحة',
                                  '${stats['rewards']}',
                                  Icons.card_giftcard,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Workers list
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                      border: isDark
                          ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'قائمة العمال',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.grey.shade800,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade500, Colors.indigo.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${workers.length} عامل',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildRealWorkersList(workers),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

          // Rewards section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: isDark
                      ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'المكافآت الحديثة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey.shade800,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRewardsList(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      );
        },
      ),
    );
  }

  // Worker statistics card
  Widget _buildWorkerStatCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Account card widget - إصلاح مشاكل الألوان البيضاء
  Widget _buildAccountCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Transactions list widget - إزالة البيانات الوهمية
  Widget _buildTransactionsList() {
    // عرض رسالة بدلاً من البيانات الوهمية
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد معاملات حالياً',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم عرض المعاملات المالية هنا عند توفرها',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  // Advance stat card widget - إصلاح مشاكل الألوان البيضاء
  Widget _buildAdvanceStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Advances list widget with enhanced error handling
  Widget _buildAdvancesList(List<AdvanceModel> advances) {
    if (advances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.payment, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'لا توجد سلف مسجلة',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم عرض السلف هنا عند إضافتها',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: advances.map((advance) {
        try {
          return _buildAdvanceItem(advance);
        } catch (e) {
          debugPrint('❌ Error building advance item: $e');
          // Return a safe error widget instead of crashing
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'خطأ في عرض السلفة: ${advance.advanceName}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }
      }).toList(),
    );
  }

  // Enhanced advance item widget with 3D flip animation
  Widget _buildAdvanceItem(AdvanceModel advance) {
    Color statusColor;
    switch (advance.status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'paid':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Safely get or create animation - fix for null check operator error
    final animation = _flipAnimations[advance.id] ?? _getFlipController(advance.id).view;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 180, // Fixed height for consistent animation
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final isShowingFront = animation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(animation.value * 3.14159),
            child: GestureDetector(
              onTap: () => _toggleAdvanceCardFlip(advance.id),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[900] ?? Colors.grey.shade900,
                      Colors.black,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isShowingFront
                    ? _buildAdvanceFrontSide(advance, statusColor)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildAdvanceBackSide(advance, statusColor),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build front side of advance card
  Widget _buildAdvanceFrontSide(AdvanceModel advance, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor,
                      statusColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(advance.status),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  advance.advanceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  advance.statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Client and amount info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'العميل',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      advance.clientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'المبلغ',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    advance.formattedAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 18,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description and date
          if (advance.description.isNotEmpty) ...[
            Text(
              advance.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Date and tap hint
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.white60),
              const SizedBox(width: 6),
              Text(
                '${advance.createdAt.day}/${advance.createdAt.month}/${advance.createdAt.year}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 12, color: Colors.white60),
                    SizedBox(width: 4),
                    Text(
                      'اضغط للخيارات',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build back side of advance card with control options
  Widget _buildAdvanceBackSide(AdvanceModel advance, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.settings, color: statusColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'خيارات التحكم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleAdvanceCardFlip(advance.id),
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                iconSize: 20,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Control buttons
          Row(
            children: [
              Expanded(
                child: _buildAdvanceControlButton(
                  'تعديل المبلغ',
                  Icons.edit,
                  const Color(0xFF10B981),
                  () => _editAdvanceAmount(advance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdvanceControlButton(
                  'حذف السلفة',
                  Icons.delete,
                  Colors.red,
                  () => _deleteAdvance(advance),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status actions (if applicable)
          if (advance.canBeApproved) ...[
            Row(
              children: [
                Expanded(
                  child: _buildAdvanceControlButton(
                    'اعتماد',
                    Icons.check_circle,
                    Colors.green,
                    () => _approveAdvance(advance),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAdvanceControlButton(
                    'رفض',
                    Icons.cancel,
                    Colors.orange,
                    () => _rejectAdvance(advance),
                  ),
                ),
              ],
            ),
          ] else if (advance.canBePaid) ...[
            _buildAdvanceControlButton(
              'تسديد السلفة',
              Icons.payment,
              Colors.blue,
              () => _payAdvance(advance),
            ),
          ],
        ],
      ),
    );
  }

  // Build control button for advance card back side
  Widget _buildAdvanceControlButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'paid':
        return Icons.payment;
      default:
        return Icons.help;
    }
  }

  // Edit advance amount
  Future<void> _editAdvanceAmount(AdvanceModel advance) async {
    final controller = TextEditingController(text: advance.amount.toString());

    final newAmount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تعديل مبلغ السلفة',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'السلفة: ${advance.advanceName}',
              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'المبلغ الجديد',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF10B981)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop(amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newAmount != null) {
      try {
        // Actually update the advance amount in the database
        await _advanceService.updateAdvanceAmount(advance.id, newAmount);

        // Show success message only after successful update
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث مبلغ السلفة إلى ${newAmount.toStringAsFixed(2)} جنيه'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Refresh the list to show updated amount
        setState(() {});
      } catch (e) {
        // Show error message only if update fails
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في تحديث المبلغ: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  // Delete advance
  Future<void> _deleteAdvance(AdvanceModel advance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            Text(
              'هل أنت متأكد من حذف السلفة "${advance.advanceName}"؟',
              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'لا يمكن التراجع عن هذا الإجراء',
              style: TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Actually delete the advance from the database
        await _advanceService.deleteAdvance(advance.id);

        // Show success message only after successful deletion
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف السلفة "${advance.advanceName}" بنجاح'),
              backgroundColor: Colors.green, // Changed to green for success
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Refresh the list to remove the deleted item
        setState(() {});
      } catch (e) {
        // Show error message only if deletion fails
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في حذف السلفة: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }



  // Approve advance
  Future<void> _approveAdvance(AdvanceModel advance) async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) return;

      await _advanceService.approveAdvance(advance.id, currentUser.id);

      setState(() {}); // Refresh the list

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم اعتماد السلفة "${advance.advanceName}" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اعتماد السلفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Reject advance
  Future<void> _rejectAdvance(AdvanceModel advance) async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    try {
      await _advanceService.rejectAdvance(advance.id, reason);

      setState(() {}); // Refresh the list

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفض السلفة "${advance.advanceName}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في رفض السلفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pay advance
  Future<void> _payAdvance(AdvanceModel advance) async {
    try {
      await _advanceService.payAdvance(advance.id);

      setState(() {}); // Refresh the list

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسديد السلفة "${advance.advanceName}" بنجاح'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تسديد السلفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show reject dialog
  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض السلفة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال سبب الرفض:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'سبب الرفض...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Load workers data from Supabase
  Future<List<UserModel>> _loadWorkersData() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final workers = await supabaseProvider.getUsersByRole(UserRole.worker.value);
      return workers;
    } catch (e) {
      debugPrint('Error loading workers data: $e');
      return [];
    }
  }

  // Load tasks and rewards statistics
  Future<Map<String, int>> _loadTasksAndRewardsStats() async {
    try {
      final supabase = Supabase.instance.client;

      // Get completed tasks count
      final tasksResponse = await supabase
          .from('worker_tasks')
          .select('id')
          .eq('status', 'completed');

      // Get rewards count
      final rewardsResponse = await supabase
          .from('worker_rewards')
          .select('id');

      return {
        'tasks': tasksResponse.length,
        'rewards': rewardsResponse.length,
      };
    } catch (e) {
      debugPrint('Error loading stats: $e');
      return {'tasks': 0, 'rewards': 0};
    }
  }

  // Real workers list widget
  Widget _buildRealWorkersList(List<UserModel> workers) {
    if (workers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'لا يوجد عمال مسجلين',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم عرض العمال هنا عند تسجيلهم',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: workers.map((worker) => _buildRealWorkerItem(worker)).toList(),
    );
  }

  // Real worker item widget
  Widget _buildRealWorkerItem(UserModel worker) {
    final isActive = worker.status == 'approved' || worker.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            backgroundImage: worker.profileImage != null ? NetworkImage(worker.profileImage!) : null,
            child: worker.profileImage == null
                ? Icon(
                    Icons.person,
                    color: isActive ? Colors.green : Colors.grey,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  worker.email,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (worker.phone.isNotEmpty)
                  Text(
                    worker.phone,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isActive ? 'نشط' : 'غير نشط',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }



  // Rewards list widget - إزالة البيانات الوهمية
  Widget _buildRewardsList() {
    // عرض رسالة بدلاً من البيانات الوهمية
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مكافآت حالياً',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم عرض المكافآت هنا عند توفرها',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  // Client Debts tab - قسم مديونية العملاء
  Widget _buildClientDebtsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF10B981),
                            const Color(0xFF10B981).withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مديونية العملاء',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'أرصدة ومعلومات العملاء',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF10B981),
                            const Color(0xFF10B981).withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: _loadClientDebts,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'تحديث',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Clients list
          _isLoadingClients
              ? SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF10B981),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'جاري تحميل بيانات العملاء...',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _clientDebts.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              child: Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'لا توجد بيانات عملاء',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط على تحديث لتحميل بيانات العملاء',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                                fontFamily: 'Cairo',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildClientDebtCard(_clientDebts[index]),
                        childCount: _clientDebts.length,
                      ),
                    ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  // Client debt card widget
  Widget _buildClientDebtCard(Map<String, dynamic> client) {
    final balance = client['balance'] as double;
    final hasWallet = client['hasWallet'] as bool? ?? false;
    final isPositiveBalance = balance > 0;
    final balanceColor = isPositiveBalance ? const Color(0xFF10B981) :
                        balance == 0 ? Colors.orange : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: balanceColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: balanceColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Client avatar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    balanceColor.withValues(alpha: 0.2),
                    balanceColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: balanceColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: balanceColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Client info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client['name'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  if ((client['email'] as String? ?? '').isNotEmpty)
                    Text(
                      client['email'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: balanceColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'الرصيد: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade300,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        '${balance.toStringAsFixed(2)} جنيه',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!hasWallet)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'لا توجد محفظة',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Phone call button
            if ((client['phone'] as String? ?? '').isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF10B981),
                      Color(0xFF10B981).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _makePhoneCall(client['phone'] as String? ?? ''),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'اتصال',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Cairo',
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
      ),
    );
  }

}