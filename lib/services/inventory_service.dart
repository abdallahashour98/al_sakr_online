import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'pb_helper.dart';

class InventoryService {
  final pb = PBHelper().pb;

  // --- المنتجات ---
  Future<List<Map<String, dynamic>>> getProducts() async {
    final records = await pb
        .collection('products')
        .getFullList(sort: '-created', expand: 'supplier');
    return records.map((r) {
      var map = PBHelper.recordToMap(r);
      if (map['image'] != null && map['image'].toString().isNotEmpty) {
        map['imagePath'] = PBHelper().getImageUrl(
          r.collectionId,
          r.id,
          map['image'],
        );
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

  // --- الوحدات ---
  Future<List<String>> getUnits() async {
    try {
      final records = await pb.collection('units').getFullList();
      return records.map((e) => e.data['name'].toString()).toList();
    } catch (e) {
      return ['قطعة', 'علبة', 'كرتونة'];
    }
  }

  Future<void> insertUnit(String name) async {
    await pb.collection('units').create(body: {'name': name});
  }

  Future<void> deleteUnit(String name) async {
    final result = await pb
        .collection('units')
        .getList(filter: 'name = "$name"');
    if (result.items.isNotEmpty) {
      await pb.collection('units').delete(result.items.first.id);
    }
  }

  // --- سجل حركة الصنف ---
  Future<List<Map<String, dynamic>>> getProductHistory(String productId) async {
    List<Map<String, dynamic>> history = [];
    try {
      final sales = await pb
          .collection('sale_items')
          .getFullList(filter: 'product = "$productId"', expand: 'sale');
      for (var item in sales) {
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
    try {
      final purchases = await pb
          .collection('purchase_items')
          .getFullList(filter: 'product = "$productId"', expand: 'purchase');
      for (var item in purchases) {
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
    try {
      final returns = await pb
          .collection('return_items')
          .getFullList(filter: 'product = "$productId"', expand: 'return');
      for (var item in returns) {
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
}
