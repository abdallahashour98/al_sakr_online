import 'package:al_sakr/main.dart';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'dart:io'; // للتعامل مع ملفات الصور
import 'package:image_picker/image_picker.dart'; // لاختيار الصور
import 'package:path_provider/path_provider.dart'; // لمسارات الحفظ
// للتحكم في المدخلات

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  List<String> _units = [];

  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _selectedProduct;

  List<Map<String, dynamic>> _invoiceItems = [];

  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();

  bool _isTaxEnabled = false;
  double _taxRate = 0.14;
  bool _isCashPayment = true;

  @override
  void initState() {
    super.initState();
    scheduleAutoBackup();
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
      });
    }
  }

  // دالة مساعدة لعرض الصورة أو اللوجو الافتراضي
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
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.shopping_bag, size: size, color: Colors.grey),
      ),
    );
  }

  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final balanceController = TextEditingController();
    bool isDebit = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('إضافة عميل جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(nameController, 'اسم العميل', Icons.person),
                  const SizedBox(height: 10),
                  _buildTextField(
                    phoneController,
                    'رقم الهاتف',
                    Icons.phone,
                    isNumber: true,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    addressController,
                    'العنوان',
                    Icons.location_on,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'الرصيد الافتتاحي (أول مرة)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  _buildTextField(
                    balanceController,
                    'المبلغ',
                    Icons.account_balance_wallet,
                    isNumber: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text(
                            "مدين (عليه)",
                            style: TextStyle(fontSize: 12),
                          ),
                          value: true,
                          groupValue: isDebit,
                          activeColor: Colors.red,
                          onChanged: (val) => setStateSB(() => isDebit = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text(
                            "دائن (له)",
                            style: TextStyle(fontSize: 12),
                          ),
                          value: false,
                          groupValue: isDebit,
                          activeColor: Colors.green,
                          onChanged: (val) => setStateSB(() => isDebit = val!),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    double amount =
                        double.tryParse(balanceController.text) ?? 0.0;
                    int id = await DatabaseHelper().insertClient({
                      'name': nameController.text,
                      'phone': phoneController.text,
                      'address': addressController.text,
                    });
                    if (amount > 0) {
                      double finalAmount = isDebit ? amount : -amount;
                      await DatabaseHelper().addOpeningBalance(id, finalAmount);
                    }
                    Navigator.pop(ctx);
                    await _loadData();
                    final newClient = _clients.firstWhere((c) => c['id'] == id);
                    setState(() {
                      _selectedClient = newClient;
                      _clientSearchController.text = newClient['name'];
                    });
                  }
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final barcodeController = TextEditingController();
    final buyPriceController = TextEditingController();
    final sellPriceController = TextEditingController();
    final minSellPriceController = TextEditingController();
    final stockController = TextEditingController();
    final reorderLevelController = TextEditingController();
    final notesController = TextEditingController();
    String selectedUnit = _units.isNotEmpty ? _units.first : 'قطعة';
    DateTime? expiryDate;
    String? selectedImagePath;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          Future<void> pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
            );
            if (pickedFile != null) {
              final appDir = await getApplicationSupportDirectory();
              final imagesDir = Directory('${appDir.path}/product_images');
              if (!await imagesDir.exists())
                await imagesDir.create(recursive: true);
              final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
              final savedImage = await File(
                pickedFile.path,
              ).copy('${imagesDir.path}/$fileName');
              setStateSB(() => selectedImagePath = savedImage.path);
            }
          }

          return AlertDialog(
            title: const Text('تسجيل صنف جديد'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: pickImage,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.withOpacity(0.2),
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
                    _buildSectionTitle('البيانات الأساسية', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            codeController,
                            'كود داخلي',
                            Icons.qr_code,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            barcodeController,
                            'باركود',
                            Icons.qr_code_scanner,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      nameController,
                      'اسم الصنف',
                      Icons.shopping_bag,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (val) => setStateSB(() => selectedUnit = val!),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('التسعير والصلاحية', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            buyPriceController,
                            'سعر الشراء',
                            Icons.attach_money,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            sellPriceController,
                            'سعر البيع',
                            Icons.sell,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      minSellPriceController,
                      'أقل سعر بيع',
                      Icons.price_check,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    InkWell(
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
                        decoration: InputDecoration(
                          labelText: 'تاريخ الصلاحية (اختياري)',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                          suffixIcon: expiryDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () =>
                                      setStateSB(() => expiryDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          expiryDate != null
                              ? "${expiryDate!.year}-${expiryDate!.month}-${expiryDate!.day}"
                              : 'لا يوجد تاريخ',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('المخزون', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            stockController,
                            'الرصيد الحالي',
                            Icons.inventory,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            reorderLevelController,
                            'حد الطلب',
                            Icons.warning_amber,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(notesController, 'ملاحظات', Icons.note),
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
                  backgroundColor: isDark ? Colors.blue[800] : Colors.blue[900],
                ),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    Map<String, dynamic> row = {
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
                      'reorderLevel':
                          int.tryParse(reorderLevelController.text) ?? 0,
                      'supplierId': null,
                      'notes': notesController.text,
                      'expiryDate': expiryDate?.toString(),
                      'imagePath': selectedImagePath,
                    };
                    int id = await DatabaseHelper().insertProduct(row);
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
                child: const Text(
                  'حفظ البيانات',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField(
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
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.tealAccent : Colors.teal[800],
        ),
      ),
    );
  }

  void _showClientSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filtered = _clients
                .where(
                  (c) => c['name'].toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('بحث عن عميل')),
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.blue),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _showAddClientDialog();
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'ابحث بالاسم...',
                      ),
                      onChanged: (val) => setStateSB(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة هذا العميل جديد'),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _showAddClientDialog();
                                },
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (c, i) => ListTile(
                                title: Text(filtered[i]['name']),
                                subtitle: Text(filtered[i]['phone'] ?? ''),
                                onTap: () {
                                  setState(() {
                                    _selectedClient = filtered[i];
                                    _clientSearchController.text =
                                        filtered[i]['name'];
                                  });
                                  Navigator.pop(ctx);
                                },
                              ),
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

  void _showProductSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filtered = _products
                .where(
                  (p) =>
                      p['name'].toLowerCase().contains(query.toLowerCase()) ||
                      (p['code'] ?? '').contains(query) ||
                      (p['barcode'] ?? '').contains(query),
                )
                .toList();
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('بحث عن صنف')),
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.blue),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _showAddProductDialog();
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'اسم، كود، باركود...',
                      ),
                      onChanged: (val) => setStateSB(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة صنف جديد'),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _showAddProductDialog();
                                },
                              ),
                            )
                          : ListView.separated(
                              separatorBuilder: (c, i) => const Divider(),
                              itemCount: filtered.length,
                              // ابحث عن دالة _showProductSearchDialog وقم بتعديل جزء الـ itemBuilder داخل الـ ListView
                              itemBuilder: (c, i) {
                                final p = filtered[i];
                                return ListTile(
                                  leading: _buildProductImage(
                                    p['imagePath'],
                                    size: 55,
                                  ), // تكبير الصورة قليلاً للتناسب مع العرض الجديد
                                  title: Text(
                                    p['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 5.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // سطر الكود
                                        Row(
                                          children: [
                                            const Text(
                                              "الكود: ",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              "${p['code'] ?? '-'}",
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 2,
                                        ), // مسافة بسيطة بين السطور
                                        // سطر المخزن
                                        Row(
                                          children: [
                                            const Text(
                                              "المخزن: ",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              "${p['stock']}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: (p['stock'] ?? 0) <= 0
                                                    ? Colors.red
                                                    : Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${p['sellPrice']} ج.م",
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const Text(
                                        "سعر البيع",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedProduct = p;
                                      _productSearchController.text = p['name'];
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
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

  void _addItemToInvoice() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار صنف')));
      return;
    }
    int qty = int.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الكمية غير صحيحة')));
      return;
    }
    setState(() {
      final existingIndex = _invoiceItems.indexWhere(
        (item) => item['productId'] == _selectedProduct!['id'],
      );
      if (existingIndex >= 0) {
        _invoiceItems[existingIndex]['quantity'] += qty;
      } else {
        _invoiceItems.add({
          'productId': _selectedProduct!['id'],
          'name': _selectedProduct!['name'],
          'quantity': qty,
          'price': _selectedProduct!['sellPrice'],
          'total': qty * (_selectedProduct!['sellPrice'] as double),
          'imagePath': _selectedProduct!['imagePath'],
        });
      }
      _selectedProduct = null;
      _productSearchController.clear();
      _qtyController.text = '1';
    });
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
  }

  double get _subTotal => _invoiceItems.fold(
    0.0,
    (sum, item) => sum + (item['quantity'] * item['price']),
  );
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _taxAmount =>
      _isTaxEnabled ? (_subTotal - _discount) * _taxRate : 0.0;
  double get _grandTotal => (_subTotal - _discount) + _taxAmount;

  Future<void> _saveInvoice() async {
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الفاتورة فارغة!')));
      return;
    }
    if (_selectedClient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار عميل')));
      return;
    }

    await DatabaseHelper().createSale(
      _selectedClient!['id'],
      _selectedClient!['name'],
      _subTotal,
      _taxAmount,
      _invoiceItems,
      refNumber: _refController.text,
      discount: _discount,
      isCash: _isCashPayment,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الفاتورة بنجاح ✅'),
          backgroundColor: Colors.green,
        ),
      );
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيعات جديدة')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: isDark ? Colors.grey[900] : Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _clientSearchController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'اسم العميل',
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                            ),
                            tooltip: 'إضافة عميل جديد',
                            onPressed: _showAddClientDialog,
                          ),
                        ),
                        onTap: _showClientSearchDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الإيصال (اختياري)',
                          prefixIcon: Icon(Icons.receipt),
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
                      flex: 2,
                      child: TextField(
                        controller: _productSearchController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'اختر الصنف',
                          prefixIcon: const Icon(Icons.shopping_bag),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_box, color: Colors.blue),
                            tooltip: 'إضافة صنف جديد',
                            onPressed: _showAddProductDialog,
                          ),
                        ),
                        onTap: _showProductSearchDialog,
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'العدد',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 5),
                    FloatingActionButton.small(
                      onPressed: _addItemToInvoice,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (_selectedProduct != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      "المتوفر في المخزن: ${_selectedProduct!['stock']}",
                      style: TextStyle(
                        color: (_selectedProduct!['stock'] as int) > 0
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _invoiceItems.isEmpty
                ? const Center(
                    child: Text(
                      'لم يتم إضافة أصناف بعد',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _invoiceItems.length,
                    itemBuilder: (context, index) {
                      final item = _invoiceItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: _buildProductImage(item['imagePath']),
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${item['quantity']} x ${item['price']} ج.م",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${(item['quantity'] * item['price']).toStringAsFixed(2)} ج.م",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
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
          Container(
            padding: const EdgeInsets.all(16),
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
                Row(
                  children: [
                    Row(
                      children: [
                        const Text(
                          "ضريبة",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Switch(
                          value: _isTaxEnabled,
                          onChanged: (val) =>
                              setState(() => _isTaxEnabled = val),
                          activeThumbColor: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(
                      width: 30,
                    ), // المسافة المطلوبة بين الضريبة ونوع الدفع
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InkWell(
                              onTap: () =>
                                  setState(() => _isCashPayment = true),
                              child: Row(
                                children: [
                                  Radio<bool>(
                                    value: true,
                                    groupValue: _isCashPayment,
                                    onChanged: (val) =>
                                        setState(() => _isCashPayment = val!),
                                    activeColor: Colors.green,
                                  ),
                                  const Text(
                                    "كاش",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  setState(() => _isCashPayment = false),
                              child: Row(
                                children: [
                                  Radio<bool>(
                                    value: false,
                                    groupValue: _isCashPayment,
                                    onChanged: (val) =>
                                        setState(() => _isCashPayment = val!),
                                    activeColor: Colors.red,
                                  ),
                                  const Text(
                                    "آجل",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'خصم (ج.م)',
                    prefixIcon: const Icon(Icons.discount, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const Divider(height: 20, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "التفاصيل:",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "المجموع: ${_subTotal.toStringAsFixed(2)} ج.م",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isTaxEnabled)
                          Text(
                            "الضريبة: +${_taxAmount.toStringAsFixed(2)} ج.م",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "الصافي النهائي",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "${_grandTotal.toStringAsFixed(2)} ج.م",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _saveInvoice,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'حفظ الفاتورة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
