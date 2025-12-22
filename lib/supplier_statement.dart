import 'package:flutter/material.dart';
import 'db_helper.dart';

class SupplierStatementScreen extends StatefulWidget {
  const SupplierStatementScreen({super.key});

  @override
  State<SupplierStatementScreen> createState() =>
      _SupplierStatementScreenState();
}

class _SupplierStatementScreenState extends State<SupplierStatementScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _statementData = [];
  int? _selectedSupplierId;
  double _finalBalance = 0;

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

  void _loadStatement(int supplierId) async {
    final data = await DatabaseHelper().getSupplierStatement(supplierId);
    double billTotal = 0;
    double paidTotal = 0;

    for (var item in data) {
      double amount = (item['amount'] as num).toDouble();
      if (item['type'] == 'payment') {
        paidTotal += amount;
      } else {
        billTotal += amount;
      }
    }

    setState(() {
      _statementData = data;
      _finalBalance = billTotal - paidTotal;
    });
  }

  void _showInvoiceDetails(int invoiceId, String title) async {
    final items = await DatabaseHelper().getPurchaseItems(invoiceId);
    if (!mounted) return;

    // معرفة الوضع الحالي
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 500,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                // لون النص متجاوب
                color: isDark ? Colors.brown[200] : Colors.brown,
              ),
            ),
            const Divider(),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('لا توجد تفاصيل'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item['productName']),
                          subtitle: Text(
                            'سعر: ${item['costPrice']}',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Text(
                            '${(item['quantity'] * item['costPrice'])} ج.م',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black,
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.brown.withOpacity(0.2)
                                : Colors.brown[100],
                            child: Text(
                              '${item['quantity']}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.brown[100]
                                    : Colors.brown[800],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentDialog() {
    if (_selectedSupplierId == null) return;

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final refController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('تسجيل سند دفع لمورد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateSB(() => selectedDate = picked);
                        }
                      },
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
                              "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}",
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile(
                            title: const Text(
                              'كاش',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'cash',
                            groupValue: paymentMethod,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setStateSB(
                              () => paymentMethod = val.toString(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text(
                              'بنك',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'bank',
                            groupValue: paymentMethod,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setStateSB(
                              () => paymentMethod = val.toString(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text(
                              'شيك',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'check',
                            groupValue: paymentMethod,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setStateSB(
                              () => paymentMethod = val.toString(),
                            ),
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
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(),
                      ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                  ),
                  onPressed: () async {
                    if (amountController.text.isNotEmpty) {
                      String methodText = paymentMethod == 'cash'
                          ? 'نقدأ'
                          : (paymentMethod == 'bank' ? 'تحويل بنكي' : 'شيك');
                      String finalNotes =
                          "($methodText) ${refController.text} ${notesController.text}";

                      await DatabaseHelper().addSupplierPayment(
                        _selectedSupplierId!,
                        double.parse(amountController.text),
                        finalNotes,
                        selectedDate.toString(),
                      );
                      Navigator.pop(context);
                      _loadStatement(_selectedSupplierId!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ السند')),
                      );
                    }
                  },
                  child: const Text(
                    'حفظ',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePayment(int id, double amount) async {
    await DatabaseHelper().deleteSupplierPayment(
      id,
      _selectedSupplierId!,
      amount,
    );
    _loadStatement(_selectedSupplierId!);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حذف السند')));
  }

  @override
  Widget build(BuildContext context) {
    // التحقق من الوضع الليلي
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double runningBalance = 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('كشف حساب مورد')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField(
              decoration: const InputDecoration(
                labelText: 'اختر المورد',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
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
                if (_selectedSupplierId != null) {
                  _loadStatement(_selectedSupplierId!);
                }
              },
            ),
          ),

          if (_selectedSupplierId != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                // لون الخلفية متجاوب
                color: isDark
                    ? Colors.brown.withOpacity(0.15)
                    : Colors.brown[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.brown.withOpacity(0.5) : Colors.brown,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الرصيد المستحق:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_finalBalance.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      // لون النص متجاوب
                      color: isDark ? Colors.brown[200] : Colors.brown,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          Expanded(
            child: _statementData.isEmpty
                ? const Center(child: Text('لا توجد عمليات'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _statementData.length,
                    itemBuilder: (context, index) {
                      final item = _statementData[index];
                      final isBill = item['type'] == 'bill';
                      final amount = item['amount'];

                      // حساب الرصيد التراكمي (تقريبي للعرض)
                      if (isBill) {
                        runningBalance += amount;
                      } else {
                        runningBalance -= amount;
                      }

                      return Card(
                        child: ListTile(
                          onTap: isBill
                              ? () => _showInvoiceDetails(
                                  item['id'],
                                  item['description'],
                                )
                              : null,
                          leading: CircleAvatar(
                            backgroundColor: isBill
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            child: Icon(
                              isBill ? Icons.receipt_long : Icons.payment,
                              color: isBill ? Colors.orange : Colors.green,
                              size: 20,
                            ),
                          ),
                          title: Text(item['description']),
                          subtitle: Text(item['date'].toString().split(' ')[0]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${isBill ? "+" : "-"} $amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isBill
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'رصيد: ${runningBalance.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              if (!isBill)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _deletePayment(item['id'], amount),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedSupplierId != null
          ? FloatingActionButton.extended(
              onPressed: _showAddPaymentDialog,
              label: const Text(
                'سند دفع',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.money_off, color: Colors.white),
              backgroundColor: Colors.brown[700],
            )
          : null,
    );
  }
}
