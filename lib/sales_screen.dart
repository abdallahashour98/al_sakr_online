import 'dart:io';
import 'package:al_sakr/services/pb_helper.dart';
import 'package:al_sakr/services/sales_service.dart';
import 'package:flutter/material.dart';
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

  bool _canAddOrder = false;
  bool _canAddClient = false;
  bool _canAddProduct = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

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
      debugPrint("Error permissions: $e");
    }
  }

  double get _subTotal =>
      _invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] as double));
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _taxableAmount => _subTotal - _discount;
  double get _taxAmount => _isTaxEnabled ? _taxableAmount * 0.14 : 0.0;
  double get _whtAmount => _isWhtEnabled ? _taxableAmount * 0.01 : 0.0;
  double get _grandTotal => _taxableAmount + _taxAmount - _whtAmount;

  Future<void> _openAddClientDialog() async {
    if (!_canAddClient) return;
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
    }
  }

  Future<void> _openAddProductDialog() async {
    if (!_canAddProduct) return;
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
    }
  }

  // ✅ دالة البحث المحسنة (زي المشتريات بالظبط)
  void _showSearchDialog({required bool isClient}) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 600),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      isClient ? 'بحث عن عميل' : 'اختر صنفاً',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      onChanged: (val) => setStateSB(() => query = val),
                      decoration: InputDecoration(
                        hintText: 'اكتب للبحث...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: PBHelper().getCollectionStream(
                          isClient ? 'clients' : 'products',
                          sort: isClient ? 'name' : '-created',
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
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

                          if (filteredList.isEmpty) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "لا توجد نتائج",
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            );
                          }

                          return ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isClient) {
                                      _selectedClient = item;
                                      _clientSearchController.text =
                                          item['name'];
                                    } else {
                                      _selectedProduct = item;
                                      _productSearchController.text =
                                          item['name'];
                                      _priceController.text = item['sellPrice']
                                          .toString();
                                    }
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // 1. الصورة
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.grey[200],
                                        ),
                                        child: isClient
                                            ? const Icon(
                                                Icons.person,
                                                size: 25,
                                                color: Colors.grey,
                                              )
                                            : _buildProductImage(
                                                item['imagePath'],
                                                size: 50,
                                              ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 2. التفاصيل
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // الاسم المتحرك
                                            SizedBox(
                                              height: 20,
                                              child: ScrollingText(
                                                text: item['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (!isClient)
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          (item['stock'] ?? 0) >
                                                              0
                                                          ? Colors.green
                                                                .withOpacity(
                                                                  0.1,
                                                                )
                                                          : Colors.red
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            (item['stock'] ??
                                                                    0) >
                                                                0
                                                            ? Colors.green
                                                                  .withOpacity(
                                                                    0.3,
                                                                  )
                                                            : Colors.red
                                                                  .withOpacity(
                                                                    0.3,
                                                                  ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          size: 12,
                                                          color:
                                                              (item['stock'] ??
                                                                      0) >
                                                                  0
                                                              ? Colors.green
                                                              : Colors.red,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          "${item['stock']}",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                (item['stock'] ??
                                                                        0) >
                                                                    0
                                                                ? Colors.green
                                                                : Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    "${item['sellPrice']} ج.م",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Text(
                                                item['phone'] ?? 'لا يوجد رقم',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("إلغاء"),
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

    // int currentStock = (_selectedProduct!['stock'] as num).toInt();
    // if (qty > currentStock) {
    //   _showError('الكمية غير متوفرة! المتاح: $currentStock');
    //   return;
    // }

    setState(() {
      final existingIndex = _invoiceItems.indexWhere(
        (item) => item['productId'] == _selectedProduct!['id'],
      );
      if (existingIndex >= 0) {
        int newQty = _invoiceItems[existingIndex]['quantity'] + qty;
        // if (newQty > currentStock) {
        //   _showError('تخطي الرصيد المتاح');
        //   return;
        // }
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
    if (!_canAddOrder) {
      _showError('ليس لديك صلاحية');
      return;
    }
    if (_invoiceItems.isEmpty || _selectedClient == null) {
      _showError('البيانات ناقصة');
      return;
    }
    try {
      await SalesService().createSale(
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
            content: Text('تم الحفظ ✅'),
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

    // ✅ استخدام MediaQuery بدلاً من LayoutBuilder
    bool isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيعات')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. الجزء العلوي (كارت البيانات)
            SliverToBoxAdapter(
              child: Card(
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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
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

                      // إضافة منتج (Responsive Layout)
                      if (!isWide)
                        // موبايل
                        Column(
                          children: [
                            TextField(
                              controller: _productSearchController,
                              readOnly: true,
                              onTap: () => _showSearchDialog(isClient: false),
                              decoration: InputDecoration(
                                labelText: 'بحث عن صنف...',
                                prefixIcon: const Icon(Icons.shopping_bag),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      labelText: 'سعر',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: TextField(
                                    controller: _qtyController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      labelText: 'عدد',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    onPressed: _addItemToInvoice,
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        // كمبيوتر
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
            ),

            // 2. الجزء الأوسط (القائمة)
            SliverToBoxAdapter(
              child: _invoiceItems.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          "السلة فارغة",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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

            // 3. الجزء السفلي (لوحة التحكم الشيك)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // لوحة التحكم (الذكية)
                        if (!isWide)
                          // موبايل (عمودي)
                          Column(
                            children: [
                              _buildSegmentedPaymentToggle(isDark),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(child: _buildDiscountField(isDark)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildTaxToggle(
                                      "ضريبة 14%",
                                      _isTaxEnabled,
                                      (v) => setState(() => _isTaxEnabled = v),
                                      Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: _buildTaxToggle(
                                      "خصم 1%",
                                      _isWhtEnabled,
                                      (v) => setState(() => _isWhtEnabled = v),
                                      Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          // كمبيوتر (أفقي موزون)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // كاش (2)
                              Expanded(
                                flex: 2,
                                child: _buildSegmentedPaymentToggle(isDark),
                              ),
                              const SizedBox(width: 15),
                              // خصم (2)
                              Expanded(
                                flex: 2,
                                child: _buildDiscountField(isDark),
                              ),
                              const SizedBox(width: 15),
                              // ضرائب (3)
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTaxToggle(
                                        "ضريبة 14%",
                                        _isTaxEnabled,
                                        (v) =>
                                            setState(() => _isTaxEnabled = v),
                                        Colors.orange,
                                        fullWidth: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTaxToggle(
                                        "خصم 1%",
                                        _isWhtEnabled,
                                        (v) =>
                                            setState(() => _isWhtEnabled = v),
                                        Colors.red,
                                        fullWidth: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),
                        const Divider(),

                        _buildSummaryLine("المجموع الفرعي", _subTotal),
                        if (_isTaxEnabled)
                          _buildSummaryLine(
                            "Value Added Tax 14%",
                            _taxAmount,
                            color: Colors.orange,
                          ),
                        if (_isWhtEnabled)
                          _buildSummaryLine(
                            "discount tax 1%",
                            _whtAmount,
                            color: Colors.red,
                          ),
                        if (_discount > 0)
                          _buildSummaryLine(
                            "خصم إضافي",
                            _discount,
                            color: Colors.green,
                          ),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: _saveInvoice,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _canAddOrder
                                    ? [accentColor, Colors.blueAccent]
                                    : [Colors.grey, Colors.grey.shade400],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _canAddOrder ? "حفظ الفاتورة" : "غير مسموح",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${_grandTotal.toStringAsFixed(2)} ج.م",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
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
            ),
          ],
        ),
      ),
    );
  }

  // --- دوال التصميم (Control Panel) ---

  Widget _buildSegmentedPaymentToggle(bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isCashPayment = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isCashPayment ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isCashPayment
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  "كاش",
                  style: TextStyle(
                    color: _isCashPayment
                        ? Colors.white
                        : (isDark ? Colors.grey : Colors.black54),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isCashPayment = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isCashPayment
                      ? Colors.redAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isCashPayment
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  "آجل",
                  style: TextStyle(
                    color: !_isCashPayment
                        ? Colors.white
                        : (isDark ? Colors.grey : Colors.black54),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountField(bool isDark) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: _discountController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          labelText: 'خصم إضافي',
          labelStyle: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey : Colors.grey[700],
          ),
          prefixIcon: const Icon(Icons.discount_outlined, size: 18),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  Widget _buildTaxToggle(
    String label,
    bool value,
    Function(bool) onChanged,
    Color activeColor, {
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: value ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? activeColor : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: value ? activeColor : Colors.grey,
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

// --- كلاس النص المتحرك (مهم جداً) ---
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const ScrollingText({required this.text, this.style, super.key});

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      _animation =
          Tween<double>(
            begin: 0,
            end: _scrollController.position.maxScrollExtent,
          ).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.linear),
          );

      _animation.addListener(() {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_animation.value);
        }
      });

      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style),
    );
  }
}
