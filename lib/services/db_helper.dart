import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/invoice.dart';

class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'invoices.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number INTEGER NOT NULL,
            date TEXT NOT NULL,
            client_name TEXT NOT NULL,
            client_address TEXT NOT NULL,
            client_phone TEXT NOT NULL,
            tax_rate REAL NOT NULL,
            other_costs REAL NOT NULL,
            paid INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
          )
        ''');
        await d.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await d.execute(
              'ALTER TABLE invoices ADD COLUMN paid INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
  }

  // ---------- Settings (business details, logo path, etc.) ----------

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final d = await db;
    final r = await d.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? defaultValue : r.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final d = await db;
    await d.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- Invoices ----------

  Future<int> nextInvoiceNumber() async {
    final d = await db;
    final r = await d.rawQuery('SELECT MAX(number) AS m FROM invoices');
    final m = r.first['m'] as int?;
    return (m ?? 0) + 1;
  }

  Future<int> saveInvoice(Invoice inv) async {
    final d = await db;
    return d.transaction((txn) async {
      int id;
      if (inv.id == null) {
        id = await txn.insert('invoices', inv.toMap());
      } else {
        id = inv.id!;
        await txn.update('invoices', inv.toMap(),
            where: 'id = ?', whereArgs: [id]);
        await txn.delete('invoice_items',
            where: 'invoice_id = ?', whereArgs: [id]);
      }
      for (final item in inv.items) {
        await txn.insert('invoice_items', {
          'invoice_id': id,
          'description': item.description,
          'amount': item.amount,
        });
      }
      return id;
    });
  }

  Future<void> setPaid(int id, bool paid) async {
    final d = await db;
    await d.update(
      'invoices',
      {'paid': paid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Invoice>> getInvoices() async {
    final d = await db;
    final rows = await d.query('invoices', orderBy: 'number DESC');
    final result = <Invoice>[];
    for (final row in rows) {
      final itemRows = await d.query('invoice_items',
          where: 'invoice_id = ?', whereArgs: [row['id']], orderBy: 'id ASC');
      result.add(Invoice.fromMap(
        row,
        itemRows.map(InvoiceItem.fromMap).toList(),
      ));
    }
    return result;
  }

  Future<void> deleteInvoice(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [id]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
  }
}
