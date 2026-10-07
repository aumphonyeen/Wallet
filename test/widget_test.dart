// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_wallet/data/wallet_repository.dart';
import 'package:smart_wallet/models/wallet_transaction.dart';
import 'package:smart_wallet/screens/wallet_screens.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  test('transaction map round-trips every persisted field', () {
    final transaction = WalletTransaction(
      id: 7,
      title: 'Lunch',
      amount: 85.5,
      type: TransactionType.expense,
      category: 'อาหาร',
      date: DateTime(2026, 10, 4),
      note: 'With friends',
      slipImagePath: 'C:/app/slips/lunch.jpg',
    );

    final restored = WalletTransaction.fromMap(transaction.toMap());

    expect(restored.id, transaction.id);
    expect(restored.title, transaction.title);
    expect(restored.amount, transaction.amount);
    expect(restored.type, transaction.type);
    expect(restored.category, transaction.category);
    expect(restored.date, transaction.date);
    expect(restored.note, transaction.note);
    expect(restored.slipImagePath, transaction.slipImagePath);
  });

  testWidgets('transaction form validates required title and positive amount', (
    tester,
  ) async {
    final controller = WalletController(WalletRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TransactionEditor(controller: controller)),
      ),
    );

    await tester.ensureVisible(find.text('บันทึกรายการ'));
    await tester.tap(find.text('บันทึกรายการ'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อรายการ'), findsOneWidget);
    expect(find.text('กรุณากรอกจำนวนเงินที่มากกว่า 0'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('wallet dashboard, history, and reports show saved entries', (
    tester,
  ) async {
    final controller = WalletController(_MemoryWalletRepository());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: WalletShell(
          controller: controller,
          isDark: false,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('เงินสุทธิเดือนนี้'), findsOneWidget);
    expect(find.text('ยังไม่มีรายการ'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'ข้าวกลางวัน');
    await tester.enterText(find.byType(TextFormField).at(1), '120');
    await tester.ensureVisible(find.text('บันทึกรายการ'));
    await tester.tap(find.text('บันทึกรายการ'));
    await tester.pumpAndSettle();

    expect(find.text('ข้าวกลางวัน'), findsOneWidget);
    expect(find.text('฿120.00'), findsNWidgets(2));

    await tester.tap(find.text('รายการ'));
    await tester.pumpAndSettle();
    expect(find.text('ประวัติรายการ'), findsOneWidget);
    expect(find.text('ข้าวกลางวัน'), findsOneWidget);

    await tester.tap(find.text('วิเคราะห์'));
    await tester.pumpAndSettle();
    expect(find.text('วิเคราะห์การเงิน'), findsOneWidget);
    expect(find.text('อาหาร'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('compact mobile layout fits each main screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = WalletController(_MemoryWalletRepository());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: WalletShell(
          controller: controller,
          isDark: false,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final page in ['รายการ', 'วิเคราะห์', 'ตั้งค่า', 'ภาพรวม']) {
      await tester.tap(find.text(page).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Screen: $page');
    }

    controller.dispose();
  });
}

class _MemoryWalletRepository extends WalletRepository {
  final List<WalletTransaction> _transactions = [];
  int _nextId = 0;

  @override
  Future<List<WalletTransaction>> getAll() async =>
      List<WalletTransaction>.of(_transactions);

  @override
  Future<void> save(WalletTransaction transaction, {XFile? newSlip}) async {
    final saved = transaction.copyWith(id: transaction.id ?? ++_nextId);
    final index = _transactions.indexWhere((item) => item.id == saved.id);
    if (index < 0) {
      _transactions.add(saved);
    } else {
      _transactions[index] = saved;
    }
  }

  @override
  Future<void> delete(WalletTransaction transaction) async {
    _transactions.removeWhere((item) => item.id == transaction.id);
  }
}
