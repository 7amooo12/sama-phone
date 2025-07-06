/// تطبيق إصلاح خطأ UUID في نظام خصم المخزون
/// Deploy UUID Type Mismatch Fix for Inventory Deduction System

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🚀 بدء تطبيق إصلاح خطأ UUID في نظام خصم المخزون...');
  
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://your-project-url.supabase.co',
      anonKey: 'your-anon-key',
    );
    
    final supabase = Supabase.instance.client;
    
    // Read the SQL file
    final sqlFile = File('fix_uuid_type_mismatch_v2.sql');
    if (!await sqlFile.exists()) {
      print('❌ ملف SQL غير موجود: fix_uuid_type_mismatch_v2.sql');
      exit(1);
    }
    
    final sqlContent = await sqlFile.readAsString();
    print('📄 تم قراءة ملف SQL بنجاح');
    
    // Execute the SQL
    print('🔄 تطبيق إصلاح قاعدة البيانات...');
    
    // Split SQL into individual statements
    final statements = sqlContent
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('--'))
        .toList();
    
    for (int i = 0; i < statements.length; i++) {
      final statement = statements[i];
      if (statement.isEmpty) continue;
      
      try {
        print('📤 تنفيذ البيان ${i + 1}/${statements.length}...');
        await supabase.rpc('exec_sql', params: {'sql': statement});
        print('✅ تم تنفيذ البيان ${i + 1} بنجاح');
      } catch (e) {
        print('❌ خطأ في تنفيذ البيان ${i + 1}: $e');
        print('📄 البيان: ${statement.substring(0, 100)}...');
      }
    }
    
    // Test the new function
    print('🧪 اختبار الدالة الجديدة...');
    
    final testResult = await supabase.rpc(
      'deduct_inventory_with_validation_v2',
      params: {
        'p_warehouse_id': '338d5af4-88ad-49cb-aec6-456ac6bd318c',
        'p_product_id': '190',
        'p_quantity': 1,
        'p_performed_by': '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',
        'p_reason': 'اختبار الدالة الجديدة',
        'p_reference_id': 'test-${DateTime.now().millisecondsSinceEpoch}',
        'p_reference_type': 'test',
      },
    );
    
    print('📊 نتيجة الاختبار: $testResult');
    
    if (testResult != null && testResult['success'] == true) {
      print('✅ تم تطبيق الإصلاح بنجاح! الدالة تعمل بشكل صحيح.');
    } else {
      print('⚠️ تم تطبيق الإصلاح ولكن الاختبار فشل: ${testResult?['error']}');
    }
    
    print('🎉 انتهى تطبيق الإصلاح');
    
  } catch (e) {
    print('❌ خطأ في تطبيق الإصلاح: $e');
    exit(1);
  }
}
