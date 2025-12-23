import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // السطر ده لازم يكون موجود
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  final String _dbName = 'SmartAccountingDB.db';
  final int _dbVersion = 2;

  // Getter للرقم عشان شاشة الإعدادات
  int get currentDbVersion => _dbVersion;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 2. الحصول على المسار الموحد
    final String path = await getDbPath();

    // 3. فتح قاعدة البيانات
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  // --- دالة الإنشاء (للمستخدم الجديد "على نظافة") ---
  Future _onCreate(Database db, int version) async {
    // 1. العملاء
    await db.execute(
      'CREATE TABLE clients (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, address TEXT, balance REAL DEFAULT 0.0)',
    );
    // 2. الموردين
    await db.execute(
      'CREATE TABLE suppliers (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, name TEXT, contactPerson TEXT, phone TEXT, address TEXT, notes TEXT, balance REAL DEFAULT 0.0)',
    );
    // 3. المنتجات (شاملة الصورة)
    await db.execute(
      'CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, code TEXT, barcode TEXT, category TEXT, unit TEXT, buyPrice REAL, sellPrice REAL, minSellPrice REAL, stock INTEGER, reorderLevel INTEGER, supplierId INTEGER, notes TEXT, expiryDate TEXT, imagePath TEXT)',
    );
    // 4. الوحدات
    await db.execute(
      'CREATE TABLE units (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
    );
    await db.insert('units', {'name': 'قطعة'});
    await db.insert('units', {'name': 'كرتونة'});

    // 5. المبيعات (شاملة كل الأعمدة الجديدة)
    await db.execute(
      "CREATE TABLE sales (id INTEGER PRIMARY KEY AUTOINCREMENT, clientId INTEGER, storedClientName TEXT, totalAmount REAL, taxAmount REAL DEFAULT 0.0, discount REAL DEFAULT 0.0, netAmount REAL DEFAULT 0.0, date TEXT, notes TEXT, referenceNumber TEXT, totalReturned REAL DEFAULT 0.0, paymentType TEXT DEFAULT 'cash')",
    );
    await db.execute(
      'CREATE TABLE sale_items (id INTEGER PRIMARY KEY AUTOINCREMENT, saleId INTEGER, productId INTEGER, productName TEXT, quantity INTEGER, price REAL)',
    );

    // 6. المرتجعات (عملاء)
    await db.execute(
      'CREATE TABLE returns (id INTEGER PRIMARY KEY AUTOINCREMENT, saleId INTEGER, clientId INTEGER, totalAmount REAL, discount REAL DEFAULT 0.0, paidAmount REAL DEFAULT 0.0, date TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE return_items (id INTEGER PRIMARY KEY AUTOINCREMENT, returnId INTEGER, productId INTEGER, quantity INTEGER, price REAL)',
    );

    // 7. المشتريات
    await db.execute(
      'CREATE TABLE purchase_invoices (id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, totalAmount REAL, taxAmount REAL DEFAULT 0.0, date TEXT, notes TEXT, referenceNumber TEXT)',
    );
    await db.execute(
      'CREATE TABLE purchase_items (id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceId INTEGER, productId INTEGER, quantity INTEGER, costPrice REAL)',
    );

    // 8. جداول مالية
    await db.execute(
      'CREATE TABLE opening_balances (id INTEGER PRIMARY KEY AUTOINCREMENT, clientId INTEGER, amount REAL, date TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE receipts (id INTEGER PRIMARY KEY AUTOINCREMENT, clientId INTEGER, amount REAL, date TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE supplier_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, amount REAL, date TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE client_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, clientId INTEGER, amount REAL, date TEXT, notes TEXT, type TEXT)',
    );
    await db.execute(
      'CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, category TEXT, notes TEXT)',
    );

    // 9. الجداول الجديدة (مهمة جداً)
    await db.execute(
      'CREATE TABLE supplier_opening_balances (id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, amount REAL, date TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE purchase_returns (id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceId INTEGER, supplierId INTEGER, totalAmount REAL, date TEXT, notes TEXT)',
    );
    await db.execute(
      'CREATE TABLE purchase_return_items (id INTEGER PRIMARY KEY AUTOINCREMENT, returnId INTEGER, productId INTEGER, quantity INTEGER, price REAL)',
    );
  }

  // --- 🔥 دالة الترقية (للمستخدم القديم - دي اللي هتحميك) 🔥 ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // الترقية التراكمية: الكود ده هيشتغل لو العميل عنده أي نسخة قديمة

    // 1. التأكد من وجود الجداول الأساسية المضافة حديثاً
    if (oldVersion < 2) {
      // جدول المصاريف
      await db.execute(
        'CREATE TABLE IF NOT EXISTS expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, category TEXT, notes TEXT)',
      );

      // تحديثات الأعمدة (نستخدم try-catch عشان لو العمود موجود التطبيق مايضربش)
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN discount REAL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN taxAmount REAL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN netAmount REAL DEFAULT 0.0',
        );
      } catch (_) {}

      // معادلة البيانات القديمة
      await db.execute(
        'UPDATE sales SET netAmount = totalAmount WHERE netAmount = 0 OR netAmount IS NULL',
      );

      try {
        await db.execute('ALTER TABLE products ADD COLUMN expiryDate TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN productName TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN totalReturned REAL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE sales ADD COLUMN paymentType TEXT DEFAULT 'cash'",
        );
      } catch (_) {}

      // جدول مدفوعات العملاء
      await db.execute(
        'CREATE TABLE IF NOT EXISTS client_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, clientId INTEGER, amount REAL, date TEXT, notes TEXT, type TEXT)',
      );

      try {
        await db.execute(
          'ALTER TABLE returns ADD COLUMN paidAmount REAL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE returns ADD COLUMN discount REAL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE purchase_invoices ADD COLUMN taxAmount REAL DEFAULT 0.0',
        );
      } catch (_) {}

      // 🔥 الجداول الجديدة (مع IF NOT EXISTS للحماية القصوى) 🔥

      // أرصدة الموردين الافتتاحية
      await db.execute(
        'CREATE TABLE IF NOT EXISTS supplier_opening_balances (id INTEGER PRIMARY KEY AUTOINCREMENT, supplierId INTEGER, amount REAL, date TEXT, notes TEXT)',
      );

      // مرتجعات الموردين
      await db.execute(
        'CREATE TABLE IF NOT EXISTS purchase_returns (id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceId INTEGER, supplierId INTEGER, totalAmount REAL, date TEXT, notes TEXT)',
      );

      await db.execute(
        'CREATE TABLE IF NOT EXISTS purchase_return_items (id INTEGER PRIMARY KEY AUTOINCREMENT, returnId INTEGER, productId INTEGER, quantity INTEGER, price REAL)',
      );

      // 🖼️ إضافة عمود الصورة (آخر تحديث)
      try {
        await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT');
      } catch (e) {
        // تجاهل الخطأ لو العمود موجود
      }
    }
  }

  // ==================== (1) المصاريف ====================
  Future<int> insertExpense(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('expenses', row);
  }

  Future<List<Map<String, dynamic>>> getExpenses({
    String? startDate,
    String? endDate,
  }) async {
    Database db = await database;
    if (startDate != null && endDate != null) {
      String end = "$endDate 23:59:59";
      return await db.query(
        'expenses',
        where: "date BETWEEN ? AND ?",
        whereArgs: [startDate, end],
        orderBy: "date DESC",
      );
    }
    return await db.query('expenses', orderBy: "date DESC");
  }

  Future<int> deleteExpense(int id) async {
    Database db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== (2) العملاء ====================
  Future<int> insertClient(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('clients', row);
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    Database db = await database;
    return await db.query('clients', orderBy: "name ASC");
  }

  Future<int> updateClient(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update(
      'clients',
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<int> deleteClient(int id) async {
    Database db = await database;
    return await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateClientOpeningBalance(int clientId, double amount) async {
    Database db = await database;
    var res = await db.query(
      'opening_balances',
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
    if (res.isNotEmpty) {
      await db.update(
        'opening_balances',
        {'amount': amount},
        where: 'clientId = ?',
        whereArgs: [clientId],
      );
    } else {
      await addOpeningBalance(clientId, amount);
    }
  }

  Future<void> addOpeningBalance(int clientId, double amount) async {
    Database db = await database;
    await db.insert('opening_balances', {
      'clientId': clientId,
      'amount': amount,
      'date': DateTime.now().toString(),
      'notes': 'رصيد افتتاحي',
    });
  }

  Future<double> getOpeningBalanceAmount(int clientId) async {
    Database db = await database;
    List<Map> result = await db.query(
      'opening_balances',
      columns: ['amount'],
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
    if (result.isNotEmpty) {
      return (result.first['amount'] as num).toDouble();
    }
    return 0.0;
  }

  // --- سندات قبض (من العميل) ---
  Future<int> addReceipt(
    int clientId,
    double amount,
    String notes,
    String date,
  ) async {
    Database db = await database;
    return await db.insert('receipts', {
      'clientId': clientId,
      'amount': amount,
      'date': date,
      'notes': notes,
    });
  }

  Future<int> updateReceipt(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update(
      'receipts',
      {'amount': row['amount'], 'date': row['date'], 'notes': row['notes']},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<int> deleteReceipt(int id) async {
    Database db = await database;
    return await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  // ✅✅ دالة جديدة: إضافة مدفوعات للعميل (مثل المرتجع النقدي) ✅✅
  Future<int> addClientPayment(
    int clientId,
    double amount,
    String notes,
    String date,
  ) async {
    Database db = await database;
    return await db.insert('client_payments', {
      'clientId': clientId,
      'amount': amount,
      'date': date,
      'notes': notes,
      'type': 'return_refund',
    });
  }

  // استبدل الدالة القديمة بهذه الدالة المحدثة
  Future<List<Map<String, dynamic>>> getClientStatement(
    int clientId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Database db = await database;

    // تجهيز شرط التاريخ
    String dateFilter = "";
    List<dynamic> args = [clientId];

    if (startDate != null && endDate != null) {
      // نضيف يوم للنهاية لضمان شمول اليوم الأخير بالكامل
      String start = startDate.toString();
      String end = endDate.add(const Duration(days: 1)).toString();
      dateFilter = " AND date >= ? AND date < ?";
      args.add(start);
      args.add(end);
    }

    // جلب البيانات مع الفلتر
    List<Map<String, dynamic>> sales = await db.rawQuery(
      'SELECT * FROM sales WHERE clientId = ?$dateFilter',
      args,
    );
    List<Map<String, dynamic>> returns = await db.rawQuery(
      'SELECT * FROM returns WHERE clientId = ?$dateFilter',
      args,
    );
    List<Map<String, dynamic>> receipts = await db.rawQuery(
      'SELECT * FROM receipts WHERE clientId = ?$dateFilter',
      args,
    );
    List<Map<String, dynamic>> paymentsToClient = await db.rawQuery(
      'SELECT * FROM client_payments WHERE clientId = ?$dateFilter',
      args,
    );

    // الأرصدة الافتتاحية عادة لا ترتبط بتاريخ محدد في كشف الفترة،
    // ولكن سنجلبها إذا لم يكن هناك فلتر تاريخ أو إذا كان تاريخ البداية يشملها
    // للتبسيط سنجلبها فقط إذا لم يتم تحديد تاريخ أو سنعتمد عليها كرصيد سابق
    List<Map<String, dynamic>> openings = [];
    if (startDate == null) {
      openings = await db.query(
        'opening_balances',
        where: 'clientId = ?',
        whereArgs: [clientId],
      );
    }

    List<Map<String, dynamic>> statement = [];

    for (var op in openings) {
      statement.add({
        'type': 'opening',
        'date': op['date'],
        'amount': (op['amount'] as num).toDouble(),
        'description': 'رصيد افتتاحي',
        'id': op['id'],
        'isDebit': true,
      });
    }
    for (var sale in sales) {
      double amount = (sale['netAmount'] != null)
          ? (sale['netAmount'] as num).toDouble()
          : (sale['totalAmount'] as num).toDouble();
      statement.add({
        'type': 'sale',
        'date': sale['date'],
        'amount': amount,
        'description': 'فاتورة مبيعات #${sale['id']}',
        'id': sale['id'],
      });
    }
    for (var ret in returns) {
      statement.add({
        'type': 'return',
        'date': ret['date'],
        'amount': (ret['totalAmount'] as num).toDouble(),
        'description': 'مرتجع مبيعات #${ret['id']}',
        'id': ret['id'],
      });
    }
    for (var rec in receipts) {
      statement.add({
        'type': 'payment',
        'date': rec['date'],
        'amount': (rec['amount'] as num).toDouble(),
        'description': rec['notes'] ?? 'دفعة',
        'id': rec['id'],
      });
    }
    for (var pay in paymentsToClient) {
      statement.add({
        'type': 'refund_payment',
        'date': pay['date'],
        'amount': (pay['amount'] as num).toDouble(),
        'description': pay['notes'] ?? 'صرف نقدية',
        'id': pay['id'],
      });
    }

    // ترتيب العمليات حسب التاريخ
    statement.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );
    return statement;
  }

  Future<double> getClientCurrentBalance(int clientId) async {
    var statement = await getClientStatement(clientId);
    double balance = 0;
    for (var item in statement) {
      if (item['type'] == 'opening' ||
          item['type'] == 'sale' ||
          item['type'] == 'refund_payment') {
        // refund_payment: يعني إحنا دفعنا للعميل فلوس (رصيده زاد عندنا/ أو قللنا اللي عليه)
        // محاسبياً: الفاتورة (مدين +)، المرتجع (دائن -).
        // القبض من العميل (دائن -).
        // الصرف للعميل (مدين +) -> لأنه أخد فلوس.
        balance += item['amount'];
      } else {
        // مرتجع أو استلام نقدية
        balance -= item['amount'];
      }
    }
    return balance;
  }

  // ==================== (3) الموردين والمشتريات ====================
  // ... (نفس الدوال السابقة بدون تغيير) ...
  Future<int> insertSupplier(Map<String, dynamic> row) async =>
      await (await database).insert('suppliers', row);
  Future<List<Map<String, dynamic>>> getSuppliers() async =>
      await (await database).query('suppliers', orderBy: "name ASC");
  Future<int> updateSupplier(Map<String, dynamic> row) async =>
      await (await database).update(
        'suppliers',
        row,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
  Future<int> deleteSupplier(int id) async => await (await database).delete(
    'suppliers',
    where: 'id = ?',
    whereArgs: [id],
  );
  Future<int> insertProduct(Map<String, dynamic> row) async =>
      await (await database).insert('products', row);
  Future<List<Map<String, dynamic>>> getProducts() async {
    Database db = await database;
    return await db.rawQuery(
      'SELECT products.*, suppliers.name as supplierName FROM products LEFT JOIN suppliers ON products.supplierId = suppliers.id',
    );
  }

  Future<int> updateProduct(Map<String, dynamic> row) async =>
      await (await database).update(
        'products',
        row,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
  Future<int> deleteProduct(int id) async => await (await database).delete(
    'products',
    where: 'id = ?',
    whereArgs: [id],
  );
  Future<void> updateProductStock(int productId, int quantityChange) async {
    Database db = await database;
    var result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (result.isNotEmpty) {
      int currentStock = result.first['stock'] as int;
      await db.update(
        'products',
        {'stock': currentStock + quantityChange},
        where: 'id = ?',
        whereArgs: [productId],
      );
    }
  }

  Future<int> insertUnit(String name) async =>
      await (await database).insert('units', {'name': name});
  Future<List<Map<String, dynamic>>> getUnits() async =>
      await (await database).query('units');
  Future<int> deleteUnit(String name) async => await (await database).delete(
    'units',
    where: 'name = ?',
    whereArgs: [name],
  );

  // --- عمليات المبيعات ---
  // --- عمليات المبيعات (معدلة لتدعم الدفع الكاش) ---
  Future<void> createSale(
    int clientId,
    String clientName,
    double totalAmount,
    double taxAmount,
    List<Map<String, dynamic>> items, {
    String refNumber = '',
    double discount = 0.0,
    bool isCash = false, // 🆕 معامل جديد: هل الفاتورة كاش؟
  }) async {
    Database db = await database;
    await db.transaction((txn) async {
      double netAmount = (totalAmount - discount) + taxAmount;

      // 1. تسجيل الفاتورة (زيادة المديونية)
      int saleId = await txn.insert('sales', {
        'clientId': clientId,
        'storedClientName': clientName,
        'date': DateTime.now().toString(),
        'totalAmount': totalAmount,
        'discount': discount,
        'taxAmount': taxAmount,
        'netAmount': netAmount,
        'referenceNumber': refNumber,
        'paymentType': isCash ? 'cash' : 'credit',
      });

      // 2. إضافة الأصناف وتحديث المخزون
      for (var item in items) {
        await txn.insert('sale_items', {
          'saleId': saleId,
          'productId': item['productId'],
          'productName': item['name'],
          'quantity': item['quantity'],
          'price': item['price'],
        });
        var prod = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item['productId']],
        );
        if (prod.isNotEmpty) {
          int currentStock = prod.first['stock'] as int;
          await txn.update(
            'products',
            {'stock': currentStock - (item['quantity'] as int)},
            where: 'id = ?',
            whereArgs: [item['productId']],
          );
        }
        if (isCash) {
          await txn.insert('receipts', {
            'clientId': clientId,
            'amount': netAmount,
            'date': DateTime.now().toString(),
            'notes': 'دفع فوري - فاتورة مبيعات #$saleId',
          });
        }
      }

      // 3. 🆕 إذا كانت الفاتورة كاش، نسجل سند قبض فوراً (تصفير المديونية لهذه الفاتورة)
      if (isCash) {
        await txn.insert('receipts', {
          'clientId': clientId,
          'amount': netAmount, // المبلغ كامل
          'date': DateTime.now().toString(),
          'notes': 'دفع فوري - فاتورة مبيعات #$saleId', // ملاحظة آلية
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSalesWithNames() async {
    Database db = await database;
    return await db.rawQuery(
      "SELECT sales.*, COALESCE(sales.storedClientName, clients.name, 'غير معروف') as clientName FROM sales LEFT JOIN clients ON sales.clientId = clients.id ORDER BY sales.date DESC",
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    Database db = await database;
    return await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
  }

  // --- المرتجعات (تم تحديثها لقبول الخصم إذا رغبت مستقبلاً) ---
  Future<void> createReturn(
    int saleId,
    int clientId,
    double returnTotal,
    List<Map<String, dynamic>> itemsToReturn, {
    double discount = 0.0,
  }) async {
    Database db = await database;
    await db.transaction((txn) async {
      int returnId = await txn.insert('returns', {
        'saleId': saleId,
        'clientId': clientId,
        'date': DateTime.now().toString(),
        'totalAmount': returnTotal,
        'discount': discount,
        'notes': 'مرتجع',
      });
      for (var item in itemsToReturn) {
        await txn.insert('return_items', {
          'returnId': returnId,
          'productId': item['productId'],
          'quantity': item['quantity'],
          'price': item['price'],
        });
        var prod = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item['productId']],
        );
        if (prod.isNotEmpty) {
          int current = prod.first['stock'] as int;
          await txn.update(
            'products',
            {'stock': current + (item['quantity'] as int)},
            where: 'id = ?',
            whereArgs: [item['productId']],
          );
        }
      }
      var sale = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (sale.isNotEmpty) {
        double currentReturned =
            (sale.first['totalReturned'] as num?)?.toDouble() ?? 0.0;
        await txn.update(
          'sales',
          {'totalReturned': currentReturned + returnTotal},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllReturns() async {
    Database db = await database;
    return await db.rawQuery(
      'SELECT returns.*, clients.name as clientName FROM returns LEFT JOIN clients ON returns.clientId = clients.id ORDER BY returns.date DESC',
    );
  }

  // --- دالة حذف المرتجع (الآمنة) ---
  Future<void> deleteReturn(int returnId) async {
    Database db = await database;
    await db.transaction((txn) async {
      // 1. جلب أصناف المرتجع قبل الحذف (عشان نخصمها من المخزن)
      List<Map<String, dynamic>> items = await txn.query(
        'return_items',
        where: 'returnId = ?',
        whereArgs: [returnId],
      );

      // 2. عكس عملية المخزون (نقص الكميات تاني)
      for (var item in items) {
        var prod = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item['productId']],
        );
        if (prod.isNotEmpty) {
          int currentStock = prod.first['stock'] as int;
          // هنا بنطرح الكمية لأننا بنلغي المرتجع
          await txn.update(
            'products',
            {'stock': currentStock - (item['quantity'] as int)},
            where: 'id = ?',
            whereArgs: [item['productId']],
          );
        }
      }

      // 3. حذف أي مدفوعات نقدية مرتبطة بهذا المرتجع (عشان الخزنة تظبط)
      // بنبحث في جدول المدفوعات عن الملاحظة اللي فيها رقم المرتجع
      await txn.delete(
        'client_payments',
        where: "notes LIKE ?",
        whereArgs: ['%مرتجع #$returnId%'],
      );

      // 4. حذف أصناف المرتجع
      await txn.delete(
        'return_items',
        where: 'returnId = ?',
        whereArgs: [returnId],
      );

      // 5. حذف المرتجع نفسه
      await txn.delete('returns', where: 'id = ?', whereArgs: [returnId]);

      // 6. (اختياري) تحديث إجمالي المرتجعات في جدول المبيعات الأصلي
      // دي خطوة تكميلية لو حابب الدقة 100% بس مش حرجة أوي للرصيد
    });
  }

  Future<List<Map<String, dynamic>>> getReturnItems(int returnId) async {
    Database db = await database;
    try {
      return await db.rawQuery(
        'SELECT ri.*, p.name as productName FROM return_items ri LEFT JOIN products p ON ri.productId = p.id WHERE ri.returnId = ?',
        [returnId],
      );
    } catch (e) {
      return [];
    }
  }

  // ✅ تعديل دالة صرف النقدية لتستخدم الجدول الجديد
  Future<void> payReturnCash(int returnId, int clientId, double amount) async {
    Database db = await database;
    await db.transaction((txn) async {
      // 1. تسجيل العملية في جدول المدفوعات (عشان الخزنة)
      await txn.insert('client_payments', {
        'clientId': clientId,
        'amount': amount,
        'date': DateTime.now().toString(),
        'notes': 'صرف نقدية عن مرتجع #$returnId',
        'type': 'return_refund',
      });

      // 2. تحديث المرتجع نفسه إننا دفعنا جزء منه أو كله
      await txn.rawUpdate(
        'UPDATE returns SET paidAmount = paidAmount + ? WHERE id = ?',
        [amount, returnId],
      );
    });
  }

  // --- المشتريات ومدفوعات الموردين والتقارير ---
  // (نفس الكود السابق بالكامل)
  // ==================== (3) الموردين والمشتريات (معدلة بنظام المتوسط المرجح) ====================

  Future<void> createPurchase(
    int supplierId,
    double totalAmount,
    List<Map<String, dynamic>> items, {
    String refNumber = '',
    String? customDate,
    double taxAmount = 0.0,
  }) async {
    Database db = await database;
    await db.transaction((txn) async {
      // 1. إنشاء الفاتورة
      int purchaseId = await txn.insert('purchase_invoices', {
        'supplierId': supplierId,
        'date': customDate ?? DateTime.now().toString(),
        'totalAmount': totalAmount,
        'referenceNumber': refNumber,
        'taxAmount': taxAmount,
      });

      for (var item in items) {
        // 2. إضافة الأصناف للفاتورة
        await txn.insert('purchase_items', {
          'invoiceId': purchaseId,
          'productId': item['productId'],
          'quantity': item['quantity'],
          'costPrice': item['price'],
        });

        // 3. تحديث المخزون (بنظام المتوسط المرجح - Weighted Average) 🔥
        var prod = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item['productId']],
        );

        if (prod.isNotEmpty) {
          int oldStock = prod.first['stock'] as int;
          double oldBuyPrice = (prod.first['buyPrice'] as num).toDouble();

          int newQty = item['quantity'] as int;
          double newBuyPrice = (item['price'] as num).toDouble();

          // معادلة المتوسط المرجح
          double totalOldValue = oldStock * oldBuyPrice; // قيمة القديم
          double totalNewValue = newQty * newBuyPrice; // قيمة الجديد
          int totalStock = oldStock + newQty; // العدد الكلي

          // تفادي القسمة على صفر (حماية)
          double weightedAveragePrice = totalStock > 0
              ? (totalOldValue + totalNewValue) / totalStock
              : newBuyPrice;

          // تحديث المنتج بالسعر الجديد (المتوسط) والكمية الجديدة
          await txn.update(
            'products',
            {
              'stock': totalStock,
              'buyPrice': weightedAveragePrice, // 👈 هنا السعر بيبقى المتوسط
            },
            where: 'id = ?',
            whereArgs: [item['productId']],
          );
        }
      }

      // 4. تحديث رصيد المورد
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
        [totalAmount, supplierId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getPurchasesWithNames() async {
    Database db = await database;
    return await db.rawQuery(
      'SELECT p.*, s.name as supplierName FROM purchase_invoices p LEFT JOIN suppliers s ON p.supplierId = s.id ORDER BY p.date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(int invoiceId) async {
    Database db = await database;
    return await db.rawQuery(
      'SELECT pi.*, p.name as productName FROM purchase_items pi LEFT JOIN products p ON pi.productId = p.id WHERE pi.invoiceId = ?',
      [invoiceId],
    );
  }

  Future<void> addSupplierPayment(
    int supplierId,
    double amount,
    String notes,
    String date,
  ) async {
    Database db = await database;
    await db.insert('supplier_payments', {
      'supplierId': supplierId,
      'amount': amount,
      'date': date,
      'notes': notes,
    });
    await db.rawUpdate(
      'UPDATE suppliers SET balance = balance - ? WHERE id = ?',
      [amount, supplierId],
    );
  }

  Future<int> updateSupplierPayment({
    required int id,
    required int supplierId,
    required double oldAmount,
    required double newAmount,
    required String newNotes,
    required String newDate,
  }) async {
    Database db = await database;
    await db.rawUpdate(
      'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
      [oldAmount, supplierId],
    );
    return await db
        .update(
          'supplier_payments',
          {'amount': newAmount, 'date': newDate, 'notes': newNotes},
          where: 'id = ?',
          whereArgs: [id],
        )
        .then((value) {
          db.rawUpdate(
            'UPDATE suppliers SET balance = balance - ? WHERE id = ?',
            [newAmount, supplierId],
          );
          return value;
        });
  }

  Future<int> deleteSupplierPayment(
    int id,
    int supplierId,
    double amount,
  ) async {
    Database db = await database;
    await db.rawUpdate(
      'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
      [amount, supplierId],
    );
    return await db.delete(
      'supplier_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierStatement(
    int supplierId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Database db = await database;

    // شروط البحث
    String whereClause = 'supplierId = ?';
    List<dynamic> args = [supplierId];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.add(const Duration(days: 1)).toIso8601String());
    }

    // 1. جلب الفواتير (مشتريات)
    List<Map<String, dynamic>> purchases = await db.query(
      'purchase_invoices',
      where: whereClause,
      whereArgs: args,
    );

    // 2. جلب المدفوعات (سندات دفع)
    List<Map<String, dynamic>> payments = await db.query(
      'supplier_payments',
      where: whereClause,
      whereArgs: args,
    );

    // 3. 🔥 جلب المرتجعات (الجديد)
    List<Map<String, dynamic>> returns = await db.query(
      'purchase_returns',
      where: whereClause,
      whereArgs: args,
    );

    List<Map<String, dynamic>> statement = [];

    // إضافة المشتريات
    for (var bill in purchases) {
      statement.add({
        'type': 'bill', // فاتورة شراء
        'date': bill['date'],
        'amount': (bill['totalAmount'] as num).toDouble(),
        'description': 'فاتورة شراء #${bill['id']}',
        'id': bill['id'],
      });
    }

    // إضافة المدفوعات
    for (var pay in payments) {
      statement.add({
        'type': 'payment', // دفع فلوس للمورد
        'date': pay['date'],
        'amount': (pay['amount'] as num).toDouble(),
        'description': pay['notes'],
        'id': pay['id'],
      });
    }

    // 🔥 إضافة المرتجعات للقائمة
    for (var ret in returns) {
      statement.add({
        'type': 'return', // مرتجع بضاعة
        'date': ret['date'],
        'amount': (ret['totalAmount'] as num).toDouble(),
        'description': 'مرتجع مشتريات #${ret['id']}', // أو ملاحظات المرتجع
        'id': ret['id'],
      });
    }

    // ترتيب الكل حسب التاريخ
    statement.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );
    return statement;
  }

  Future<Map<String, double>> getGeneralReportData() async {
    Database db = await database;

    // 1. الأرصدة التراكمية (كما هي)
    var inv = await db.rawQuery(
      'SELECT SUM(stock * buyPrice) as t FROM products',
    );
    var open = await db.rawQuery(
      'SELECT SUM(amount) as t FROM opening_balances',
    );
    var sales = await db.rawQuery('SELECT SUM(netAmount) as t FROM sales');
    var ret = await db.rawQuery('SELECT SUM(totalAmount) as t FROM returns');
    var rec = await db.rawQuery('SELECT SUM(amount) as t FROM receipts');
    var clientPay = await db.rawQuery(
      'SELECT SUM(amount) as t FROM client_payments',
    );
    var sup = await db.rawQuery('SELECT SUM(balance) as t FROM suppliers');

    // 2. تجهيز تواريخ الشهر الحالي بدقة (من أول لحظة في الشهر لأول لحظة في الشهر القادم)
    DateTime now = DateTime.now();

    // أول يوم في الشهر الحالي (مثلاً: 2025-12-01 00:00:00)
    String startOfMonth = DateTime(now.year, now.month, 1).toString();

    // أول يوم في الشهر القادم (مثلاً: 2026-01-01 00:00:00)
    // استخدام هذا الأسلوب يضمن أننا نغطي كل لحظة في الشهر الحالي
    String startOfNextMonth = DateTime(now.year, now.month + 1, 1).toString();

    // 3. الاستعلامات باستخدام المنطق الجديد (>= البداية و < النهاية)

    // أ. المبيعات
    var mSales = await db.rawQuery(
      'SELECT SUM(netAmount) as t FROM sales WHERE date >= ? AND date < ?',
      [startOfMonth, startOfNextMonth],
    );

    // ب. المصاريف
    var mExp = await db.rawQuery(
      'SELECT SUM(amount) as t FROM expenses WHERE date >= ? AND date < ?',
      [startOfMonth, startOfNextMonth],
    );

    // ج. المرتجعات
    var mRet = await db.rawQuery(
      'SELECT SUM(totalAmount) as t FROM returns WHERE date >= ? AND date < ?',
      [startOfMonth, startOfNextMonth],
    );

    // د. 🔥 إجمالي فواتير الشراء (accrual)
    var mPurBills = await db.rawQuery(
      'SELECT SUM(totalAmount) as t FROM purchase_invoices WHERE date >= ? AND date < ?',
      [startOfMonth, startOfNextMonth],
    );

    // هـ. 🔥 المدفوعات للموردين (cash flow)
    var mSupPay = await db.rawQuery(
      'SELECT SUM(amount) as t FROM supplier_payments WHERE date >= ? AND date < ?',
      [startOfMonth, startOfNextMonth],
    );

    // الحسابات النهائية
    double inventory = (inv.first['t'] as num?)?.toDouble() ?? 0.0;

    double receivables =
        ((open.first['t'] as num?)?.toDouble() ?? 0) +
        ((sales.first['t'] as num?)?.toDouble() ?? 0) +
        ((clientPay.first['t'] as num?)?.toDouble() ?? 0) -
        ((ret.first['t'] as num?)?.toDouble() ?? 0) -
        ((rec.first['t'] as num?)?.toDouble() ?? 0);

    double payables = (sup.first['t'] as num?)?.toDouble() ?? 0.0;

    return {
      'inventory': inventory,
      'receivables': receivables,
      'payables': payables,
      'monthlySales': (mSales.first['t'] as num?)?.toDouble() ?? 0.0,
      'monthlyExpenses': (mExp.first['t'] as num?)?.toDouble() ?? 0.0,
      'monthlyReturns': (mRet.first['t'] as num?)?.toDouble() ?? 0.0,
      // القيم الجديدة
      'monthlyBills': (mPurBills.first['t'] as num?)?.toDouble() ?? 0.0,
      'monthlyPayments': (mSupPay.first['t'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getProductHistory(int productId) async {
    Database db = await database;
    var sales = await db.rawQuery(
      "SELECT 'بيع' as type, s.date, si.quantity, si.price, s.referenceNumber as ref FROM sale_items si JOIN sales s ON si.saleId = s.id WHERE si.productId = ?",
      [productId],
    );
    var purchases = await db.rawQuery(
      "SELECT 'شراء' as type, p.date, pi.quantity, pi.costPrice as price, p.referenceNumber as ref FROM purchase_items pi JOIN purchase_invoices p ON pi.invoiceId = p.id WHERE pi.productId = ?",
      [productId],
    );
    var returns = await db.rawQuery(
      "SELECT 'مرتجع' as type, r.date, ri.quantity, ri.price, '' as ref FROM return_items ri JOIN returns r ON ri.returnId = r.id WHERE ri.productId = ?",
      [productId],
    );
    List<Map<String, dynamic>> history = [...sales, ...purchases, ...returns];
    history.sort(
      (a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
    );
    return history;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null; // 🔥🔥 هذا السطر هو الحل السحري
      // كدة لما تيجي تطلب الداتا تاني، التطبيق هيعمل اتصال جديد أوتوماتيك
    }
  }

  // --- 🆕 دالة لمعرفة الكميات التي تم إرجاعها سابقاً لفاتورة معينة ---
  Future<Map<int, int>> getAlreadyReturnedItems(int saleId) async {
    Database db = await database;
    var result = await db.rawQuery(
      '''
      SELECT ri.productId, SUM(ri.quantity) as total
      FROM return_items ri
      JOIN returns r ON ri.returnId = r.id
      WHERE r.saleId = ?
      GROUP BY ri.productId
    ''',
      [saleId],
    );

    Map<int, int> returnedMap = {};
    for (var row in result) {
      returnedMap[row['productId'] as int] = (row['total'] as num).toInt();
    }
    return returnedMap;
  }

  Future<void> createPurchaseReturn(
    int invoiceId,
    int supplierId,
    double returnTotal,
    List<Map<String, dynamic>> itemsToReturn,
  ) async {
    Database db = await database;
    await db.transaction((txn) async {
      // أ. تسجيل المرتجع
      int returnId = await txn.insert('purchase_returns', {
        'invoiceId': invoiceId,
        'supplierId': supplierId,
        'date': DateTime.now().toString(),
        'totalAmount': returnTotal,
        'notes': 'مرتجع مشتريات',
      });

      // ب. تسجيل الأصناف وتحديث المخزون
      for (var item in itemsToReturn) {
        await txn.insert('purchase_return_items', {
          'returnId': returnId,
          'productId': item['productId'],
          'quantity': item['quantity'],
          'price': item['price'],
        });

        // 🔥 تحديث المخزون: هنا بنقلل المخزون (لأننا رجعنا البضاعة للمورد)
        var prod = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item['productId']],
        );
        if (prod.isNotEmpty) {
          int current = prod.first['stock'] as int;
          await txn.update(
            'products',
            {'stock': current - (item['quantity'] as int)}, // طرح الكمية
            where: 'id = ?',
            whereArgs: [item['productId']],
          );
        }
      }

      // ج. تحديث رصيد المورد (بنقلل الفلوس اللي ليه عندنا)
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance - ? WHERE id = ?',
        [returnTotal, supplierId],
      );
    });
  }

  // دالة جلب قائمة مرتجعات الموردين
  Future<List<Map<String, dynamic>>> getAllPurchaseReturns() async {
    Database db = await database;
    return await db.rawQuery(
      'SELECT pr.*, s.name as supplierName FROM purchase_returns pr LEFT JOIN suppliers s ON pr.supplierId = s.id ORDER BY pr.date DESC',
    );
  }

  // دالة جلب تفاصيل أصناف مرتجع المورد
  Future<List<Map<String, dynamic>>> getPurchaseReturnItems(
    int returnId,
  ) async {
    Database db = await database;
    return await db.rawQuery(
      'SELECT pri.*, p.name as productName FROM purchase_return_items pri LEFT JOIN products p ON pri.productId = p.id WHERE pri.returnId = ?',
      [returnId],
    );
  }

  // جلب قيمة الرصيد الافتتاحي الحالي
  Future<double> getSupplierOpeningBalance(int supplierId) async {
    Database db = await database;
    List<Map> result = await db.query(
      'supplier_opening_balances',
      columns: ['amount'],
      where: 'supplierId = ?',
      whereArgs: [supplierId],
    );
    if (result.isNotEmpty) {
      return (result.first['amount'] as num).toDouble();
    }
    return 0.0;
  }

  Future<void> updateSupplierOpeningBalance(
    int supplierId,
    double newAmount,
  ) async {
    Database db = await database;
    await db.transaction((txn) async {
      // 1. نجيب القيمة القديمة المسجلة
      double oldAmount = 0.0;
      List<Map> result = await txn.query(
        'supplier_opening_balances',
        columns: ['amount'],
        where: 'supplierId = ?',
        whereArgs: [supplierId],
      );

      if (result.isNotEmpty) {
        oldAmount = (result.first['amount'] as num).toDouble();
        // تحديث السجل الموجود
        await txn.update(
          'supplier_opening_balances',
          {'amount': newAmount},
          where: 'supplierId = ?',
          whereArgs: [supplierId],
        );
      } else {
        // إنشاء سجل جديد
        await txn.insert('supplier_opening_balances', {
          'supplierId': supplierId,
          'amount': newAmount,
          'date': DateTime.now().toString(),
          'notes': 'رصيد افتتاحي (معدل)',
        });
      }

      // 2. حساب الفرق (الجديد - القديم)
      double diff = newAmount - oldAmount;

      // 3. تسميع الفرق في رصيد المورد الحالي
      if (diff != 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
          [diff, supplierId],
        );
      }
    });
  }

  Future<String> getDbPath() async {
    Directory dir;
    // لو كمبيوتر (ويندوز/لينكس) نحفظ في المستندات عشان تكون ظاهرة وسهلة
    if (Platform.isWindows || Platform.isLinux) {
      dir = await getApplicationDocumentsDirectory();
      dir = Directory(join(dir.path, 'AlSakr_Data')); // مجلد خاص بالبرنامج
    } else {
      // لو موبايل (أندرويد)
      dir = await getApplicationDocumentsDirectory(); // أو getDatabasesPath()
    }

    // التأكد من وجود المجلد
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return join(dir.path, _dbName);
  }
}
