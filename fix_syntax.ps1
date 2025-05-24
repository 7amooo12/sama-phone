$file = "lib/services/stockwarehouse_api.dart"
$content = Get-Content $file -Raw
$fixedSection = @'
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
'@

# Find the block to replace - we'll look for the try block at line 888 which is missing its catch
$pattern = [regex]::Escape('                  try {')
$patternMatch = [regex]::Match($content, $pattern)

if ($patternMatch.Success) {
    $startIndex = $patternMatch.Index
    $endIndex = $content.IndexOf('                  break;', $startIndex) + '                  break;'.Length
    
    if ($endIndex -gt $startIndex) {
        # Create the fixed content
        $fixedContent = $content.Substring(0, $startIndex - '                if (RegExp(r''\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}'').hasMatch(text) ||
                    RegExp(r''\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}'').hasMatch(text)) {'.Length) + 
            $fixedSection + 
            $content.Substring($endIndex + 1)
        
        # Save the fixed content
        $fixedContent | Set-Content $file -Force
        Write-Host "File fixed successfully!"
    } else {
        Write-Host "Could not find the end of the block to replace."
    }
} else {
    Write-Host "Could not find the pattern to replace."
} 