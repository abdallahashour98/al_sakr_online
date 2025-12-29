import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 مهم عشان نتحكم في إدخال الأرقام
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

  // القائمة قابلة للتعديل
  List<String> _categories = [
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

  void _showManageCategoriesDialog(StateSetter updateParentState) {
    final newCategoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('إدارة التصنيفات'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCategoryController,
                          decoration: const InputDecoration(
                            hintText: 'تصنيف جديد...',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          if (newCategoryController.text.isNotEmpty) {
                            setState(() {
                              _categories.add(newCategoryController.text);
                            });
                            updateParentState(() {});
                            setStateDialog(() {});
                            newCategoryController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _categories.length,
                      itemBuilder: (c, i) => ListTile(
                        dense: true,
                        title: Text(_categories[i]),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_categories.length > 1) {
                              setState(() {
                                _categories.removeAt(i);
                              });
                              updateParentState(() {});
                              setStateDialog(() {});
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🆕 دالة موحدة للإضافة والتعديل
  // لو بعتنا expenseToEdit يبقى تعديل، لو null يبقى إضافة
  void _showExpenseDialog({Map<String, dynamic>? expenseToEdit}) {
    final isEditing = expenseToEdit != null;

    final titleController = TextEditingController(
      text: isEditing ? expenseToEdit['title'] : '',
    );
    final amountController = TextEditingController(
      text: isEditing ? expenseToEdit['amount'].toString() : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? expenseToEdit['notes'] : '',
    );

    String selectedCategory = isEditing
        ? expenseToEdit['category']
        : (_categories.isNotEmpty ? _categories[0] : 'أخرى');
    DateTime selectedDate = isEditing
        ? DateTime.parse(expenseToEdit['date'])
        : DateTime.now();

    // التأكد من وجود التصنيف
    if (!_categories.contains(selectedCategory)) {
      selectedCategory = _categories[0];
    }

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              title: Text(isEditing ? 'تعديل مصروف' : 'تسجيل مصروف جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // المبلغ (إجباري + أرقام فقط)
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ), // كيبورد أرقام
                      inputFormatters: [
                        // 🆕 السماح بالأرقام ونقطة واحدة فقط (للأرقام العشرية)
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'المبلغ *',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                        hintText: "0.00",
                      ),
                    ),
                    const SizedBox(height: 10),

                    // العنوان
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'بند الصرف (اختياري)',
                        hintText: 'اتركه فارغاً لاستخدام اسم التصنيف',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // التصنيف
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'التصنيف',
                              prefixIcon: Icon(Icons.category),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 15,
                              ),
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateSB(() => selectedCategory = val!);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _showManageCategoriesDialog(setStateSB),
                        ),
                      ],
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
                        );
                        if (picked != null)
                          setStateSB(() => selectedDate = picked);
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
                    backgroundColor: isEditing ? Colors.blue : Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (amountController.text.isNotEmpty) {
                      String finalTitle = titleController.text.isEmpty
                          ? selectedCategory
                          : titleController.text;

                      if (isEditing) {
                        // 🆕 منطق التعديل
                        await DatabaseHelper().updateExpense({
                          'id': expenseToEdit['id'], // مهم جداً الـ ID
                          'title': finalTitle,
                          'amount':
                              double.tryParse(amountController.text) ?? 0.0,
                          'category': selectedCategory,
                          'date': selectedDate.toString(),
                          'notes': notesController.text,
                        });
                      } else {
                        // منطق الإضافة
                        await DatabaseHelper().insertExpense({
                          'title': finalTitle,
                          'amount':
                              double.tryParse(amountController.text) ?? 0.0,
                          'category': selectedCategory,
                          'date': selectedDate.toString(),
                          'notes': notesController.text,
                        });
                      }

                      Navigator.pop(context);
                      _loadExpenses();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? 'تم تعديل المصروف بنجاح'
                                : 'تم تسجيل المصروف بنجاح',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال المبلغ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'حفظ التعديلات' : 'حفظ'),
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
      appBar: AppBar(title: const Text('إدارة المصروفات')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
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
                          // 🆕 أزرار التعديل والحذف
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
                              const SizedBox(width: 5),
                              // زر التعديل
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showExpenseDialog(expenseToEdit: item),
                              ),
                              // زر الحذف
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
        // عند الإضافة نرسل null
        onPressed: () => _showExpenseDialog(),
        label: const Text('تسجيل مصروف', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.red[700],
      ),
    );
  }
}
