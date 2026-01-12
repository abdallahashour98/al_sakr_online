import 'package:al_sakr/services/pb_helper.dart';
import 'package:flutter/material.dart';
import 'services/sales_service.dart';

/// ============================================================
/// 📑 شاشة تقرير المبيعات التفصيلي (Sales Report Screen)
/// ============================================================
/// الغرض:
/// عرض فواتير المبيعات لشهر محدد، مع إمكانية إدارة المرتجعات وتعديل البيانات.
///
/// الميزات الأساسية:
/// 1. تجميع الفواتير حسب العميل.
/// 2. حساب صافي الربح الشهري (المبيعات - المرتجعات - المصروفات).
/// 3. نظام ذكي للمرتجعات (يسمح بإرجاع أصناف محددة وحساب الضرائب نسبياً).
class ReportsScreen extends StatefulWidget {
  final DateTime?
  initialDate; // 🔗 يستقبل التاريخ من "التقرير الشامل" لتوحيد العرض
  const ReportsScreen({super.key, this.initialDate});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedDate; // الشهر المحدد للعرض

  // --- تخزين البيانات ---
  List<Map<String, dynamic>> _monthlySales = []; // كل فواتير الشهر
  Map<String, List<Map<String, dynamic>>> _groupedSales =
      {}; // الفواتير مجمعة باسم العميل

  // --- خرائط التتبع (Tracking Maps) ---
  /// خريطة تربط [رقم الفاتورة] -> [إجمالي قيمة البضاعة المرتجعة منها]
  Map<String, double> _invoiceReturnsTotalMap = {};

  /// خريطة تربط [رقم الفاتورة] -> [إجمالي النقدية التي تم ردها للعميل]
  Map<String, double> _invoiceReturnsPaidMap = {};

  // --- الإجماليات المالية للشهر ---
  double _totalNetSalesForMonth = 0.0;
  double _totalReturnsForMonth = 0.0;
  double _totalExpensesForMonth = 0.0;
  double _netMovementForMonth = 0.0; // صافي الربح/الخسارة

