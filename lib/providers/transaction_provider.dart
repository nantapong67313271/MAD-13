import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/my_transaction.dart';

class TransactionProvider with ChangeNotifier {
  static const String _dbName = 'expenses.db';
  static const String _tableName = 'transactions';
  Database? _database;
  List<MyTransaction> _transactions = [];

  List<MyTransaction> get transactions => [..._transactions];
  TransactionProvider() {
    fetchAndSetTransactions(); // โหลดข้อมูลเมื่อ Provider ถูกสร้าง
  }

  // กระบวนการที่ 2: การสร้างฐานข้อมูล
  Future<void> _initDatabase() async {
    if (_database != null) return;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      _database = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) {
          return db.execute(
            'CREATE TABLE transactions(id TEXT PRIMARY KEY, title TEXT, amount REAL, date TEXT, type TEXT, note TEXT)',
          );
        },
        // ===== เพิ่มส่วน onUpgrade ตรงนี้ครับ =====
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE transactions ADD COLUMN note TEXT');
            print('Database upgraded: Added note column');
          }
        },
        // ==========================================
      );
      print('Database initialized at $path');
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    TransactionType type,
  ) async {
    await _initDatabase(); // ตรวจสอบว่า DB พร้อมใช้งาน
    if (_database == null) return;

    final newTransaction = MyTransaction(
      title: title,
      amount: amount,
      date: date,
      type: type,
    );

    final id = await _database!.insert(_tableName, newTransaction.toMap());
    print('Inserted transaction with id: $id');
  }

  Future<void> fetchAndSetTransactions() async {
    await _initDatabase();
    if (_database == null) return;

    final dataList = await _database!.query(_tableName, orderBy: 'date DESC');
    _transactions = dataList
        .map((item) => MyTransaction.fromMap(item))
        .toList();
    print('Fetched ${_transactions.length} transactions.');
    notifyListeners(); // แจ้ง UI ให้วาดใหม่
  }

  Future<void> updateTransaction(int id, MyTransaction newTransaction) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.update(
      _tableName,
      newTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    await fetchAndSetTransactions();
  }

  Future<double> getBalance() async {
    await _initDatabase();
    if (_database == null) return 0.0;
    final db = _database!;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT SUM(
      CASE 
        WHEN type = 'TransactionType.income' THEN amount 
        ELSE -amount 
      END
    ) as totalBalance
    FROM transactions
  ''');

    if (result.isNotEmpty && result.first['totalBalance'] != null) {
      return (result.first['totalBalance'] as num).toDouble();
    }
    return 0.0;
  }
}
