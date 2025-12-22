import 'package:flutter/material.dart';
import 'db_helper.dart';

class ClientStatementScreen extends StatefulWidget {
  const ClientStatementScreen({super.key});

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _statementData = [];
  List<Map<String, dynamic>> _filteredData = []; // القائمة المعروضة بعد الفلترة

  int? _selectedClientId;
  double _finalBalance = 0; // الرصيد النهائي العام للعميل

  // متغيرات التاريخ
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // متغيرات ملخص الفترة
  double _periodSales = 0;
  double _periodReturns = 0;
  double _periodPaid = 0;

  // نوع العرض الحالي (الكل، فواتير، مرتجعات...)
  String _displayFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  void _loadClients() async {
    final data = await DatabaseHelper().getClients();
    setState(() {
      _clients = data;
    });
  }

  // تحميل الكشف بناءً على التاريخ
  void _loadStatement() async {
    if (_selectedClientId == null) return;

    // 1. جلب الرصيد الكلي الحالي للعميل (بغض النظر عن التاريخ)
    final totalBal = await DatabaseHelper().getClientCurrentBalance(
      _selectedClientId!,
    );

    // 2. جلب الحركات في الفترة المحددة
    final data = await DatabaseHelper().getClientStatement(
      _selectedClientId!,
      startDate: _startDate,
      endDate: _endDate,
    );

    double pSales = 0;
    double pReturns = 0;
    double pPaid = 0;

    for (var item in data) {
      double amount = (item['amount'] as num).toDouble();
      String type = item['type'];

      if (type == 'sale') {
        pSales += amount;
      } else if (type == 'return') {
        pReturns += amount;
      } else if (type == 'payment') {
        pPaid += amount;
      }
    }

    setState(() {
      _statementData = data;
      _finalBalance = totalBal;
      _periodSales = pSales;
      _periodReturns = pReturns;
      _periodPaid = pPaid;
      _applyLocalFilter(); // تطبيق فلتر النوع (فواتير/مرتجعات...)
    });
  }

  // فلترة القائمة محلياً (لترتيب الفواتير تحت بعضها الخ)
  void _applyLocalFilter() {
    if (_displayFilter == 'all') {
      _filteredData = List.from(_statementData);
    } else if (_displayFilter == 'sales') {
      _filteredData = _statementData.where((i) => i['type'] == 'sale').toList();
    } else if (_displayFilter == 'returns') {
      _filteredData = _statementData
          .where((i) => i['type'] == 'return')
          .toList();
    } else if (_displayFilter == 'payments') {
      _filteredData = _statementData
          .where((i) => i['type'] == 'payment' || i['type'] == 'refund_payment')
          .toList();
    }
  }

  // اختيار التاريخ
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

  // --- التفاصيل والدفع (كما هي) ---
  void _showTransactionDetails(Map<String, dynamic> item) async {
    if (item['type'] != 'sale') return;
    final db = await DatabaseHelper().database;
    final saleDataList = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [item['id']],
    );
    if (saleDataList.isEmpty) return;
    final saleData = saleDataList.first;
    final items = await DatabaseHelper().getSaleItems(item['id']);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'تفاصيل الفاتورة #${item['id']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(items[i]['productName']),
                  subtitle: Text(
                    '${items[i]['quantity']} × ${items[i]['price']}',
                  ),
                  trailing: Text(
                    '${(items[i]['quantity'] * items[i]['price'])} ج.م',
                  ),
                ),
              ),
            ),
            const Divider(),
            Text(
              'الصافي: ${saleData['netAmount']} ج.م',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    if (_selectedClientId == null) return;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isNotEmpty) {
                await DatabaseHelper().addReceipt(
                  _selectedClientId!,
                  double.parse(amountController.text),
                  notesController.text,
                  DateTime.now().toString(),
                );
                Navigator.pop(context);
                _loadStatement();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('كشف حسابات العملاء')),
      body: Column(
        children: [
          // 1. اختيار العميل
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: DropdownButtonFormField(
              decoration: InputDecoration(
                labelText: 'اختر العميل',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
              ),
              items: _clients
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'],
                      child: Text(c['name']),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedClientId = val as int?);
                _loadStatement();
              },
            ),
          ),

          // 2. فلاتر التاريخ (مثل الموردين)
          if (_selectedClientId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: isDark ? Colors.black12 : Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "من:",
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              _startDate.toString().split(' ')[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "إلى:",
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              _endDate.toString().split(' ')[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. ملخص الفترة والرصيد الحالي
          if (_selectedClientId != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _buildStatCard(
                    "مبيعات الفترة",
                    _periodSales,
                    Colors.orange,
                    isDark,
                  ),
                  const SizedBox(width: 5),
                  _buildStatCard(
                    "مدفوعات الفترة",
                    _periodPaid,
                    Colors.green,
                    isDark,
                  ),
                  const SizedBox(width: 5),
                  _buildStatCard(
                    "الرصيد النهائي",
                    _finalBalance,
                    _finalBalance > 0 ? Colors.red : Colors.green,
                    isDark,
                    isBold: true,
                  ),
                ],
              ),
            ),

            // 4. أزرار التنظيم (التابات)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _buildFilterChip('الكل', 'all'),
                  _buildFilterChip('فواتير المبيعات', 'sales'),
                  _buildFilterChip('المرتجعات', 'returns'),
                  _buildFilterChip('الدفعات المالية', 'payments'),
                ],
              ),
            ),
            const Divider(),
          ],

          // 5. القائمة
          Expanded(
            child: _selectedClientId == null
                ? const Center(child: Text("الرجاء اختيار عميل"))
                : _filteredData.isEmpty
                ? const Center(child: Text("لا توجد بيانات في هذه الفترة"))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _filteredData.length,
                    itemBuilder: (context, index) {
                      final item = _filteredData[index];
                      return _buildTransactionCard(item, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedClientId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showPaymentDialog(),
              label: const Text(
                'تسجيل دفعة',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add_card, color: Colors.white),
              backgroundColor: Colors.teal,
            )
          : null,
    );
  }

  // ويدجت الكارت الصغير للإحصائيات
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
              "${value.toStringAsFixed(1)}",
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

  // ويدجت زر الفلتر
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
        selectedColor: Colors.teal,
        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      ),
    );
  }

  // تصميم كارت المعاملة في القائمة
  Widget _buildTransactionCard(Map<String, dynamic> item, bool isDark) {
    IconData icon;
    Color color;
    String typeLabel;

    if (item['type'] == 'sale') {
      icon = Icons.shopping_cart;
      color = Colors.orange;
      typeLabel = "فاتورة";
    } else if (item['type'] == 'return') {
      icon = Icons.assignment_return;
      color = Colors.purple;
      typeLabel = "مرتجع";
    } else if (item['type'] == 'payment') {
      icon = Icons.attach_money;
      color = Colors.green;
      typeLabel = "دفعة";
    } else {
      icon = Icons.account_balance;
      color = Colors.blue;
      typeLabel = "رصيد/أخرى";
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: item['type'] == 'sale'
            ? () => _showTransactionDetails(item)
            : null,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item['description'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              "${item['amount'].toStringAsFixed(1)} ج.م",
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        subtitle: Text(
          "${item['date'].toString().split(' ')[0]}  •  $typeLabel",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: item['type'] == 'sale'
            ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
            : null,
      ),
    );
  }
}
