import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class PBHelper {
  // Singleton Pattern
  static final PBHelper _instance = PBHelper._internal();
  factory PBHelper() => _instance;

  // رابط السيرفر
  final baseUrl = 'http://company-system.ddns.net:8090';
  // ❌ (الكود القديم) كان final وتمت تهيئته فوراً، وهذا يمنع استخدام Store
  // final PocketBase pb = PocketBase('http://127.0.0.1:8090');

  // ✅ (التعديل) نجعله late ليتم تهيئته لاحقاً في دالة init
  late PocketBase pb;

  RecordModel? currentUser;

  // ✅ التأكد من التهيئة قبل استدعاء authStore
  bool get isLoggedIn {
    try {
      return pb.authStore.isValid;
    } catch (e) {
      return false; // لو لسه ماتعملش init
    }
  }

  PBHelper._internal();

  // ============================================================
  // 🚀 1. التهيئة والإعدادات (Auth Persistence & Theme)
  // ============================================================

  /// دالة التهيئة: يجب استدعاؤها في main.dart قبل تشغيل التطبيق
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // إعداد مخزن المصادقة لربطه بذاكرة الجهاز (Persistent Login)
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );

    // ✅ تهيئة PocketBase مع المخزن الجديد
    pb = PocketBase(baseUrl, authStore: store);

    print("PB Initialized. Logged in? ${pb.authStore.isValid}");
  }

  // ... باقي الكود كما هو ...

  /// حفظ وضع الـ Dark Mode
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // بنحفظه كنص (String) عشان نعرف نسترجعه صح
    await prefs.setString('theme_mode', mode.toString());
  }

  /// استرجاع وضع الـ Dark Mode (الافتراضي true)
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('theme_mode');

    if (saved == 'ThemeMode.dark') return ThemeMode.dark;
    if (saved == 'ThemeMode.light') return ThemeMode.light;

    return ThemeMode.system; // ✅ هذا هو الافتراضي (زي السيستم)
  }

  // ============================================================
  // 🔐 2. المصادقة والمستخدمين (Auth & Users)
  // ============================================================

  // تسجيل الدخول
  Future<bool> login(String email, String password) async {
    try {
      await pb.collection('users').authWithPassword(email, password);
      return pb.authStore.isValid;
    } catch (e) {
      print("Login Error: $e");
      return false;
    }
  }

  // تسجيل الخروج
  void logout() {
    // 1. ⚠️ هام جداً: إلغاء جميع الاشتراكات اللحظية لمنع تضارب التوكن
    // هذا السطر يغلق أي خط مفتوح (سواء داشبورد أو غيره)
    pb.realtime.unsubscribe();

    // 2. مسح بيانات المصادقة
    pb.authStore.clear();
  }

  // معرفة هل أنا أدمن
  bool get isAdmin {
    if (!pb.authStore.isValid) return false;
    // model deprecated, use record instead
    final record = pb.authStore.record;
    if (record == null) return false;
    return record.data['role'] == 'admin';
  }

  // داخل كلاس PBHelper
  Future<List<Map<String, dynamic>>> getUsers() async {
    // بنجيب كل اليوزرات مترتبين بالأحدث
    final records = await pb.collection('users').getFullList(sort: '-created');

    // هنا التعديل المهم: بناخد (كل) الداتا اللي في السجل ونزود عليها الـ id
    return records.map((record) {
      // 1. ناخد نسخة من الداتا كلها (بما فيها الصلاحيات الجديدة)
      final data = Map<String, dynamic>.from(record.data);

      // 2. نضيف الـ id والـ email (لأنهم أحياناً بيكونوا بره الـ data)
      data['id'] = record.id;
      // لو الإيميل مش موجود جوه الداتا، هاته من السجل نفسه
      if (!data.containsKey('email') || data['email'] == "") {
        data['email'] = record.getStringValue('email');
      }

      return data;
    }).toList();
  }

  // إنشاء مستخدم جديد
  Future<void> createUser(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final body = <String, dynamic>{
      "username":
          name.replaceAll(' ', '').toLowerCase() +
          "${DateTime.now().millisecond}",
      "email": email,
      "emailVisibility": true,
      "password": password,
      "passwordConfirm": password,
      "name": name,
      "role": role,
    };
    await pb.collection('users').create(body: body);
  }

  // حذف مستخدم
  Future<void> deleteUser(String id) async {
    await pb.collection('users').delete(id);
  }

  // تغيير الباسورد
  Future<void> updateUserPassword(String userId, String newPassword) async {
    final body = <String, dynamic>{
      "password": newPassword,
      "passwordConfirm": newPassword,
    };
    await pb.collection('users').update(userId, body: body);
  }

  // ============================================================
  // ⚙️ 3. الإعدادات العامة والوحدات
  // ============================================================

  // جلب إعدادات الشركة
  Future<Map<String, dynamic>> getCompanySettings() async {
    try {
      final records = await pb
          .collection('settings')
          .getList(page: 1, perPage: 1);
      if (records.items.isNotEmpty) {
        return _recordToMap(records.items.first);
      }
    } catch (e) {
      // الجدول فارغ
    }
    return {};
  }

  // حفظ إعدادات الشركة
  Future<void> saveCompanySettings(Map<String, dynamic> data) async {
    try {
      final records = await pb
          .collection('settings')
          .getList(page: 1, perPage: 1);
      if (records.items.isNotEmpty) {
        await pb
            .collection('settings')
            .update(records.items.first.id, body: data);
      } else {
        await pb.collection('settings').create(body: data);
      }
    } catch (e) {
      print("Error saving settings: $e");
      rethrow;
    }
  }

  // جلب الوحدات
  Future<List<String>> getUnits() async {
    try {
      final records = await pb.collection('units').getFullList();
      return records.map((e) => e.data['name'].toString()).toList();
    } catch (e) {
      return ['قطعة', 'علبة', 'كرتونة'];
    }
  }

  // إضافة وحدة
  Future<void> insertUnit(String name) async {
    try {
      await pb.collection('units').create(body: {'name': name});
    } catch (e) {
      print(e);
    }
  }

  // حذف وحدة
  Future<void> deleteUnit(String name) async {
    try {
      final result = await pb
          .collection('units')
          .getList(filter: 'name = "$name"');
      if (result.items.isNotEmpty) {
        await pb.collection('units').delete(result.items.first.id);
      }
    } catch (e) {
      print("Error deleting unit: $e");
    }
  }

  // ============================================================
  // 👥 4. العملاء (Clients)
  // ============================================================

  Future<List<Map<String, dynamic>>> getClients() async {
    final records = await pb.collection('clients').getFullList(sort: 'name');
    return records.map(_recordToMap).toList();
  }

  Future<RecordModel> insertClient(Map<String, dynamic> body) async {
    body.remove('id');
    return await pb.collection('clients').create(body: body);
  }

  Future<RecordModel> updateClient(String id, Map<String, dynamic> body) async {
    return await pb.collection('clients').update(id, body: body);
  }

  Future<void> deleteClient(String id) async {
    await pb.collection('clients').delete(id);
  }

  Future<double> getClientCurrentBalance(String clientId) async {
    try {
      final client = await pb.collection('clients').getOne(clientId);
      return (client.data['balance'] ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  // الأرصدة الافتتاحية للعملاء
  Future<double> getClientOpeningBalance(String clientId) async {
    try {
      final records = await pb
          .collection('opening_balances')
          .getList(filter: 'client = "$clientId"', perPage: 1);
      if (records.items.isNotEmpty) {
        return (records.items.first.data['amount'] ?? 0).toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> updateClientOpeningBalance(
    String clientId,
    double newAmount,
  ) async {
    try {
      final records = await pb
          .collection('opening_balances')
          .getList(filter: 'client = "$clientId"', perPage: 1);
      double oldAmount = 0.0;

      if (records.items.isNotEmpty) {
        final record = records.items.first;
        oldAmount = (record.data['amount'] ?? 0).toDouble();
        await pb
            .collection('opening_balances')
            .update(record.id, body: {'amount': newAmount});
      } else {
        await pb
            .collection('opening_balances')
            .create(
              body: {
                'client': clientId,
                'amount': newAmount,
                'date': DateTime.now().toIso8601String(),
                'notes': 'رصيد افتتاحي',
              },
            );
      }

      double diff = newAmount - oldAmount;
      if (diff != 0) {
        final client = await pb.collection('clients').getOne(clientId);
        double currentBal = (client.data['balance'] ?? 0).toDouble();
        await pb
            .collection('clients')
            .update(clientId, body: {'balance': currentBal + diff});
      }
    } catch (e) {
      print("Error updating client opening balance: $e");
    }
  }

  // ============================================================
  // 🏭 5. الموردين (Suppliers)
  // ============================================================

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final records = await pb.collection('suppliers').getFullList(sort: 'name');
    return records.map(_recordToMap).toList();
  }

  Future<RecordModel> insertSupplier(Map<String, dynamic> body) async {
    body.remove('id');
    return await pb.collection('suppliers').create(body: body);
  }

  Future<RecordModel> updateSupplier(
    String id,
    Map<String, dynamic> body,
  ) async {
    return await pb.collection('suppliers').update(id, body: body);
  }

  Future<void> deleteSupplier(String id) async {
    await pb.collection('suppliers').delete(id);
  }

  // الأرصدة الافتتاحية للموردين
  Future<double> getSupplierOpeningBalance(String supplierId) async {
    try {
      final records = await pb
          .collection('supplier_opening_balances')
          .getList(filter: 'supplier = "$supplierId"', perPage: 1);
      if (records.items.isNotEmpty) {
        return (records.items.first.data['amount'] ?? 0).toDouble();
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> updateSupplierOpeningBalance(
    String supplierId,
    double newAmount,
  ) async {
    try {
      final records = await pb
          .collection('supplier_opening_balances')
          .getList(filter: 'supplier = "$supplierId"', perPage: 1);
      double oldAmount = 0.0;

      if (records.items.isNotEmpty) {
        final record = records.items.first;
        oldAmount = (record.data['amount'] ?? 0).toDouble();
        await pb
            .collection('supplier_opening_balances')
            .update(record.id, body: {'amount': newAmount});
      } else {
        await pb
            .collection('supplier_opening_balances')
            .create(
              body: {
                'supplier': supplierId,
                'amount': newAmount,
                'date': DateTime.now().toIso8601String(),
                'notes': 'رصيد افتتاحي (معدل)',
              },
            );
      }

      double diff = newAmount - oldAmount;
      if (diff != 0) {
        final supplier = await pb.collection('suppliers').getOne(supplierId);
        double currentBal = (supplier.data['balance'] ?? 0).toDouble();
        await pb
            .collection('suppliers')
            .update(supplierId, body: {'balance': currentBal + diff});
      }
    } catch (e) {
      print("Error updating supplier opening balance: $e");
    }
  }

  // مدفوعات الموردين (محدثة مع الصورة)
  Future<void> addSupplierPayment({
    required String supplierId,
    required double amount,
    required String notes,
    required String date,
    String paymentMethod = 'cash', // طريقة الدفع
    String? imagePath, // مسار الصورة
  }) async {
    // تجهيز الملف
    List<http.MultipartFile> files = [];
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        // تأكد أن الاسم في الداتا بيز هو receiptImage
        files.add(await http.MultipartFile.fromPath('receiptImage', imagePath));
      }
    }

    await pb
        .collection('supplier_payments')
        .create(
          body: {
            'supplier': supplierId,
            'amount': amount,
            'notes': notes,
            'date': date,
            'method': paymentMethod,
          },
          files: files,
        );

    try {
      final supplier = await pb.collection('suppliers').getOne(supplierId);
      double currentBalance = (supplier.data['balance'] ?? 0).toDouble();
      // الدفع للمورد يقلل الرصيد (اللي هو علينا)
      await pb
          .collection('suppliers')
          .update(supplierId, body: {'balance': currentBalance - amount});
    } catch (e) {
      print("Error updating supplier balance: $e");
    }
  }

  Future<void> deleteSupplierPayment(
    String paymentId,
    String supplierId,
    double amount,
  ) async {
    await pb.collection('supplier_payments').delete(paymentId);
    try {
      final supplier = await pb.collection('suppliers').getOne(supplierId);
      double currentBalance = (supplier.data['balance'] ?? 0).toDouble();
      await pb
          .collection('suppliers')
          .update(supplierId, body: {'balance': currentBalance + amount});
    } catch (e) {
      print("Error restoring supplier balance: $e");
    }
  }

  Future<void> updateSupplierPayment({
    required String id,
    required String supplierId,
    required double oldAmount,
    required double newAmount,
    required String newNotes,
    required String newDate,
  }) async {
    await pb
        .collection('supplier_payments')
        .update(
          id,
          body: {'amount': newAmount, 'notes': newNotes, 'date': newDate},
        );
    double diff = newAmount - oldAmount;
    if (diff != 0) {
      final supplier = await pb.collection('suppliers').getOne(supplierId);
      double currentBalance = (supplier.data['balance'] ?? 0).toDouble();
      await pb
          .collection('suppliers')
          .update(supplierId, body: {'balance': currentBalance - diff});
    }
  }

  // ============================================================
  // 📦 6. المنتجات (Products)
  // ============================================================

  Future<List<Map<String, dynamic>>> getProducts() async {
    final records = await pb
        .collection('products')
        .getFullList(sort: '-created', expand: 'supplier');
    return records.map((r) {
      var map = _recordToMap(r);
      if (map['image'] != null && map['image'].toString().isNotEmpty) {
        map['imagePath'] = getImageUrl(r.collectionId, r.id, map['image']);
      }
      return map;
    }).toList();
  }

  Future<RecordModel> insertProduct(
    Map<String, dynamic> body,
    String? imagePath,
  ) async {
    body.remove('id');
    List<http.MultipartFile> files = [];
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
    }
    return await pb.collection('products').create(body: body, files: files);
  }

  Future<RecordModel> updateProduct(
    String id,
    Map<String, dynamic> body,
    String? imagePath,
  ) async {
    List<http.MultipartFile> files = [];
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      final file = File(imagePath);
      if (await file.exists()) {
        files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
    }
    return await pb.collection('products').update(id, body: body, files: files);
  }

  Future<void> deleteProduct(String id) async {
    await pb.collection('products').delete(id);
  }

  Future<List<Map<String, dynamic>>> getProductHistory(String productId) async {
    List<Map<String, dynamic>> history = [];
    // مبيعات
    try {
      final sales = await pb
          .collection('sale_items')
          .getFullList(filter: 'product = "$productId"', expand: 'sale');
      for (var item in sales) {
        // ignore: deprecated_member_use
        final sale = item.expand['sale']?.first;
        if (sale != null) {
          history.add({
            'type': 'بيع',
            'date': sale.data['date'],
            'quantity': item.data['quantity'],
            'price': item.data['price'],
            'ref': 'فاتورة #${sale.id.substring(0, 5)}',
          });
        }
      }
    } catch (e) {}
    // مشتريات
    try {
      final purchases = await pb
          .collection('purchase_items')
          .getFullList(filter: 'product = "$productId"', expand: 'purchase');
      for (var item in purchases) {
        // ignore: deprecated_member_use
        final purchase = item.expand['purchase']?.first;
        if (purchase != null) {
          history.add({
            'type': 'شراء',
            'date': purchase.data['date'],
            'quantity': item.data['quantity'],
            'price': item.data['costPrice'],
            'ref':
                purchase.data['referenceNumber'] ??
                'فاتورة #${purchase.id.substring(0, 5)}',
          });
        }
      }
    } catch (e) {}
    // مرتجعات
    try {
      final returns = await pb
          .collection('return_items')
          .getFullList(filter: 'product = "$productId"', expand: 'return');
      for (var item in returns) {
        // ignore: deprecated_member_use
        final ret = item.expand['return']?.first;
        if (ret != null) {
          history.add({
            'type': 'مرتجع',
            'date': ret.data['date'],
            'quantity': item.data['quantity'],
            'price': item.data['price'],
            'ref': 'مرتجع #${ret.id.substring(0, 5)}',
          });
        }
      }
    } catch (e) {}

    history.sort(
      (a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
    );
    return history;
  }

  // ============================================================
  // 🧾 7. المبيعات والمرتجعات (Sales & Returns)
  // ============================================================

  Future<void> createSale(
    String clientId,
    String clientName,
    double totalAmount,
    double taxAmount,
    List<Map<String, dynamic>> items, {
    String refNumber = '',
    double discount = 0.0,
    bool isCash = true,
    double whtAmount = 0.0,
  }) async {
    double netAmount = (totalAmount - discount) + taxAmount - whtAmount;

    final sale = await pb
        .collection('sales')
        .create(
          body: {
            'client': clientId,
            'totalAmount': totalAmount,
            'discount': discount,
            'taxAmount': taxAmount, // ✅ حفظ الضريبة
            'whtAmount': whtAmount, // ✅ حفظ خصم المنبع
            'netAmount': netAmount, // ✅ حفظ الصافي النهائي
            'paymentType': isCash ? 'cash' : 'credit',
            'date': DateTime.now().toIso8601String(),
            'referenceNumber': refNumber,
          },
        );

    for (var item in items) {
      await pb
          .collection('sale_items')
          .create(
            body: {
              'sale': sale.id,
              'product': item['productId'],
              'quantity': item['quantity'],
              'price': item['price'],
            },
          );
      try {
        final product = await pb
            .collection('products')
            .getOne(item['productId']);
        int currentStock = (product.data['stock'] ?? 0).toInt();
        await pb
            .collection('products')
            .update(
              item['productId'],
              body: {'stock': currentStock - (item['quantity'] as int)},
            );
      } catch (e) {
        print("Error updating stock: $e");
      }
    }

    // تحديث رصيد العميل (في حالة الآجل)
    try {
      final client = await pb.collection('clients').getOne(clientId);
      double currentBalance = (client.data['balance'] ?? 0).toDouble();

      if (!isCash) {
        // الآجل يزود المديونية على العميل
        await pb
            .collection('clients')
            .update(clientId, body: {'balance': currentBalance + netAmount});
      }
    } catch (e) {
      print("Error updating client balance: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final records = await pb
        .collection('sales')
        .getFullList(sort: '-date', expand: 'client');
    return records.map(_recordToMap).toList();
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    try {
      final records = await pb
          .collection('sale_items')
          .getFullList(filter: 'sale = "$saleId"', expand: 'product');
      return records.map((r) {
        var map = _recordToMap(r);
        // ignore: deprecated_member_use
        if (r.expand.containsKey('product'))
          map['productName'] = r.expand['product']?.first.data['name'];
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSaleById(String saleId) async {
    try {
      final record = await pb.collection('sales').getOne(saleId);
      return _recordToMap(record);
    } catch (e) {
      return null;
    }
  }

  // --- المرتجعات ---

  // ✅ الدالة التي كانت مفقودة وتسبب خطأ في BackupService (لأنها كانت تسمى getAllReturns في مكان وتستدعى بـ getReturns في مكان آخر)
  Future<List<Map<String, dynamic>>> getReturns() async {
    return await getAllReturns();
  }

  Future<void> createReturn(
    String saleId,
    String clientId,
    double returnTotal,
    List<Map<String, dynamic>> itemsToReturn, {
    double discount = 0.0,
  }) async {
    final returnRecord = await pb
        .collection('returns')
        .create(
          body: {
            'sale': saleId,
            'client': clientId,
            'totalAmount': returnTotal,
            'discount': discount,
            'date': DateTime.now().toIso8601String(),
            'notes': 'مرتجع مبيعات',
          },
        );

    for (var item in itemsToReturn) {
      await pb
          .collection('return_items')
          .create(
            body: {
              'return': returnRecord.id,
              'product': item['productId'],
              'quantity': item['quantity'],
              'price': item['price'],
            },
          );
      try {
        final product = await pb
            .collection('products')
            .getOne(item['productId']);
        int currentStock = (product.data['stock'] ?? 0).toInt();
        await pb
            .collection('products')
            .update(
              item['productId'],
              body: {'stock': currentStock + (item['quantity'] as int)},
            );
      } catch (e) {
        print("Error returning stock: $e");
      }
    }

    try {
      final client = await pb.collection('clients').getOne(clientId);
      double currentBalance = (client.data['balance'] ?? 0).toDouble();
      await pb
          .collection('clients')
          .update(clientId, body: {'balance': currentBalance - returnTotal});
    } catch (e) {
      print("Error updating client balance after return: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getReturnItems(String returnId) async {
    try {
      final records = await pb
          .collection('return_items')
          .getFullList(filter: 'return = "$returnId"', expand: 'product');
      return records.map((r) {
        var map = _recordToMap(r);
        // ignore: deprecated_member_use
        if (r.expand.containsKey('product'))
          map['productName'] = r.expand['product']?.first.data['name'];
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteReturn(String returnId) async {
    try {
      final items = await getReturnItems(returnId);
      for (var item in items) {
        final product = await pb.collection('products').getOne(item['product']);
        int currentStock = (product.data['stock'] ?? 0).toInt();
        int qty = (item['quantity'] as num).toInt();
        await pb
            .collection('products')
            .update(product.id, body: {'stock': currentStock - qty});
      }
      await pb.collection('returns').delete(returnId);
    } catch (e) {
      print("Error deleting return: $e");
    }
  }

  Future<void> payReturnCash(
    String returnId,
    String clientId,
    double amount,
  ) async {
    try {
      // 1. تسجيل حركة الدفع في جدول المدفوعات
      await pb
          .collection('client_payments')
          .create(
            body: {
              'client': clientId,
              'amount': amount,
              'date': DateTime.now().toIso8601String(),
              'notes': 'صرف نقدية عن مرتجع',
              'type': 'return_refund',
            },
          );

      // 2. تحديث المبلغ المدفوع في جدول المرتجعات
      final retRecord = await pb.collection('returns').getOne(returnId);
      // بنجيب القيمة القديمة ونزود عليها الجديد
      double oldPaid = (retRecord.data['paidAmount'] ?? 0).toDouble();

      await pb
          .collection('returns')
          .update(returnId, body: {'paidAmount': oldPaid + amount});
    } catch (e) {
      print("Error paying return cash: $e");
      throw e; // لازم السطر ده عشان الشاشة تعرف إن في مشكلة وتطلعلك الرسالة
    }
  }

  // ✅ الدالة المفقودة للتحقق من الكميات المرجعة سابقاً (تستخدم في ReportsScreen)
  Future<Map<String, int>> getAlreadyReturnedItems(String saleId) async {
    Map<String, int> result = {};
    try {
      final returns = await pb
          .collection('returns')
          .getFullList(filter: 'sale = "$saleId"');
      for (var ret in returns) {
        final items = await pb
            .collection('return_items')
            .getFullList(filter: 'return = "${ret.id}"');
        for (var item in items) {
          String prodId = item.data['product'];
          int qty = (item.data['quantity'] as num).toInt();
          result[prodId] = (result[prodId] ?? 0) + qty;
        }
      }
    } catch (e) {}
    return result;
  }

  // ============================================================
  // 🚚 8. المشتريات (Purchases)
  // ============================================================
  // إنشار فاتورة مشتريات (محدثة لتقبل الخصم والضرائب)
  Future<void> createPurchase(
    String supplierId,
    double totalAmount,
    List<Map<String, dynamic>> items, {
    String? refNumber,
    String? customDate,
    String paymentType = 'cash',
    double taxAmount = 0.0, // ضريبة 14%
    double whtAmount = 0.0, // خصم 1%
    double discount = 0.0, // ✅ التعديل هنا: إضافة معامل الخصم
  }) async {
    try {
      // 1. إنشاء الفاتورة (الرأس)
      final body = {
        'supplier': supplierId,
        'totalAmount': totalAmount,
        'paymentType': paymentType,
        'date': customDate ?? DateTime.now().toIso8601String(),
        'referenceNumber': refNumber ?? '',
        'taxAmount': taxAmount,
        'whtAmount': whtAmount,
        'discount': discount, // ✅ إرسال الخصم للداتا بيز
      };

      final record = await pb.collection('purchases').create(body: body);

      // 2. إضافة الأصناف
      for (var item in items) {
        await pb
            .collection('purchase_items')
            .create(
              body: {
                'purchase': record.id,
                'product': item['productId'],
                'quantity': item['quantity'],
                'costPrice': item['price'],
              },
            );

        // 3. تحديث المخزن (زيادة الكمية وسعر الشراء)
        final productData = await pb
            .collection('products')
            .getOne(item['productId']);
        int currentStock = (productData.data['stock'] as num).toInt();
        await pb
            .collection('products')
            .update(
              item['productId'],
              body: {
                'stock': currentStock + (item['quantity'] as int),
                'buyPrice': item['price'], // تحديث آخر سعر شراء
              },
            );
      }

      // 4. تحديث رصيد المورد (إذا كانت آجل)
      if (paymentType == 'credit') {
        final supplierData = await pb
            .collection('suppliers')
            .getOne(supplierId);
        double currentBalance = (supplierData.data['balance'] as num)
            .toDouble();

        // المشتريات الآجل بتزود الفلوس اللي "للمورد" (علينا)
        await pb
            .collection('suppliers')
            .update(
              supplierId,
              body: {'balance': currentBalance + totalAmount},
            );
      }
    } catch (e) {
      throw Exception("فشل إنشاء الفاتورة: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getPurchases() async {
    try {
      final records = await pb
          .collection('purchases')
          .getFullList(sort: '-date', expand: 'supplier');
      return records.map(_recordToMap).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPurchasesWithNames() async {
    return await getPurchases(); // نفس الوظيفة
  }

  Future<Map<String, dynamic>?> getPurchaseById(String purchaseId) async {
    try {
      final record = await pb.collection('purchases').getOne(purchaseId);
      return _recordToMap(record);
    } catch (e) {
      return null;
    }
  }

  // --- مرتجعات المشتريات ---

  Future<void> createPurchaseReturn(
    String purchaseId,
    String supplierId,
    double returnTotal,
    List<Map<String, dynamic>> itemsToReturn,
  ) async {
    final returnRecord = await pb
        .collection('purchase_returns')
        .create(
          body: {
            'purchase': purchaseId,
            'supplier': supplierId,
            'totalAmount': returnTotal,
            'date': DateTime.now().toIso8601String(),
            'notes': 'مرتجع مشتريات',
          },
        );

    for (var item in itemsToReturn) {
      await pb
          .collection('purchase_return_items')
          .create(
            body: {
              'purchase_return': returnRecord.id,
              'product': item['productId'],
              'quantity': item['quantity'],
              'price': item['price'],
            },
          );
      try {
        final product = await pb
            .collection('products')
            .getOne(item['productId']);
        int currentStock = (product.data['stock'] ?? 0).toInt();
        await pb
            .collection('products')
            .update(
              item['productId'],
              body: {'stock': currentStock - (item['quantity'] as int)},
            );
      } catch (e) {
        print("Error reducing stock for return: $e");
      }
    }

    try {
      final supplier = await pb.collection('suppliers').getOne(supplierId);
      double currentBalance = (supplier.data['balance'] ?? 0).toDouble();
      await pb
          .collection('suppliers')
          .update(supplierId, body: {'balance': currentBalance - returnTotal});
    } catch (e) {
      print("Error updating supplier balance after return: $e");
    }
  }

  // ============================================================
  // 📝 9. أذونات التسليم (Delivery Orders)
  // ============================================================

  Future<List<Map<String, dynamic>>> getAllDeliveryOrders() async {
    try {
      final records = await pb
          .collection('delivery_orders')
          .getFullList(sort: '-date', expand: 'client');
      return records.map((r) {
        var map = _recordToMap(r);
        // ignore: deprecated_member_use
        if (r.expand.containsKey('client'))
          map['clientName'] = r.expand['client']?.first.data['name'];
        else
          map['clientName'] = 'عميل غير معروف';
        if (map['signedImage'] != null &&
            map['signedImage'].toString().isNotEmpty) {
          map['signedImagePath'] = getImageUrl(
            r.collectionId,
            r.id,
            map['signedImage'],
          );
        }
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDeliveryOrderItems(
    String orderId,
  ) async {
    try {
      final records = await pb
          .collection('delivery_order_items')
          .getFullList(
            filter: 'delivery_order = "$orderId"',
            expand: 'product',
          );
      return records.map((r) {
        var map = _recordToMap(r);
        // ignore: deprecated_member_use
        if (r.expand.containsKey('product'))
          map['productName'] = r.expand['product']?.first.data['name'];
        else
          map['productName'] = r.data['description'] ?? 'صنف';
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createDeliveryOrder(
    String clientId,
    String supplyOrderNumber,
    String manualNo,
    String address,
    String date,
    String notes,
    List<Map<String, dynamic>> items,
  ) async {
    final order = await pb
        .collection('delivery_orders')
        .create(
          body: {
            'client': clientId,
            'supplyOrderNumber': supplyOrderNumber,
            'manualNo': manualNo,
            'address': address,
            'date': date,
            'notes': notes,
            'isLocked': false,
          },
        );

    for (var item in items) {
      String? productId = item['productId'];
      if (productId == null) {
        try {
          final p = await pb
              .collection('products')
              .getList(filter: 'name = "${item['productName']}"', perPage: 1);
          if (p.items.isNotEmpty) productId = p.items.first.id;
        } catch (e) {}
      }
      await pb
          .collection('delivery_order_items')
          .create(
            body: {
              'delivery_order': order.id,
              'product': productId,
              'quantity': item['quantity'],
              'description': item['description'] ?? item['productName'],
              'relatedSupplyOrder': item['relatedSupplyOrder'],
            },
          );
    }
  }

  Future<void> updateDeliveryOrder(
    String id,
    String clientId,
    String supplyOrderNumber,
    String manualNo,
    String address,
    String date,
    String notes,
    List<Map<String, dynamic>> items,
  ) async {
    await pb
        .collection('delivery_orders')
        .update(
          id,
          body: {
            'client': clientId,
            'supplyOrderNumber': supplyOrderNumber,
            'manualNo': manualNo,
            'address': address,
            'date': date,
            'notes': notes,
          },
        );

    final oldItems = await pb
        .collection('delivery_order_items')
        .getFullList(filter: 'delivery_order = "$id"');
    for (var item in oldItems) {
      await pb.collection('delivery_order_items').delete(item.id);
    }

    for (var item in items) {
      String? productId = item['productId'];
      if (productId == null) {
        try {
          final p = await pb
              .collection('products')
              .getList(filter: 'name = "${item['productName']}"', perPage: 1);
          if (p.items.isNotEmpty) productId = p.items.first.id;
        } catch (e) {}
      }
      await pb
          .collection('delivery_order_items')
          .create(
            body: {
              'delivery_order': id,
              'product': productId,
              'quantity': item['quantity'],
              'description': item['description'],
              'relatedSupplyOrder': item['relatedSupplyOrder'],
            },
          );
    }
  }

  Future<void> deleteDeliveryOrder(String id) async {
    await pb.collection('delivery_orders').delete(id);
  }

  Future<void> toggleOrderLock(
    String id,
    bool isLocked, {
    String? imagePath,
  }) async {
    Map<String, dynamic> body = {'isLocked': isLocked};
    if (isLocked && imagePath != null) {
      await pb
          .collection('delivery_orders')
          .update(
            id,
            body: body,
            files: [
              await http.MultipartFile.fromPath('signedImage', imagePath),
            ],
          );
    } else {
      await pb.collection('delivery_orders').update(id, body: body);
    }
  }

  Future<void> updateOrderImage(String id, String? imagePath) async {
    if (imagePath != null) {
      await pb
          .collection('delivery_orders')
          .update(
            id,
            files: [
              await http.MultipartFile.fromPath('signedImage', imagePath),
            ],
          );
    } else {
      await pb
          .collection('delivery_orders')
          .update(id, body: {'signedImage': null});
    }
  }

  // ============================================================
  // 💰 10. المصاريف والمالية (Expenses & Financials)
  // ============================================================

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final records = await pb
        .collection('expenses')
        .getFullList(sort: '-created');
    return records.map(_recordToMap).toList();
  }

  Future<RecordModel> insertExpense(Map<String, dynamic> body) async {
    body.remove('id');
    return await pb.collection('expenses').create(body: body);
  }

  Future<void> deleteExpense(String id) async {
    await pb.collection('expenses').delete(id);
  }

  Future<void> addExpense(Map<String, dynamic> body) async {
    await pb.collection('expenses').create(body: body);
  }

  Future<void> updateExpense(String id, Map<String, dynamic> body) async {
    await pb.collection('expenses').update(id, body: body);
  }

  Future<RecordModel> addReceipt({
    required String clientId,
    required double amount,
    required String notes,
    required String date,
  }) async {
    return await pb
        .collection('receipts')
        .create(
          body: {
            'client': clientId,
            'amount': amount,
            'notes': notes,
            'date': date,
          },
        );
  }

  // كشف حساب العميل
  Future<List<Map<String, dynamic>>> getClientStatement(
    String clientId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String dateFilter = "";
    if (startDate != null && endDate != null) {
      String start = startDate.toIso8601String();
      String end = endDate.add(const Duration(days: 1)).toIso8601String();
      dateFilter = ' && date >= "$start" && date < "$end"';
    }

    final sales = await pb
        .collection('sales')
        .getFullList(filter: 'client = "$clientId" $dateFilter', sort: 'date');

    List<RecordModel> returns = [];
    try {
      returns = await pb
          .collection('returns')
          .getFullList(
            filter: 'client = "$clientId" $dateFilter',
            sort: 'date',
          );
    } catch (e) {}

    List<RecordModel> receipts = [];
    try {
      receipts = await pb
          .collection('receipts')
          .getFullList(
            filter: 'client = "$clientId" $dateFilter',
            sort: 'date',
          );
    } catch (e) {}

    List<Map<String, dynamic>> statement = [];
    for (var s in sales) {
      statement.add({
        'type': 'sale',
        'date': s.data['date'],
        'amount': (s.data['netAmount'] ?? s.data['totalAmount'] ?? 0)
            .toDouble(),
        'description': 'فاتورة مبيعات',
        'id': s.id,
      });
    }
    for (var r in returns) {
      statement.add({
        'type': 'return',
        'date': r.data['date'],
        'amount': (r.data['totalAmount'] ?? 0).toDouble(),
        'description': 'مرتجع مبيعات',
        'id': r.id,
      });
    }
    for (var pay in receipts) {
      statement.add({
        'type': 'payment',
        'date': pay.data['date'],
        'amount': (pay.data['amount'] ?? 0).toDouble(),
        'description': pay.data['notes'] ?? 'دفعة',
        'id': pay.id,
      });
    }

    statement.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );
    return statement;
  }

  // كشف حساب المورد
  Future<List<Map<String, dynamic>>> getSupplierStatement(
    String supplierId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String dateFilter = "";
    if (startDate != null && endDate != null) {
      String start = startDate.toIso8601String();
      String end = endDate.add(const Duration(days: 1)).toIso8601String();
      dateFilter = ' && date >= "$start" && date < "$end"';
    }
    List<Map<String, dynamic>> statement = [];

    final purchases = await pb
        .collection('purchases')
        .getFullList(
          filter: 'supplier = "$supplierId" $dateFilter',
          sort: 'date',
        );
    for (var p in purchases) {
      statement.add({
        'type': 'bill',
        'date': p.data['date'],
        'amount': (p.data['totalAmount'] as num).toDouble(),
        'description': 'فاتورة شراء #${p.id.substring(0, 5)}',
        'id': p.id,
      });
    }

    try {
      final returns = await pb
          .collection('purchase_returns')
          .getFullList(
            filter: 'supplier = "$supplierId" $dateFilter',
            sort: 'date',
          );
      for (var r in returns) {
        statement.add({
          'type': 'return',
          'date': r.data['date'],
          'amount': (r.data['totalAmount'] as num).toDouble(),
          'description': 'مرتجع مشتريات #${r.id.substring(0, 5)}',
          'id': r.id,
        });
      }
    } catch (e) {}

    try {
      final payments = await pb
          .collection('supplier_payments')
          .getFullList(
            filter: 'supplier = "$supplierId" $dateFilter',
            sort: 'date',
          );
      for (var p in payments) {
        statement.add({
          'type': 'payment',
          'date': p.data['date'],
          'amount': (p.data['amount'] as num).toDouble(),
          'description': p.data['notes'] ?? 'سند دفع',
          'id': p.id,
        });
      }
    } catch (e) {}

    statement.sort(
      (a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])),
    );
    return statement;
  }

  // ============================================================
  // 📊 11. التقارير والدوال المساعدة (Reports & Helpers)
  // ============================================================
  // ============================================================
  // 📊 تقارير الداشبورد (التقرير المالي الشامل)
  // ============================================================
  Future<Map<String, double>> getGeneralReportData() async {
    final now = DateTime.now();

    // 1. تحديد نطاق التاريخ (الشهر الحالي)
    String startOfMonth =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-01 00:00:00";
    String nextMonth = now.month == 12
        ? "${now.year + 1}-01-01 00:00:00"
        : "${now.year}-${(now.month + 1).toString().padLeft(2, '0')}-01 00:00:00";

    String dateFilter = "date >= '$startOfMonth' && date < '$nextMonth'";

    try {
      // --- أ: بيانات الشهر الحالي (حركة السيولة) ---
      // 2. أ: مرتجعات العملاء (شهري)
      final clientReturnsRec = await pb
          .collection('returns')
          .getFullList(filter: dateFilter);
      double monthlyClientReturns = clientReturnsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 2. ب: مرتجعات الموردين (شهري)
      final supplierReturnsRec = await pb
          .collection('purchase_returns')
          .getFullList(filter: dateFilter);
      double monthlySupplierReturns = supplierReturnsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 1. المبيعات (الشهرية)
      final salesRec = await pb
          .collection('sales')
          .getFullList(filter: dateFilter);
      double monthlySales = salesRec.fold(
        0.0,
        (sum, item) => sum + (item.data['netAmount'] ?? 0),
      );

      // 2. المرتجعات (عملاء فقط - الشهرية)
      final returnsRec = await pb
          .collection('returns')
          .getFullList(filter: dateFilter);
      double monthlyReturns = returnsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 3. المصاريف (الشهرية)
      final expensesRec = await pb
          .collection('expenses')
          .getFullList(filter: dateFilter);
      double monthlyExpenses = expensesRec.fold(
        0.0,
        (sum, item) => sum + (item.data['amount'] ?? 0),
      );

      // 4. فواتير الشراء (التزام مالي - شهري)
      final purchasesRec = await pb
          .collection('purchases')
          .getFullList(filter: dateFilter);
      double monthlyBills = purchasesRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 5. مدفوعات نقدية للموردين (خروج كاش - شهري)
      final supplierPayRec = await pb
          .collection('supplier_payments')
          .getFullList(filter: dateFilter);
      double monthlyPayments = supplierPayRec.fold(
        0.0,
        (sum, item) => sum + (item.data['amount'] ?? 0),
      );

      // --- ب: بيانات المركز المالي (تراكمي / الأرصدة الحالية) ---

      // 6. قيمة المخزون (سعر الشراء * الكمية)
      final productsRec = await pb.collection('products').getFullList();
      double inventoryVal = productsRec.fold(0.0, (sum, item) {
        double qty = (item.data['stock'] ?? 0).toDouble();
        double cost = (item.data['buyPrice'] ?? 0).toDouble();
        return sum + (qty * cost);
      });

      // 7. لنا عند العملاء (المديونيات)
      final clientsRec = await pb.collection('clients').getFullList();
      double receivables = clientsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['balance'] ?? 0),
      );

      // 8. علينا للموردين (الالتزامات)
      final suppliersRec = await pb.collection('suppliers').getFullList();
      double payables = suppliersRec.fold(
        0.0,
        (sum, item) => sum + (item.data['balance'] ?? 0),
      );

      return {
        'monthlySales': monthlySales,
        'clientReturns': monthlyClientReturns, // ✅ مفصول
        'supplierReturns': monthlySupplierReturns, // ✅ مفصول
        'monthlyReturns': monthlyReturns,
        'monthlyExpenses': monthlyExpenses,
        'monthlyBills': monthlyBills, // قيمة فواتير الشراء
        'monthlyPayments': monthlyPayments, // ما تم دفعه للموردين فعلياً
        'inventory': inventoryVal,
        'receivables': receivables,
        'payables': payables,
      };
    } catch (e) {
      print("Error fetching report data: $e");
      return {};
    }
  }
  // --- Helpers ---

  String getImageUrl(String collectionId, String recordId, String filename) {
    if (filename.isEmpty) return '';
    return '$baseUrl/api/files/$collectionId/$recordId/$filename';
  }

  Map<String, dynamic> _recordToMap(RecordModel record) {
    var data = Map<String, dynamic>.from(record.data);
    data['id'] = record.id;
    data['collectionId'] = record.collectionId;
    data['created'] = record.created;
    data['updated'] = record.updated;

    try {
      // فك بيانات العلاقات (Expand)
      if (record.expand.isNotEmpty) {
        // 1. فك بيانات المورد (للشراء)
        if (record.expand.containsKey('supplier')) {
          final suppliers = record.expand['supplier'];
          if (suppliers != null && suppliers.isNotEmpty) {
            data['supplierName'] = suppliers[0].data['name'];
          }
        }

        // 2. فك بيانات العميل (للبيع والمرتجع)
        if (record.expand.containsKey('client')) {
          final clients = record.expand['client'];
          if (clients != null && clients.isNotEmpty) {
            data['clientName'] = clients[0].data['name'];
          }
        }

        // 3. فك بيانات المنتج (للتفاصيل)
        if (record.expand.containsKey('product')) {
          final products = record.expand['product'];
          if (products != null && products.isNotEmpty) {
            data['productName'] = products[0].data['name'];
          }
        }
      }
    } catch (e) {
      print("Error expanding record: $e");
    }
    return data;
  } // ============================================================
  //  دوال إضافية مطلوبة لشاشة العملاء المتقدمة (نسخ ولصق داخل الكلاس)
  // ============================================================

  // 1. جلب كل المبيعات (لحساب إجمالي مبيعات الفترة)
  Future<List<Map<String, dynamic>>> getAllSales() async {
    try {
      final records = await pb
          .collection('sales')
          .getFullList(sort: '-date', expand: 'client');
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('client'))
          map['expand'] = {'client': e.expand['client']![0].toJson()};
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 2. جلب كل المقبوضات (لحساب المحصل)
  Future<List<Map<String, dynamic>>> getAllReceipts() async {
    try {
      final records = await pb
          .collection('receipts')
          .getFullList(sort: '-date', expand: 'client');
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('client'))
          map['expand'] = {'client': e.expand['client']![0].toJson()};
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 3. جلب كل المرتجعات
  Future<List<Map<String, dynamic>>> getAllReturns() async {
    try {
      final records = await pb
          .collection('returns')
          .getFullList(sort: '-date', expand: 'client');
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('client'))
          map['expand'] = {'client': e.expand['client']![0].toJson()};
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 4. جلب مبيعات عميل محدد (لصفحة التفاصيل)
  Future<List<Map<String, dynamic>>> getSalesByClient(String clientId) async {
    try {
      final records = await pb
          .collection('sales')
          .getFullList(filter: 'client = "$clientId"', sort: '-date');
      return records.map((e) => e.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  // 5. جلب مقبوضات عميل محدد
  Future<List<Map<String, dynamic>>> getReceiptsByClient(
    String clientId,
  ) async {
    try {
      final records = await pb
          .collection('receipts')
          .getFullList(filter: 'client = "$clientId"', sort: '-date');
      return records.map((e) => e.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  // 6. جلب مرتجعات عميل محدد
  Future<List<Map<String, dynamic>>> getReturnsByClient(String clientId) async {
    try {
      final records = await pb
          .collection('returns')
          .getFullList(filter: 'client = "$clientId"', sort: '-date');
      return records.map((e) => e.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  //  دوال المقبوضات (سندات القبض) - Receipts
  // ============================================================
  // إنشاء سند قبض (دفعة) جديد مع صورة (محدثة مع Debugging)
  Future<void> createReceipt(
    String clientId,
    double amount,
    String notes,
    String date, {
    String paymentMethod = 'cash',
    String? imagePath,
  }) async {
    // تجهيز الملف
    List<http.MultipartFile> files = [];

    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        print("✅ جاري رفع الصورة: $imagePath"); // للتأكد أن المسار وصل
        // تأكد أن الاسم هنا 'receiptImage' يطابق تماماً اسم الحقل في PocketBase
        files.add(await http.MultipartFile.fromPath('receiptImage', imagePath));
      } else {
        print("❌ خطأ: ملف الصورة غير موجود في المسار المحدد");
      }
    } else {
      print("ℹ️ تم الحفظ بدون صورة");
    }

    try {
      await pb
          .collection('receipts')
          .create(
            body: {
              'client': clientId,
              'amount': amount,
              'notes': notes,
              'date': date,
              'method': paymentMethod,
            },
            files: files, // إرسال الملفات
          );
      print("✅ تم إنشاء السند بنجاح");
    } catch (e) {
      print("❌ خطأ أثناء إنشاء السند: $e");
      throw e;
    }
  }
  // ============================================================
  //  دوال إضافية (الموردين - Dashboard)
  // ============================================================

  // 1. جلب كل المشتريات (لحساب إجمالي مشتريات الشركة)
  Future<List<Map<String, dynamic>>> getAllPurchases() async {
    try {
      final records = await pb
          .collection('purchases')
          .getFullList(sort: '-date', expand: 'supplier');
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('supplier'))
          map['expand'] = {'supplier': e.expand['supplier']![0].toJson()};
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 2. جلب كل مدفوعات الموردين
  Future<List<Map<String, dynamic>>> getAllSupplierPayments() async {
    try {
      final records = await pb
          .collection('supplier_payments')
          .getFullList(sort: '-date', expand: 'supplier');
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('supplier'))
          map['expand'] = {'supplier': e.expand['supplier']![0].toJson()};
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 3. جلب كل مرتجعات الشراء
  Future<List<Map<String, dynamic>>> getAllPurchaseReturns() async {
    try {
      final records = await pb
          .collection('purchase_returns')
          .getFullList(sort: '-date', expand: 'supplier');
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('supplier'))
          map['expand'] = {'supplier': e.expand['supplier']![0].toJson()};
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }
  // ============================================================
  //  دوال تفاصيل الفواتير والمرتجعات (للموردين)
  // ============================================================

  // 1. جلب أصناف فاتورة شراء معينة
  Future<List<Map<String, dynamic>>> getPurchaseItems(String purchaseId) async {
    try {
      final records = await pb
          .collection('purchase_items')
          .getFullList(filter: 'purchase = "$purchaseId"', expand: 'product');
      return records.map((e) {
        final map = e.toJson();
        // نفك بيانات المنتج عشان نجيب اسمه
        if (e.expand.containsKey('product')) {
          map['productName'] = e.expand['product']![0].data['name'];
        }
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // 2. جلب أصناف مرتجع شراء معين
  Future<List<Map<String, dynamic>>> getPurchaseReturnItems(
    String returnId,
  ) async {
    try {
      // تأكد من اسم الجدول في الداتا بيز عندك (purchase_return_items)
      final records = await pb
          .collection('purchase_return_items')
          .getFullList(
            filter: 'purchase_return = "$returnId"',
            expand: 'product',
          );
      return records.map((e) {
        final map = e.toJson();
        if (e.expand.containsKey('product')) {
          map['productName'] = e.expand['product']![0].data['name'];
        }
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }
  // ============================================================
  // 🌍 إعدادات اللغة (Language)
  // ============================================================

  /// حفظ كود اللغة (ar أو en)
  Future<void> saveLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', languageCode);
  }

  /// استرجاع اللغة المحفوظة (الافتراضي عربي)
  Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString('app_lang');

    // لو مفيش لغة محفوظة، نرجع عربي كافتراضي
    if (lang == 'en') return const Locale('en');
    return const Locale('ar');
  }
  // ============================================================
  // ⚡ Real-time Streams (البيانات الحية)
  // ============================================================

  /// دالة عامة لعمل Stream لأي Collection
  /// بتقوم بجلب البيانات أول مرة، ثم تحديثها عند حدوث أي تغيير في السيرفر
  // ============================================================
  // ⚡ Real-time Streams (البيانات الحية - النسخة الآمنة)
  // ============================================================
  // ============================================================
  // ⚡ Real-time Streams (النسخة الآمنة جداً - Anti-Crash)
  // ============================================================

  // ============================================================
  // ⚡ Real-time Streams (النسخة الآمنة جداً - Anti-Crash)
  // ============================================================
  // ============================================================
  // 🛡️ دالة الستريم الآمنة (ضد الكراش أثناء التطوير)
  // ============================================================
  Stream<List<Map<String, dynamic>>> getCollectionStream(
    String collectionName, {
    String sort = '-created',
    String? expand,
    String? filter,
  }) {
    // بنستخدم broadcast عشان الستريم يقبل أكتر من مستمع وميقفلش
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    // 1. دالة لجلب البيانات العادية (HTTP) - دي المضمونة
    Future<void> fetchData() async {
      try {
        final records = await pb
            .collection(collectionName)
            .getFullList(sort: sort, expand: expand, filter: filter);

        if (!controller.isClosed) {
          final data = records.map((r) => _recordToMap(r)).toList();
          controller.add(data);
        }
      } catch (e) {
        print("⚠️ Error fetching data: $e");
      }
    }

    // 2. هات البيانات فوراً أول ما نفتح (Initial Load)
    fetchData();

    // 3. محاولة الاشتراك في الـ Real-time (بشكل محمي تماماً)
    // نستخدم Future.delayed لضمان عدم تعطيل الواجهة أثناء محاولة الاتصال
    Future.delayed(Duration.zero, () async {
      try {
        // ✅ محاولة الاشتراك
        await pb.collection(collectionName).subscribe('*', (e) {
          // عند حدوث أي تغيير (إضافة/حذف/تعديل)، نعيد جلب البيانات
          if (!controller.isClosed) {
            fetchData();
          }
        });
      } catch (err) {
        // 🛑 هنا السر: لو الاشتراك فشل (404 أو غيره)، نتجاهله تماماً
        // التطبيق سيعمل كأنه Offline أو HTTP عادي ولن يغلق
        print("⚠️ Real-time connection ignored (Safe Mode): $err");
      }
    });

    // 4. تنظيف عند الإغلاق (Dispose)
    controller.onCancel = () {
      try {
        // محاولة إلغاء الاشتراك بهدوء
        pb.collection(collectionName).unsubscribe('*');
      } catch (_) {
        // لو فشل الإلغاء، لا يهم
      }
      controller.close();
    };

    return controller.stream;
  }

  // 1. حذف مرتجع عميل (عكس العملية: ننقص المخزن ونزود مديونية العميل)
  Future<void> deleteReturnSafe(String returnId) async {
    try {
      // أ. جلب بيانات المرتجع وتفاصيله
      final retRecord = await pb.collection('returns').getOne(returnId);
      final items = await getReturnItems(returnId);
      final clientId = retRecord.data['client'];
      final totalAmount = (retRecord.data['totalAmount'] as num).toDouble();

      // ب. عكس تأثير المخزن (خصم الكميات التي دخلت بالخطأ)
      for (var item in items) {
        String prodId = item['product'];
        int qty = (item['quantity'] as num).toInt();

        // هات المنتج الحالي
        final prod = await pb.collection('products').getOne(prodId);
        int currentStock = (prod.data['stock'] as num).toInt();

        // نقص المخزن
        await pb
            .collection('products')
            .update(prodId, body: {'stock': currentStock - qty});
      }

      // ج. عكس تأثير رصيد العميل (إعادة المديونية عليه)
      if (clientId != null && clientId.toString().isNotEmpty) {
        final client = await pb.collection('clients').getOne(clientId);
        double currentBal = (client.data['balance'] as num).toDouble();

        // المرتجع كان بيقلل المديونية، الحذف يرجع يزودها تاني
        await pb
            .collection('clients')
            .update(clientId, body: {'balance': currentBal + totalAmount});
      }

      // د. (اختياري) لو كان فيه صرف نقدية (PaidAmount) المفروض نعمل قيد عكسي أو نمنع الحذف
      // للتبسيط هنا: سنحذف المرتجع فقط، والنقدية تظل كما هي "مصروفة بالخطأ" أو يتم تسويتها يدوياً.

      // هـ. الحذف النهائي
      await pb.collection('returns').delete(returnId);
      print("✅ تم حذف مرتجع العميل وتسوية المخزن والرصيد.");
    } catch (e) {
      throw Exception("فشل حذف المرتجع: $e");
    }
  }

  // 2. حذف مرتجع مورد (عكس العملية: نزود المخزن وننقص فلوس المورد)
  Future<void> deletePurchaseReturnSafe(String returnId) async {
    try {
      // أ. جلب البيانات
      final retRecord = await pb
          .collection('purchase_returns')
          .getOne(returnId);
      final items = await getPurchaseReturnItems(returnId);
      final supplierId = retRecord.data['supplier'];
      final totalAmount = (retRecord.data['totalAmount'] as num).toDouble();

      // ب. عكس تأثير المخزن (إرجاع الكميات للمخزن لأننا لغينا خروجها للمورد)
      for (var item in items) {
        String prodId = item['product'];
        int qty = (item['quantity'] as num).toInt();

        final prod = await pb.collection('products').getOne(prodId);
        int currentStock = (prod.data['stock'] as num).toInt();

        // زود المخزن تاني
        await pb
            .collection('products')
            .update(prodId, body: {'stock': currentStock + qty});
      }

      // ج. عكس تأثير رصيد المورد (إعادة الفلوس اللي كانت لينا عنده)
      // مرتجع المورد بيخلي الرصيد (لنا)، لما نحذفه الرصيد يرجع (علينا) أو يقل من (لنا)
      if (supplierId != null && supplierId.toString().isNotEmpty) {
        final supp = await pb.collection('suppliers').getOne(supplierId);
        double currentBal = (supp.data['balance'] as num).toDouble();

        // المرتجع كان بيزود رصيدنا عند المورد (أو يقلل مديونيتنا)
        // الحذف لازم يعكس ده (ينقص المبلغ من الرصيد)
        await pb
            .collection('suppliers')
            .update(supplierId, body: {'balance': currentBal - totalAmount});
      }

      // د. الحذف النهائي
      await pb.collection('purchase_returns').delete(returnId);
      print("✅ تم حذف مرتجع المورد وتسوية المخزن والرصيد.");
    } catch (e) {
      throw Exception("فشل حذف مرتجع المورد: $e");
    }
  }

  // تحديث بيانات المستخدم (الاسم والصلاحية)
  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await pb.collection('users').update(id, body: data);
  }
}
