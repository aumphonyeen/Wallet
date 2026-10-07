import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/wallet_transaction.dart';

class WalletRepository {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasePath = kIsWeb
        ? 'smart_wallet.db'
        : path.join(await getDatabasesPath(), 'smart_wallet.db');
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE wallet_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            slip_image_path TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX transactions_date_idx '
          'ON wallet_transactions(date)',
        );
      },
    );
    return _database!;
  }

  Future<List<WalletTransaction>> getAll() async {
    final rows = await (await database).query(
      'wallet_transactions',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(WalletTransaction.fromMap).toList();
  }

  Future<void> save(WalletTransaction transaction, {XFile? newSlip}) async {
    final db = await database;
    final copiedSlip = newSlip == null ? null : await _copySlip(newSlip);
    final savedTransaction = transaction.copyWith(
      slipImagePath: copiedSlip ?? transaction.slipImagePath,
    );
    try {
      if (transaction.id == null) {
        await db.insert('wallet_transactions', savedTransaction.toMap());
      } else {
        final changed = await db.update(
          'wallet_transactions',
          savedTransaction.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [transaction.id],
        );
        if (changed == 0) {
          throw StateError('ไม่พบรายการที่ต้องการแก้ไข');
        }
      }
    } catch (_) {
      if (copiedSlip != null && !kIsWeb) {
        await File(copiedSlip).delete();
      }
      rethrow;
    }
  }

  Future<void> delete(WalletTransaction transaction) async {
    final db = await database;
    final deleted = await db.delete(
      'wallet_transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    if (deleted == 0) {
      throw StateError('ไม่พบรายการที่ต้องการลบ');
    }
    final slipPath = transaction.slipImagePath;
    if (slipPath != null && !kIsWeb) {
      final slip = File(slipPath);
      if (await slip.exists()) await slip.delete();
    }
  }

  Future<String> _copySlip(XFile slip) async {
    if (kIsWeb) {
      final bytes = await slip.readAsBytes();
      return 'data:${slip.mimeType ?? 'image/jpeg'};base64,'
          '${base64Encode(bytes)}';
    }
    final directory = await getApplicationDocumentsDirectory();
    final slipsDirectory = Directory(path.join(directory.path, 'slips'));
    await slipsDirectory.create(recursive: true);
    final extension = path.extension(slip.path).toLowerCase();
    final filename = '${DateTime.now().microsecondsSinceEpoch}$extension';
    final copiedFile = await File(
      slip.path,
    ).copy(path.join(slipsDirectory.path, filename));
    return copiedFile.path;
  }
}

class WalletController extends ChangeNotifier {
  WalletController(this._repository);

  final WalletRepository _repository;
  List<WalletTransaction> transactions = [];
  bool isLoading = true;
  Object? loadError;

  Future<void> load() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      transactions = await _repository.getAll();
    } catch (error) {
      loadError = error;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> save(WalletTransaction transaction, {XFile? newSlip}) async {
    await _repository.save(transaction, newSlip: newSlip);
    transactions = await _repository.getAll();
    notifyListeners();
  }

  Future<void> delete(WalletTransaction transaction) async {
    await _repository.delete(transaction);
    transactions = await _repository.getAll();
    notifyListeners();
  }
}
