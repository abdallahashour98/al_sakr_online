import 'package:flutter/material.dart';
import 'pb_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _allSales = [];
  Map<String, List<Map<String, dynamic>>> _groupedSales = {};

  // خرائط المرتجعات
  Map<String, double> _returnsTotalMap = {};
  Map<String, double> _returnsPaidMap = {};

  bool _isLoading = true;
  double _monthlyNetProfit = 0.0;

  // ✅ 1. متغير صلاحية إضافة مرتجع
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
        setState(() {
          _canAddReturn = userRecord.data['allow_add_returns'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error permissions: $e");
    }
  }

  void _loadData() async {
    final salesData = await PBHelper().getSales();
    final allReturns = await PBHelper().getAllReturns();

    Map<String, double> returnsTotalMap = {};
    Map<String, double> returnsPaidMap = {};

    for (var ret in allReturns) {
      String saleId = '';
      if (ret['sale'] is Map) {
        saleId = ret['sale']['id'] ?? '';
      } else {
        saleId = ret['sale']?.toString() ?? '';
      }

      if (saleId.isNotEmpty) {
        double total = (ret['totalAmount'] as num?)?.toDouble() ?? 0.0;
        double paid = (ret['paidAmount'] as num?)?.toDouble() ?? 0.0;

        returnsTotalMap[saleId] = (returnsTotalMap[saleId] ?? 0.0) + total;
        returnsPaidMap[saleId] = (returnsPaidMap[saleId] ?? 0.0) + paid;
      }
    }

    final reportData = await PBHelper().getGeneralReportData();

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var sale in salesData) {
      String clientName = sale['clientName'] ?? 'عميل غير معروف';
      grouped.putIfAbsent(clientName, () => []).add(sale);
    }

    if (mounted) {
      setState(() {
        _allSales = salesData;
        _groupedSales = grouped;
        _returnsTotalMap = returnsTotalMap;
        _returnsPaidMap = returnsPaidMap;

        double mSales = reportData['monthlySales'] ?? 0.0;
        double mReturns = reportData['monthlyReturns'] ?? 0.0;
        double mExpenses = reportData['monthlyExpenses'] ?? 0.0;
        _monthlyNetProfit = (mSales - mReturns) - mExpenses;
        _isLoading = false;
      });
    }
  }

  String fmt(dynamic number) {
    if (number == null) return "0.00";
    if (number is num) return number.toDouble().toStringAsFixed(2);
    return double.tryParse(number.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  double _calculateTotalNetSales() {
    double sum = 0;
    for (var sale in _allSales) {
      double net = (sale['netAmount'] as num?)?.toDouble() ?? 0.0;
      double returned = _returnsTotalMap[sale['id']] ?? 0.0;
      sum += (net - returned);
    }
    return sum;
  }

  // --- كارت الفاتورة ---
  Widget _buildInvoiceCard(Map<String, dynamic> sale, bool isDark) {
    double itemsTotal = (sale['totalAmount'] as num).toDouble();
    double discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    double tax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double wht = (sale['whtAmount'] as num?)?.toDouble() ?? 0.0;

    double amountAfterDiscount = itemsTotal - discount;
    double finalNet = amountAfterDiscount + tax - wht;

    double returnedTotal = _returnsTotalMap[sale['id']] ?? 0.0;
    double returnedCash = _returnsPaidMap[sale['id']] ?? 0.0;

    bool isCashSale = (sale['paymentType'] == 'cash');
    double paidByClient = isCashSale ? finalNet : 0.0;

    double netValue = finalNet - returnedTotal;
    double netPayment = paidByClient - returnedCash;
    double remaining = netValue - netPayment;

    bool isFullyReturned = (returnedTotal >= finalNet - 0.1) && finalNet > 0;

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "فاتورة #${sale['id'].toString().substring(0, 5)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isFullyReturned ? Colors.red : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCashSale
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCashSale ? "كاش" : "آجل",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCashSale ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "الصافي: ${fmt(finalNet)} ج.م",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              sale['date'].toString().split(' ')[0],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),

        // ✅ 3. زر المرتجع (يخضع للصلاحية)
        trailing: isFullyReturned
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  "مرتجع بالكامل",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : (_canAddReturn
                  ? ElevatedButton.icon(
                      onPressed: () => _showReturnDialog(sale),
                      icon: const Icon(Icons.assignment_return, size: 14),
                      label: const Text("مرتجع"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.grey[700]
                            : Colors.white,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        side: const BorderSide(color: Colors.red, width: 0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(60, 30),
                      ),
                    )
                  : null // إخفاء الزر لو مفيش صلاحية
                    ),

        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                _buildInfoRow("إجمالي الأصناف", "${fmt(itemsTotal)} ج.م"),
                if (discount > 0) ...[
                  _buildInfoRow(
                    "الخصم",
                    "-${fmt(discount)} ج.م",
                    color: Colors.red,
                  ),
                  const Divider(height: 10, indent: 20, endIndent: 20),
                ],
                if (tax > 0)
                  _buildInfoRow(
                    "الضريبة (14%)",
                    "+${fmt(tax)} ج.م",
                    color: Colors.orange,
                  ),
                if (wht > 0)
                  _buildInfoRow(
                    "خصم منبع (1%)",
                    "-${fmt(wht)} ج.م",
                    color: Colors.teal,
                  ),

                const Divider(height: 15, thickness: 1.5),
                _buildInfoRow(
                  "الإجمالي النهائي",
                  "${fmt(finalNet)} ج.م",
                  isBold: true,
                  size: 15,
                  color: isDark ? Colors.tealAccent : Colors.teal,
                ),

                if (isCashSale)
                  _buildInfoRow(
                    "مدفوع (كاش)",
                    "${fmt(paidByClient)} ج.م",
                    color: Colors.green,
                  ),

                if (returnedTotal > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          "قيمة المرتجعات",
                          "-${fmt(returnedTotal)} ج.م",
                          color: Colors.red,
                          size: 12,
                        ),
                        if (returnedCash > 0)
                          _buildInfoRow(
                            "تم رد نقدية للعميل",
                            "${fmt(returnedCash)} ج.م",
                            color: Colors.orange[800],
                            size: 12,
                          ),
                      ],
                    ),
                  ),
                ],

                const Divider(),
                _buildInfoRow(
                  remaining > 0.1
                      ? "متبقي على العميل (لنا)"
                      : (remaining < -0.1 ? "مستحق للعميل (له)" : "خالص"),
                  "${fmt(remaining.abs())} ج.م",
                  isBold: true,
                  size: 16,
                  color: (remaining > -0.1 && remaining < 0.1)
                      ? Colors.green
                      : (remaining > 0 ? Colors.red : Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ديالوج المرتجع ---
  void _showReturnDialog(Map<String, dynamic> sale) async {
    // حماية إضافية
    if (!_canAddReturn) return;

    final items = await PBHelper().getSaleItems(sale['id']);
    final previouslyReturnedMap = await PBHelper().getAlreadyReturnedItems(
      sale['id'],
    );

    Map<String, int> returnQuantities = {};
    for (var item in items) {
      returnQuantities[item['id']] = 0;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          double grossReturnTotal = 0;
          List<Map<String, dynamic>> itemsToReturn = [];

          for (var item in items) {
            String itemId = item['id'];
            int qty = returnQuantities[itemId] ?? 0;
            if (qty > 0) {
              double price = (item['price'] as num).toDouble();
              grossReturnTotal += qty * price;
              itemsToReturn.add({
                'productId': item['product'],
                'quantity': qty,
                'price': price,
              });
            }
          }

          double saleItemsTotal = (sale['totalAmount'] as num).toDouble();
          double saleDiscount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
          double saleTax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;
          double saleWht = (sale['whtAmount'] as num?)?.toDouble() ?? 0.0;

          bool hasTax = saleTax > 0.1;
          bool hasWht = saleWht > 0.1;

          double discountRatio = (saleItemsTotal > 0)
              ? (saleDiscount / saleItemsTotal)
              : 0;
          double returnDiscountShare = grossReturnTotal * discountRatio;
          double netReturnBeforeTax = grossReturnTotal - returnDiscountShare;
          double returnTaxShare = hasTax ? netReturnBeforeTax * 0.14 : 0.0;
          double returnWhtShare = hasWht ? netReturnBeforeTax * 0.01 : 0.0;
          double finalReturnTotal =
              netReturnBeforeTax + returnTaxShare - returnWhtShare;

          return AlertDialog(
            title: Text(
              "مرتجع فاتورة #${sale['id'].toString().substring(0, 5)}",
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: Column(
                children: [
                  const Text(
                    "حدد الكميات للإرجاع:",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        String prodId = item['product'];
                        int originalQty = (item['quantity'] as num).toInt();
                        int alreadyReturned =
                            previouslyReturnedMap[prodId] ?? 0;
                        int availableToReturn = originalQty - alreadyReturned;
                        if (availableToReturn < 0) availableToReturn = 0;

                        String itemId = item['id'];
                        int currentReturnQty = returnQuantities[itemId] ?? 0;

                        return Card(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          child: Opacity(
                            opacity: availableToReturn > 0 ? 1.0 : 0.5,
                            child: ListTile(
                              title: Text(
                                item['productName'] ?? 'صنف',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text("${fmt(item['price'])} ج.م"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (availableToReturn > 0) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        if (currentReturnQty > 0)
                                          setStateSB(
                                            () => returnQuantities[itemId] =
                                                currentReturnQty - 1,
                                          );
                                      },
                                    ),
                                    Text(
                                      "$currentReturnQty",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.green,
                                      ),
                                      onPressed: () {
                                        if (currentReturnQty <
                                            availableToReturn)
                                          setStateSB(
                                            () => returnQuantities[itemId] =
                                                currentReturnQty + 1,
                                          );
                                      },
                                    ),
                                  ] else
                                    const Text(
                                      "مكتمل",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  _buildSummaryRow("قيمة الأصناف", grossReturnTotal),
                  if (returnDiscountShare > 0)
                    _buildSummaryRow(
                      "يخصم خصم سابق",
                      returnDiscountShare,
                      color: Colors.red,
                    ),
                  if (returnTaxShare > 0)
                    _buildSummaryRow(
                      "استرداد ضريبة (14%)",
                      returnTaxShare,
                      color: Colors.orange,
                    ),
                  if (returnWhtShare > 0)
                    _buildSummaryRow(
                      "عكس خصم منبع (1%)",
                      returnWhtShare,
                      color: Colors.teal,
                    ),
                  const Divider(),
                  _buildSummaryRow(
                    "إجمالي المرتجع",
                    finalReturnTotal,
                    isBold: true,
                    color: isDark ? Colors.greenAccent : Colors.green[800],
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
                onPressed: () async {
                  if (finalReturnTotal <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يجب اختيار صنف واحد على الأقل'),
                      ),
                    );
                    return;
                  }
                  await PBHelper().createReturn(
                    sale['id'],
                    sale['clientId'] ?? sale['client'],
                    finalReturnTotal,
                    itemsToReturn,
                    discount: returnDiscountShare,
                  );
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تسجيل المرتجع بنجاح ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  "تأكيد",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    double size = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: size),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: size,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double val, {
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "${fmt(val)} ج.م",
          style: TextStyle(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color profitColor = _monthlyNetProfit >= 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل المبيعات ')),
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
                      "إجمالي صافي المبيعات",
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "${fmt(_calculateTotalNetSales())} ج.م",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "${_allSales.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                : _groupedSales.isEmpty
                ? const Center(child: Text("لا توجد مبيعات مسجلة"))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _groupedSales.keys.length,
                    itemBuilder: (context, index) {
                      String clientName = _groupedSales.keys.elementAt(index);
                      List<Map<String, dynamic>> clientInvoices =
                          _groupedSales[clientName]!;
                      double clientTotal = clientInvoices.fold(0.0, (
                        sum,
                        item,
                      ) {
                        double net =
                            (item['netAmount'] as num? ?? item['totalAmount'])
                                .toDouble();
                        double returned = _returnsTotalMap[item['id']] ?? 0.0;
                        return sum + (net - returned);
                      });

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.teal.withOpacity(0.2)
                                : Colors.teal[50],
                            child: Icon(Icons.person, color: Colors.teal[700]),
                          ),
                          title: Text(
                            clientName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("${clientInvoices.length} فواتير"),
                          trailing: Text(
                            "${fmt(clientTotal)} ج.م",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.tealAccent
                                  : Colors.teal[800],
                              fontSize: 15,
                            ),
                          ),
                          children: clientInvoices
                              .map((sale) => _buildInvoiceCard(sale, isDark))
                              .toList(),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "صافي حركة الشهر (ربح/خسارة):",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "(المبيعات الصافية - المصاريف)",
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Text(
                  "${fmt(_monthlyNetProfit)} ج.م",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: profitColor,
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
