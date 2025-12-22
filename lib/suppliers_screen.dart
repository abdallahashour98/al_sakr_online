import 'package:flutter/material.dart';
import 'db_helper.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // 1️⃣ استخدام كونترولر للرصيد الافتتاحي
  final TextEditingController _openingBalanceController =
      TextEditingController();

  final TextEditingController _searchController = TextEditingController();

  // نوع الرصيد (لك / عليك)
  String _balanceType = 'debit';

  @override
  void initState() {
    super.initState();
    _refreshSuppliers();
  }

  void _refreshSuppliers() async {
    final data = await DatabaseHelper().getSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = data;
        _filteredSuppliers = data;
      });
    }
  }

  void _runFilter(String keyword) {
    List<Map<String, dynamic>> results = [];
    if (keyword.isEmpty) {
      results = _suppliers;
    } else {
      results = _suppliers.where((s) {
        final name = s['name'].toString().toLowerCase();
        final code = s['code']?.toString().toLowerCase() ?? '';
        final input = keyword.toLowerCase();
        return name.contains(input) || code.contains(input);
      }).toList();
    }
    setState(() {
      _filteredSuppliers = results;
    });
  }

  void _clearControllers() {
    _codeController.clear();
    _nameController.clear();
    _contactPersonController.clear();
    _phoneController.clear();
    _addressController.clear();
    _notesController.clear();
    _openingBalanceController.text = '0';
    _balanceType = 'debit';
  }

  // 2️⃣ الدالة بقت async عشان نجيب الرصيد الافتتاحي
  void _showSupplierDialog({Map<String, dynamic>? supplier}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _clearControllers(); // تصفير الأول

    if (supplier != null) {
      _codeController.text = supplier['code'] ?? '';
      _nameController.text = supplier['name'];
      _contactPersonController.text = supplier['contactPerson'] ?? '';
      _phoneController.text = supplier['phone'] ?? '';
      _addressController.text = supplier['address'] ?? '';
      _notesController.text = supplier['notes'] ?? '';

      // 🔥 جلب الرصيد الافتتاحي المسجل لهذا المورد
      double opBalance = await DatabaseHelper().getSupplierOpeningBalance(
        supplier['id'],
      );

      // تحديد القيمة والنوع (دائن/مدين) بناءً على الرقم
      _openingBalanceController.text = opBalance.abs().toString();
      // لو موجب يبقى علينا (debit)، لو سالب يبقى لنا (credit) حسب منطق الكود بتاعك
      _balanceType = opBalance >= 0 ? 'debit' : 'credit';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text(
                supplier == null ? 'إضافة مورد جديد' : 'تعديل بيانات المورد',
                style: TextStyle(
                  color: isDark ? Colors.blue[200] : Colors.blue[900],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. الكود والاسم
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'كود المورد',
                              prefixIcon: Icon(Icons.qr_code),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم المورد/الشركة',
                              prefixIcon: Icon(Icons.business),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 2. المسئول والتليفون
                    TextField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المسئول',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'التليفون / الموبايل',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),

                    // 3. العنوان والملاحظات
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),

                    const Divider(height: 30),

                    // 4. الرصيد الافتتاحي (يظهر الآن في الإضافة والتعديل)
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          supplier == null
                              ? 'الرصيد الافتتاحي (بداية التعامل)'
                              : 'تعديل الرصيد الافتتاحي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _openingBalanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'المبلغ',
                              icon: const Icon(Icons.account_balance_wallet),
                              filled: true,
                              fillColor: _balanceType == 'debit'
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile(
                            title: const Text(
                              'لنا (دائن)', // بالسالب
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'credit',
                            groupValue: _balanceType,
                            activeColor: Colors.green,
                            onChanged: (val) =>
                                setStateSB(() => _balanceType = val.toString()),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile(
                            title: const Text(
                              'علينا (مدين)', // بالموجب
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'debit',
                            groupValue: _balanceType,
                            activeColor: Colors.red,
                            onChanged: (val) =>
                                setStateSB(() => _balanceType = val.toString()),
                          ),
                        ),
                      ],
                    ),
                    if (supplier != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          "تنبيه: تعديل هذا الرقم سيقوم بتعديل رصيد المورد الحالي بالفرق.",
                          style: TextStyle(fontSize: 10, color: Colors.orange),
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
                    backgroundColor: isDark
                        ? Colors.blue[800]
                        : Colors.blue[900],
                  ),
                  onPressed: () async {
                    if (_nameController.text.isEmpty) return;

                    // 3️⃣ تجهيز قيمة الرصيد الافتتاحي الجديدة
                    double opAmount =
                        double.tryParse(_openingBalanceController.text) ?? 0.0;
                    if (_balanceType == 'credit') opAmount = -opAmount;

                    if (supplier == null) {
                      // --- حالة الإضافة ---
                      // 1. نضيف المورد برصيد صفر مبدئياً
                      int newId = await DatabaseHelper().insertSupplier({
                        'code': _codeController.text,
                        'name': _nameController.text,
                        'contactPerson': _contactPersonController.text,
                        'phone': _phoneController.text,
                        'address': _addressController.text,
                        'notes': _notesController.text,
                        'balance': 0.0,
                      });

                      // 2. نسجل الرصيد الافتتاحي (وده هيسمع في الرصيد الكلي)
                      await DatabaseHelper().updateSupplierOpeningBalance(
                        newId,
                        opAmount,
                      );
                    } else {
                      // --- حالة التعديل ---
                      // 1. نحدث البيانات النصية
                      await DatabaseHelper().updateSupplier({
                        'id': supplier['id'],
                        'code': _codeController.text,
                        'name': _nameController.text,
                        'contactPerson': _contactPersonController.text,
                        'phone': _phoneController.text,
                        'address': _addressController.text,
                        'notes': _notesController.text,
                        // لاحظ: مبنبعتش balance هنا عشان ميصفرش الرصيد الحالي
                      });

                      // 2. نحدث الرصيد الافتتاحي (السيستم هيحسب الفرق ويعدل الرصيد الحالي)
                      await DatabaseHelper().updateSupplierOpeningBalance(
                        supplier['id'],
                        opAmount,
                      );
                    }

                    _clearControllers();
                    if (mounted) {
                      Navigator.pop(context);
                      _refreshSuppliers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الحفظ بنجاح')),
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

  void _deleteSupplier(int id) async {
    // يفضل التأكد قبل الحذف
    await DatabaseHelper().deleteSupplier(id);
    _refreshSuppliers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المورد'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الموردين والمخازن')),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _runFilter,
              decoration: InputDecoration(
                labelText: 'بحث بكود المورد أو الاسم...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _runFilter('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
            ),
          ),

          Expanded(
            child: _filteredSuppliers.isEmpty
                ? const Center(child: Text('لا يوجد موردين مسجلين'))
                : ListView.builder(
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final s = _filteredSuppliers[index];
                      double bal = (s['balance'] as num).toDouble();
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.blue[100],
                            child: Text(
                              s['name'].isNotEmpty
                                  ? s['name'][0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.blue[100]
                                    : Colors.blue[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            s['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s['code'] != null &&
                                  s['code'].toString().isNotEmpty)
                                Text(
                                  'كود: ${s['code']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.blueGrey,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              Text(
                                'المسئول: ${s['contactPerson'] ?? '-'}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                'ت: ${s['phone']}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // عرض الرصيد
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${bal.abs().toStringAsFixed(1)} ج.م',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: bal > 0
                                          ? Colors
                                                .red // علينا (مدين)
                                          : (bal < 0
                                                ? Colors
                                                      .green // لنا (دائن)
                                                : Colors.grey),
                                    ),
                                  ),
                                  Text(
                                    bal > 0
                                        ? 'له (علينا)'
                                        : (bal < 0 ? 'لنا (مقدم)' : 'خالص'),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showSupplierDialog(supplier: s);
                                  }
                                  if (val == 'delete') _deleteSupplier(s['id']);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 10),
                                        Text('تعديل'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 10),
                                        Text('حذف'),
                                      ],
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(),
        label: const Text('إضافة مورد', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_business, color: Colors.white),
        backgroundColor: Colors.blue[900],
      ),
    );
  }
}
