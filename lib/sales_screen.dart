import 'dart:io';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // --- المتغيرات الأساسية ---
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  List<String> _units = [];

  final List<Map<String, dynamic>> _invoiceItems = [];

  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _selectedProduct;

  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _refController = TextEditingController();

  bool _isTaxEnabled = false;
  bool _isWhtEnabled = false;
  bool _isCashPayment = true;
  DateTime _invoiceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final clients = await DatabaseHelper().getClients();
    final products = await DatabaseHelper().getProducts();
    final unitsData = await DatabaseHelper().getUnits();

    if (mounted) {
      setState(() {
        _clients = clients;
        _products = products;
        _units = unitsData.map((u) => u['name'] as String).toList();
        if (_units.isEmpty) _units = ['قطعة', 'كرتونة'];
      });
    }
  }

  // --- الحسابات ---
  double get _subTotal =>
      _invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] as double));
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _taxAmount => _isTaxEnabled ? (_subTotal - _discount) * 0.14 : 0.0;
  double get _whtAmount => _isWhtEnabled ? (_subTotal - _discount) * 0.01 : 0.0;
  double get _grandTotal => ((_subTotal - _discount) + _taxAmount) + _whtAmount;

  // --- الصور ---
  Widget _buildProductImage(String? imagePath, {double size = 50}) {
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
        errorBuilder: (ctx, err, stack) =>
            Icon(Icons.shopping_bag, size: size, color: Colors.grey),
      ),
    );
  }

  // --- إضافة صنف (Pro) ---
  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final barcodeController = TextEditingController();
    final buyPriceController = TextEditingController();
    final sellPriceController = TextEditingController();
    final minSellPriceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final reorderController = TextEditingController(text: '5');
    String selectedUnit = _units.isNotEmpty ? _units.first : 'قطعة';
    String? selectedImagePath;
    DateTime? expiryDate;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('تسجيل صنف جديد'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null) {
                            final appDir =
                                await getApplicationSupportDirectory();
                            final imagesDir = Directory(
                              '${appDir.path}/product_images',
                            );
                            if (!await imagesDir.exists())
                              await imagesDir.create(recursive: true);
                            final fileName =
                                '${DateTime.now().millisecondsSinceEpoch}.jpg';
                            final saved = await File(
                              picked.path,
                            ).copy('${imagesDir.path}/$fileName');
                            setStateSB(() => selectedImagePath = saved.path);
                          }
                        },
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          backgroundImage: selectedImagePath != null
                              ? FileImage(File(selectedImagePath!))
                              : null,
                          child: selectedImagePath == null
                              ? const Icon(Icons.add_a_photo, size: 30)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildSectionLabel("البيانات الأساسية", isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            codeController,
                            "كود داخلي",
                            Icons.qr_code,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogField(
                            barcodeController,
                            "باركود",
                            Icons.qr_code_scanner,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDialogField(
                      nameController,
                      "اسم الصنف",
                      Icons.shopping_bag,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        prefixIcon: Icon(Icons.scale),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (val) => setStateSB(() => selectedUnit = val!),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionLabel("التسعير والصلاحية", isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            buyPriceController,
                            "سعر الشراء",
                            Icons.monetization_on,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogField(
                            sellPriceController,
                            "سعر البيع",
                            Icons.sell,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            minSellPriceController,
                            "أقل سعر بيع",
                            Icons.price_check,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setStateSB(() => expiryDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تاريخ الصلاحية',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                expiryDate != null
                                    ? "${expiryDate!.year}-${expiryDate!.month}-${expiryDate!.day}"
                                    : "لا يوجد",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionLabel("المخزون", isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            stockController,
                            "الرصيد الحالي",
                            Icons.inventory_2,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogField(
                            reorderController,
                            "حد الطلب",
                            Icons.warning_amber,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      sellPriceController.text.isNotEmpty) {
                    int id = await DatabaseHelper().insertProduct({
                      'name': nameController.text,
                      'code': codeController.text,
                      'barcode': barcodeController.text,
                      'unit': selectedUnit,
                      'buyPrice':
                          double.tryParse(buyPriceController.text) ?? 0.0,
                      'sellPrice':
                          double.tryParse(sellPriceController.text) ?? 0.0,
                      'minSellPrice':
                          double.tryParse(minSellPriceController.text) ?? 0.0,
                      'stock': int.tryParse(stockController.text) ?? 0,
                      'reorderLevel': int.tryParse(reorderController.text) ?? 0,
                      'expiryDate': expiryDate?.toString(),
                      'imagePath': selectedImagePath,
                    });
                    Navigator.pop(ctx);
                    await _loadData();
                    setState(() {
                      _selectedProduct = _products.firstWhere(
                        (p) => p['id'] == id,
                      );
                      _productSearchController.text = _selectedProduct!['name'];
                    });
                  }
                },
                child: const Text('حفظ البيانات'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- إضافة عميل (Pro) ---
  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final balanceController = TextEditingController();
    bool isDebit = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) => AlertDialog(
          title: const Text('إضافة عميل جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل',
                    prefixIcon: Icon(Icons.person),
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
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    prefixIcon: Icon(Icons.location_on),
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
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text("مدين (عليه)"),
                        value: true,
                        groupValue: isDebit,
                        activeColor: Colors.red,
                        onChanged: (v) => setStateSB(() => isDebit = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text("دائن (له)"),
                        value: false,
                        groupValue: isDebit,
                        activeColor: Colors.green,
                        onChanged: (v) => setStateSB(() => isDebit = v!),
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
                  int id = await DatabaseHelper().insertClient({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'address': addressController.text,
                    'balance': 0.0,
                  });
                  double amount =
                      double.tryParse(balanceController.text) ?? 0.0;
                  if (amount > 0)
                    await DatabaseHelper().addOpeningBalance(
                      id,
                      isDebit ? amount : -amount,
                    );
                  Navigator.pop(ctx);
                  await _loadData();
                  setState(() {
                    _selectedClient = _clients.firstWhere((c) => c['id'] == id);
                    _clientSearchController.text = _selectedClient!['name'];
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

  // --- منطق الفاتورة ---
  void _addItemToInvoice() {
    if (_selectedProduct == null) {
      _showError('الرجاء اختيار صنف أولاً');
      return;
    }
    int qty = int.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) return;
    int currentStock = (_selectedProduct!['stock'] as int);
    if (qty > currentStock) {
      _showError('الكمية غير متوفرة! المتاح: $currentStock');
      return;
    }
    setState(() {
      final existingIndex = _invoiceItems.indexWhere(
        (item) => item['productId'] == _selectedProduct!['id'],
      );
      double price = (_selectedProduct!['sellPrice'] as num).toDouble();
      if (existingIndex >= 0) {
        int newQty = _invoiceItems[existingIndex]['quantity'] + qty;
        if (newQty > currentStock) {
          _showError('تخطي الرصيد المتاح');
          return;
        }
        _invoiceItems[existingIndex]['quantity'] = newQty;
        _invoiceItems[existingIndex]['total'] = newQty * price;
      } else {
        _invoiceItems.add({
          'productId': _selectedProduct!['id'],
          'name': _selectedProduct!['name'],
          'quantity': qty,
          'price': price,
          'total': qty * price,
          'imagePath': _selectedProduct!['imagePath'],
        });
      }
      _selectedProduct = null;
      _productSearchController.clear();
      _qtyController.text = '1';
    });
  }

  void _removeItem(int index) {
    setState(() => _invoiceItems.removeAt(index));
  }

  Future<void> _saveInvoice() async {
    if (_invoiceItems.isEmpty || _selectedClient == null) {
      _showError('البيانات ناقصة!');
      return;
    }
    try {
      await DatabaseHelper().createSale(
        _selectedClient!['id'],
        _selectedClient!['name'],
        _subTotal,
        _taxAmount,
        _invoiceItems,
        refNumber: _refController.text,
        discount: _discount,
        isCash: _isCashPayment,
        whtAmount: _whtAmount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
        _resetScreen();
      }
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  void _resetScreen() {
    setState(() {
      _invoiceItems.clear();
      _selectedClient = null;
      _clientSearchController.clear();
      _selectedProduct = null;
      _productSearchController.clear();
      _qtyController.text = '1';
      _discountController.text = '0';
      _refController.clear();
      _isCashPayment = true;
      _isTaxEnabled = false;
      _isWhtEnabled = false;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- البحث ---
  void _showSearchDialog({required bool isClient}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            var filtered = isClient
                ? _clients
                      .where(
                        (c) => c['name'].toLowerCase().contains(
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
              title: Text(isClient ? 'بحث عن عميل' : 'بحث عن صنف'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'بحث...',
                      ),
                      onChanged: (val) => setStateSB(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        separatorBuilder: (c, i) => const Divider(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          if (isClient) {
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(item['name']),
                              onTap: () {
                                setState(() {
                                  _selectedClient = item;
                                  _clientSearchController.text = item['name'];
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          } else {
                            return ListTile(
                              leading: _buildProductImage(item['imagePath']),
                              title: Text(item['name']),
                              subtitle: Text("مخزن: ${item['stock']}"),
                              onTap: () {
                                setState(() {
                                  _selectedProduct = item;
                                  _productSearchController.text = item['name'];
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.blue[300]! : Colors.blue[800]!;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيعات جديدة')),
      body: Column(
        children: [
          // 1. الجزء العلوي (البيانات)
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
                          controller: _clientSearchController,
                          readOnly: true,
                          onTap: () => _showSearchDialog(isClient: true),
                          decoration: InputDecoration(
                            labelText: 'العميل',
                            prefixIcon: const Icon(Icons.person),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.blue,
                              ),
                              onPressed: _showAddClientDialog,
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _productSearchController,
                          readOnly: true,
                          onTap: () => _showSearchDialog(isClient: false),
                          decoration: InputDecoration(
                            labelText: 'الصنف',
                            prefixIcon: const Icon(Icons.shopping_bag),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.add_box,
                                color: Colors.blue,
                              ),
                              onPressed: _showAddProductDialog,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'العدد',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton.filled(
                        onPressed: _addItemToInvoice,
                        icon: const Icon(Icons.add_shopping_cart),
                        style: IconButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedProduct != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            "المخزن: ${_selectedProduct!['stock']}",
                            style: TextStyle(
                              color: (_selectedProduct!['stock'] as int) > 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "السعر: ${_selectedProduct!['sellPrice']} ج.م",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. قائمة الأصناف
          Expanded(
            child: _invoiceItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const Text(
                          "لم يتم إضافة أصناف",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _invoiceItems.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final item = _invoiceItems[index];
                      return Card(
                        child: ListTile(
                          leading: _buildProductImage(item['imagePath']),
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${item['quantity']} × ${item['price']} ج.م",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${(item['total'] as double).toStringAsFixed(1)}",
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
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 3. الجزء السفلي (المحسن جداً)
          Container(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24,
            ), // مساحة أكبر من تحت
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
                // الصف العلوي: (يمين: الدفع) - (وسط: خصم) - (يسار: ضرايب)
                // في التطبيقات العربي: اليمين هو البداية (Row children)
                Row(
                  children: [
                    // 1. طريقة الدفع (يمين)
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

                    // 2. الخصم (وسط)
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'خصم إضافي',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 3. الضرايب (يسار) - 1% ثم 14%
                    Row(
                      children: [
                        _buildToggleChip(
                          "14%",
                          _isTaxEnabled,
                          (v) => setState(() => _isTaxEnabled = v),
                          Colors.orange,
                        ),
                        const SizedBox(width: 4),
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

                const Divider(height: 20),

                // تفاصيل الأرقام (Subtotal etc.)
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
                        color: Colors.red,
                      ),
                    if (_discount > 0)
                      _buildSummaryLine(
                        "خصم إضافي (-)",
                        _discount,
                        color: Colors.red,
                      ),
                  ],
                ),

                const SizedBox(height: 15),

                // شريط الحفظ العائم (Floating Style)
                GestureDetector(
                  onTap: _saveInvoice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(50), // شكل كبسولة
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
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
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_grandTotal.toStringAsFixed(1)} ج.م",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
  Widget _buildDialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.blue[300] : Colors.blue[800],
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildToggleChip(
    String label,
    bool value,
    Function(bool) onChanged,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? color : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? color : Colors.transparent),
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
      child: Container(
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, double val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            val.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
