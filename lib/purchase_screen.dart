import 'dart:io';
import 'package:flutter/material.dart';
import 'product_dialog.dart';
import 'supplier_dialog.dart';
import 'pb_helper.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  // --- المتغيرات ---
  List<String> _units = [];
  final List<Map<String, dynamic>> _cart = [];

  String? _selectedSupplierId;
  String? _selectedProductId;

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

  bool _isTaxEnabled = false;
  bool _isWhtEnabled = false;
  bool _isCashPayment = false;

  // ✅ 1. متغيرات الصلاحيات
  bool _canAddPurchase = false;
  bool _canAddSupplier = false;
  bool _canAddProduct = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // تحميل الصلاحيات
    _loadUnits();
  }

  // ✅ 2. دالة تحميل الصلاحيات
  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) {
        setState(() {
          _canAddPurchase = true;
          _canAddSupplier = true;
          _canAddProduct = true;
        });
      }
      return;
    }

    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAddPurchase = userRecord.data['allow_add_purchases'] ?? false;
          // نستخدم صلاحية العملاء والموردين لإضافة المورد
          _canAddSupplier = userRecord.data['allow_add_clients'] ?? false;
          _canAddProduct = userRecord.data['allow_add_products'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error loading perms: $e");
    }
  }

  Future<void> _loadUnits() async {
    final unitsData = await PBHelper().getUnits();
    if (mounted) {
      setState(() {
        _units = unitsData;
        if (_units.isEmpty) _units = ['قطعة', 'كرتونة'];
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
  double get _taxAmount => _isTaxEnabled ? (_subTotal - _discount) * 0.14 : 0.0;
  double get _whtAmount => _isWhtEnabled ? (_subTotal - _discount) * 0.01 : 0.0;
  double get _grandTotal => (_subTotal - _discount) + _taxAmount - _whtAmount;

  // --- الصور ---
  Widget _buildProductImage(String? imagePath, {double size = 45}) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.broken_image, size: size, color: Colors.grey),
          ),
        );
      } else if (File(imagePath).existsSync()) {
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

  // ============================================================
  // ✅ استدعاء الكلاسات الجديدة (مع الصلاحيات)
  // ============================================================

  Future<void> _openAddSupplierDialog() async {
    // حماية
    if (!_canAddSupplier) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية إضافة موردين')),
      );
      return;
    }

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const SupplierDialog(),
    );

    if (result != null && result is Map) {
      setState(() {
        _selectedSupplierId = result['id'];
        _supplierSearchController.text = result['name'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد المورد الجديد تلقائياً ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openAddProductDialog() async {
    // حماية
    if (!_canAddProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية إضافة أصناف')),
      );
      return;
    }

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ProductDialog(),
    );

    if (result != null && result is Map) {
      setState(() {
        _selectedProductId = result['id'];
        _productSearchController.text = result['name'];
        _costPriceController.text = (result['buyPrice'] ?? 0).toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد الصنف الجديد تلقائياً ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // --- البحث (Real-time Stream) ---
  void _showSearchDialog({required bool isSupplier}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
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
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: PBHelper().getCollectionStream(
                          isSupplier ? 'suppliers' : 'products',
                          sort: isSupplier ? 'name' : '-created',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError)
                            return Center(
                              child: Text('خطأ: ${snapshot.error}'),
                            );
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          final allItems = snapshot.data!;
                          final filteredList = allItems.where((item) {
                            final q = query.toLowerCase();
                            final name = (item['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            if (isSupplier) {
                              return name.contains(q);
                            } else {
                              final code = (item['code'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return name.contains(q) || code.contains(q);
                            }
                          }).toList();

                          if (filteredList.isEmpty)
                            return const Center(child: Text("لا توجد نتائج"));

                          return ListView.separated(
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
                                      _supplierSearchController.text =
                                          item['name'];
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              } else {
                                return ListTile(
                                  leading: _buildProductImage(
                                    item['imagePath'],
                                  ),
                                  title: Text(item['name']),
                                  subtitle: Text("مخزن: ${item['stock']}"),
                                  trailing: Text(
                                    "${item['buyPrice']}",
                                    style: const TextStyle(color: Colors.grey),
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

  void _addToCart() {
    if (_selectedProductId == null ||
        _qtyController.text.isEmpty ||
        _costPriceController.text.isEmpty)
      return;
    int qty = int.tryParse(_qtyController.text) ?? 0;
    double cost = double.tryParse(_costPriceController.text) ?? 0.0;
    if (qty <= 0) return;

    String prodName = _productSearchController.text;

    setState(() {
      _cart.add({
        'productId': _selectedProductId!,
        'name': prodName,
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
    // ✅ حماية زر الحفظ
    if (!_canAddPurchase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية حفظ فاتورة مشتريات')),
      );
      return;
    }

    if (_selectedSupplierId == null || _cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('البيانات ناقصة')));
      return;
    }

    try {
      await PBHelper().createPurchase(
        _selectedSupplierId!,
        _grandTotal,
        _cart,
        refNumber: _refNumController.text,
        customDate: _invoiceDate.toIso8601String(),
        taxAmount: _taxAmount,
        whtAmount: _whtAmount,
        discount: _discount,
        paymentType: _isCashPayment ? 'cash' : 'credit',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.brown[300]! : Colors.brown[700]!;
    final blueColor = Colors.blue[800]!;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات ')),
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
                            // ✅ زر إضافة مورد
                            suffixIcon: _canAddSupplier
                                ? IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    onPressed: _openAddSupplierDialog,
                                  )
                                : null,
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
                            // ✅ زر إضافة صنف
                            suffixIcon: _canAddProduct
                                ? IconButton(
                                    icon: const Icon(Icons.add_box),
                                    onPressed: _openAddProductDialog,
                                  )
                                : null,
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

          // 3. الجزء السفلي
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                        "خصم إضافي (-)",
                        _discount,
                        color: Colors.red,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ✅ زر الحفظ (يخضع للصلاحية)
                GestureDetector(
                  onTap: _submitPurchase,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: _canAddPurchase
                          ? blueColor
                          : Colors.grey, // لون باهت لو ممنوع
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
                        Text(
                          _canAddPurchase ? "حفظ الفاتورة" : "غير مسموح بالحفظ",
                          style: const TextStyle(
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

  // Helper Widgets (Same as before)
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
