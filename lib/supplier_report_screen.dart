import 'package:flutter/material.dart';
import 'db_helper.dart';

class SupplierReportScreen extends StatefulWidget {
  const SupplierReportScreen({super.key});

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  // 1. المتغيرات الأساسية (مدمجة)
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _statementData = [];
  List<Map<String, dynamic>> _filteredData = [];
  int? _selectedSupplierId;
  double _finalBalance = 0;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  double _periodPurchases = 0;
  double _periodPaid = 0;
  String _displayFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  void _loadSuppliers() async {
    final data = await DatabaseHelper().getSuppliers();
    setState(() {
      _suppliers = data;
    });
  }

  // تحميل البيانات (المنطق المدمج)
  // استبدل الدالة القديمة بهذه الجديدة
  void _loadStatement() async {
    if (_selectedSupplierId == null) return;

    // 1. جلب العمليات (فواتير، مرتجعات، دفع) خلال الفترة
    final data = await DatabaseHelper().getSupplierStatement(
      _selectedSupplierId!,
      startDate: _startDate,
      endDate: _endDate,
    );

    // 2. 🔥 جلب الرصيد الافتتاحي الأساسي للمورد (الذي تم تسجيله عند الإضافة)
    // ملاحظة: للحصول على كشف حساب دقيق 100%، المفروض نحسب كمان العمليات اللي حصلت "قبل" تاريخ البداية
    // لكن مبدئياً سنعرض الرصيد الافتتاحي المسجل في كارت المورد.
    double openingBalance = await DatabaseHelper().getSupplierOpeningBalance(
      _selectedSupplierId!,
    );

    double purchases = 0;
    double paid = 0;

    // 3. دمج الرصيد الافتتاحي في القائمة ليظهر للمستخدم
    // بنعمل نسخة قابلة للتعديل من الداتا
    List<Map<String, dynamic>> allData = List.from(data);

    if (openingBalance != 0) {
      allData.insert(0, {
        'id': 0, // ID وهمي
        'type': 'opening', // نوع جديد عشان نميزه في الرسم
        'amount': openingBalance.abs(),
        'date': _startDate.toString(), // نخليه بتاريخ بداية البحث
        'description': 'رصيد افتتاحي / سابق',
      });
    }

    // 4. حساب الإجماليات
    for (var item in allData) {
      double amount = (item['amount'] as num).toDouble();

      if (item['type'] == 'opening') {
        // لو الرصيد بالموجب (علينا) بنزود المديونية، لو بالسالب (لنا) بننقصها
        // (حسب منطقك: موجب = مدين/علينا)
        if (openingBalance > 0)
          purchases += amount;
        else
          paid += amount; // أو نعتبرها رصيد دائن
      } else if (item['type'] == 'payment') {
        paid += amount;
      } else if (item['type'] == 'bill') {
        purchases += amount;
      } else if (item['type'] == 'return') {
        purchases -= amount;
      }
    }

    // المعادلة: (الرصيد الافتتاحي + الفواتير) - (المدفوعات + المرتجعات)
    // هنا بسطناها بإننا دمجنا الافتتاحي في المتغيرات فوق
    double finalBal = 0;
    // حساب دقيق: الرصيد الافتتاحي + الفواتير - المدفوعات - المرتجعات
    // لاحظ: في اللوب فوق، المرتجع خصمناه من المشتريات بالفعل

    // الطريقة الأبسط للحساب النهائي المباشر:
    double totalBills = 0;
    double totalPayments = 0;
    double totalReturns = 0;

    for (var item in data) {
      // نحسب العمليات فقط
      if (item['type'] == 'bill') totalBills += (item['amount'] as num);
      if (item['type'] == 'payment') totalPayments += (item['amount'] as num);
      if (item['type'] == 'return') totalReturns += (item['amount'] as num);
    }

    finalBal = openingBalance + totalBills - totalReturns - totalPayments;

    setState(() {
      _statementData = allData; // القائمة الجديدة اللي فيها الافتتاحي
      _periodPurchases = totalBills; // مشتريات الفترة فقط للعرض
      _periodPaid = totalPayments; // مدفوعات الفترة فقط للعرض
      _finalBalance = finalBal; // الرصيد النهائي (شامل الافتتاحي)
      _applyLocalFilter();
    });
  }

