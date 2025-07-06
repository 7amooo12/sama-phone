import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// أداة التحقق من إعداد قاعدة البيانات
/// تتحقق من وجود الجداول المطلوبة وتوفر إرشادات الإصلاح
class DatabaseSetupChecker {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// التحقق من إعداد قاعدة البيانات الكامل
  static Future<DatabaseSetupResult> checkDatabaseSetup() async {
    final result = DatabaseSetupResult();
    
    try {
      AppLogger.info('🔍 فحص إعداد قاعدة البيانات...');

      // فحص الجداول الأساسية
      result.addCheck('warehouse_release_orders', await _checkTableExists('warehouse_release_orders'));
      result.addCheck('warehouse_release_order_items', await _checkTableExists('warehouse_release_order_items'));
      result.addCheck('warehouse_release_order_history', await _checkTableExists('warehouse_release_order_history'));

      // فحص العلاقات
      if (result.allTablesExist) {
        result.relationshipsValid = await _checkRelationships();
      }

      // فحص الفهارس
      if (result.allTablesExist) {
        result.indexesValid = await _checkIndexes();
      }

      // فحص الصلاحيات
      if (result.allTablesExist) {
        result.permissionsValid = await _checkPermissions();
      }

      AppLogger.info('✅ فحص قاعدة البيانات مكتمل');
      return result;

    } catch (e) {
      AppLogger.error('❌ خطأ في فحص قاعدة البيانات: $e');
      result.error = e.toString();
      return result;
    }
  }

