import 'dart:async';
import 'package:flutter/material.dart';

class AppLocalizations {

  AppLocalizations(this.locale);
  final Locale locale;

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // ... existing translations ...
      'orders': 'Orders',
      'damaged_items': 'Damaged Items',
      'order': 'Order',
      'total': 'Total',
      'date': 'Date',
      'phone': 'Phone',
      'order_items': 'Order Items',
      'print': 'Print',
      'details': 'Details',
      'no_orders_found': 'No orders found',
      'quantity': 'Quantity',
      'reason': 'Reason',
      'notes': 'Notes',
      'loss_amount': 'Loss Amount',
      'review': 'Review',
      'mark_resolved': 'Mark Resolved',
      'report_damaged_item': 'Report Damaged Item',
      'no_damaged_items_found': 'No damaged items found',
      'stock_orders': 'Stock Orders',
      'warehouse': 'Warehouse',
      'products': 'Products',
      'product': 'Product',
      'no_products_found': 'No products found',
      'in_stock': 'in stock',
      'opening_balance': 'Opening Balance',
      'current_stock': 'Current Stock',
      'out_of_stock': 'Out of stock',
      'price': 'Price',
      'category': 'Category',
      'description': 'Description',
      'view_details': 'View Details',
      'add_to_cart': 'Add to Cart',
    },
    'ar': {
      // ... existing translations ...
      'orders': 'الطلبات',
      'damaged_items': 'العناصر التالفة',
      'order': 'طلب',
      'total': 'المجموع',
      'date': 'التاريخ',
      'phone': 'الهاتف',
      'order_items': 'عناصر الطلب',
      'print': 'طباعة',
      'details': 'التفاصيل',
      'no_orders_found': 'لا توجد طلبات',
      'quantity': 'الكمية',
      'reason': 'السبب',
      'notes': 'ملاحظات',
      'loss_amount': 'قيمة الخسارة',
      'review': 'مراجعة',
      'mark_resolved': 'تم الحل',
      'report_damaged_item': 'الإبلاغ عن عنصر تالف',
      'no_damaged_items_found': 'لا توجد عناصر تالفة',
      'stock_orders': 'طلبات المخزون',
      'warehouse': 'المستودع',
      'products': 'المنتجات',
      'product': 'منتج',
      'no_products_found': 'لا توجد منتجات',
      'in_stock': 'متوفر',
      'opening_balance': 'رصيد أول مدة',
      'current_stock': 'المخزون الحالي',
      'out_of_stock': 'غير متوفر',
      'price': 'السعر',
      'category': 'الفئة',
      'description': 'الوصف',
      'view_details': 'عرض التفاصيل',
      'add_to_cart': 'إضافة للسلة',
    },
  };

  String? translate(String key) {
    return _localizedValues[locale.languageCode]?[key];
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
} 