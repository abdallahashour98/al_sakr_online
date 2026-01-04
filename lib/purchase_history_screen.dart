import 'package:flutter/material.dart';
import 'pb_helper.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  Map<String, List<Map<String, dynamic>>> _groupedPurchases = {};
  List<Map<String, dynamic>> _allPurchases = [];
  bool _isLoading = true;

  Map<String, double> _returnsMap = {};
  double _monthlyPurchases = 0.0;

  // ✅ 1. متغير صلاحية (استخدام صلاحية الشراء لعمل المرتجع)
  bool _canAddReturn = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // تحميل الصلاحيات
    _loadData();
  }

  // ✅ 2. دالة تحميل الصلاحيات
  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) setState(() => _canAddReturn = true);
      return;
    }

    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        // نستخدم صلاحية "إضافة مشتريات" لتمكينه من عمل "مرتجع مشتريات"
        // (لأننا لم ننشئ صلاحية خاصة بمرتجع الشراء في الداتا بيز)
        setState(() {
          _canAddReturn = userRecord.data['allow_add_purchases'] ?? false;
        });
      }
    } catch (e) {
      //
    }
  }

  void _loadData() async {
    final data = await PBHelper().getPurchasesWithNames();

    // 1. جلب المرتجعات وحسابها
    final allReturns = await PBHelper().getAllPurchaseReturns();
    Map<String, double> returnsMap = {};
    for (var ret in allReturns) {
      String invId =
          ret['purchase']?.toString() ?? ret['invoiceId']?.toString() ?? '';
      if (invId.isNotEmpty) {
        double amount = (ret['totalAmount'] as num?)?.toDouble() ?? 0.0;
        returnsMap[invId] = (returnsMap[invId] ?? 0.0) + amount;
      }
    }

    final reportData = await PBHelper().getGeneralReportData();

    // 3. تجميع الفواتير حسب المورد
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
        _isLoading = false;
      });
    }
  }

  String fmt(dynamic number) {
    if (number == null) return "0.00";
    if (number is num) return number.toDouble().toStringAsFixed(2);
    return double.tryParse(number.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  double _calculateTotalNetPurchases() {
    double sum = 0;
    for (var pur in _allPurchases) {
      double total = (pur['totalAmount'] as num).toDouble();
      double returned = _returnsMap[pur['id']] ?? 0.0;
      sum += (total - returned);
    }
    return sum;
  }

  void _showDetails(Map<String, dynamic> invoice) async {
    final items = await PBHelper().getPurchaseItems(invoice['id']);
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    double total = (invoice['totalAmount'] as num).toDouble();
    double tax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double wht = (invoice['whtAmount'] as num?)?.toDouble() ?? 0.0;
    double discount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;

    double subTotal = items.fold(
      0.0,
      (sum, item) =>
          sum +
          ((item['quantity'] as num) * (item['costPrice'] as num)).toDouble(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
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
                    'فاتورة #${invoice['id'].toString().substring(0, 5)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.brown[200] : Colors.brown,
                    ),
                  ),

                  // ✅ 3. زر المرتجع (يخضع للصلاحية)
                  if (_canAddReturn)
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
                      '${fmt((items[i]['quantity'] as int) * (items[i]['costPrice'] as num))} ج.م',
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
                    _buildDetailRow("إجمالي الأصناف", subTotal, isDark),
                    if (discount > 0)
                      _buildDetailRow(
                        "خصم (-)",
                        discount,
                        isDark,
                        valColor: Colors.red,
                      ),
                    if (tax > 0)
                      _buildDetailRow(
                        "ضريبة 14% (+)",
                        tax,
                        isDark,
                        valColor: Colors.orange,
                      ),
                    if (wht > 0)
                      _buildDetailRow(
                        "خصم منبع 1% (-)",
                        wht,
                        isDark,
                        valColor: Colors.teal,
                      ),
                    const Divider(height: 15),
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
    double val,
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
            "${val.toStringAsFixed(2)} ج.م",
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

  // --- ديالوج المرتجع ---
  void _showPurchaseReturnDialog(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) {
    // حماية إضافية
    if (!_canAddReturn) return;

    double invTax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double invWht = (invoice['whtAmount'] as num?)?.toDouble() ?? 0.0;
    double invDiscount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;

    bool hasTax = invTax > 0.1;
    bool hasWht = invWht > 0.1;

    double originalItemsTotal = items.fold(
      0.0,
      (sum, item) =>
          sum + ((item['quantity'] as num) * (item['costPrice'] as num)),
    );

    Map<String, int> returnQuantities = {};
    for (var item in items) {
      returnQuantities[item['product']] = 0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double returnBaseTotal = 0;
          List<Map<String, dynamic>> itemsToReturn = [];

          for (var item in items) {
            String prodId = item['product'];
            int qty = returnQuantities[prodId] ?? 0;
            if (qty > 0) {
              double price = (item['costPrice'] as num).toDouble();
              returnBaseTotal += qty * price;
              itemsToReturn.add({
                'productId': prodId,
                'quantity': qty,
                'price': price,
              });
            }
          }

          double returnDiscount = 0.0;
          if (originalItemsTotal > 0 && invDiscount > 0) {
            double ratio = returnBaseTotal / originalItemsTotal;
            returnDiscount = invDiscount * ratio;
          }

          double netReturnBase = returnBaseTotal - returnDiscount;
          double returnTaxVal = hasTax ? netReturnBase * 0.14 : 0.0;
          double returnWhtVal = hasWht ? netReturnBase * 0.01 : 0.0;
          double finalReturnTotal = netReturnBase + returnTaxVal - returnWhtVal;

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: Text(
              "مرتجع من فاتورة #${invoice['id'].toString().substring(0, 5)}",
              style: const TextStyle(fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
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
                        int maxQty = (item['quantity'] as num).toInt();
                        String prodId = item['product'];
                        int currentReturn = returnQuantities[prodId] ?? 0;

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
                            subtitle: Text("سعر: ${item['costPrice']}"),
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
                                          () => returnQuantities[prodId] =
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
                                          () => returnQuantities[prodId] =
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
                  if (returnDiscount > 0)
                    _buildDialogRow(
                      "يخصم خصم سابق:",
                      returnDiscount,
                      color: Colors.red,
                    ),
                  if (returnTaxVal > 0)
                    _buildDialogRow(
                      "استرداد ضريبة (14%):",
                      returnTaxVal,
                      color: Colors.orange,
                    ),
                  if (returnWhtVal > 0)
                    _buildDialogRow(
                      "عكس خصم منبع (1%):",
                      returnWhtVal,
                      color: Colors.teal,
                    ),
                  const Divider(),
                  _buildDialogRow(
                    "إجمالي المرتجع:",
                    finalReturnTotal,
                    isBold: true,
                    color: Colors.blue,
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
                        await PBHelper().createPurchaseReturn(
                          invoice['id'],
                          invoice['supplier'] ?? invoice['supplierId'],
                          finalReturnTotal,
                          itemsToReturn,
                        );
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إنشاء المرتجع بنجاح ✅'),
                            backgroundColor: Colors.green,
                          ),
                        );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل المشتريات ')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: isDark
                ? const Color(0xFF1E1E1E)
                : const Color.fromARGB(255, 9, 38, 62),
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
                                '#${invoice['id'].toString().substring(0, 5)} - ${invoice['date'].toString().split(' ')[0]}',
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