  bool _isLoading = true;
  bool _canAddReturn = false; // صلاحية عمل مرتجع
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    // ضبط التاريخ: إذا لم يتم تمرير تاريخ، نستخدم الوقت الحالي
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadPermissions();
    _loadData();
  }

  /// تحميل الصلاحيات من قاعدة البيانات
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

  /// تغيير الشهر المعروض وإعادة تحميل البيانات
  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
        1,
      );
      _isLoading = true;
    });
    _loadData();
  }

  /// 📥 دالة جلب البيانات ومعالجتها (Core Logic)
  void _loadData() async {
    // 1. تحديد بداية ونهاية الشهر بدقة
    DateTime startOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    DateTime endOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    String startStr = startOfMonth.toIso8601String();
    String endStr = endOfMonth.toIso8601String();

    try {
      // 2. جلب البيانات بالتوازي (Parallel Fetching) لتحسين الأداء
      final salesData = await SalesService().getSales(
        startDate: startStr,
        endDate: endStr,
      );
      final returnsThisMonth = await SalesService().getReturns(
        startDate: startStr,
        endDate: endStr,
      );
      final expensesData = await SalesService().getExpenses(
        startDate: startStr,
        endDate: endStr,
      );

      // جلب *كل* المرتجعات (حتى لو في شهر تاني) عشان نعرف حالة الفاتورة (هل هي مرتجعة كلياً؟)
      final allReturnsForStatus = await SalesService().getReturns();

      // 3. معالجة البيانات (Data Processing)
      double totalSalesNet = 0.0;
      Map<String, List<Map<String, dynamic>>> grouped = {};

      // تجميع الفواتير تحت اسم العميل وحساب صافي المبيعات
      for (var sale in salesData) {
        String clientName = sale['clientName'] ?? 'عميل غير معروف';
        grouped.putIfAbsent(clientName, () => []).add(sale);

        double net = (sale['netAmount'] as num? ?? sale['totalAmount'])
            .toDouble();
        totalSalesNet += net;
      }

      // حساب إجماليات المرتجعات والمصروفات لهذا الشهر
      double totalReturnsValue = returnsThisMonth.fold(
        0.0,
        (sum, item) => sum + (item['totalAmount'] as num).toDouble(),
      );
      double totalExpensesValue = expensesData.fold(
        0.0,
        (sum, item) => sum + (item['amount'] as num).toDouble(),
      );

      // 4. بناء خريطة حالة الفواتير (Invoice Status Map)
      // الهدف: معرفة كل فاتورة "اتاخد منها كام" في المرتجعات
      Map<String, double> invReturnsTotal = {};
      Map<String, double> invReturnsPaid = {};

      for (var ret in allReturnsForStatus) {
        String saleId = '';
        if (ret['sale'] is Map) {
          saleId = ret['sale']['id'] ?? '';
        } else {
          saleId = ret['sale']?.toString() ?? '';
        }

        if (saleId.isNotEmpty) {
          double total = (ret['totalAmount'] as num?)?.toDouble() ?? 0.0;
          double paid = (ret['paidAmount'] as num?)?.toDouble() ?? 0.0;

          invReturnsTotal[saleId] = (invReturnsTotal[saleId] ?? 0.0) + total;
          invReturnsPaid[saleId] = (invReturnsPaid[saleId] ?? 0.0) + paid;
        }
      }

      if (mounted) {
        setState(() {
          _monthlySales = salesData;
          _groupedSales = grouped;
          _invoiceReturnsTotalMap = invReturnsTotal;
          _invoiceReturnsPaidMap = invReturnsPaid;

          _totalNetSalesForMonth = totalSalesNet;
          _totalReturnsForMonth = totalReturnsValue;
          _totalExpensesForMonth = totalExpensesValue;

          // 📊 المعادلة المحاسبية: صافي الحركة = (مبيعات - مرتجعات) - مصروفات
          _netMovementForMonth =
              (_totalNetSalesForMonth - _totalReturnsForMonth) -
              _totalExpensesForMonth;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String fmt(dynamic number) {
    if (number == null) return "0.00";
    if (number is num) return number.toDouble().toStringAsFixed(2);
    return double.tryParse(number.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  String _getMonthName(int month) {
    const months = [
      "يناير",
      "فبراير",
      "مارس",
      "أبريل",
      "مايو",
      "يونيو",
      "يوليو",
      "أغسطس",
      "سبتمبر",
      "أكتوبر",
      "نوفمبر",
      "ديسمبر",
    ];
    return months[month - 1];
  }

  // ============================================================
  // 🎨 واجهة البطاقة (UI Components)
  // ============================================================

  /// بناء كارت الفاتورة الواحد
  Widget _buildInvoiceCard(Map<String, dynamic> sale, bool isDark) {
    // استخراج الأرقام المالية
    double itemsTotal = (sale['totalAmount'] as num).toDouble();
    double discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    double tax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double wht = (sale['whtAmount'] as num?)?.toDouble() ?? 0.0;

    // صافي الفاتورة الأصلي
    double amountAfterDiscount = itemsTotal - discount;
    double finalNet = amountAfterDiscount + tax - wht;

    // ما تم إرجاعه من هذه الفاتورة سابقاً
    double returnedTotal = _invoiceReturnsTotalMap[sale['id']] ?? 0.0;
    double returnedCash = _invoiceReturnsPaidMap[sale['id']] ?? 0.0;

    // حالة الدفع
    bool isCashSale = (sale['paymentType'] == 'cash');
    double paidByClient = isCashSale ? finalNet : 0.0;

    // الحسابات الختامية للفاتورة (بعد المرتجعات)
    double netValue = finalNet - returnedTotal; // قيمة الفاتورة الحالية
    double netPayment = paidByClient - returnedCash; // صافي المدفوع
    double remaining = netValue - netPayment; // المتبقي

    // هل الفاتورة "ماتت" (مرتجعة بالكامل)؟
    bool isFullyReturned = (returnedTotal >= finalNet - 0.1) && finalNet > 0;

    String refNumber = sale['referenceNumber']?.toString() ?? '';
    String displayId = refNumber.isNotEmpty
        ? "#$refNumber"
        : "#${sale['id'].toString().substring(0, 5)}";

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                "فاتورة $displayId",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isFullyReturned
                      ? Colors.red
                      : null, // لون أحمر لو مرتجعة
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // بادج نوع الدفع (كاش/آجل)
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
          ],
        ),
        // أزرار التحكم في الفاتورة
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              tooltip: "تعديل الرقم",
              onPressed: () => _showEditRefDialog(sale),
            ),
            if (isFullyReturned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  "مرتجع",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (_canAddReturn)
              IconButton(
                icon: const Icon(
                  Icons.assignment_return,
                  size: 18,
                  color: Colors.red,
                ),
                tooltip: "مرتجع",
                onPressed: () => _showReturnDialog(sale),
              ),
          ],
        ),
        // التفاصيل الداخلية عند الفتح
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

                // لو فيه مرتجعات سابقة، اعرض تفاصيلها
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
                // حالة الحساب (لنا / له / خالص)
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
                const SizedBox(height: 15),
                // زر عرض الأصناف بالتفصيل
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showItemsBottomSheet(sale),
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text("عرض قائمة الأصناف والتفاصيل"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (دالة _showItemsBottomSheet كما هي لعرض التفاصيل)
  void _showItemsBottomSheet(Map<String, dynamic> sale) async {
    // (نفس الكود الخاص بعرض الأصناف في BottomSheet)
    // ...
    final items = await SalesService().getSaleItems(sale['id']);
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    double totalAmount = (sale['totalAmount'] as num).toDouble();
    double discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    double tax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double wht = (sale['whtAmount'] as num?)?.toDouble() ?? 0.0;
    double netAmount = (sale['netAmount'] as num?)?.toDouble() ?? 0.0;

    String refNumber = sale['referenceNumber']?.toString() ?? '';
    String displayId = refNumber.isNotEmpty
        ? "#$refNumber"
        : "#${sale['id'].toString().substring(0, 5)}";

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
                  const Text(
                    "أصناف الفاتورة",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(displayId, style: TextStyle(color: Colors.grey[600])),
                ],
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
                          ? Colors.teal.withOpacity(0.2)
                          : Colors.teal[50],
                      child: Text(
                        '${items[i]['quantity']}',
                        style: TextStyle(
                          color: isDark ? Colors.tealAccent : Colors.teal[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      items[i]['productName'] ?? 'صنف',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${items[i]['price']} ج.م'),
                    trailing: Text(
                      '${fmt((items[i]['quantity'] as int) * (items[i]['price'] as num))} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              const Divider(),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow("إجمالي الأصناف", totalAmount),
                    if (discount > 0)
                      _buildSummaryRow("خصم (-)", discount, color: Colors.red),
                    if (tax > 0)
                      _buildSummaryRow(
                        "ضريبة 14% (+)",
                        tax,
                        color: Colors.orange,
                      ),
                    if (wht > 0)
                      _buildSummaryRow(
                        "خصم منبع 1% (-)",
                        wht,
                        color: Colors.teal,
                      ),
                    const Divider(height: 15),
                    _buildSummaryRow(
                      "الإجمالي النهائي",
                      netAmount,
                      isBold: true,
                      color: isDark ? Colors.tealAccent : Colors.teal,
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

  /// ↩️ دالة معالج المرتجع (Wizard)
  /// تسمح للمستخدم باختيار الكميات التي يريد إرجاعها من كل صنف
  void _showReturnDialog(Map<String, dynamic> sale) async {
    if (!_canAddReturn) return;

    final items = await SalesService().getSaleItems(sale['id']);
    // جلب الكميات المرتجعة سابقاً من هذه الفاتورة
    final previouslyReturnedMap = await SalesService().getAlreadyReturnedItems(
      sale['id'],
    );

    Map<String, int> returnQuantities = {};
    for (var item in items) {
      returnQuantities[item['id']] = 0; // تصفير الكميات في البداية
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          double grossReturnTotal = 0;
          List<Map<String, dynamic>> itemsToReturn = [];

          // حساب الإجمالي المبدئي للمرتجع بناءً على الكميات المختارة
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

          // جلب بيانات الضرائب والخصومات من الفاتورة الأصلية
          double saleItemsTotal = (sale['totalAmount'] as num).toDouble();
          double saleDiscount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
          double saleTax = (sale['taxAmount'] as num?)?.toDouble() ?? 0.0;
          double saleWht = (sale['whtAmount'] as num?)?.toDouble() ?? 0.0;

          bool hasTax = saleTax > 0.1;
          bool hasWht = saleWht > 0.1;

          // 🧮 معادلات "النسبة والتناسب" (Proportional Logic)
          // نحسب نسبة الخصم في الفاتورة الأصلية ونطبقها على المرتجع
          double discountRatio = (saleItemsTotal > 0)
              ? (saleDiscount / saleItemsTotal)
              : 0;

          double returnDiscountShare =
              grossReturnTotal * discountRatio; // الخصم المسترد
          double netReturnBeforeTax =
              grossReturnTotal - returnDiscountShare; // الصافي قبل الضريبة

          double returnTaxShare = hasTax
              ? netReturnBeforeTax * 0.14
              : 0.0; // ضريبة مستردة
          double returnWhtShare = hasWht
              ? netReturnBeforeTax * 0.01
              : 0.0; // خصم منبع معكوس

          double finalReturnTotal =
              netReturnBeforeTax +
              returnTaxShare -
              returnWhtShare; // المبلغ النهائي للمرتجع

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "مرتجع فاتورة #${sale['id'].toString().substring(0, 5)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "حدد الكميات للإرجاع:",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  // قائمة الأصناف للاختيار منها
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      separatorBuilder: (c, i) => const SizedBox(height: 5),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        String prodId = item['product'];
                        int originalQty = (item['quantity'] as num).toInt();
                        int alreadyReturned =
                            previouslyReturnedMap[prodId] ?? 0;
                        // المتاح للإرجاع = الكمية الأصلية - اللي رجع قبل كده
                        int availableToReturn = originalQty - alreadyReturned;
                        if (availableToReturn < 0) availableToReturn = 0;

                        String itemId = item['id'];
                        int currentReturnQty = returnQuantities[itemId] ?? 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['productName'] ?? 'صنف',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "${fmt(item['price'])} ج.م",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (availableToReturn > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: currentReturnQty > 0
                                          ? () => setStateSB(
                                              () => returnQuantities[itemId] =
                                                  currentReturnQty - 1,
                                            )
                                          : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    SizedBox(
                                      width: 30,
                                      child: Center(
                                        child: Text(
                                          "$currentReturnQty",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.green,
                                      ),
                                      onPressed:
                                          currentReturnQty < availableToReturn
                                          ? () => setStateSB(
                                              () => returnQuantities[itemId] =
                                                  currentReturnQty + 1,
                                            )
                                          : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    "مكتمل",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
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
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("إلغاء"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () async {
                            if (finalReturnTotal <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'يجب اختيار صنف واحد على الأقل',
                                  ),
                                ),
                              );
                              return;
                            }
                            await SalesService().createReturn(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ دالة تعديل رقم الفاتورة المرجعي
  void _showEditRefDialog(Map<String, dynamic> sale) {
    // ... (نفس الكود الأصلي)
    final refController = TextEditingController(
      text: sale['referenceNumber']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تعديل رقم الفاتورة"),
        content: TextField(
          controller: refController,
          decoration: const InputDecoration(
            labelText: "رقم الفاتورة اليدوي",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SalesService().updateSaleReference(
                  sale['id'],
                  refController.text,
                );

                Navigator.pop(ctx);
                _loadData();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم التعديل بنجاح ✅"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("خطأ: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  // --- Widgets مساعدة ---
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
    Color profitColor = _netMovementForMonth >= 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المبيعات'),
        centerTitle: true,
        // شريط التنقل بين الشهور (Footer of AppBar)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    "${_getMonthName(_selectedDate.month)} ${_selectedDate.year}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. الشريط العلوي (ملخص سريع)
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
                      "إجمالي مبيعات الشهر",
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "${fmt(_totalNetSalesForMonth)} ج.م",
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
                      "${_monthlySales.length}",
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

          // 2. قائمة الفواتير
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedSales.isEmpty
                ? const Center(child: Text("لا توجد مبيعات مسجلة في هذا الشهر"))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _groupedSales.keys.length,
                    itemBuilder: (context, index) {
                      String clientName = _groupedSales.keys.elementAt(index);
                      List<Map<String, dynamic>> clientInvoices =
                          _groupedSales[clientName]!;

                      // حساب إجمالي مبيعات العميل (بعد خصم المرتجعات)
                      double clientTotal = clientInvoices.fold(0.0, (
                        sum,
                        item,
                      ) {
                        double net =
                            (item['netAmount'] as num? ?? item['totalAmount'])
                                .toDouble();
                        double returned =
                            _invoiceReturnsTotalMap[item['id']] ?? 0.0;
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

          // 3. الشريط السفلي (النتائج النهائية)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(15),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "صافي حركة الشهر (ربح/خسارة):",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "(المبيعات - المرتجعات - المصاريف)",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${fmt(_netMovementForMonth)} ج.م",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: profitColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
