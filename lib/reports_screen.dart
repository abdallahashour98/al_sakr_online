import 'package:flutter/material.dart';
import 'db_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _allSales = [];
  Map<String, List<Map<String, dynamic>>> _groupedSales = {};

  // خريطة لتخزين المرتجعات (رقم الفاتورة -> قيمة المرتجع)
  Map<int, double> _returnsMap = {};

  bool _isLoading = true;

  // متغير لحساب الشريط السفلي (حركة الشهر)
  double _monthlyNetProfit = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final dbHelper = DatabaseHelper();

    // 1. جلب المبيعات (الفواتير)
    final salesData = await dbHelper.getSalesWithNames();

    // 2. جلب كل المرتجعات وتجهيز الخريطة لضمان دقة الحساب
    final allReturns = await dbHelper.getAllReturns();
    Map<int, double> returnsMap = {};
    for (var ret in allReturns) {
      int saleId = ret['saleId'] ?? 0;
      double amount = (ret['totalAmount'] as num?)?.toDouble() ?? 0.0;
      if (returnsMap.containsKey(saleId)) {
        returnsMap[saleId] = returnsMap[saleId]! + amount;
      } else {
        returnsMap[saleId] = amount;
      }
    }

    // 3. جلب بيانات التقرير العام (لحساب حركة الشهر والمصاريف)
    final reportData = await dbHelper.getGeneralReportData();

    // تجميع الفواتير حسب العميل
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var sale in salesData) {
      String clientName = sale['clientName'] ?? 'عميل غير معروف';
      if (!grouped.containsKey(clientName)) {
        grouped[clientName] = [];
      }
      grouped[clientName]!.add(sale);
    }

    if (mounted) {
      setState(() {
        _allSales = salesData;
        _groupedSales = grouped;
        _returnsMap = returnsMap;

        // حساب صافي حركة الشهر للشريط السفلي
        // المعادلة: (مبيعات الشهر - مرتجعات الشهر) - مصاريف الشهر
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

  // 🔥 دالة لحساب إجمالي صافي المبيعات (للشريط العلوي) 🔥
  double _calculateTotalNetSales() {
    double sum = 0;
    for (var sale in _allSales) {
      // صافي الفاتورة (قبل خصم المرتجع)
      double net = (sale['netAmount'] as num?)?.toDouble() ?? 0.0;

      // قيمة المرتجع من الخريطة المحدثة
      double returned = _returnsMap[sale['id']] ?? 0.0;

      // نجمع الصافي الفعلي
      sum += (net - returned);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // لون النص للشريط السفلي بناءً على الربح أو الخسارة
    Color profitColor = _monthlyNetProfit >= 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل المبيعات (تفصيلي)')),
      body: Column(
        children: [
          // 1️⃣ الشريط العلوي (إجمالي الصافي وعدد الفواتير)
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

          // 2️⃣ قائمة الفواتير (مجمعة حسب العميل)
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

                      // حساب إجمالي العميل (صافي الفواتير - المرتجعات)
                      double clientTotal = clientInvoices.fold(0.0, (
                        sum,
                        item,
                      ) {
                        double total = (item['totalAmount'] as num).toDouble();
                        double discount =
                            (item['discount'] as num?)?.toDouble() ?? 0.0;
                        double tax =
                            (item['taxAmount'] as num?)?.toDouble() ?? 0.0;

                        double net = (total - discount) + tax;
                        double returned = _returnsMap[item['id']] ?? 0.0;

                        return sum + (net - returned);
                      });

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

          // 3️⃣ الشريط السفلي (صافي حركة الشهر)
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

  // --- تصميم كارت الفاتورة (معدل) ---
  // --- تصميم كارت الفاتورة (معدل للقراءة المباشرة) ---
  // --- تصميم كارت الفاتورة (التسلسل المنطقي: أصل -> خصم -> بعد الخصم -> ضريبة -> صافي) ---
  // --- تصميم كارت الفاتورة (بالمنطق العكسي: إضافة الخصم للأصل) ---
  // --- تصميم كارت الفاتورة (التصحيح النهائي: قراءة الأصل وطرح الخصم) ---
  Widget _buildInvoiceCard(Map<String, dynamic> sale, bool isDark) {
    // 1. استخراج القيم من قاعدة البيانات
    // totalAmount هنا هو إجمالي سعر الأصناف (110 حسب مثالك)
    double originalTotal = (sale['totalAmount'] as num).toDouble();

    double discount = (sale['discount'] as num?)?.toDouble() ?? 0.0; // 10
    double tax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0; // 14

    // 2. حساب المبلغ بعد الخصم (الوعاء الضريبي)
    // 110 - 10 = 100
    double amountAfterDiscount = originalTotal - discount;

    // 3. حساب الصافي النهائي
    // نعتمد على NetAmount المحفوظ لأنه الأدق، أو نحسبه
    double finalNet;
    if (sale['netAmount'] != null && (sale['netAmount'] as num) > 0) {
      finalNet = (sale['netAmount'] as num).toDouble();
    } else {
      // 100 + 14 = 114
      finalNet = amountAfterDiscount + tax;
    }

    // المرتجعات
    double returned = _returnsMap[sale['id']] ?? 0.0;
    bool isFullyReturned = (returned >= finalNet - 0.1) && finalNet > 0;

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "فاتورة #${sale['id']}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isFullyReturned ? Colors.red : null,
              ),
            ),
            Text(
              sale['date'].toString().split(' ')[0],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Column(
          children: [
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "الصافي: ${fmt(finalNet)} ج.م",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (returned > 0)
                  Text(
                    "مرتجع: -${fmt(returned)}",
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
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
            : ElevatedButton.icon(
                onPressed: () => _showReturnDialog(sale),
                icon: const Icon(Icons.assignment_return, size: 14),
                label: const Text("مرتجع"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[700] : Colors.white,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  side: const BorderSide(color: Colors.red, width: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(60, 30),
                ),
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
                // 1. السعر الأصلي (110)
                _buildInfoRow("إجمالي السلة", "${fmt(originalTotal)} ج.م"),

                // 2. الخصم (-10)
                if (discount > 0) ...[
                  _buildInfoRow(
                    "الخصم",
                    "-${fmt(discount)} ج.م",
                    color: Colors.red,
                  ),

                  // 3. السعر بعد الخصم (100)
                  const Divider(height: 10, indent: 20, endIndent: 20),
                  _buildInfoRow(
                    "بعد الخصم",
                    "${fmt(amountAfterDiscount)} ج.م",
                    isBold: true,
                    size: 14,
                  ),
                ],

                // 4. الضريبة (+14)
                if (tax > 0)
                  _buildInfoRow(
                    "الضريبة (14%)",
                    "+${fmt(tax)} ج.م",
                    color: Colors.orange,
                  ),

                const Divider(height: 15, thickness: 1.5),

                // 5. الصافي النهائي (114)
                _buildInfoRow(
                  "الإجمالي النهائي",
                  "${fmt(finalNet)} ج.م",
                  isBold: true,
                  size: 16,
                  color: isDark ? Colors.tealAccent : Colors.teal,
                ),

                // المرتجعات
                if (returned > 0) ...[
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
                          "-${fmt(returned)} ج.م",
                          color: Colors.red,
                          size: 12,
                        ),
                        _buildInfoRow(
                          "المطلوب دفعه",
                          "${fmt(finalNet - returned)} ج.م",
                          isBold: true,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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

  // --- ديالوج المرتجع ---
  void _showReturnDialog(Map<String, dynamic> sale) async {
    final items = await DatabaseHelper().getSaleItems(sale['id']);
    // جلب المرتجعات السابقة
    final previouslyReturnedMap = await DatabaseHelper()
        .getAlreadyReturnedItems(sale['id']);

    Map<int, int> returnQuantities = {};
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
            int qty = returnQuantities[item['id']] ?? 0;
            if (qty > 0) {
              grossReturnTotal += qty * (item['price'] as num).toDouble();
              itemsToReturn.add({
                'productId': item['productId'],
                'quantity': qty,
                'price': item['price'],
              });
            }
          }

          double saleTotal = (sale['totalAmount'] as num).toDouble();
          double saleDiscount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
          double discountRatio = (saleTotal == 0)
              ? 0
              : (saleDiscount / saleTotal);
          double returnDiscountShare = grossReturnTotal * discountRatio;
          double netReturnBeforeTax = grossReturnTotal - returnDiscountShare;
          double saleTax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;
          double originalNetBeforeTax = saleTotal - saleDiscount;
          double taxRatio = (originalNetBeforeTax == 0)
              ? 0
              : (saleTax / originalNetBeforeTax);
          double returnTaxShare = netReturnBeforeTax * taxRatio;
          double finalReturnTotal = netReturnBeforeTax + returnTaxShare;

          return AlertDialog(
            title: Text("مرتجع فاتورة #${sale['id']}"),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
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
                        int originalQty = item['quantity'];
                        int alreadyReturned =
                            previouslyReturnedMap[item['productId']] ?? 0;
                        int availableToReturn = originalQty - alreadyReturned;
                        if (availableToReturn < 0) availableToReturn = 0;
                        int currentReturnQty =
                            returnQuantities[item['id']] ?? 0;

                        return Card(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          child: Opacity(
                            opacity: availableToReturn > 0 ? 1.0 : 0.5,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['productName'] ?? 'صنف',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "${fmt(item['price'])} ج.م",
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (availableToReturn > 0) ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            if (currentReturnQty > 0)
                                              setStateSB(
                                                () =>
                                                    returnQuantities[item['id']] =
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
                                                () =>
                                                    returnQuantities[item['id']] =
                                                        currentReturnQty + 1,
                                              );
                                          },
                                        ),
                                      ] else
                                        const Text(
                                          "تم الإرجاع بالكامل",
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Text(
                                          "أصل: $originalQty",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          "سابق: $alreadyReturned",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                        Text(
                                          "متبقي: $availableToReturn",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("قيمة الأصناف:"),
                            Text("${fmt(grossReturnTotal)} ج.م"),
                          ],
                        ),
                        if (returnDiscountShare > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "يخصم خصم (${fmt(discountRatio * 100)}%):",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "-${fmt(returnDiscountShare)}",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (returnTaxShare > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "استرداد ضريبة (${fmt(taxRatio * 100)}%):",
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "+${fmt(returnTaxShare)}",
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "صافي المرتجع (للدفع):",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${fmt(finalReturnTotal)} ج.م",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark
                                    ? Colors.greenAccent
                                    : Colors.green[800],
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
                  await DatabaseHelper().createReturn(
                    sale['id'],
                    sale['clientId'] ?? 0,
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
}
