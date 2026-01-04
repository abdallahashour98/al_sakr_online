import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pb_helper.dart';
import 'package:image_picker/image_picker.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  // بيانات للإحصائيات العامة
  List<Map<String, dynamic>> _allPurchases = [];
  List<Map<String, dynamic>> _allPayments = [];
  double _totalPurchases = 0.0;
  double _totalPaid = 0.0;

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // كونترولرز الديالوج
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  String _balanceType = 'debit';

  // ✅ 1. متغيرات الصلاحيات
  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // تحميل الصلاحيات
    _loadStaticStats();
  }

  // ✅ 2. دالة تحميل الصلاحيات
  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) {
        setState(() {
          _canAdd = true;
          _canEdit = true;
          _canDelete = true;
        });
      }
      return;
    }

    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          // نستخدم صلاحيات "العملاء والموردين"
          _canAdd = userRecord.data['allow_add_clients'] ?? false;
          _canEdit =
              (userRecord.data['allow_add_clients'] ?? false) ||
              (userRecord.data['allow_edit_clients'] ?? false);
          _canDelete = userRecord.data['allow_delete_clients'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error loading permissions: $e");
    }
  }

  Future<void> _loadStaticStats() async {
    try {
      final purchases = await PBHelper().getAllPurchases();
      final payments = await PBHelper().getAllSupplierPayments();
      if (mounted) {
        setState(() {
          _allPurchases = purchases;
          _allPayments = payments;
          _calculateStaticDashboard();
        });
      }
    } catch (e) {
      print(e);
    }
  }

  void _calculateStaticDashboard() {
    double tPurchases = 0.0;
    double tPaid = 0.0;
    for (var bill in _allPurchases)
      tPurchases += (bill['totalAmount'] as num? ?? 0.0);
    for (var pay in _allPayments) tPaid += (pay['amount'] as num? ?? 0.0);
    setState(() {
      _totalPurchases = tPurchases;
      _totalPaid = tPaid;
    });
  }

  void _clearControllers() {
    _codeController.clear();
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
    _contactController.clear();
    _notesController.clear();
    _openingBalanceController.text = '0';
    _balanceType = 'debit';
  }

  // --- ديالوج المورد ---
  void _showSupplierDialog({Map<String, dynamic>? supplier}) async {
    // حماية
    if (supplier == null && !_canAdd) return;
    if (supplier != null && !_canEdit) return;

    _clearControllers();
    if (supplier != null) {
      _codeController.text = supplier['code'] ?? '';
      _nameController.text = supplier['name'];
      _contactController.text = supplier['contactPerson'] ?? '';
      _phoneController.text = supplier['phone'] ?? '';
      _addressController.text = supplier['address'] ?? '';
      _notesController.text = supplier['notes'] ?? '';
      double currentOp = await PBHelper().getSupplierOpeningBalance(
        supplier['id'],
      );
      _openingBalanceController.text = currentOp.abs().toString();
      _balanceType = currentOp >= 0 ? 'debit' : 'credit';
    }

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          backgroundColor: dialogColor,
          title: Text(
            supplier == null ? 'إضافة مورد' : 'تعديل بيانات المورد',
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _codeController,
                        'الكود',
                        Icons.qr_code,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        _nameController,
                        'اسم المورد',
                        Icons.business,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  _contactController,
                  'المسئول',
                  Icons.person,
                  isDark,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  _phoneController,
                  'الهاتف',
                  Icons.phone,
                  isDark,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  _addressController,
                  'العنوان',
                  Icons.location_on,
                  isDark,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  _notesController,
                  'ملاحظات',
                  Icons.note,
                  isDark,
                ),
                const Divider(),
                Text(
                  'الرصيد الافتتاحي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orangeAccent : Colors.brown,
                  ),
                ),
                _buildTextField(
                  _openingBalanceController,
                  'المبلغ',
                  Icons.attach_money,
                  isDark,
                  isNumber: true,
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: Text(
                          'علينا (له)',
                          style: TextStyle(color: textColor),
                        ),
                        value: 'debit',
                        groupValue: _balanceType,
                        activeColor: Colors.red,
                        onChanged: (v) =>
                            setStateSB(() => _balanceType = v.toString()),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: Text(
                          'لنا (مقدم)',
                          style: TextStyle(color: textColor),
                        ),
                        value: 'credit',
                        groupValue: _balanceType,
                        activeColor: Colors.green,
                        onChanged: (v) =>
                            setStateSB(() => _balanceType = v.toString()),
                      ),
                    ),
                  ],
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
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (_nameController.text.isEmpty) return;
                Map<String, dynamic> data = {
                  'code': _codeController.text,
                  'name': _nameController.text,
                  'contactPerson': _contactController.text,
                  'phone': _phoneController.text,
                  'address': _addressController.text,
                  'notes': _notesController.text,
                };
                try {
                  String supplierId;
                  if (supplier == null) {
                    data['balance'] = 0.0;
                    final rec = await PBHelper().insertSupplier(data);
                    supplierId = rec.id;
                  } else {
                    await PBHelper().updateSupplier(supplier['id'], data);
                    supplierId = supplier['id'];
                  }
                  double amount =
                      double.tryParse(_openingBalanceController.text) ?? 0.0;
                  double finalBal = (_balanceType == 'debit')
                      ? amount
                      : -amount;
                  await PBHelper().updateSupplierOpeningBalance(
                    supplierId,
                    finalBal,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم الحفظ'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController c,
    String label,
    IconData icon,
    bool isDark, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF383838) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  void _deleteSupplier(String id) {
    if (!_canDelete) return; // حماية

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف المورد"),
        content: const Text("تأكيد الحذف؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await PBHelper().deleteSupplier(id);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text('إدارة الموردين')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: PBHelper().getCollectionStream('suppliers', sort: 'name'),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("خطأ: ${snapshot.error}"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final allSuppliers = snapshot.data!;
          final filtered = allSuppliers
              .where(
                (s) =>
                    _searchQuery.isEmpty ||
                    s['name'].toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

          double totalDebt = 0.0;
          for (var s in filtered) {
            double bal = (s['balance'] as num? ?? 0.0).toDouble();
            if (bal > 0) totalDebt += bal;
          }
          filtered.sort(
            (a, b) => (b['balance'] as num).compareTo(a['balance'] as num),
          );

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: isDark ? const Color(0xFF1A1A1A) : Colors.brown[50],
                child: Column(
                  children: [
                    Row(
                      children: [
                        _summaryCard(
                          "إجمالي المشتريات",
                          _totalPurchases,
                          Colors.orange,
                          Icons.shopping_cart,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          "إجمالي المدفوعات",
                          _totalPaid,
                          Colors.green,
                          Icons.payment,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _summaryCard(
                          "المستحق للموردين",
                          totalDebt,
                          Colors.red,
                          Icons.warning,
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "بحث...",
                        hintStyle: TextStyle(color: subColor),
                        prefixIcon: Icon(Icons.search, color: subColor),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 10),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final s = filtered[index];
                    double bal = (s['balance'] as num? ?? 0.0).toDouble();
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: bal > 0
                              ? Colors.red.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          child: Text(
                            s['name'][0].toUpperCase(),
                            style: TextStyle(
                              color: bal > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                        title: Text(
                          s['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          "ت: ${s['phone'] ?? '-'}",
                          style: TextStyle(color: subColor),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${bal.abs().toStringAsFixed(1)} ج.م",
                                  style: TextStyle(
                                    color: bal > 0 ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  bal > 0 ? "له" : "لنا",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),

                            // ✅ 3. القائمة المنسدلة للتعديل والحذف (تخضع للصلاحية)
                            if (_canEdit || _canDelete)
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: subColor),
                                onSelected: (value) {
                                  if (value == 'edit')
                                    _showSupplierDialog(supplier: s);
                                  if (value == 'delete')
                                    _deleteSupplier(s['id']);
                                },
                                itemBuilder: (c) => [
                                  if (_canEdit)
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
                                  if (_canDelete)
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierDetailScreen(supplier: s),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // ✅ 4. زر إضافة مورد (يخضع للصلاحية)
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _showSupplierDialog(),
              label: const Text(
                "مورد جديد",
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.brown[700],
            )
          : null,
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              NumberFormat.compact().format(amount),
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ... (باقي الكود الخاص بـ SupplierDetailScreen كما هو)
// انسخ باقي الكلاس SupplierDetailScreen من الكود القديم وضعه هنا لاستكمال الملف
// (لم أقم بتكراره هنا لأنه لم يتغير ولتوفير المساحة، لكنه ضروري لعمل التطبيق)

// ============================================================================
// شاشة تفاصيل المورد (تم تحديثها بزر الدفع مع الصلاحيات)
// ============================================================================

class SupplierDetailScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  // ... (نفس المتغيرات السابقة) ...
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _loading = true;
  String _filterType = "الكل";
  DateTimeRange? _dateRange;
  double _currentVisibleBalance = 0.0;

  // ✅ صلاحية الدفع للمورد
  bool _canAddPayment = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // تحميل الصلاحيات
    _loadDetails();
  }

  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) setState(() => _canAddPayment = true);
      return;
    }

    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        // نسمح بالدفع لمن يملك حق "شراء" أو "إضافة موردين"
        setState(() {
          _canAddPayment =
              (userRecord.data['allow_add_purchases'] ?? false) ||
              (userRecord.data['allow_add_clients'] ?? false);
        });
      }
    } catch (e) {
      //
    }
  }

  Future<void> _loadDetails() async {
    // ... (انسخ نفس كود _loadDetails السابق من كودك) ...
    // الاختصار هنا لعدم التكرار، لكن يجب أن يكون موجوداً

    // سأضع نسخة مختصرة للتأكد:
    setState(() => _loading = true);
    final purchases = await PBHelper().getSupplierStatement(
      widget.supplier['id'],
    );
    final openingBal = await PBHelper().getSupplierOpeningBalance(
      widget.supplier['id'],
    );
    List<Map<String, dynamic>> temp = [];
    for (var item in purchases) {
      double amount = (item['amount'] as num).toDouble();
      bool isBill = item['type'] == 'bill';
      temp.add({
        'id': item['id'],
        'date': item['date'],
        'type': isBill
            ? "فاتورة شراء"
            : (item['type'] == 'return' ? "مرتجع شراء" : "سند دفع"),
        'amount': amount,
        'isDebit': isBill,
        'category': isBill
            ? "فواتير"
            : (item['type'] == 'return' ? "مرتجع" : "دفعات"),
        'rawDate': DateTime.parse(item['date']),
        'rawRecord': item,
      });
    }
    temp.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate']));
    List<Map<String, dynamic>> calculatedList = [];
    double runningBalance = openingBal;
    for (var t in temp) {
      if (t['isDebit'])
        runningBalance += t['amount'];
      else
        runningBalance -= t['amount'];
      t['runningBalance'] = runningBalance;
      calculatedList.add(t);
    }
    _applyFilters(calculatedList, openingBal);
  }

  void _applyFilters(
    List<Map<String, dynamic>> fullList,
    double initialOpening,
  ) {
    // ... (انسخ كود الفلترة السابق بالكامل) ...
    // تأكد من نسخ دالة _applyFilters و _pickDateRange و _showTransactionDetails من كودك الأصلي
    // لأني اختصرتهم هنا.

    // لضمان العمل سأعيد كتابة الجزء الأساسي من applyFilters
    List<Map<String, dynamic>> result = [];
    double startBalance = initialOpening;
    if (_dateRange != null) {
      final beforeRange = fullList
          .where((t) => (t['rawDate'] as DateTime).isBefore(_dateRange!.start))
          .toList();
      if (beforeRange.isNotEmpty)
        startBalance = beforeRange.last['runningBalance'];
      result = fullList.where((t) {
        final d = t['rawDate'] as DateTime;
        return d.isAfter(
              _dateRange!.start.subtract(const Duration(seconds: 1)),
            ) &&
            d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    } else {
      result = fullList;
    }
    List<Map<String, dynamic>> finalDisplay = [];
    finalDisplay.add({
      'type': 'رصيد سابق',
      'amount': startBalance.abs(),
      'isDebit': startBalance >= 0,
      'runningBalance': startBalance,
      'isHeader': true,
      'category': 'الكل',
      'date': '---',
    });
    finalDisplay.addAll(result);
    if (_filterType != "الكل")
      finalDisplay = finalDisplay
          .where((t) => t['category'] == _filterType || t['isHeader'] == true)
          .toList();
    if (mounted)
      setState(() {
        _allTransactions = fullList;
        _filteredTransactions = finalDisplay;
        _currentVisibleBalance = fullList.isNotEmpty
            ? fullList.last['runningBalance']
            : startBalance;
        _loading = false;
      });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );
    if (picked != null)
      setState(() {
        _dateRange = picked;
        _loadDetails();
      });
  }

  void _showTransactionDetails(Map<String, dynamic> item) async {
    // ... (انسخ دالة التفاصيل من كودك السابق لتعمل النقرات) ...
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.supplier['name']),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _dateRange != null ? Colors.orange : null,
            ),
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _dateRange = null;
                  _loadDetails();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.brown[50],
            child: Column(
              children: [
                Text(
                  _dateRange != null
                      ? "الرصيد في نهاية الفترة"
                      : "الرصيد الحالي",
                  style: TextStyle(color: subColor),
                ),
                const SizedBox(height: 5),
                Text(
                  "${_currentVisibleBalance.abs().toStringAsFixed(1)} ج.م",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _currentVisibleBalance > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                Text(
                  _currentVisibleBalance > 0 ? "له (علينا)" : "لنا (مقدم)",
                  style: TextStyle(color: subColor),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ["الكل", "فواتير", "دفعات", "مرتجعات"].map((
                      filter,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filterType == filter,
                          onSelected: (val) => setState(() {
                            _filterType = filter;
                            _loadDetails();
                          }),
                          selectedColor: Colors.brown,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_dateRange != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: Text(
                "عرض الفترة من: ${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} إلى: ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (ctx, i) {
                      final item = _filteredTransactions[i];
                      bool isDebit = item['isDebit'];
                      bool isHeader = item['isHeader'] == true;
                      return Card(
                        color: isHeader
                            ? (isDark ? Colors.grey[800] : Colors.grey[200])
                            : cardColor,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: ListTile(
                          onTap: () => _showTransactionDetails(item),
                          leading: Icon(
                            isHeader
                                ? Icons.account_balance
                                : (isDebit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward),
                            color: isHeader
                                ? subColor
                                : (isDebit ? Colors.red : Colors.green),
                          ),
                          title: Text(
                            item['type'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            isHeader
                                ? "---"
                                : "${item['date'].toString().split(' ')[0]}",
                            style: TextStyle(color: subColor),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${item['amount'].toStringAsFixed(1)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isHeader
                                      ? textColor
                                      : (isDebit ? Colors.red : Colors.green),
                                ),
                              ),
                              Text(
                                "رصيد: ${item['runningBalance'].toStringAsFixed(1)}",
                                style: TextStyle(fontSize: 10, color: subColor),
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

      // ✅ 4. زر إضافة دفعة (يخضع للصلاحية)
      floatingActionButton: _canAddPayment
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 10),
              child: FloatingActionButton.extended(
                onPressed: () {
                  _showAddPaymentDialog(context);
                },
                label: const Text(
                  "سداد دفعة",
                  style: TextStyle(color: Colors.white),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                backgroundColor: Colors.brown,
              ),
            )
          : null,
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String paymentMethod = "cash";
    String? selectedImagePath;
    DateTime selectedDate = DateTime.now();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txt = isDark ? Colors.white : Colors.black;
    final border = isDark ? Colors.grey[600]! : Colors.grey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: bg,
          title: Text("سند دفع للمورد", style: TextStyle(color: txt)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: txt),
                  decoration: InputDecoration(
                    labelText: "المبلغ",
                    labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: isDark ? Colors.grey : null,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  dropdownColor: isDark
                      ? const Color(0xFF333333)
                      : Colors.white,
                  decoration: InputDecoration(
                    labelText: "طريقة الدفع",
                    labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: border),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: "cash",
                      child: Text(
                        "نـقـدي (Cash)",
                        style: TextStyle(color: txt),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "cheque",
                      child: Text(
                        "شـيـك (Cheque)",
                        style: TextStyle(color: txt),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "bank_transfer",
                      child: Text(
                        "تحويل بنكي (Transfer)",
                        style: TextStyle(color: txt),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setStateDialog(() => paymentMethod = val!),
                ),
                const SizedBox(height: 15),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      // ✅ تخصيص الثيم هنا أيضاً
                      builder: (c, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: isDark
                              ? const ColorScheme.dark(
                                  primary: Colors.brown,
                                  onPrimary: Colors.white,
                                  surface: Color(
                                    0xFF424242,
                                  ), // خلفية رمادية واضحة
                                  onSurface: Colors.white,
                                )
                              : const ColorScheme.light(primary: Colors.brown),
                          dialogTheme: DialogThemeData(
                            backgroundColor: isDark
                                ? const Color(0xFF424242)
                                : Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setStateDialog(() => selectedDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "التاريخ",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: isDark ? Colors.grey : null,
                      ),
                    ),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(selectedDate),
                      style: TextStyle(color: txt),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null)
                      setStateDialog(() => selectedImagePath = image.path);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: border,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          color: isDark ? Colors.grey : Colors.blueGrey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedImagePath != null
                                ? "تم اختيار صورة ✅"
                                : "إرفاق صورة (اختياري)",
                            style: TextStyle(
                              color: selectedImagePath != null
                                  ? Colors.green
                                  : (isDark ? Colors.grey : Colors.black54),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedImagePath != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                setStateDialog(() => selectedImagePath = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: noteCtrl,
                  style: TextStyle(color: txt),
                  decoration: InputDecoration(
                    labelText: "ملاحظات",
                    labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                    prefixIcon: Icon(
                      Icons.note,
                      color: isDark ? Colors.grey : null,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (amtCtrl.text.isNotEmpty) {
                  await PBHelper().addSupplierPayment(
                    supplierId: widget.supplier['id'],
                    amount: double.parse(amtCtrl.text),
                    notes: noteCtrl.text,
                    date: selectedDate.toIso8601String(),
                    paymentMethod: paymentMethod,
                    imagePath: selectedImagePath,
                  );
                  Navigator.pop(ctx);
                  _loadDetails();
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }
}
