import 'package:flutter/material.dart';
import 'db_helper.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  // المتغيرات الأصلية الخاصة بك
  Map<String, List<Map<String, dynamic>>> _groupedPurchases = {};
  List<Map<String, dynamic>> _allPurchases = []; // قائمة كاملة للإحصائيات
  bool _isLoading = true;

  // متغيرات الإحصائيات الجديدة (مثل سجل المبيعات)
  Map<int, double> _returnsMap = {};
  double _monthlyPurchases = 0.0;
  double _monthlyReturns = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // تحديث دالة التحميل لجلب بيانات الإحصائيات
  void _loadData() async {
    final dbHelper = DatabaseHelper();
    final data = await dbHelper.getPurchasesWithNames();

    // 1. جلب المرتجعات وتجهيز الخريطة (للحساب الدقيق)
    final allReturns = await dbHelper.getAllPurchaseReturns();
    Map<int, double> returnsMap = {};
    for (var ret in allReturns) {
      int invId = ret['invoiceId'] ?? 0;
      double amount = (ret['totalAmount'] as num?)?.toDouble() ?? 0.0;
      returnsMap[invId] = (returnsMap[invId] ?? 0.0) + amount;
    }

    // 2. جلب بيانات التقرير العام للشهر الحالي
    final reportData = await dbHelper.getGeneralReportData();

    // 3. تجميع الفواتير حسب المورد (من الكود الأصلي الخاص بك)
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var invoice in data) {
      String supplierName = invoice['supplierName'] ?? 'مورد غير معروف';
      grouped.putIfAbsent(supplierName, () => []).add(invoice);
    }

    if (mounted) {
      setState(() {
        _allPurchases = data;
        _groupedPurchases = grouped;
        _returnsMap = returnsMap;
        _monthlyPurchases = reportData['monthlyBills'] ?? 0.0;
        _monthlyReturns = reportData['monthlyReturns'] ?? 0.0;
        _isLoading = false;
      });
    }
  }

  // دالة فورمات الأرقام
  String fmt(dynamic number) {
    if (number == null) return "0.00";
    if (number is num) return number.toDouble().toStringAsFixed(2);
    return double.tryParse(number.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  // حساب صافي المشتريات (الإجمالي - المرتجع)
  double _calculateTotalNetPurchases() {
    double sum = 0;
    for (var pur in _allPurchases) {
      double total = (pur['totalAmount'] as num).toDouble();
      double returned = _returnsMap[pur['id']] ?? 0.0;
      sum += (total - returned);
    }
    return sum;
  }

  // --- دوال العرض والديالوجات (الخاصة بك بالكامل دون تغيير) ---

  void _showDetails(Map<String, dynamic> invoice) async {
    final items = await DatabaseHelper().getPurchaseItems(invoice['id']);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double total = (invoice['totalAmount'] as num).toDouble();
    double tax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double subTotal = total - tax;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'فاتورة توريد #${invoice['id']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.brown[200] : Colors.brown,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPurchaseReturnDialog(invoice, items);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    icon: const Icon(
                      Icons.assignment_return,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "مرتجع",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (invoice['referenceNumber'] != null &&
                  invoice['referenceNumber'].toString().isNotEmpty)
                Text(
                  'مرجع المورد: ${invoice['referenceNumber']}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                  ),
                ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isDark
                          ? Colors.brown.withOpacity(0.2)
                          : Colors.brown[100],
                      child: Text(
                        '${items[i]['quantity']}',
                        style: TextStyle(
                          color: isDark ? Colors.brown[100] : Colors.brown[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      items[i]['productName'] ?? 'صنف',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('تكلفة: ${items[i]['costPrice']}'),
                    trailing: Text(
                      '${fmt(items[i]['quantity'] * items[i]['costPrice'])} ج.م',
                    ),
                  ),
                ),
              ),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.brown[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      "إجمالي الأصناف",
                      "${subTotal.toStringAsFixed(2)} ج.م",
                      isDark,
                    ),
                    if (tax > 0)
                      _buildDetailRow(
                        "الضريبة المضافة",
                        "+ ${tax.toStringAsFixed(2)} ج.م",
                        isDark,
                        valColor: Colors.orange,
                      ),
                    if (tax > 0) const Divider(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'إجمالي الفاتورة:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.brown[200] : Colors.brown,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    Color? valColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valColor ?? (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseReturnDialog(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) {
    double invoiceTotal = (invoice['totalAmount'] as num).toDouble();
    double invoiceTax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double invoiceSubTotal = invoiceTotal - invoiceTax;
    double taxRate = (invoiceSubTotal > 0) ? invoiceTax / invoiceSubTotal : 0.0;

    Map<int, int> returnQuantities = {};
    for (var item in items) {
      returnQuantities[item['productId']] = 0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double returnBaseTotal = 0;
          List<Map<String, dynamic>> itemsToReturn = [];
          for (var item in items) {
            int qty = returnQuantities[item['productId']] ?? 0;
            if (qty > 0) {
              returnBaseTotal += qty * (item['costPrice'] as num).toDouble();
              itemsToReturn.add({
                'productId': item['productId'],
                'quantity': qty,
                'price': item['costPrice'],
              });
            }
          }
          double returnTaxShare = returnBaseTotal * taxRate;
          double finalReturnTotal = returnBaseTotal + returnTaxShare;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: Text(
              "مرتجع من فاتورة #${invoice['id']}",
              style: const TextStyle(fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  const Text(
                    "حدد الكميات التي تريد إعادتها للمورد:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        int maxQty = item['quantity'];
                        int currentReturn =
                            returnQuantities[item['productId']] ?? 0;
                        return Card(
                          color: isDark ? Colors.grey[800] : Colors.grey[50],
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            title: Text(
                              item['productName'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "سعر: ${item['costPrice']}",
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: currentReturn > 0
                                      ? () => setStateDialog(
                                          () =>
                                              returnQuantities[item['productId']] =
                                                  currentReturn - 1,
                                        )
                                      : null,
                                ),
                                Text(
                                  "$currentReturn",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.green,
                                  ),
                                  onPressed: currentReturn < maxQty
                                      ? () => setStateDialog(
                                          () =>
                                              returnQuantities[item['productId']] =
                                                  currentReturn + 1,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  _buildDialogRow("قيمة الأصناف:", returnBaseTotal),
                  if (returnTaxShare > 0)
                    _buildDialogRow(
                      "استرداد ضريبة:",
                      returnTaxShare,
                      color: Colors.orange,
                    ),
                  _buildDialogRow(
                    "إجمالي المرتجع:",
                    finalReturnTotal,
                    isBold: true,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: finalReturnTotal > 0
                    ? () async {
                        await DatabaseHelper().createPurchaseReturn(
                          invoice['id'],
                          invoice['supplierId'],
                          finalReturnTotal,
                          itemsToReturn,
                        );
                        Navigator.pop(ctx);
                        _loadData();
                      }
                    : null,
                child: const Text(
                  "تأكيد الإرجاع",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogRow(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "${fmt(val)} ج.م",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isBold ? 16 : 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- الواجهة الرئيسية (التصميم الجديد المدمج) ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل المشتريات (تفصيلي)')),
      body: Column(
        children: [
          // 1. الشريط العلوي (الإحصائيات)
          Container(
            padding: const EdgeInsets.all(15),
            color: isDark
                ? const Color(0xFF1E1E1E)
                : Color.fromARGB(255, 9, 38, 62),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      "صافي المشتريات",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "${fmt(_calculateTotalNetPurchases())} ج.م",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.white24),
                Column(
                  children: [
                    const Text(
                      "عدد الفواتير",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "${_allPurchases.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. القائمة (نفس تصميم الـ ExpansionTile الخاص بك)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedPurchases.isEmpty
                ? const Center(child: Text('لا توجد فواتير مشتريات'))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _groupedPurchases.keys.length,
                    itemBuilder: (context, index) {
                      String supplierName = _groupedPurchases.keys.elementAt(
                        index,
                      );
                      List<Map<String, dynamic>> invoices =
                          _groupedPurchases[supplierName]!;

                      double totalSupplierPurchases = invoices.fold(
                        0,
                        (sum, item) =>
                            sum + (item['totalAmount'] as num).toDouble(),
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          shape: Border.all(color: Colors.transparent),
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.brown.withOpacity(0.2)
                                : Colors.brown[100],
                            child: Text(
                              supplierName.isNotEmpty ? supplierName[0] : '?',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.brown[100]
                                    : Colors.brown[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            supplierName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${invoices.length} فواتير'),
                          trailing: Text(
                            '${fmt(totalSupplierPurchases)} ج.م',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.brown[200] : Colors.brown,
                            ),
                          ),
                          children: invoices.map((invoice) {
                            double returned = _returnsMap[invoice['id']] ?? 0.0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              leading: Icon(
                                Icons.receipt_long,
                                color: returned > 0
                                    ? Colors.red
                                    : (isDark ? Colors.grey[400] : Colors.grey),
                              ),
                              title: Text(
                                '#${invoice['id']} - ${invoice['date'].toString().split(' ')[0]}',
                              ),
                              subtitle: returned > 0
                                  ? Text(
                                      "مرتجع: -${fmt(returned)}",
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                '${fmt(invoice['totalAmount'])} ج.م',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => _showDetails(invoice),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),

          // 3. الشريط السفلي (حركة الشهر)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "إجمالي مشتريات الشهر الحالي:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${fmt(_monthlyPurchases)} ج.م",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.brown[200] : Colors.brown[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
