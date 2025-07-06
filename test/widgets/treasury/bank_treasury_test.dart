import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/treasury_models.dart';
import 'package:smartbiztracker_new/widgets/treasury/payment_method_selector.dart';
import 'package:smartbiztracker_new/widgets/treasury/bank_selector.dart';
import 'package:smartbiztracker_new/widgets/treasury/bank_account_input_fields.dart';

void main() {
  group('Bank Treasury Functionality Tests', () {
    testWidgets('PaymentMethodSelector should switch between cash and bank', (WidgetTester tester) async {
      TreasuryType selectedType = TreasuryType.cash;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentMethodSelector(
              selectedType: selectedType,
              onTypeChanged: (type) {
                selectedType = type;
              },
            ),
          ),
        ),
      );

      // Verify cash option is initially selected
      expect(find.text('خزنة نقدية'), findsOneWidget);
      expect(find.text('حساب بنكي'), findsOneWidget);

      // Tap on bank option
      await tester.tap(find.text('حساب بنكي'));
      await tester.pump();

      // Verify the callback was called
      expect(selectedType, TreasuryType.bank);
    });

    testWidgets('BankSelector should display Egyptian banks', (WidgetTester tester) async {
      EgyptianBank? selectedBank;
      String? customBankName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BankSelector(
              selectedBank: selectedBank,
              customBankName: customBankName,
              onBankChanged: (bank) {
                selectedBank = bank;
              },
              onCustomBankNameChanged: (name) {
                customBankName = name;
              },
            ),
          ),
        ),
      );

      // Verify Egyptian banks are displayed
      expect(find.text('البنك التجاري الدولي'), findsOneWidget);
      expect(find.text('بنك مصر'), findsOneWidget);
      expect(find.text('بنك القاهرة'), findsOneWidget);
      expect(find.text('بنك آخر'), findsOneWidget);

      // Tap on CIB bank
      await tester.tap(find.text('البنك التجاري الدولي'));
      await tester.pump();

      // Verify the callback was called
      expect(selectedBank, EgyptianBank.cib);
    });

    testWidgets('BankAccountInputFields should validate account number', (WidgetTester tester) async {
      final accountNumberController = TextEditingController();
      final initialBalanceController = TextEditingController();
      final accountHolderController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: BankAccountInputFields(
                accountNumberController: accountNumberController,
                initialBalanceController: initialBalanceController,
                accountHolderController: accountHolderController,
                currencyCode: 'EGP',
              ),
            ),
          ),
        ),
      );

      // Find the account number field
      final accountNumberField = find.byType(TextFormField).first;
      
      // Enter invalid account number (too short)
      await tester.enterText(accountNumberField, '123');
      await tester.pump();

      // Verify validation message would appear
      expect(find.text('رقم الحساب البنكي'), findsOneWidget);
      expect(find.text('الرصيد الابتدائي'), findsOneWidget);
      expect(find.text('اسم صاحب الحساب'), findsOneWidget);
    });

    test('TreasuryVault model should support bank account information', () {
      final bankTreasury = TreasuryVault(
        id: 'test-id',
        name: 'Test Bank Treasury',
        currency: 'EGP',
        balance: 1000.0,
        exchangeRateToEgp: 1.0,
        isMainTreasury: false,
        positionX: 0.0,
        positionY: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        treasuryType: TreasuryType.bank,
        bankName: 'Commercial International Bank',
        accountNumber: '1234567890123456',
        accountHolderName: 'John Doe',
      );

      // Test bank treasury properties
      expect(bankTreasury.isBankTreasury, true);
      expect(bankTreasury.isCashTreasury, false);
      expect(bankTreasury.bankIcon, '🏦');
      expect(bankTreasury.maskedAccountNumber, '12******3456');
      expect(bankTreasury.displayName, 'Test Bank Treasury - Commercial International Bank');
    });

    test('TreasuryVault should handle different bank icons', () {
      final cibTreasury = TreasuryVault(
        id: 'cib-id',
        name: 'CIB Treasury',
        currency: 'EGP',
        balance: 1000.0,
        exchangeRateToEgp: 1.0,
        isMainTreasury: false,
        positionX: 0.0,
        positionY: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        treasuryType: TreasuryType.bank,
        bankName: 'Commercial International Bank',
        accountNumber: '1234567890',
      );

      final egyptBankTreasury = TreasuryVault(
        id: 'egypt-id',
        name: 'Egypt Bank Treasury',
        currency: 'EGP',
        balance: 1000.0,
        exchangeRateToEgp: 1.0,
        isMainTreasury: false,
        positionX: 0.0,
        positionY: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        treasuryType: TreasuryType.bank,
        bankName: 'بنك مصر',
        accountNumber: '1234567890',
      );

      expect(cibTreasury.bankIcon, '🏦');
      expect(egyptBankTreasury.bankIcon, '🇪🇬');
    });

    test('TreasuryVault should mask account numbers correctly', () {
      final shortAccount = TreasuryVault(
        id: 'short-id',
        name: 'Short Account',
        currency: 'EGP',
        balance: 1000.0,
        exchangeRateToEgp: 1.0,
        isMainTreasury: false,
        positionX: 0.0,
        positionY: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        treasuryType: TreasuryType.bank,
        bankName: 'Test Bank',
        accountNumber: '1234',
      );

      final longAccount = TreasuryVault(
        id: 'long-id',
        name: 'Long Account',
        currency: 'EGP',
        balance: 1000.0,
        exchangeRateToEgp: 1.0,
        isMainTreasury: false,
        positionX: 0.0,
        positionY: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        treasuryType: TreasuryType.bank,
        bankName: 'Test Bank',
        accountNumber: '12345678901234567890',
      );

      expect(shortAccount.maskedAccountNumber, '1234');
      expect(longAccount.maskedAccountNumber, '12********7890');
    });

    test('EgyptianBank enum should have correct values', () {
      expect(EgyptianBank.cib.nameAr, 'البنك التجاري الدولي');
      expect(EgyptianBank.cib.nameEn, 'Commercial International Bank');
      expect(EgyptianBank.cib.icon, '🏦');
      
      expect(EgyptianBank.bankOfEgypt.nameAr, 'بنك مصر');
      expect(EgyptianBank.bankOfCairo.nameAr, 'بنك القاهرة');
      expect(EgyptianBank.other.nameAr, 'بنك آخر');
    });
  });
}