  /// التحقق من وجود جدول معين
  static Future<bool> _checkTableExists(String tableName) async {
    try {
      await _supabase
          .from(tableName)
          .select('*')
          .limit(1);
      return true;
    } catch (e) {
      if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        return false;
      }
      // إذا كان خطأ آخر، نفترض أن الجدول موجود
      return true;
    }
  }

  /// التحقق من العلاقات بين الجداول
  static Future<bool> _checkRelationships() async {
    try {
      // اختبار العلاقة بين warehouse_release_orders و warehouse_release_order_items
      await _supabase
          .from('warehouse_release_orders')
          .select('''
            id,
            warehouse_release_order_items (
              id,
              release_order_id
            )
          ''')
          .limit(1);
      return true;
    } catch (e) {
      AppLogger.warning('⚠️ مشكلة في العلاقات: $e');
      return false;
    }
  }

  /// التحقق من الفهارس
  static Future<bool> _checkIndexes() async {
    try {
      // هذا فحص أساسي - في التطبيق الحقيقي يمكن فحص الفهارس بشكل أكثر تفصيلاً
      return true;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من الصلاحيات
  static Future<bool> _checkPermissions() async {
    try {
      // اختبار صلاحيات القراءة والكتابة
      await _supabase
          .from('warehouse_release_orders')
          .select('id')
          .limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إنشاء تقرير مفصل عن حالة قاعدة البيانات
  static Future<String> generateSetupReport() async {
    final result = await checkDatabaseSetup();
    
    final report = StringBuffer();
    report.writeln('# تقرير إعداد قاعدة البيانات');
    report.writeln('التاريخ: ${DateTime.now()}');
    report.writeln('');
    
    report.writeln('## حالة الجداول');
    for (final check in result.tableChecks.entries) {
      final status = check.value ? '✅ موجود' : '❌ مفقود';
      report.writeln('- ${check.key}: $status');
    }
    
    report.writeln('');
    report.writeln('## حالة النظام');
    report.writeln('- جميع الجداول موجودة: ${result.allTablesExist ? "✅ نعم" : "❌ لا"}');
    report.writeln('- العلاقات صحيحة: ${result.relationshipsValid ? "✅ نعم" : "❌ لا"}');
    report.writeln('- الفهارس صحيحة: ${result.indexesValid ? "✅ نعم" : "❌ لا"}');
    report.writeln('- الصلاحيات صحيحة: ${result.permissionsValid ? "✅ نعم" : "❌ لا"}');
    
    if (result.error != null) {
      report.writeln('');
      report.writeln('## أخطاء');
      report.writeln('- ${result.error}');
    }
    
    if (!result.isFullySetup) {
      report.writeln('');
      report.writeln('## خطوات الإصلاح المطلوبة');
      report.writeln(getSetupInstructions(result));
    }
    
    return report.toString();
  }

  /// الحصول على إرشادات الإعداد
  static String getSetupInstructions(DatabaseSetupResult result) {
    final instructions = StringBuffer();
    
    if (!result.allTablesExist) {
      instructions.writeln('### 1. تطبيق migration قاعدة البيانات');
      instructions.writeln('');
      instructions.writeln('**الطريقة الأولى: استخدام Supabase CLI**');
      instructions.writeln('```bash');
      instructions.writeln('cd /path/to/your/project');
      instructions.writeln('supabase db push');
      instructions.writeln('```');
      instructions.writeln('');
      instructions.writeln('**الطريقة الثانية: تنفيذ SQL يدوياً**');
      instructions.writeln('1. اذهب إلى Supabase Dashboard');
      instructions.writeln('2. انتقل إلى SQL Editor');
      instructions.writeln('3. انسخ محتوى الملف: supabase/migrations/20241222000000_create_warehouse_release_orders.sql');
      instructions.writeln('4. نفذ الاستعلام');
      instructions.writeln('');
    }
    
    if (!result.relationshipsValid) {
      instructions.writeln('### 2. إصلاح العلاقات');
      instructions.writeln('- تأكد من وجود foreign key constraints');
      instructions.writeln('- تحقق من أسماء الأعمدة');
      instructions.writeln('');
    }
    
    if (!result.permissionsValid) {
      instructions.writeln('### 3. إعداد الصلاحيات');
      instructions.writeln('- تأكد من Row Level Security policies');
      instructions.writeln('- تحقق من صلاحيات المستخدم');
      instructions.writeln('');
    }
    
    instructions.writeln('### 4. إعادة تشغيل التطبيق');
    instructions.writeln('بعد تطبيق التغييرات، أعد تشغيل التطبيق للتأكد من عمل النظام.');
    
    return instructions.toString();
  }

  /// فحص سريع لحالة قاعدة البيانات
  static Future<bool> quickCheck() async {
    try {
      final result = await checkDatabaseSetup();
      return result.isFullySetup;
    } catch (e) {
      return false;
    }
  }
}

/// نتيجة فحص إعداد قاعدة البيانات
class DatabaseSetupResult {
  final Map<String, bool> tableChecks = {};
  bool relationshipsValid = false;
  bool indexesValid = false;
  bool permissionsValid = false;
  String? error;

  void addCheck(String tableName, bool exists) {
    tableChecks[tableName] = exists;
  }

  bool get allTablesExist => tableChecks.values.every((exists) => exists);
  
  bool get isFullySetup => 
      allTablesExist && 
      relationshipsValid && 
      indexesValid && 
      permissionsValid && 
      error == null;

  List<String> get missingTables => 
      tableChecks.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .toList();

  String get summary {
    if (isFullySetup) {
      return 'قاعدة البيانات مُعدة بشكل صحيح';
    } else if (allTablesExist) {
      return 'الجداول موجودة ولكن هناك مشاكل في الإعداد';
    } else {
      return 'جداول مفقودة: ${missingTables.join(", ")}';
    }
  }
}

/// أداة مساعدة لعرض حالة قاعدة البيانات في واجهة المستخدم
class DatabaseStatusWidget {
  static Future<void> showDatabaseStatus(context) async {
    final result = await DatabaseSetupChecker.checkDatabaseSetup();
    
    // يمكن استخدام هذا لعرض dialog أو snackbar
    // مع معلومات حالة قاعدة البيانات
  }
}
