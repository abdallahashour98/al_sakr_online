import 'dart:io';
import 'package:flutter/material.dart';
import 'pb_helper.dart';

// ✅ استدعاء الكلاسات الموحدة
import 'product_dialog.dart';
import 'client_dialog.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // --- المتغيرات ---
  final List<Map<String, dynamic>> _invoiceItems = [];
  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _selectedProduct;

  // Controllers
  final _clientSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _refController = TextEditingController();

  bool _isTaxEnabled = false;
  bool _isWhtEnabled = false;
  bool _isCashPayment = true;
  DateTime _invoiceDate = DateTime.now();

  // ✅ 1. متغيرات الصلاحيات
  bool _canAddOrder = false; // حفظ الفاتورة
  bool _canAddClient = false; // زر إضافة عميل
  bool _canAddProduct = false; // زر إضافة صنف

  // الآيدي الخاص بالسوبر أدمن
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // ✅ تحميل الصلاحيات
  }

  // ✅ 2. دالة تحميل الصلاحيات
  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) {
        setState(() {
          _canAddOrder = true;
          _canAddClient = true;
          _canAddProduct = true;
        });
      }
      return;
    }

    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAddOrder = userRecord.data['allow_add_orders'] ?? false;
          _canAddClient = userRecord.data['allow_add_clients'] ?? false;
          _canAddProduct = userRecord.data['allow_add_products'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الصلاحيات: $e");
    }
  }

  // --- الحسابات ---
  double get _subTotal =>
      _invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] as double));
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _taxableAmount => _subTotal - _discount;
  double get _taxAmount => _isTaxEnabled ? _taxableAmount * 0.14 : 0.0;
  double get _whtAmount => _isWhtEnabled ? _taxableAmount * 0.01 : 0.0;
  double get _grandTotal => _taxableAmount + _taxAmount - _whtAmount;

  // ============================================================
  // ✅ دوال فتح الديالوجات
  // ============================================================
  Future<void> _openAddClientDialog() async {
    // حماية: لو مش مسموح له يضيف عميل
    if (!_canAddClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية إضافة عملاء')),
      );
      return;
    }

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ClientDialog(),
    );

    if (result != null && result is Map) {
      setState(() {
        _selectedClient = result as Map<String, dynamic>;
        _clientSearchController.text = result['name'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد العميل الجديد تلقائياً ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openAddProductDialog() async {
    // حماية: لو مش مسموح له يضيف صنف
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
        _selectedProduct = result as Map<String, dynamic>;
        _productSearchController.text = result['name'];
        _priceController.text = (result['sellPrice'] ?? 0).toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد الصنف الجديد تلقائياً ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ============================================================
  // 🔍 البحث الحي
  // ============================================================
  void _showSearchDialog({required bool isClient}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
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
                        hintText: 'ابحث هنا...',
                      ),
                      onChanged: (val) => setStateSB(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: PBHelper().getCollectionStream(
                          isClient ? 'clients' : 'products',
                          sort: isClient ? 'name' : '-created',
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
                            if (isClient) {
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
                              if (isClient) {
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(item['name']),
                                  subtitle: Text(item['phone'] ?? ''),
                                  onTap: () {
                                    setState(() {
                                      _selectedClient = item;
                                      _clientSearchController.text =
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
                                  trailing: Text("${item['sellPrice']} ج.م"),
                                  onTap: () {
                                    setState(() {
                                      _selectedProduct = item;
                                      _productSearchController.text =
                                          item['name'];
                                      _priceController.text = item['sellPrice']
                                          .toString();
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

  void _addItemToInvoice() {
    if (_selectedProduct == null ||
        _qtyController.text.isEmpty ||
        _priceController.text.isEmpty)
      return;

    int qty = int.tryParse(_qtyController.text) ?? 1;
    double price = double.tryParse(_priceController.text) ?? 0.0;
    if (qty <= 0) return;

    int currentStock = (_selectedProduct!['stock'] as num).toInt();
    if (qty > currentStock) {
      _showError('الكمية غير متوفرة! المتاح: $currentStock');
      return;
    }

    setState(() {
      final existingIndex = _invoiceItems.indexWhere(
        (item) => item['productId'] == _selectedProduct!['id'],
      );

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
      _priceController.clear();
      _qtyController.text = '1';
    });
  }

  void _removeItem(int index) {
    setState(() => _invoiceItems.removeAt(index));
  }

  Future<void> _saveInvoice() async {
    // ✅ حماية زر الحفظ
    if (!_canAddOrder) {
      _showError('ليس لديك صلاحية حفظ فواتير المبيعات');
      return;
    }

    if (_invoiceItems.isEmpty || _selectedClient == null) {
      _showError('البيانات ناقصة (عميل أو أصناف)');
      return;
    }
    try {
      await PBHelper().createSale(
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
            content: Text('تم حفظ الفاتورة بنجاح ✅'),
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
      _priceController.clear();
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
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.blue[300]! : Colors.blue[800]!;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيعات ')),
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
                            // ✅ زر إضافة عميل (يظهر فقط لو مسموح)
                            suffixIcon: _canAddClient
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.blue,
                                    ),
                                    onPressed: _openAddClientDialog,
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
                            // ✅ زر إضافة صنف (يظهر فقط لو مسموح)
                            suffixIcon: _canAddProduct
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.add_box,
                                      color: Colors.blue,
                                    ),
                                    onPressed: _openAddProductDialog,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'سعر',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'عدد',
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
                ],
              ),
            ),
          ),

          // 2. قائمة الأصناف
          Expanded(
            child: _invoiceItems.isEmpty
                ? const Center(
                    child: Text(
                      "السلة فارغة",
                      style: TextStyle(color: Colors.grey),
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

          // 3. الجزء السفلي (الحسابات)
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
                        decoration: const InputDecoration(
                          labelText: 'خصم',
                          isDense: true,
                          border: OutlineInputBorder(),
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
                  _buildSummaryLine("خصم إضافي", _discount, color: Colors.red),
                const SizedBox(height: 15),

                // ✅ زر الحفظ (يخضع للصلاحية)
                GestureDetector(
                  onTap: _saveInvoice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      // لون باهت لو ممنوع
                      color: _canAddOrder ? accentColor : Colors.grey,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _canAddOrder ? "حفظ الفاتورة" : "غير مسموح بالحفظ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${_grandTotal.toStringAsFixed(1)} ج.م",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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

  // Helper Widgets
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
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey,
          ),
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
