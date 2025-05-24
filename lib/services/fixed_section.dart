// Fixed date extraction section for stockwarehouse_api.dart
/*
Replace the problematic code around line 888-913 with this code:

                if (RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(text) ||
                    RegExp(r'\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}').hasMatch(text)) {
                  try {
                    // محاولة تحليل التاريخ بأنماط مختلفة
                    final dateStr = RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').firstMatch(text)?.group(0) ??
                        RegExp(r'\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}').firstMatch(text)?.group(0) ?? '';
                    
                    if (dateStr.isNotEmpty) {
                      final parts = dateStr.split(RegExp(r'[/\-\.]'));
                      if (parts.length == 3) {
                        // تحديد ما إذا كان التنسيق dd/mm/yyyy أو yyyy/mm/dd
                        if (parts[0].length == 4) {
                          // yyyy/mm/dd
                          final year = int.tryParse(parts[0]) ?? DateTime.now().year;
                          final month = int.tryParse(parts[1]) ?? 1;
                          final day = int.tryParse(parts[2]) ?? 1;
                          createdAt = DateTime(year, month, day);
                        } else {
                          // dd/mm/yyyy أو mm/dd/yyyy (نفترض dd/mm/yyyy في السياق العربي)
                          final day = int.tryParse(parts[0]) ?? 1;
                          final month = int.tryParse(parts[1]) ?? 1;
                          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
                          // إضافة القرن إذا كانت السنة مكونة من رقمين فقط
                          final fullYear = year < 100 ? 2000 + year : year;
                          createdAt = DateTime(fullYear, month, day);
                        }
                      }
                    }
                  } catch (e) {
                    logger.e('خطأ في استخراج التاريخ', e);
                  }
                  break;
                }
*/ 