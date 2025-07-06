import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'lib/widgets/treasury/client_wallets_summary_card.dart';
import 'lib/widgets/treasury/electronic_wallets_summary_card.dart';
import 'lib/utils/accountant_theme_config.dart';

/// Test file to verify Arabic text rendering fixes in wallet summary cards
/// This file demonstrates the improvements made to handle Arabic text properly
class ArabicTextRenderingTest extends StatelessWidget {
  const ArabicTextRenderingTest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arabic Text Rendering Test',
      theme: ThemeData.dark(),
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'اختبار عرض النصوص العربية',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
          textDirection: ui.TextDirection.rtl,
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Container(
        decoration: AccountantThemeConfig.mainBackgroundGradient,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test section header
              const Text(
                'اختبار بطاقات ملخص المحافظ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
                textDirection: ui.TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Test description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'هذا الاختبار يتحقق من الإصلاحات التالية:\n'
                  '• إصلاح تجزئة النصوص العربية\n'
                  '• حل مشاكل تداخل النصوص\n'
                  '• تحسين المسافات بين العناصر\n'
                  '• ضمان عرض صحيح للخط العربي\n'
                  '• تحسين التكيف مع أحجام الشاشات المختلفة',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                    height: 1.5,
                  ),
                  textDirection: ui.TextDirection.rtl,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Test cards in different screen sizes
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Desktop size test
                      _buildTestSection(
                        'اختبار حجم سطح المكتب (1200px+)',
                        _buildWalletCards(1200),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Tablet size test
                      _buildTestSection(
                        'اختبار حجم الجهاز اللوحي (768px-1199px)',
                        _buildWalletCards(900),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Mobile size test
                      _buildTestSection(
                        'اختبار حجم الهاتف المحمول (<768px)',
                        _buildWalletCards(400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestSection(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
            textDirection: ui.TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildWalletCards(double screenWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = screenWidth < 768 
            ? constraints.maxWidth * 0.9
            : constraints.maxWidth * 0.45;
        
        return screenWidth < 600
            ? Column(
                children: [
                  SizedBox(
                    width: cardWidth,
                    height: 140,
                    child: const ClientWalletsSummaryCard(
                      isSelected: false,
                      isConnectionMode: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: cardWidth,
                    height: 140,
                    child: const ElectronicWalletsSummaryCard(
                      isSelected: false,
                      isConnectionMode: false,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 140,
                      child: const ClientWalletsSummaryCard(
                        isSelected: false,
                        isConnectionMode: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 140,
                      child: const ElectronicWalletsSummaryCard(
                        isSelected: false,
                        isConnectionMode: false,
                      ),
                    ),
                  ),
                ],
              );
      },
    );
  }
}

void main() {
  runApp(const ArabicTextRenderingTest());
}
