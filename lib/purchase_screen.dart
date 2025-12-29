import 'dart:io';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  // --- المتغيرات ---
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _cart = [];
  List<String> _units = [];

  int? _selectedSupplierId;
  int? _selectedProductId;

  final TextEditingController _supplierSearchController =
      TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _refNumController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );

  DateTime _invoiceDate = DateTime.now();

  // إعدادات الفاتورة
  bool _isTaxEnabled = false; // 14%
  bool _isWhtEnabled = false; // 1%
  bool _isCashPayment = false; // المشتريات غالباً آجل

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final suppliers = await DatabaseHelper().getSuppliers();
    final products = await DatabaseHelper().getProducts();
    final unitsData = await DatabaseHelper().getUnits();

    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _products = products;
        _units = unitsData.map((u) => u['name'] as String).toList();
      });
    }
  }

  // --- الحسابات ---
  double get _subTotal {
    double sum = 0;
    for (var item in _cart) {
      sum += (item['total'] as num).toDouble();
    }
    return sum;
  }

  double get _discount => double.tryParse(_discountController.text) ?? 0.0;

  // الضريبة تضاف (14%)
  double get _taxAmount => _isTaxEnabled ? (_subTotal - _discount) * 0.14 : 0.0;

  // ضريبة الخصم 1% (تضاف للمبلغ)
  double get _whtAmount => _isWhtEnabled ? (_subTotal - _discount) * 0.01 : 0.0;

  // الإجمالي النهائي
  double get _grandTotal => (_subTotal - _discount) + _taxAmount - _whtAmount;

  // --- الصور ---
  Widget _buildProductImage(String? imagePath, {double size = 45}) {
    if (imagePath != null && File(imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/splash_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.shopping_bag, size: size, color: Colors.grey),
      ),
    );
  }

  // --- إضافة مورد ---
  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final balanceController = TextEditingController();
    bool isLiability = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: const Text('إضافة مورد جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المورد/الشركة',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const Divider(),
                const Text(
                  "الرصيد الافتتاحي",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text("علينا (له)"),
                        value: true,
                        groupValue: isLiability,
                        activeColor: Colors.red,
                        onChanged: (v) => setStateSB(() => isLiability = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text("لنا (عليه)"),
                        value: false,
                        groupValue: isLiability,
                        activeColor: Colors.green,
                        onChanged: (v) => setStateSB(() => isLiability = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  double amount =
                      double.tryParse(balanceController.text) ?? 0.0;
                  double finalBalance = isLiability ? amount : -amount;
                  int id = await DatabaseHelper().insertSupplier({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'balance': finalBalance,
                  });
                  if (amount > 0) {
                    await DatabaseHelper().updateSupplierOpeningBalance(
                      id,
                      finalBalance,
                    );
                  }
                  Navigator.pop(ctx);
                  await _loadData();
                  setState(() {
                    _selectedSupplierId = id;
                    _supplierSearchController.text = nameController.text;
                  });
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // --- إضافة صنف ---
  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final buyPriceController = TextEditingController();
    final sellPriceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    String selectedUnit = _units.isNotEmpty ? _units.first : 'قطعة';
    String? selectedImagePath;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: const Text('إضافة صنف جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      final appDir = await getApplicationSupportDirectory();
                      final fileName =
                          '${DateTime.now().millisecondsSinceEpoch}.jpg';
                      final saved = await File(
                        picked.path,
                      ).copy('${appDir.path}/$fileName');
                      setStateSB(() => selectedImagePath = saved.path);
                    }
                  },
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: selectedImagePath != null
                        ? FileImage(File(selectedImagePath!))
                        : null,
                    child: selectedImagePath == null
                        ? const Icon(Icons.add_a_photo)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الصنف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'كود',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رصيد',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: buyPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر الشراء',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: sellPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر البيع',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  int id = await DatabaseHelper().insertProduct({
                    'name': nameController.text,
                    'code': codeController.text,
                    'unit': selectedUnit,
                    'buyPrice': double.tryParse(buyPriceController.text) ?? 0.0,
                    'sellPrice':
                        double.tryParse(sellPriceController.text) ?? 0.0,
                    'stock': int.tryParse(stockController.text) ?? 0,
                    'imagePath': selectedImagePath,
                  });
                  Navigator.pop(ctx);
                  await _loadData();
                  setState(() {
                    _selectedProductId = id;
                    _productSearchController.text = nameController.text;
                    _costPriceController.text = buyPriceController.text;
                  });
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // --- البحث ---
  void _showSearchDialog({required bool isSupplier}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            var filteredList = isSupplier
                ? _suppliers
                      .where(
                        (s) => s['name'].toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList()
                : _products
                      .where(
                        (p) =>
                            p['name'].toLowerCase().contains(
                              query.toLowerCase(),
                            ) ||
                            (p['code'] ?? '').contains(query),
                      )
                      .toList();
            return AlertDialog(
              title: Text(isSupplier ? 'بحث عن مورد' : 'بحث عن صنف'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'بحث...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) => setStateSB(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        separatorBuilder: (c, i) => const Divider(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          if (isSupplier) {
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(item['name']),
                              onTap: () {
                                setState(() {
                                  _selectedSupplierId = item['id'];
                                  _supplierSearchController.text = item['name'];
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          } else {
                            return ListTile(
                              leading: _buildProductImage(item['imagePath']),
                              title: Text(item['name']),
                              subtitle: Text("مخزن: ${item['stock']}"),
                              trailing: Text(
                                "${item['buyPrice']}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedProductId = item['id'];
                                  _productSearchController.text = item['name'];
                                  _costPriceController.text = item['buyPrice']
                                      .toString();
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addToCart() {
    if (_selectedProductId == null ||
        _qtyController.text.isEmpty ||
        _costPriceController.text.isEmpty)
      return;
    final product = _products.firstWhere((p) => p['id'] == _selectedProductId);
    int qty = int.tryParse(_qtyController.text) ?? 0;
    double cost = double.tryParse(_costPriceController.text) ?? 0.0;
    if (qty <= 0) return;

    setState(() {
      _cart.add({
        'productId': product['id'],
        'name': product['name'],
        'price': cost,
        'quantity': qty,
        'total': (qty * cost).toDouble(),
      });
      _selectedProductId = null;
      _productSearchController.clear();
      _qtyController.clear();
      _costPriceController.clear();
    });
  }

  void _submitPurchase() async {
    if (_selectedSupplierId == null || _cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('البيانات ناقصة')));
      return;
    }

    await DatabaseHelper().createPurchase(
      _selectedSupplierId!,
      _grandTotal, // الإجمالي النهائي
      _cart,
      refNumber: _refNumController.text,
      customDate: _invoiceDate.toString(),
      taxAmount: _taxAmount,
      whtAmount: _whtAmount,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ الفاتورة بنجاح ✅'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.brown[300]! : Colors.brown[700]!;
    final blueColor = Colors.blue[800]!;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات (توريد)')),
      body: Column(
        children: [
          // 1. الجزء العلوي
          Card(
            margin: const EdgeInsets.all(10),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _supplierSearchController,
                          readOnly: true,
                          onTap: () => _showSearchDialog(isSupplier: true),
                          decoration: InputDecoration(
                            labelText: 'المورد',
                            prefixIcon: const Icon(Icons.local_shipping),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: _showAddSupplierDialog,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _invoiceDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _invoiceDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'التاريخ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(
                              "${_invoiceDate.year}-${_invoiceDate.month}-${_invoiceDate.day}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _refNumController,
                    decoration: const InputDecoration(
                      labelText: 'رقم المرجع (فاتورة المورد)',
                      prefixIcon: Icon(Icons.receipt),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _productSearchController,
                          readOnly: true,
                          onTap: () => _showSearchDialog(isSupplier: false),
                          decoration: InputDecoration(
                            labelText: 'الصنف',
                            prefixIcon: const Icon(Icons.category),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_box),
                              onPressed: _showAddProductDialog,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: TextField(
                          controller: _costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'كمية',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton.filled(
                        onPressed: _addToCart,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. القائمة
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Text(
                      'السلة فارغة',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _cart.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 5),
                    itemBuilder: (c, i) => Card(
                      child: ListTile(
                        title: Text(
                          _cart[i]['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${_cart[i]['quantity']} x ${_cart[i]['price']}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${_cart[i]['total']} ج.م",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _cart.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // 3. الجزء السفلي (التصميم النهائي الموزع + Expanded)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الصف العلوي للتحكم
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. الدفع (يمين)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPaymentTab("كاش", true),
                          _buildPaymentTab("آجل", false),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 2. الخصم (وسط) - واخد Expanded عشان يملى المساحة
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'خصم (ج.م)',
                          labelStyle: const TextStyle(fontSize: 11),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 3. الضرايب (يسار)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleChip(
                          "14%",
                          _isTaxEnabled,
                          (v) => setState(() => _isTaxEnabled = v),
                          Colors.orange,
                        ),
                        const SizedBox(width: 5),
                        _buildToggleChip(
                          "1%",
                          _isWhtEnabled,
                          (v) => setState(() => _isWhtEnabled = v),
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 25),

                // تفاصيل الأرقام
                Column(
                  children: [
                    _buildSummaryLine("المجموع الفرعي", _subTotal),
                    if (_isTaxEnabled)
                      _buildSummaryLine(
                        "Value Added Tax 14% ",
                        _taxAmount,
                        color: Colors.orange,
                      ),
                    if (_isWhtEnabled)
                      _buildSummaryLine(
                        "discount tax  1%  ",
                        _whtAmount,
                        color: Colors.orange,
                      ),
                    if (_discount > 0)
                      _buildSummaryLine(
                        "خصم تجاري (-)",
                        _discount,
                        color: Colors.red,
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // زر الحفظ العائم (أزرق)
                GestureDetector(
                  onTap: _submitPurchase,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: blueColor, // أزرق
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: blueColor.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "حفظ الفاتورة",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_grandTotal.toStringAsFixed(2)} ج.م",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
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

  // --- Widgets مساعدة ---
  Widget _buildToggleChip(
    String label,
    bool value,
    Function(bool) onChanged,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: value ? color : Colors.grey),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTab(String label, bool isCashVal) {
    bool isSelected = _isCashPayment == isCashVal;
    return GestureDetector(
      onTap: () => setState(() => _isCashPayment = isCashVal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isCashVal ? Colors.green : Colors.red)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, double val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            val.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