  void _applyLocalFilter() {
    if (_displayFilter == 'all') {
      _filteredData = List.from(_statementData);
    } else if (_displayFilter == 'bills') {
      _filteredData = _statementData.where((i) => i['type'] == 'bill').toList();
    } else if (_displayFilter == 'returns') {
      _filteredData = _statementData
          .where((i) => i['type'] == 'return')
          .toList();
    } else if (_displayFilter == 'payments') {
      _filteredData = _statementData
          .where((i) => i['type'] == 'payment')
          .toList();
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
      _loadStatement();
    }
  }

  // --- دوال العمليات (التي كانت في كود الموردين الأصلي وتم الحفاظ عليها) ---

  void _showInvoiceDetails(Map<String, dynamic> item) async {
    final items = await DatabaseHelper().getPurchaseItems(item['id']);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'تفاصيل فاتورة #${item['id']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(items[i]['productName'] ?? 'صنف'),
                  subtitle: Text(
                    '${items[i]['quantity']} × ${items[i]['costPrice']}',
                  ),
                  trailing: Text(
                    '${(items[i]['quantity'] * items[i]['costPrice'])} ج.م',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة إضافة/تعديل السند (محفوظة بالكامل بجميع خياراتها: كاش، بنك، شيك)
  void _showPaymentDialog({Map<String, dynamic>? existingPayment}) {
    if (_selectedSupplierId == null) return;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final refController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String paymentMethod = 'cash';

    if (existingPayment != null) {
      amountController.text = existingPayment['amount'].toString();
      selectedDate = DateTime.parse(existingPayment['date']);
      String desc = existingPayment['description'] ?? '';
      if (desc.contains('بنك'))
        paymentMethod = 'bank';
      else if (desc.contains('شيك'))
        paymentMethod = 'check';
      notesController.text = desc;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: Text(
            existingPayment == null ? 'تسجيل سند دفع' : 'تعديل سند دفع',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: const Text(
                          'كاش',
                          style: TextStyle(fontSize: 10),
                        ),
                        value: 'cash',
                        groupValue: paymentMethod,
                        onChanged: (v) =>
                            setStateSB(() => paymentMethod = v.toString()),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text(
                          'بنك',
                          style: TextStyle(fontSize: 10),
                        ),
                        value: 'bank',
                        groupValue: paymentMethod,
                        onChanged: (v) =>
                            setStateSB(() => paymentMethod = v.toString()),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text(
                          'شيك',
                          style: TextStyle(fontSize: 10),
                        ),
                        value: 'check',
                        groupValue: paymentMethod,
                        onChanged: (v) =>
                            setStateSB(() => paymentMethod = v.toString()),
                      ),
                    ),
                  ],
                ),
                if (paymentMethod != 'cash')
                  TextField(
                    controller: refController,
                    decoration: InputDecoration(
                      labelText: paymentMethod == 'bank'
                          ? 'رقم التحويل'
                          : 'رقم الشيك',
                    ),
                  ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  String methodText = paymentMethod == 'cash'
                      ? 'نقدأ'
                      : (paymentMethod == 'bank' ? 'تحويل بنكي' : 'شيك');
                  String finalNotes = notesController.text.isEmpty
                      ? "($methodText) ${refController.text}"
                      : notesController.text;

                  if (existingPayment == null) {
                    await DatabaseHelper().addSupplierPayment(
                      _selectedSupplierId!,
                      double.parse(amountController.text),
                      finalNotes,
                      selectedDate.toString(),
                    );
                  } else {
                    await DatabaseHelper().updateSupplierPayment(
                      id: existingPayment['id'],
                      supplierId: _selectedSupplierId!,
                      oldAmount: (existingPayment['amount'] as num).toDouble(),
                      newAmount: double.parse(amountController.text),
                      newNotes: finalNotes,
                      newDate: selectedDate.toString(),
                    );
                  }
                  Navigator.pop(context);
                  _loadStatement();
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePayment(int id, double amount) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السند'),
        content: const Text('هل أنت متأكد؟ سيتم إعادة المبلغ لمديونية المورد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper().deleteSupplierPayment(
                id,
                _selectedSupplierId!,
                amount,
              );
              _loadStatement();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- بناء الواجهة (تصميم العملاء المتطور) ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('كشف حسابات الموردين')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: DropdownButtonFormField(
              decoration: InputDecoration(
                labelText: 'اختر المورد',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.white,
              ),
              items: _suppliers
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'],
                      child: Text(s['name']),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedSupplierId = val as int?);
                _loadStatement();
              },
            ),
          ),

          if (_selectedSupplierId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: isDark ? Colors.black12 : Colors.grey[100],
              child: Row(
                children: [
                  Expanded(child: _buildDateBox(true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDateBox(false)),
                ],
              ),
            ),

          if (_selectedSupplierId != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _buildStatCard(
                    "مشتريات الفترة",
                    _periodPurchases,
                    Colors.orange,
                    isDark,
                  ),
                  const SizedBox(width: 5),
                  _buildStatCard(
                    "مدفوعات الفترة",
                    _periodPaid,
                    Colors
                        .blue, // غيرت دي أزرق عشان الأخضر ميتكررش، أو سيبها green زي ما تحب
                    isDark,
                  ),
                  const SizedBox(width: 5),

                  // 👇 التعديل هنا: تحديد اللون بناءً على القيمة
                  _buildStatCard(
                    "صافي المستحق",
                    _finalBalance, // الرقم زي ما هو
                    _finalBalance > 0
                        ? Colors
                              .red // لو موجب (علينا) => أحمر
                        : (_finalBalance < 0
                              ? Colors.green
                              : Colors.brown), // لو سالب (لنا) => أخضر
                    isDark,
                    isBold: true,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _buildFilterChip('الكل', 'all'),
                  _buildFilterChip('فواتير الشراء', 'bills'),
                  _buildFilterChip('المرتجعات', 'returns'),
                  _buildFilterChip('سندات الدفع', 'payments'),
                ],
              ),
            ),
            const Divider(),
          ],

          Expanded(
            child: _selectedSupplierId == null
                ? const Center(child: Text("الرجاء اختيار مورد"))
                : _filteredData.isEmpty
                ? const Center(child: Text("لا توجد بيانات"))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _filteredData.length,
                    itemBuilder: (context, index) =>
                        _buildTransactionCard(_filteredData[index], isDark),
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedSupplierId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showPaymentDialog(),
              label: const Text(
                'سند دفع',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.money_off, color: Colors.white),
              backgroundColor: Colors.brown,
            )
          : null,
    );
  }

  Widget _buildDateBox(bool isStart) {
    return InkWell(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isStart ? "من:" : "إلى:",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              isStart
                  ? _startDate.toString().split(' ')[0]
                  : _endDate.toString().split(' ')[0],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    double value,
    Color color,
    bool isDark, {
    bool isBold = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _displayFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _displayFilter = value;
              _applyLocalFilter();
            });
          }
        },
        selectedColor: Colors.brown,
        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item, bool isDark) {
    IconData icon;
    Color color;
    String label;
    if (item['type'] == 'opening') {
      icon = Icons.account_balance;
      color = Colors.blueGrey;
      label = "رصيد سابق";
    } else if (item['type'] == 'bill') {
      icon = Icons.shopping_bag;
      color = Colors.orange;
      label = "فاتورة شراء";
    } else if (item['type'] == 'return') {
      icon = Icons.assignment_return;
      color = Colors.red;
      label = "مرتجع";
    } else {
      icon = Icons.payments;
      color = Colors.green;
      label = "سند دفع";
    }

    return Card(
      elevation: item['type'] == 'opening' ? 0 : 1, // تمييز الافتتاحي
      color: item['type'] == 'opening'
          ? (isDark ? Colors.grey[900] : Colors.grey[200])
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: item['type'] == 'bill' ? () => _showInvoiceDetails(item) : null,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item['description'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              "${item['amount'].toStringAsFixed(1)} ج.م",
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        subtitle: Text(
          "${item['date'].toString().split(' ')[0]}  •  $label",
          style: const TextStyle(fontSize: 11),
        ),
        // الرصيد الافتتاحي لا يمكن حذفه من هنا (يعدل من شاشة الموردين)
        trailing: (item['type'] == 'payment')
            ? PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') _showPaymentDialog(existingPayment: item);
                  if (val == 'delete')
                    _deletePayment(
                      item['id'],
                      (item['amount'] as num).toDouble(),
                    );
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            : (item['type'] == 'bill'
                  ? const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    )
                  : null), // لا نظهر أيقونات للافتتاحي
      ),
    );
  }
}
