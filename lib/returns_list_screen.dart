import 'package:flutter/material.dart';
import 'db_helper.dart';

class ReturnsListScreen extends StatefulWidget {
  const ReturnsListScreen({super.key});

  @override
  State<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends State<ReturnsListScreen> {
  // بيانات العملاء (من كودك القديم)
  Map<String, List<Map<String, dynamic>>> _clientReturns = {};

  // بيانات الموردين (الجديد)
  Map<String, List<Map<String, dynamic>>> _supplierReturns = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final db = DatabaseHelper();

    // 1. جلب مرتجعات العملاء (كودك القديم)
    final cData = await db.getAllReturns();
    Map<String, List<Map<String, dynamic>>> cGrouped = {};
    for (var ret in cData) {
      String clientName = ret['clientName'] ?? 'عميل غير معروف';
      if (!cGrouped.containsKey(clientName)) {
        cGrouped[clientName] = [];
      }
      cGrouped[clientName]!.add(ret);
    }

    // 2. جلب مرتجعات الموردين (الجديد)
    // تأكد إنك ضفت دالة getAllPurchaseReturns في db_helper زي ما اتفقنا
    final sData = await db.getAllPurchaseReturns();
    Map<String, List<Map<String, dynamic>>> sGrouped = {};
    for (var ret in sData) {
      String supplierName = ret['supplierName'] ?? 'مورد غير معروف';
      if (!sGrouped.containsKey(supplierName)) {
        sGrouped[supplierName] = [];
      }
      sGrouped[supplierName]!.add(ret);
    }

    if (mounted) {
      setState(() {
        _clientReturns = cGrouped;
        _supplierReturns = sGrouped;
        _isLoading = false;
      });
    }
  }

  // --- دوال مساعدة ---
  String fmt(dynamic number) {
    if (number == null) return "0.00";
    if (number is String) {
      double? parsed = double.tryParse(number);
      return parsed != null ? parsed.toStringAsFixed(2) : number;
    }
    if (number is num) {
      return number.toDouble().toStringAsFixed(2);
    }
    return "0.00";
  }

