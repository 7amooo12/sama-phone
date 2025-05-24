import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'dashboard': 'لوحة التحكم',
      'products': 'المنتجات',
      'orders': 'الطلبات',
      'customers': 'العملاء',
      'settings': 'الإعدادات',
      'profile': 'الملف الشخصي',
      'logout': 'تسجيل الخروج',
      'notifications': 'الإشعارات',
      'reports': 'التقارير',
      'inventory': 'المخزون',
      'sales': 'المبيعات',
      'expenses': 'المصروفات',
      'employees': 'الموظفين',
      'suppliers': 'الموردين',
      'categories': 'التصنيفات',
      'brands': 'العلامات التجارية',
    },
    'en': {
      'dashboard': 'Dashboard',
      'products': 'Products',
      'orders': 'Orders',
      'customers': 'Customers',
      'settings': 'Settings',
      'profile': 'Profile',
      'logout': 'Logout',
      'notifications': 'Notifications',
      'reports': 'Reports',
      'inventory': 'Inventory',
      'sales': 'Sales',
      'expenses': 'Expenses',
      'employees': 'Employees',
      'suppliers': 'Suppliers',
      'categories': 'Categories',
      'brands': 'Brands',
    },
  };

  String get currentLanguage => locale.languageCode;

  String translate(String key) {
    return _localizedValues[currentLanguage]?[key] ?? key;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
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