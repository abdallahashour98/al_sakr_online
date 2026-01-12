import 'package:flutter/material.dart';
import 'services/purchases_service.dart';

/// ============================================================
/// 📦 شاشة سجل المشتريات (Purchase History Screen)
/// ============================================================
/// الغرض:
/// عرض أرشيف فواتير الشراء، تجميعها حسب الموردين، وإدارة مرتجعات الموردين.
///
/// الميزات الأساسية:
/// 1. فلترة زمنية (شهرية).
/// 2. تجميع الفواتير (Grouped List) لكل مورد.
/// 3. إنشاء مرتجع شراء (Purchase Return) مع حساب الضرائب والخصومات نسبياً.
/// 4. تعديل الأرقام المرجعية للفواتير (للمطابقة مع الفواتير الورقية).
class PurchaseHistoryScreen extends StatefulWidget {
  final DateTime?
  initialDate; // 🔗 استقبال التاريخ لتوحيد السياق مع التقرير الشامل
  const PurchaseHistoryScreen({super.key, this.initialDate});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  late DateTime _selectedDate; // الشهر المحدد للعرض

  // --- تخزين البيانات ---
  /// خريطة لتجميع الفواتير: [اسم المورد] -> [قائمة الفواتير]
  Map<String, List<Map<String, dynamic>>> _groupedPurchases = {};
  List<Map<String, dynamic>> _monthlyPurchases =
      []; // قائمة مسطحة للفواتير (للحسابات)

  bool _isLoading = true;

  // --- خرائط التتبع ---
  /// خريطة تربط [رقم الفاتورة] -> [قيمة المرتجعات التي تمت عليها]
  /// تستخدم لتلوين الفاتورة باللون الأحمر إذا كانت مرتجعة بالكامل
  Map<String, double> _invoiceReturnsMap = {};

  // --- الإجماليات المالية للشهر ---
  double _totalMonthPurchases = 0.0; // إجمالي الفواتير
  double _totalMonthReturns = 0.0; // إجمالي المرتجعات المسجلة هذا الشهر
  double _netMonthMovement = 0.0; // الصافي (مشتريات - مرتجعات)