  // حذف مرتجع عميل (من كودك القديم)
  void _deleteClientReturn(int id) async {
    await DatabaseHelper().deleteReturn(id);
    _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف المرتجع'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ==================== واجهة التطبيق ====================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // عدد التابات
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل المرتجعات'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: "مرتجعات العملاء"),
              Tab(icon: Icon(Icons.local_shipping), text: "مرتجعات الموردين"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // التاب الأول: العملاء (بنفس تصميمك القديم)
                  _buildClientsTab(),
                  // التاب الثاني: الموردين (تصميم جديد مشابه)
                  _buildSuppliersTab(),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 1️⃣ تاب مرتجعات العملاء (نفس اللوجيك بتاعك بالظبط)
  // ---------------------------------------------------------
  Widget _buildClientsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_clientReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_shopping_cart,
              size: 80,
              color: Colors.orange[200],
            ),
            const SizedBox(height: 10),
            const Text(
              'لا توجد مرتجعات عملاء',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _clientReturns.keys.length,
      itemBuilder: (context, index) {
        String clientName = _clientReturns.keys.elementAt(index);
        List<Map<String, dynamic>> clientReturns = _clientReturns[clientName]!;

        // حساباتك القديمة (ممتازة)
        double totalValue = clientReturns.fold(
          0.0,
          (sum, item) => sum + (item['totalAmount'] as num).toDouble(),
        );
        double totalPaid = clientReturns.fold(
          0.0,
          (sum, item) => sum + (item['paidAmount'] as num?)!.toDouble(),
        ); // تم التصحيح هنا لضمان عدم وجود null
        double totalDue = totalValue - totalPaid;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepOrange.withOpacity(0.1),
              child: Icon(Icons.person, color: Colors.deepOrange[800]),
            ),
            title: Text(
              clientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text("${clientReturns.length} عملية مرتجع"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${fmt(totalValue)} ج.م",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                if (totalDue > 0.1)
                  Text(
                    "مستحق: ${fmt(totalDue)}",
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                  ),
              ],
            ),
            children: clientReturns
                .map((ret) => _buildClientReturnCard(ret, isDark))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildClientReturnCard(Map<String, dynamic> ret, bool isDark) {
    double total = (ret['totalAmount'] as num).toDouble();
    double paid = (ret['paidAmount'] as num?)?.toDouble() ?? 0.0;
    bool isFullyPaid = paid >= total - 0.1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        onTap: () => _showClientReturnDetails(ret),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFullyPaid
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFullyPaid ? Icons.check : Icons.assignment_return,
            color: isFullyPaid ? Colors.green : Colors.orange,
            size: 20,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "مرتجع #${ret['id']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              ret['date'].toString().split(' ')[0],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "القيمة: ${fmt(total)} ج.م",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!isFullyPaid)
              Text(
                "باقي: ${fmt(total - paid)}",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                "تم الصرف",
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _deleteClientReturn(ret['id']), // إضافة زر الحذف هنا
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 2️⃣ تاب مرتجعات الموردين (الجديد)
  // ---------------------------------------------------------
  Widget _buildSuppliersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_supplierReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 80, color: Colors.blueGrey[200]),
            const SizedBox(height: 10),
            const Text(
              'لا توجد مرتجعات موردين',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _supplierReturns.keys.length,
      itemBuilder: (context, index) {
        String supplierName = _supplierReturns.keys.elementAt(index);
        List<Map<String, dynamic>> returns = _supplierReturns[supplierName]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey.withOpacity(0.1),
              child: const Icon(Icons.local_shipping, color: Colors.blueGrey),
            ),
            title: Text(
              supplierName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text("${returns.length} عملية مرتجع"),
            children: returns.map((ret) {
              return ListTile(
                leading: const Icon(Icons.outbox, color: Colors.brown),
                title: Text(
                  "مرتجع #${ret['id']} (فاتورة شراء #${ret['invoiceId']})",
                ),
                subtitle: Text(ret['date'].toString().split(' ')[0]),
                trailing: Text(
                  "${fmt(ret['totalAmount'])} ج.م",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
                onTap: () => _showSupplierReturnDetails(ret),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // تفاصيل مرتجع العميل (كودك القديم - لم يتم المساس به)
  // ---------------------------------------------------------
  // --- تفاصيل مرتجع العميل (معدلة لإظهار الضريبة) ---
  void _showClientReturnDetails(Map<String, dynamic> returnData) async {
    final db = await DatabaseHelper().database;
    final items = await db.query(
      'return_items',
      where: 'returnId = ?',
      whereArgs: [returnData['id']],
    );

    // 1. جلب الفاتورة الأصلية للتحقق من (الكاش/الآجل) و (هل يوجد ضريبة؟)
    bool isOriginalSaleCash = true;
    bool hasTax = false; // هل الفاتورة الأصلية كان بها ضريبة؟

    if (returnData['saleId'] != null) {
      final originSale = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [returnData['saleId']],
      );
      if (originSale.isNotEmpty) {
        // التحقق من نوع الدفع
        if (originSale.first['paymentType'] == 'credit') {
          isOriginalSaleCash = false;
        }
        // التحقق من وجود ضريبة
        double saleTax =
            (originSale.first['taxAmount'] as num?)?.toDouble() ?? 0.0;
        if (saleTax > 0) {
          hasTax = true;
        }
      }
    }

    // تجهيز الأصناف
    List<Map<String, dynamic>> enrichedItems = [];
    for (var item in items) {
      var prod = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [item['productId']],
      );
      String pName = prod.isNotEmpty
          ? prod.first['name'] as String
          : 'منتج محذوف';
      Map<String, dynamic> newItem = Map.from(item);
      newItem['productName'] = pName;
      enrichedItems.add(newItem);
    }

    final freshReturnList = await db.query(
      'returns',
      where: 'id = ?',
      whereArgs: [returnData['id']],
    );
    if (freshReturnList.isEmpty) return;
    Map<String, dynamic> freshReturn = freshReturnList.first;

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- 2. الحسابات المالية (فصل الضريبة) ---
    double totalReturnAmount = (freshReturn['totalAmount'] as num).toDouble();
    double returnTax = 0.0;
    double returnSubTotal = totalReturnAmount;

    // لو الفاتورة الأصلية كان فيها ضريبة، يبقى المرتجع ده شامل ضريبة 14%
    if (hasTax) {
      // المعادلة العكسية: المبلغ قبل الضريبة = المبلغ الكلي / 1.14
      returnSubTotal = totalReturnAmount / 1.14;
      returnTax = totalReturnAmount - returnSubTotal;
    }

    // حساب المدفوع والمتبقي
    double paid = (freshReturn['paidAmount'] as num?)?.toDouble() ?? 0.0;
    double remaining = totalReturnAmount - paid;
    if (remaining < 0) remaining = 0;
    bool isPaid = remaining <= 0.1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // الهيدر
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مرتجع عميل #${freshReturn['id']}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange[700],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isPaid ? "مدفوع بالكامل" : "غير مدفوع",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  freshReturn['date'].toString().split('.')[0],
                  style: const TextStyle(color: Colors.grey),
                ),

                // توضيح حالة الفاتورة الأصلية
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    isOriginalSaleCash
                        ? "(فاتورة أصلية: كاش)"
                        : "(فاتورة أصلية: آجل/دين)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOriginalSaleCash
                          ? Colors.green
                          : Colors.redAccent,
                    ),
                  ),
                ),

                const Divider(height: 20),

                // قائمة الأصناف
                Expanded(
                  child: ListView.separated(
                    itemCount: enrichedItems.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final item = enrichedItems[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: Text(
                            "${item['quantity']}",
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          item['productName'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("سعر الوحدة: ${fmt(item['price'])}"),
                        trailing: Text(
                          "${fmt((item['quantity'] as int) * (item['price'] as num))} ج.م",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),

                // 🔥 الفوتر المالي (تم تحديثه لعرض الضريبة) 🔥
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      // 1. إجمالي الأصناف (بدون ضريبة)
                      _buildSummaryRow("إجمالي الأصناف", returnSubTotal),

                      // 2. الضريبة (تظهر فقط لو كانت موجودة)
                      if (hasTax)
                        _buildSummaryRow(
                          "الضريبة (14%)",
                          returnTax,
                          color: Colors.orange,
                        ),

                      const Divider(),

                      // 3. الإجمالي النهائي
                      _buildSummaryRow(
                        "الإجمالي النهائي",
                        totalReturnAmount,
                        isBold: true,
                      ),

                      const SizedBox(height: 5),
                      // 4. المدفوع والمتبقي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("تم صرف:", style: TextStyle(fontSize: 12)),
                          Text(
                            fmt(paid),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      if (remaining > 0.1) ...[
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "المتبقي للصرف:",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              fmt(remaining),
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 15),

                      // زر الصرف
                      if (!isPaid)
                        if (isOriginalSaleCash)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.attach_money,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'صرف نقدية للعميل',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () async {
                                await _processCashRefund(
                                  freshReturn,
                                  remaining,
                                );
                                final updatedData = await db.query(
                                  'returns',
                                  where: 'id = ?',
                                  whereArgs: [freshReturn['id']],
                                );
                                if (updatedData.isNotEmpty) {
                                  setStateSheet(() {
                                    freshReturn = updatedData.first;
                                  });
                                  _loadData();
                                }
                              },
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              "لا يمكن صرف نقدية لأن الفاتورة الأصلية كانت (آجل).\nتم خصم المبلغ من مديونية العميل.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 5),
                            Text(
                              "تمت التسوية المالية بنجاح",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // تفاصيل مرتجع المورد (جديد)
  // ---------------------------------------------------------
  // --- تفاصيل مرتجع المورد (معدلة لإظهار الضريبة) ---
  void _showSupplierReturnDetails(Map<String, dynamic> ret) async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    // 1. جلب الأصناف
    final items = await dbHelper.getPurchaseReturnItems(ret['id']);

    // 2. جلب الفاتورة الأصلية لحساب نسبة الضريبة
    final invoiceRes = await db.query(
      'purchase_invoices',
      where: 'id = ?',
      whereArgs: [ret['invoiceId']],
    );

    double returnTotal = (ret['totalAmount'] as num).toDouble();
    double returnTax = 0.0;
    double returnSubTotal = returnTotal;
    bool hasTax = false;

    if (invoiceRes.isNotEmpty) {
      final inv = invoiceRes.first;
      double invTotal = (inv['totalAmount'] as num).toDouble();
      double invTax = (inv['taxAmount'] as num?)?.toDouble() ?? 0.0;

      if (invTax > 0) {
        hasTax = true;
        // حساب نسبة الضريبة من الفاتورة الأصلية
        // النسبة = قيمة الضريبة / (الإجمالي - الضريبة)
        double invSubTotal = invTotal - invTax;
        if (invSubTotal > 0) {
          double taxRate = invTax / invSubTotal;

          // استخراج الضريبة من المرتجع بناءً على هذه النسبة
          // صافي المرتجع = إجمالي المرتجع / (1 + النسبة)
          returnSubTotal = returnTotal / (1 + taxRate);
          returnTax = returnTotal - returnSubTotal;
        }
      }
    }

    if (!mounted) return;

    // تصميم الشيت
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 500, // ارتفاع مناسب
        child: Column(
          children: [
            Text(
              "تفاصيل مرتجع مورد #${ret['id']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 5),
            Text(
              "(من فاتورة شراء #${ret['invoiceId']})",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(),

            // قائمة الأصناف
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(items[i]['productName'] ?? 'صنف'),
                  subtitle: Text(
                    "${items[i]['quantity']} × ${items[i]['price']} (سعر الشراء)",
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    "${fmt((items[i]['quantity'] as int) * (items[i]['price'] as num))} ج.م",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const Divider(),

            // الفوتر المالي (بالضريبة)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // 1. قيمة الأصناف
                  _buildSummaryRow("قيمة الأصناف", returnSubTotal),

                  // 2. الضريبة المستردة
                  if (hasTax)
                    _buildSummaryRow(
                      "استرداد ضريبة",
                      returnTax,
                      color: Colors.orange[800],
                    ),

                  if (hasTax) const Divider(),

                  // 3. الإجمالي
                  _buildSummaryRow(
                    "إجمالي المرتجع",
                    returnTotal,
                    isBold: true,
                    color: Colors.brown,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دوال مساعدة أخرى (من كودك)
  Widget _buildSummaryRow(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            "${fmt(val)} ج.م",
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCashRefund(
    Map<String, dynamic> returnItem,
    double maxAmount,
  ) async {
    TextEditingController amountController = TextEditingController(
      text: maxAmount.toString(),
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صرف نقدية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("المبلغ المستحق: ${fmt(maxAmount)} ج.م"),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المراد صرفه',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              double payAmount = double.tryParse(amountController.text) ?? 0.0;
              if (payAmount <= 0 || payAmount > maxAmount) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('مبلغ غير صحيح')));
                return;
              }
              await DatabaseHelper().payReturnCash(
                returnItem['id'],
                returnItem['clientId'],
                payAmount,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم الصرف بنجاح ✅'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
