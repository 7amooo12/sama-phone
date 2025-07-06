# Smart Biz Tracker

تطبيق إدارة الأعمال الذكي باستخدام Flutter و Supabase

## المتطلبات

- Flutter SDK (3.4.0 أو أحدث)
- Dart SDK (3.0.0 أو أحدث)
- Android Studio / VS Code
- Supabase Account

## الإعداد

1. قم بإنشاء مشروع Supabase جديد من لوحة التحكم
2. انسخ المشروع:
   ```bash
   git clone https://github.com/yourusername/smartbiztracker_new.git
   cd smartbiztracker_new
   ```

3. قم بتثبيت التبعيات:
   ```bash
   flutter pub get
   ```

4. قم بإنشاء ملف `.env` في المجلد الرئيسي وأضف بيانات اعتماد Supabase:
   ```
   SUPABASE_URL=your-project-url
   SUPABASE_ANON_KEY=your-anon-key
   ```

5. قم بتشغيل الترحيل في Supabase:
   - انسخ محتويات `supabase/migrations` إلى SQL Editor في لوحة تحكم Supabase
   - قم بتشغيل الترحيلات بالترتيب

6. قم بتشغيل التطبيق:
   ```bash
   flutter run
   ```

## الميزات

- نظام مصادقة آمن
- إدارة المستخدمين متعددة الأدوار
- واجهة مستخدم عربية سلسة
- دعم وضع عدم الاتصال
- تخزين البيانات المحلي
- مزامنة في الوقت الفعلي

## الأمان

- التحقق من صحة البريد الإلكتروني
- التحقق من تكرار الحسابات
- معالجة الأخطاء الشاملة
- حماية نقاط النهاية
- تشفير البيانات

## المساهمة

1. Fork المشروع
2. قم بإنشاء فرع للميزة: `git checkout -b feature/amazing-feature`
3. قم بعمل Commit للتغييرات: `git commit -m 'إضافة ميزة رائعة'`
4. قم بعمل Push للفرع: `git push origin feature/amazing-feature`
5. قم بفتح Pull Request

## الترخيص

هذا المشروع مرخص تحت رخصة MIT - انظر ملف [LICENSE](LICENSE) للتفاصيل.

# SmartBizTracker - Flutter App

## Code Quality Fixes and Improvements

### 🔧 Completed Code Fixes

The following improvements have been made to the codebase:

1. **Constructor Syntax Updates**
   - Updated constructors to use the modern `super.key` syntax
   - Fixed in multiple widgets including `WorkerDashboard`, `ProductManagementScreen`, `PerformanceChart`, `AssignedOrderCard`, `OrderSummaryCard`, and `BusinessStatsCard`

2. **Color Opacity Updates**
   - Replaced deprecated `withOpacity()` method with `withValues(opacity:)`
   - Added a convenient `safeOpacity()` extension method in `utils/color_extension.dart`
   - Updated across all widgets and screens where color opacity was used

3. **Naming Convention Standardization**
   - Updated constant names to use `lowerCamelCase` instead of `UPPERCASE_WITH_UNDERSCORES`
   - Applied in configuration files like `constants.dart`

4. **Fixed Missing Parameters**
   - Addressed constructor parameter issues in user models
   - Added missing required parameters
   - Fixed incorrect parameter usage

5. **Linting Configuration**
   - Set up `analysis_options.yaml` with comprehensive rules
   - Enforced consistent code quality standards

### 📊 Best Practices Going Forward

1. **Use the safeOpacity Extension**
   ```dart
   // Instead of this (deprecated):
   color: Colors.black.withOpacity(0.5);
   
   // Use this:
   import 'package:smartbiztracker_new/utils/color_extension.dart';
   color: Colors.black.safeOpacity(0.5);
   ```

2. **Constructor Pattern**
   ```dart
   // Use this pattern for all widget constructors:
   const MyWidget({
     super.key,
     required this.parameter1,
     this.parameter2,
   });
   ```

3. **Naming Conventions**
   - Class names: `UpperCamelCase` (e.g., `UserService`)
   - Variables, methods, and parameters: `lowerCamelCase` (e.g., `getUserData`)
   - Constants: `lowerCamelCase` (e.g., `appName`, not `APP_NAME`)

4. **Running Lint Checks**
   ```bash
   # Run Flutter analysis to check for code issues
   flutter analyze
   ```

### 🚀 Additional Recommendations

1. **Automated Testing**
   - Add unit tests for critical business logic
   - Implement widget tests for UI components

2. **Code Documentation**
   - Add descriptive comments for complex logic
   - Use dartdoc-compatible comments for public APIs

3. **Package Management**
   - Regularly update dependencies
   - Check for deprecated packages

4. **Performance Optimization**
   - Minimize expensive operations in the build method
   - Use const constructors for widgets when possible
   - Consider using cached network images for remote images

By following these guidelines, the code will maintain high quality and be easier to maintain in the future.

## Troubleshooting

If you encounter any issues with the codebase, refer to the `FIXING_GUIDE.md` file for detailed solutions to common problems.
