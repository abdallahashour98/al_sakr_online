import 'package:al_sakr/services/auth_service.dart';
import 'package:al_sakr/services/purchases_service.dart';
import 'package:al_sakr/services/sales_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/pb_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // لم نعد بحاجة لقائمة _expenses اليدوية ولا _isLoading ولا _totalExpenses كمتغيرات حالة
  // سيتم حسابهم لحظياً داخل الـ StreamBuilder

  bool _canAdd = false;
  bool _canDelete = false;
  final String _superAdminId = "1sxo74splxbw1yh";

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
    _loadPermissions();
    // _loadExpenses(); // ❌ تم إلغاؤها لأننا نستخدم Stream
  }

  Future<void> _loadPermissions() async {
    final myId = SalesService().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canAdd = true;
          _canDelete = true;
        });
      return;
    }

    try {
      final userRecord = await AuthService().pb
          .collection('users')
          .getOne(myId);
      if (mounted) {
        setState(() {
          _canAdd = userRecord.data['allow_add_expenses'] ?? false;
          _canDelete = userRecord.data['allow_delete_expenses'] ?? false;
        });
      }
    } catch (e) {
      //
    }
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
    if (!_canAdd) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية التعديل')));
      return;
    }

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

  void _showExpenseDialog({Map<String, dynamic>? expenseToEdit}) {
    if (expenseToEdit == null && !_canAdd) return;
    if (expenseToEdit != null && !_canAdd) return;

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
    DateTime selectedDate = isEditing && expenseToEdit['date'] != null
        ? DateTime.parse(expenseToEdit['date'])
        : DateTime.now();

    if (!_categories.contains(selectedCategory)) {
      _categories.add(selectedCategory);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth > 600 ? 500 : screenWidth * 0.95;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 20,
              ),
              child: Container(
                width: dialogWidth,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEditing ? 'تعديل مصروف' : 'تسجيل مصروف جديد',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. المبلغ (الأول)
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d*'),
                          ),
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'المبلغ *',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : null,
                          ),
                          prefixIcon: Icon(
                            Icons.money,
                            color: isDark ? Colors.grey[400] : null,
                          ),
                          border: const OutlineInputBorder(),
                          hintText: "0.00",
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF383838)
                              : Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. التصنيف
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedCategory,
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? const Color(0xFF333333)
                                  : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'التصنيف',
                                labelStyle: TextStyle(
                                  color: isDark ? Colors.grey[400] : null,
                                ),
                                prefixIcon: Icon(
                                  Icons.category,
                                  color: isDark ? Colors.grey[400] : null,
                                ),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 15,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF383838)
                                    : Colors.grey[50],
                              ),
                              items: _categories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(
                                    cat,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setStateSB(() => selectedCategory = val!);
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF383838)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showManageCategoriesDialog(setStateSB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. بند الصرف
                      TextField(
                        controller: titleController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'بند الصرف (اختياري)',
                          hintText: 'وصف المصروف',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : null,
                          ),
                          prefixIcon: Icon(
                            Icons.title,
                            color: isDark ? Colors.grey[400] : null,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF383838)
                              : Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4. التاريخ
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (c, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: isDark
                                    ? const ColorScheme.dark(
                                        primary: Colors.red,
                                        onPrimary: Colors.white,
                                        surface: Color(0xFF424242),
                                        onSurface: Colors.white,
                                      )
                                    : const ColorScheme.light(
                                        primary: Colors.red,
                                      ),
                                dialogTheme: DialogThemeData(
                                  backgroundColor: isDark
                                      ? const Color(0xFF424242)
                                      : Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null)
                            setStateSB(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF383838)
                                : Colors.grey[50],
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                color: isDark ? Colors.grey : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 5. ملاحظات
                      TextField(
                        controller: notesController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'ملاحظات إضافية',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : null,
                          ),
                          prefixIcon: Icon(
                            Icons.note,
                            color: isDark ? Colors.grey[400] : null,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF383838)
                              : Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEditing
                                    ? Colors.blue
                                    : Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                if (amountController.text.isNotEmpty) {
                                  String finalTitle = titleController.text
                                      .trim();

                                  try {
                                    if (isEditing) {
                                      await PurchasesService()
                                          .updateExpense(expenseToEdit['id'], {
                                            'title': finalTitle,
                                            'amount':
                                                double.tryParse(
                                                  amountController.text,
                                                ) ??
                                                0.0,
                                            'category': selectedCategory,
                                            'date': selectedDate
                                                .toIso8601String(),
                                            'notes': notesController.text,
                                          });
                                    } else {
                                      await PurchasesService().insertExpense({
                                        'title': finalTitle,
                                        'amount':
                                            double.tryParse(
                                              amountController.text,
                                            ) ??
                                            0.0,
                                        'category': selectedCategory,
                                        'date': selectedDate.toIso8601String(),
                                        'notes': notesController.text,
                                      });
                                    }
                                    Navigator.pop(context);
                                    // _loadExpenses(); // ❌ لا حاجة لها مع Stream
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEditing
                                              ? 'تم تعديل المصروف بنجاح'
                                              : 'تم تسجيل المصروف بنجاح',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('خطأ: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteExpense(String id) async {
    if (!_canDelete) return;

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
              await PurchasesService().deleteExpense(id);
              // _loadExpenses(); // ❌ لا حاجة لها مع Stream
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
      // ✅ استخدام StreamBuilder للبيانات الحية (Real-time)
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: PBHelper().getCollectionStream('expenses', sort: '-created'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ في تحميل البيانات"));
          }

          final expensesList = snapshot.data ?? [];

          // ✅ حساب الإجمالي تلقائياً من البيانات الواردة
          double totalExpenses = expensesList.fold(
            0.0,
            (sum, item) => sum + (item['amount'] as num).toDouble(),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
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
                          '${totalExpenses.toStringAsFixed(2)} ج.م',
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
                    child: expensesList.isEmpty
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
                            padding: const EdgeInsets.only(
                              left: 15,
                              right: 15,
                              top: 0,
                              bottom: 100,
                            ),
                            itemCount: expensesList.length,
                            itemBuilder: (context, index) {
                              final item = expensesList[index];

                              String titleToShow =
                                  item['title'].toString().isEmpty
                                  ? item['category']
                                  : item['title'];

                              bool isTitleSameAsCategory =
                                  (item['title'].toString().isEmpty ||
                                  item['title'] == item['category']);
                              String datePart = item['date'].toString().split(
                                ' ',
                              )[0];

                              String subtitleText = isTitleSameAsCategory
                                  ? datePart
                                  : '${item['category']} • $datePart';

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
                                      color: isDark
                                          ? Colors.red[200]
                                          : Colors.red[800],
                                    ),
                                  ),
                                  title: Text(
                                    titleToShow,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(subtitleText),
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
                                      const SizedBox(width: 5),
                                      if (_canAdd)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          onPressed: () => _showExpenseDialog(
                                            expenseToEdit: item,
                                          ),
                                        ),
                                      if (_canDelete)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _deleteExpense(item['id']),
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
            ),
          );
        },
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _showExpenseDialog(),
              label: const Text(
                'تسجيل مصروف',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.red[700],
            )
          : null,
    );
  }
}
