import 'dart:io';

import 'package:flutter/material.dart';
import 'db_helper.dart';
// للتعامل مع ملفات الصور
import 'package:image_picker/image_picker.dart'; // لاختيار الصور من المعرض
import 'package:path_provider/path_provider.dart'; // للحصول على مسار حفظ الصور

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _cart = [];
  List<String> _units = [];

  int? _selectedSupplierId;
  final TextEditingController _supplierSearchController =
      TextEditingController();

  int? _selectedProductId;
  final TextEditingController _productSearchController =
      TextEditingController();

  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _refNumController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();

  // 🆕 متغير للتحكم في الضريبة
  bool _isTaxEnabled = false;

  // 🆕 دوال الحسابات (قبل وبعد الضريبة)
  double get _subTotal {
    double sum = 0;
    for (var item in _cart) {
      sum += (item['total'] as num).toDouble();
    }
    return sum;
  }

  double get _taxAmount => _isTaxEnabled ? _subTotal * 0.14 : 0.0;

  double get _grandTotal => _subTotal + _taxAmount;
  // دالة مساعدة لعرض الصورة أو اللوجو الافتراضي (مثل شاشة المبيعات)
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

  // --- دوال إضافة مورد وصنف (كما هي) ---
  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final balanceController = TextEditingController();
    bool isLiability = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('إضافة مورد جديد'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSectionTitle('البيانات الأساسية', isDark),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildTextField(
                            codeController,
                            'كود المورد',
                            Icons.qr_code,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            nameController,
                            'اسم المورد/الشركة',
                            Icons.business,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      contactController,
                      'اسم المسؤول',
                      Icons.person,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      phoneController,
                      'التليفون / الموبايل',
                      Icons.phone,
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      addressController,
                      'العنوان',
                      Icons.location_on,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(notesController, 'ملاحظات', Icons.note),
                    const SizedBox(height: 20),
                    _buildSectionTitle('الرصيد الافتتاحي', isDark),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            balanceController,
                            'المبلغ',
                            Icons.account_balance_wallet,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          children: [
                            Row(
                              children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: isLiability,
                                  activeColor: Colors.red,
                                  onChanged: (val) =>
                                      setStateSB(() => isLiability = val!),
                                ),
                                const Text(
                                  "علينا (له)",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Radio<bool>(
                                  value: false,
                                  groupValue: isLiability,
                                  activeColor: Colors.green,
                                  onChanged: (val) =>
                                      setStateSB(() => isLiability = val!),
                                ),
                                const Text(
                                  "لنا (عليه)",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
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
                  backgroundColor: Colors.blue[800],
                ),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    double amount =
                        double.tryParse(balanceController.text) ?? 0.0;
                    double finalBalance = isLiability ? amount : -amount;
                    int id = await DatabaseHelper().insertSupplier({
                      'name': nameController.text,
                      'code': codeController.text,
                      'contactPerson': contactController.text,
                      'phone': phoneController.text,
                      'address': addressController.text,
                      'notes': notesController.text,
                      'balance': finalBalance,
                    });
                    Navigator.pop(ctx);
                    await _loadData();
                    setState(() {
                      _selectedSupplierId = id;
                      _supplierSearchController.text = nameController.text;
                    });
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إضافة المورد بنجاح ✅'),
                          backgroundColor: Colors.green,
                        ),
                      );
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

  // ===========================================================================
  // ديالوج إضافة صنف جديد (متطور مع دعم الصور)
  // ===========================================================================
  Future<void> _showAddProductDialog() async {
    // تعريف المتحكمات للحقول
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final barcodeController = TextEditingController();
    final buyPriceController = TextEditingController();
    final sellPriceController = TextEditingController();
    final stockController = TextEditingController(
      text: '0',
    ); // المخزن الافتراضي 0
    final reorderLevelController = TextEditingController(
      text: '5',
    ); // حد الطلب الافتراضي
    final notesController = TextEditingController();
    String? selectedImagePath; // متغير لتخزين مسار الصورة المختار

    await showDialog(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالضغط خارج الديالوج
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder مهم جداً لتحديث الصورة عند اختيارها
        builder: (context, setStateSB) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          // --- دالة اختيار الصورة وحفظها ---
          Future<void> pickImage() async {
            final picker = ImagePicker();
            // فتح معرض الصور
            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
            );

            if (pickedFile != null) {
              // الحصول على مسار مجلد المستندات الخاص بالتطبيق
              final appDir = await getApplicationSupportDirectory();
              final imagesDir = Directory('${appDir.path}/product_images');
              // إنشاء المجلد لو مش موجود
              if (!await imagesDir.exists()) {
                await imagesDir.create(recursive: true);
              }
              // تسمية الصورة باسم فريد بناءً على الوقت الحالي
              final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
              // نسخ الصورة للمسار الجديد
              final savedImage = await File(
                pickedFile.path,
              ).copy('${imagesDir.path}/$fileName');

              // تحديث الواجهة لعرض الصورة المختارة
              setStateSB(() {
                selectedImagePath = savedImage.path;
              });
            }
          }

          return AlertDialog(
            title: const Text('إضافة صنف جديد متطور'),
            content: SizedBox(
              width: 500, // عرض مناسب للديالوج
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- منطقة اختيار الصورة (أيقونة الكاميرا) ---
                    GestureDetector(
                      onTap: pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        // عرض الصورة إذا تم اختيارها، وإلا عرض أيقونة الإضافة
                        backgroundImage: selectedImagePath != null
                            ? FileImage(File(selectedImagePath!))
                            : null,
                        child: selectedImagePath == null
                            ? Icon(
                                Icons.add_a_photo,
                                size: 35,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "اضغط لإضافة صورة المنتج",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 25),

                    // --- حقول البيانات ---
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصنف *',
                        prefixIcon: Icon(Icons.shopping_bag),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // صف الأكواد
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            codeController,
                            'كود داخلي',
                            Icons.qr_code,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogTextField(
                            barcodeController,
                            'باركود',
                            Icons.qr_code_scanner,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // صف الأسعار (مهم جداً في التوريد)
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            buyPriceController,
                            'سعر الشراء *',
                            Icons.monetization_on,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogTextField(
                            sellPriceController,
                            'سعر البيع',
                            Icons.sell,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // صف المخزون وحد الطلب
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            stockController,
                            'الرصيد الافتتاحي',
                            Icons.inventory_2,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialogTextField(
                            reorderLevelController,
                            'حد التنبيه',
                            Icons.add_alert,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // الملاحظات
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check),
                label: const Text('حفظ الصنف'),
                onPressed: () async {
                  // التحقق من الحقول الإجبارية
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى كتابة اسم الصنف!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (buyPriceController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى تحديد سعر الشراء المبدئي!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // تجهيز البيانات للحفظ
                  Map<String, dynamic> row = {
                    'name': nameController.text,
                    'code': codeController.text,
                    'barcode': barcodeController.text,
                    'buyPrice': double.tryParse(buyPriceController.text) ?? 0.0,
                    'sellPrice':
                        double.tryParse(sellPriceController.text) ?? 0.0,
                    'stock': int.tryParse(stockController.text) ?? 0,
                    'reorderLevel':
                        int.tryParse(reorderLevelController.text) ?? 0,
                    'notes': notesController.text,
                    'imagePath':
                        selectedImagePath, // 🔥🔥 حفظ مسار الصورة في قاعدة البيانات 🔥🔥
                  };

                  // إدخال الصنف في قاعدة البيانات والحصول على الـ ID الجديد
                  int newProductId = await DatabaseHelper().insertProduct(row);

                  Navigator.pop(ctx); // إغلاق الديالوج

                  // تحديث البيانات واختيار الصنف الجديد تلقائياً في شاشة التوريد
                  await _loadData();
                  setState(() {
                    _selectedProductId = newProductId;
                    _productSearchController.text = nameController.text;
                    // تعيين سعر الشراء المدخل في الديالوج كخيار افتراضي في الفاتورة
                    _costPriceController.text = buyPriceController.text;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم إضافة الصنف "${nameController.text}" بنجاح ✅',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- دالة مساعدة لتقليل تكرار كود الـ TextField داخل الديالوج ---
  Widget _buildDialogTextField(
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
        isDense: true, // لجعل الحقل أصغر قليلاً
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
      ),
    );
  }

  // ... (دوال البحث _showSearchDialog كما هي) ...
  void _showSearchDialog({required bool isSupplier}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            var filteredList = [];
            if (isSupplier) {
              filteredList = _suppliers
                  .where(
                    (s) =>
                        s['name'].toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
            } else {
              filteredList = _products
                  .where(
                    (p) =>
                        p['name'].toLowerCase().contains(query.toLowerCase()) ||
                        (p['code'] ?? '').contains(query) ||
                        (p['barcode'] ?? '').contains(query),
                  )
                  .toList();
            }
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(isSupplier ? 'بحث عن مورد' : 'بحث عن صنف'),
                  ),
                  if (!isSupplier)
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
                height: 400, // زيادة الارتفاع ليتناسب مع التصميم الجديد
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'بحث باسم، كود، باركود...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) => setStateSB(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredList.isEmpty
                          ? const Center(child: Text('لا توجد نتائج'))
                          : ListView.separated(
                              separatorBuilder: (c, i) => const Divider(),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final item = filteredList[index];

                                if (isSupplier) {
                                  // شكل عرض المورد (بسيط)
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    title: Text(item['name']),
                                    onTap: () {
                                      setState(() {
                                        _selectedSupplierId = item['id'];
                                        _supplierSearchController.text =
                                            item['name'];
                                      });
                                      Navigator.pop(ctx);
                                    },
                                  );
                                } else {
                                  // الشكل المطور لعرض الصنف (مثل المبيعات)
                                  return ListTile(
                                    leading: _buildProductImage(
                                      item['imagePath'],
                                    ),
                                    title: Text(
                                      item['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "كود: ${item['code'] ?? '-'}",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          "مخزن: ${item['stock']}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: (item['stock'] ?? 0) <= 0
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${item['buyPrice']} ج.م",
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text(
                                          "سعر الشراء",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedProductId = item['id'];
                                        _productSearchController.text =
                                            item['name'];
                                        _costPriceController.text =
                                            item['buyPrice'].toString();
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

    // 🆕 إرسال البيانات (شاملة الضريبة) للداتا بيز
    await DatabaseHelper().createPurchase(
      _selectedSupplierId!,
      _grandTotal, // نرسل الإجمالي النهائي ليشمل الضريبة في رصيد المورد
      _cart,
      refNumber: _refNumController.text,
      customDate: _invoiceDate.toString(),
      taxAmount: _taxAmount, // 🆕 إرسال قيمة الضريبة للحفظ
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

  // --- دوال مساعدة للتصميم ---
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor = isDark ? Colors.brown[300]! : Colors.brown;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات (توريد)')),
      body: Column(
        children: [
          // ... (الجزء العلوي كما هو: المورد، التاريخ، الأصناف) ...
          // للاختصار سأعيد كتابة الهيكل الأساسي
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
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
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: _showAddSupplierDialog,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            ),
                            child: Text(
                              "${_invoiceDate.year}-${_invoiceDate.month}-${_invoiceDate.day}",
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
                      labelText: 'رقم المرجع',
                      prefixIcon: Icon(Icons.receipt),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_box),
                              onPressed: _showAddProductDialog,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'سعر',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'كمية',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.brown,
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('السلة فارغة'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemCount: _cart.length,
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
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _cart.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // 🆕🆕 الجزء السفلي الجديد (التفاصيل والضريبة) 🆕🆕
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. زر تفعيل الضريبة
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      "تطبيق ضريبة (14%)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _isTaxEnabled,
                      onChanged: (val) => setState(() => _isTaxEnabled = val),
                      activeThumbColor: Colors.brown,
                    ),
                  ],
                ),
                const Divider(),

                // 2. تفاصيل الأرقام
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "المجموع الفرعي:",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text("${_subTotal.toStringAsFixed(2)} ج.م"),
                  ],
                ),
                if (_isTaxEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "قيمة الضريبة:",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "+${_taxAmount.toStringAsFixed(2)} ج.م",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),

                // 3. الإجمالي النهائي وزر الحفظ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "الإجمالي النهائي",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "${_grandTotal.toStringAsFixed(2)} ج.م",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.brown[700]
                            : Colors.brown[800],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _submitPurchase,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text(
                        'حفظ الفاتورة',
                        style: TextStyle(color: Colors.white, fontSize: 16),
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
