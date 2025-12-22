import 'package:flutter/material.dart';
import 'db_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  double _totalExpenses = 0.0;

  // قائمة تصنيفات المصاريف الثابتة (لتسهيل الاختيار)
  final List<String> _categories = [
    'رواتب وأجور',
    'إيجار',
    'كهرباء ومياه',
    'إنترنت واتصالات',
    'صيانة',
    'نقل ومواصلات',
    'تسويق وإعلانات',
    'نثريات',
    'بضاعة تالفة',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() async {
    final data = await DatabaseHelper().getExpenses();

    double total = 0;
    for (var item in data) {
      total += (item['amount'] as num).toDouble();
    }

    setState(() {
      _expenses = data;
      _totalExpenses = total;
      _isLoading = false;
    });
  }

  // دالة مساعدة لاختيار أيقونة مناسبة لكل تصنيف
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'رواتب وأجور':
        return Icons.people;
      case 'إيجار':
        return Icons.home_work;
      case 'كهرباء ومياه':
        return Icons.electric_bolt;
      case 'إنترنت واتصالات':
        return Icons.wifi;
      case 'صيانة':
        return Icons.build;
      case 'نقل ومواصلات':
        return Icons.local_shipping;
      case 'تسويق وإعلانات':
        return Icons.campaign;
      case 'نثريات':
        return Icons.coffee;
      case 'بضاعة تالفة':
        return Icons.broken_image;
      default:
        return Icons.attach_money;
    }
  }

  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = _categories[0];
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (_) {
        // نستخدم StatefulBuilder داخل الديالوج لتحديث الحالة (مثل التاريخ والنوع)
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              title: const Text('تسجيل مصروف جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // المبلغ
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // عنوان المصروف
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'بند الصرف (وصف مختصر)',
                        hintText: 'مثال: فاتورة كهرباء شهر 5',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // التصنيف (Dropdown)
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        setStateSB(() => selectedCategory = val!);
                      },
                    ),
                    const SizedBox(height: 10),

                    // التاريخ
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: isDark
                                    ? const ColorScheme.dark(
                                        primary: Colors.red,
                                      )
                                    : const ColorScheme.light(
                                        primary: Colors.red,
                                      ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setStateSB(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
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

                    // ملاحظات
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية',
                        prefixIcon: Icon(Icons.note),
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
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (amountController.text.isNotEmpty &&
                        titleController.text.isNotEmpty) {
                      await DatabaseHelper().insertExpense({
                        'title': titleController.text,
                        'amount': double.tryParse(amountController.text) ?? 0.0,
                        'category': selectedCategory,
                        'date': selectedDate.toString(),
                        'notes': notesController.text,
                      });

                      Navigator.pop(context);
                      _loadExpenses(); // تحديث القائمة
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم تسجيل المصروف بنجاح',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال المبلغ والوصف'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteExpense(int id) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: const Text('هل أنت متأكد من الحذف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper().deleteExpense(id);
              _loadExpenses();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المصروفات'),
        // تم الاعتماد على الثيم الرئيسي للألوان
      ),
      body: Column(
        children: [
          // --- كارت الملخص العلوي ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              // تدرج لوني أحمر للمصاريف
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.red[900]!, Colors.red[700]!]
                    : [Colors.red[700]!, Colors.red[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'إجمالي المصروفات المسجلة',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_totalExpenses.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // --- قائمة المصروفات ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.money_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'لا توجد مصروفات مسجلة',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final item = _expenses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.red.withOpacity(0.2)
                                : Colors.red[50],
                            child: Icon(
                              _getCategoryIcon(item['category']),
                              color: isDark ? Colors.red[200] : Colors.red[800],
                            ),
                          ),
                          title: Text(
                            item['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['category']} • ${item['date'].toString().split(' ')[0]}',
                              ),
                              if (item['notes'] != null &&
                                  item['notes'].toString().isNotEmpty)
                                Text(
                                  'ملاحظة: ${item['notes']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '-${item['amount']} ج.م',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => _deleteExpense(item['id']),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        label: const Text('تسجيل مصروف', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.red[700],
      ),
    );
  }
}