  // --- الصلاحيات ---
  bool _canAddReturn = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    // استخدام التاريخ المرر أو التاريخ الحالي كافتراضي
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadPermissions();
    _loadData();
  }

  /// تحميل الصلاحيات (هل المستخدم مسموح له يضيف مشتريات/مرتجعات؟)
  Future<void> _loadPermissions() async {
    final myId = PurchasesService().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) setState(() => _canAddReturn = true);
      return;
    }

    try {
      final userRecord = await PurchasesService().pb
          .collection('users')
          .getOne(myId);
      if (mounted) {
        setState(() {
          _canAddReturn = userRecord.data['allow_add_purchases'] ?? false;
        });
      }
    } catch (e) {
      // ignore errors
    }
  }

  /// تغيير الشهر وإعادة تحميل البيانات
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

  /// 📥 دالة جلب البيانات (Core Logic)
  void _loadData() async {
    // 1. تحديد نطاق التاريخ (من أول ثانية في الشهر لآخر ثانية)
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
      // 2. جلب البيانات من السيرفس (فواتير ومرتجعات هذا الشهر)
      final purchasesData = await PurchasesService().getPurchases(
        startDate: startStr,
        endDate: endStr,
      );
      final returnsThisMonth = await PurchasesService().getAllPurchaseReturns(
        startDate: startStr,
        endDate: endStr,
      );

      // نجيب *كل* المرتجعات عشان نعرف حالة الفاتورة (حتى لو المرتجع حصل في شهر تاني)
      final allReturnsForStatus = await PurchasesService()
          .getAllPurchaseReturns();

      // 3. معالجة البيانات والحسابات
      double totalPurchasesVal = 0.0;
      Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var invoice in purchasesData) {
        String supplierName = invoice['supplierName'] ?? 'مورد غير معروف';
        grouped.putIfAbsent(supplierName, () => []).add(invoice);

        // totalAmount هنا هو الصافي النهائي للفاتورة
        totalPurchasesVal += (invoice['totalAmount'] as num).toDouble();
      }

      // إجمالي المرتجعات المالية (كمعاملة مالية تمت في هذا الشهر)
      double totalReturnsVal = returnsThisMonth.fold(
        0.0,
        (sum, item) => sum + (item['totalAmount'] as num).toDouble(),
      );

      // بناء خريطة حالة الفواتير
      Map<String, double> returnsMap = {};
      for (var ret in allReturnsForStatus) {
        // دعم للحقول المختلفة (purchase أو invoiceId حسب تحديثات الداتابيز)
        String invId =
            ret['purchase']?.toString() ?? ret['invoiceId']?.toString() ?? '';
        if (invId.isNotEmpty) {
          double amount = (ret['totalAmount'] as num?)?.toDouble() ?? 0.0;
          returnsMap[invId] = (returnsMap[invId] ?? 0.0) + amount;
        }
      }

      if (mounted) {
        setState(() {
          _monthlyPurchases = purchasesData;
          _groupedPurchases = grouped;
          _invoiceReturnsMap = returnsMap;

          _totalMonthPurchases = totalPurchasesVal;
          _totalMonthReturns = totalReturnsVal;
          // الصافي = المشتريات - المرتجعات
          _netMonthMovement = _totalMonthPurchases - _totalMonthReturns;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading purchases: $e");
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
  // 🛠️ أدوات التعديل والإجراءات (Actions)
  // ============================================================

  /// حوار تعديل الرقم المرجعي للفاتورة (لتطابق الفاتورة الورقية)
  void _showEditRefDialog(Map<String, dynamic> invoice) {
    final refController = TextEditingController(
      text: invoice['referenceNumber']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تعديل مرجع الفاتورة"),
        content: TextField(
          controller: refController,
          decoration: const InputDecoration(
            labelText: "رقم فاتورة المورد (يدوي)",
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
                await PurchasesService().updatePurchaseReference(
                  invoice['id'],
                  refController.text,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData(); // تحديث الواجهة
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم التعديل بنجاح ✅"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
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

  /// ↩️ دالة معالج مرتجع المشتريات (Purchase Return Logic)
  /// تقوم بحساب قيمة المرتجع بناءً على سعر التكلفة ونسبة الخصم والضرائب في الفاتورة الأصلية
  void _showPurchaseReturnDialog(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
  ) {
    if (!_canAddReturn) return;

    // جلب قيم الضرائب والخصومات من الفاتورة الأصلية
    double invTax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double invWht = (invoice['whtAmount'] as num?)?.toDouble() ?? 0.0;
    double invDiscount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;

    bool hasTax = invTax > 0.1;
    bool hasWht = invWht > 0.1;

    // حساب إجمالي الأصناف الأصلي (لحساب نسبة الخصم)
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
          double returnBaseTotal = 0; // إجمالي الأصناف المرتجعة (سعر تكلفة)
          List<Map<String, dynamic>> itemsToReturn = [];

          // تجميع الأصناف المختارة
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

          // 🧮 الحسابات التناسبية (Proportional Math)
          // لو الفاتورة كان عليها خصم، لازم المرتجع يتخصم منه نفس النسبة
          double returnDiscount = 0.0;
          if (originalItemsTotal > 0 && invDiscount > 0) {
            double ratio = returnBaseTotal / originalItemsTotal;
            returnDiscount = invDiscount * ratio;
          }

          double netReturnBase = returnBaseTotal - returnDiscount;

          // حساب الضرائب المستردة
          double returnTaxVal = hasTax ? netReturnBase * 0.14 : 0.0;
          double returnWhtVal = hasWht ? netReturnBase * 0.01 : 0.0;

          // المعادلة النهائية للمرتجع
          double finalReturnTotal = netReturnBase + returnTaxVal - returnWhtVal;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          String refNumber = invoice['referenceNumber']?.toString() ?? '';
          String displayId = refNumber.isNotEmpty
              ? "#$refNumber"
              : "#${invoice['id'].toString().substring(0, 5)}";

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
                    "مرتجع من فاتورة $displayId",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "حدد الكميات التي تريد إعادتها للمورد:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),

                  // قائمة الأصناف
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      separatorBuilder: (c, i) => const SizedBox(height: 5),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        int maxQty = (item['quantity'] as num).toInt();
                        String prodId = item['product'];
                        int currentReturn = returnQuantities[prodId] ?? 0;

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
                                      item['productName'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "سعر: ${item['costPrice']}",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // أزرار التحكم في الكمية (+ / -)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: currentReturn > 0
                                        ? () => setStateDialog(
                                            () => returnQuantities[prodId] =
                                                currentReturn - 1,
                                          )
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Center(
                                      child: Text(
                                        "$currentReturn",
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
                                    onPressed: currentReturn < maxQty
                                        ? () => setStateDialog(
                                            () => returnQuantities[prodId] =
                                                currentReturn + 1,
                                          )
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
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
                  const SizedBox(height: 15),

                  // أزرار التأكيد
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
                          onPressed: finalReturnTotal > 0
                              ? () async {
                                  // إنشاء المرتجع في قاعدة البيانات
                                  await PurchasesService().createPurchaseReturn(
                                    invoice['id'],
                                    invoice['supplier'] ??
                                        invoice['supplierId'],
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

  // ============================================================
  // 🎨 واجهة البطاقة (UI Components)
  // ============================================================

  Widget _buildInvoiceCard(Map<String, dynamic> invoice, bool isDark) {
    // قراءة القيم المالية
    double savedFinalTotal = (invoice['totalAmount'] as num).toDouble();
    double tax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double wht = (invoice['whtAmount'] as num?)?.toDouble() ?? 0.0;
    double discount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;

    // حساب إجمالي الأصناف قبل الإضافات (للعرض فقط)
    double calculatedSubTotal = savedFinalTotal - tax + wht + discount;

    double returnedTotal = _invoiceReturnsMap[invoice['id']] ?? 0.0;
    bool isCash = (invoice['paymentType'] == 'cash');

    // هل الفاتورة مرتجعة بالكامل؟
    bool isFullyReturned =
        (returnedTotal >= savedFinalTotal - 0.1) && savedFinalTotal > 0;

    String refNumber = invoice['referenceNumber']?.toString() ?? '';
    String displayId = refNumber.isNotEmpty
        ? "#$refNumber"
        : "#${invoice['id'].toString().substring(0, 5)}";

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
                  color: isFullyReturned ? Colors.red : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // بادج طريقة الدفع
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCash
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCash ? "كاش" : "آجل",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCash ? Colors.green : Colors.red,
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
                  "الصافي: ${fmt(savedFinalTotal)} ج.م",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  invoice['date'].toString().split(' ')[0],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              tooltip: "تعديل الرقم",
              onPressed: () => _showEditRefDialog(invoice),
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
                onPressed: () async {
                  final items = await PurchasesService().getPurchaseItems(
                    invoice['id'],
                  );
                  if (mounted) _showPurchaseReturnDialog(invoice, items);
                },
              ),
          ],
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
                _buildInfoRow(
                  "إجمالي الأصناف",
                  "${fmt(calculatedSubTotal)} ج.م",
                ),
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
                  "${fmt(savedFinalTotal)} ج.م",
                  isBold: true,
                  size: 15,
                  color: isDark ? Colors.tealAccent : Colors.teal,
                ),
                if (returnedTotal > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: _buildInfoRow(
                      "قيمة المرتجعات",
                      "-${fmt(returnedTotal)} ج.م",
                      color: Colors.red,
                      size: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showItemsBottomSheet(invoice),
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

  // ... (دوال مساعدة للعرض _showItemsBottomSheet, _buildDetailRow, etc...)
  // تم تبسيطها هنا للتركيز، لكن الكود الأصلي يحتوي عليها
  void _showItemsBottomSheet(Map<String, dynamic> invoice) async {
    // (نفس الكود الخاص بعرض الأصناف، لكنه يستخدم Cost Price بدل السعر البيع)
    final items = await PurchasesService().getPurchaseItems(invoice['id']);
    // ... rest of the code for bottom sheet
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    double savedFinalTotal = (invoice['totalAmount'] as num).toDouble();
    double tax = (invoice['taxAmount'] as num?)?.toDouble() ?? 0.0;
    double wht = (invoice['whtAmount'] as num?)?.toDouble() ?? 0.0;
    double discount = (invoice['discount'] as num?)?.toDouble() ?? 0.0;
    double calculatedSubTotal = savedFinalTotal - tax + wht + discount;

    String refNumber = invoice['referenceNumber']?.toString() ?? '';
    String displayId = refNumber.isNotEmpty
        ? "#$refNumber"
        : "#${invoice['id'].toString().substring(0, 5)}";

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
                    "قائمة الأصناف والتفاصيل",
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
                    subtitle: Text('سعر الشراء: ${items[i]['costPrice']}'),
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
                    _buildDetailRow(
                      "إجمالي الأصناف",
                      calculatedSubTotal,
                      isDark,
                    ),
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
                          '${fmt(savedFinalTotal)} ج.م',
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
            "${fmt(val)} ج.م",
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color profitColor = _netMonthMovement >= 0 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المشتريات'),
        centerTitle: true,
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
                      "إجمالي مشتريات الشهر",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "${fmt(_totalMonthPurchases)} ج.م",
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
                      "${_monthlyPurchases.length}",
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

          // 2. قائمة الفواتير المجمعة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedPurchases.isEmpty
                ? const Center(
                    child: Text('لا توجد فواتير مشتريات في هذا الشهر'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _groupedPurchases.keys.length,
                    itemBuilder: (context, index) {
                      String supplierName = _groupedPurchases.keys.elementAt(
                        index,
                      );
                      List<Map<String, dynamic>> invoices =
                          _groupedPurchases[supplierName]!;

                      // حساب إجمالي المورد (ظاهرياً)
                      double totalSupplierPurchases = invoices.fold(
                        0,
                        (sum, item) =>
                            sum + (item['totalAmount'] as num).toDouble(),
                      );

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.brown.withOpacity(0.2)
                                : Colors.brown[100],
                            child: Icon(
                              Icons.local_shipping,
                              color: Colors.brown[700],
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
                              fontSize: 15,
                            ),
                          ),
                          children: invoices
                              .map(
                                (invoice) => _buildInvoiceCard(invoice, isDark),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),

          // 3. الشريط السفلي (الصافي)
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
                          "صافي حركة الشهر (مشتريات - مرتجعات):",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            "(الفواتير الصافية - المرتجعات)",
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
                    "${fmt(_netMonthMovement)} ج.م",
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
