import 'dart:io';
import 'package:al_sakr/services/pb_helper.dart';
import 'package:al_sakr/services/sales_service.dart';
import 'package:flutter/material.dart';
import 'product_dialog.dart';
import 'client_dialog.dart';

/// ============================================================
/// 🛒 شاشة المبيعات (Sales Screen) - نقطة البيع (POS)
/// ============================================================
/// الغرض:
/// تتيح للمستخدم (/المسؤول) إنشاء فواتير مبيعات جديدة.
///
/// الميزات الأساسية:
/// 1. البحث عن العملاء وإضافتهم.
/// 2. البحث عن المنتجات (بالاسم أو الكود) وإضافتها للسلة.
/// 3. حساب العمليات الحسابية (الضرائب، الخصم، الإجمالي) تلقائياً.
/// 4. التعامل مع الصلاحيات (User Permissions) لإخفاء/إظهار الميزات.
/// 5. تصميم متجاوب (Responsive) يعمل على الموبايل والكمبيوتر.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // ============================================================
  // 1️⃣ إدارة الحالة والمتغيرات (State & Variables)
  // ============================================================

  /// سلة المشتريات: قائمة تحتوي على المنتجات التي تم اختيارها للفاتورة الحالية
  final List<Map<String, dynamic>> _invoiceItems = [];

  /// العميل المختار حالياً للفاتورة
  Map<String, dynamic>? _selectedClient;

  /// المنتج الذي يتم تجهيزه للإضافة (Temp selection)
  Map<String, dynamic>? _selectedProduct;

  // --- أدوات التحكم في النصوص (Text Controllers) ---
  final _clientSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _qtyController = TextEditingController(
    text: '1',
  ); // القيمة الافتراضية 1
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(
    text: '0',
  ); // خصم إضافي على الفاتورة
  final _refController =
      TextEditingController(); // رقم الفاتورة اليدوي أو المرجعي

  // --- إعدادات الفاتورة (Flags) ---
  bool _isTaxEnabled = false; // هل يتم تطبيق ضريبة القيمة المضافة 14%؟
  bool _isWhtEnabled = false; // هل يتم تطبيق ضريبة الخصم من المنبع 1%؟
  bool _isCashPayment = true; // نوع الفاتورة: كاش (true) أو آجل (false)
  DateTime _invoiceDate = DateTime.now(); // تاريخ الفاتورة

  // --- الصلاحيات (Permissions) ---
  // يتم تحميل هذه القيم من قاعدة البيانات عند فتح الشاشة
  bool _canAddOrder = false;
  bool _canAddClient = false;
  bool _canAddProduct = false;

  /// معرف المدير العام (Super Admin) - يمتلك كل الصلاحيات دائماً
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    // عند بدء الشاشة، نبدأ فوراً في جلب صلاحيات المستخدم
    _loadPermissions();
  }

  /// 🔐 دالة تحميل الصلاحيات (Authorization Logic)
  /// تتحقق من هوية المستخدم الحالي وتفعل الأزرار بناءً على صلاحياته في الـ Database
  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    // 1. لو المستخدم هو الـ Super Admin -> افتح كل الصلاحيات فوراً
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

    // 2. لو مستخدم عادي -> اسأل قاعدة البيانات (Users Collection)
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

  // ============================================================
  // 2️⃣ "الآلة الحاسبة" (Getters for Calculations)
  // ============================================================
  // هذه الدوال تحسب الأرقام ديناميكياً بناءً على محتوى السلة والخيارات المفعلة

  /// مجموع أسعار المنتجات قبل أي خصم أو ضريبة
  double get _subTotal =>
      _invoiceItems.fold(0.0, (sum, item) => sum + (item['total'] as double));

  /// قيمة الخصم المكتوبة في الحقل
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;

  /// المبلغ الخاضع للضريبة (الإجمالي الفرعي - الخصم)
  double get _taxableAmount => _subTotal - _discount;

  /// قيمة الضريبة المضافة (14%) إذا كانت مفعلة
  double get _taxAmount => _isTaxEnabled ? _taxableAmount * 0.14 : 0.0;

  /// قيمة ضريبة الخصم والتحصيل (1%) إذا كانت مفعلة
  double get _whtAmount => _isWhtEnabled ? _taxableAmount * 0.01 : 0.0;

  /// صافي الفاتورة النهائي المطلوب دفعه
  double get _grandTotal => _taxableAmount + _taxAmount - _whtAmount;

  // ============================================================
  // 3️⃣ الحوارات والنوافذ المنبثقة (Dialogs)
  // ============================================================

  /// فتح نافذة إضافة عميل جديد
  Future<void> _openAddClientDialog() async {
    if (!_canAddClient) return; // حماية إضافية للصلاحية
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ClientDialog(),
    );
    // إذا تم إضافة عميل بنجاح، يتم اختياره تلقائياً
    if (result != null && result is Map) {
      setState(() {
        _selectedClient = result as Map<String, dynamic>;
        _clientSearchController.text = result['name'];
      });
    }
  }

  /// فتح نافذة إضافة منتج جديد
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

  /// 🔎 دالة البحث الشاملة (Universal Search Dialog)
  /// تستخدم للبحث عن العملاء (isClient = true) أو المنتجات (isClient = false)
  /// - تدعم البحث بالاسم وبالكود (للمنتجات).
  /// - تعرض النتائج بشكل فوري (Real-time Stream).
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
                    // عنوان البحث
                    Text(
                      isClient ? 'بحث عن عميل' : 'اختر صنفاً',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // حقل كتابة البحث
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

                    // عرض النتائج باستخدام Stream
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

                          // عملية الفلترة (Client-side filtering)
                          final filteredList = allItems.where((item) {
                            final q = query.toLowerCase();
                            final name = (item['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            if (isClient) {
                              return name.contains(q);
                            } else {
                              // في المنتجات نبحث بالاسم أو الباركود
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
                                  // عند اختيار عنصر، نحدث المتغيرات ونغلق البحث
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
                                // تصميم كارت العنصر في البحث
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
                                      // صورة العنصر
                                      Container(
                                        width: 30,
                                        height: 30,
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
                                                size: 25,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // تفاصيل الاسم والسعر/الرقم
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
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
                                                  // حالة المخزون (أخضر=متاح، أحمر=نفد)
                                                  _buildStockIndicator(
                                                    item['stock'],
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
                    // زر الإلغاء
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

  // Helper widget لعرض حالة المخزون داخل البحث
  Widget _buildStockIndicator(dynamic stockVal) {
    int stock = (stockVal ?? 0);
    bool inStock = stock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: inStock
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: inStock
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 12,
            color: inStock ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            "$stock",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: inStock ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 4️⃣ منطق الفاتورة (Invoice Logic)
  // ============================================================

  /// إضافة صنف للسلة (Invoice Items)
  /// تقوم هذه الدالة بالتحقق من المدخلات، وتحديث الكمية إذا كان الصنف موجوداً مسبقاً
  void _addItemToInvoice() {
    // 1. التحقق من صحة المدخلات
    if (_selectedProduct == null ||
        _qtyController.text.isEmpty ||
        _priceController.text.isEmpty) {
      return;
    }

    int qty = int.tryParse(_qtyController.text) ?? 1;
    double price = double.tryParse(_priceController.text) ?? 0.0;
    if (qty <= 0) return;

    // TODO: تفعيل التحقق من المخزون عند الحاجة
    // int currentStock = (_selectedProduct!['stock'] as num).toInt();
    // if (qty > currentStock) {
    //   _showError('الكمية غير متوفرة! المتاح: $currentStock');
    //   return;
    // }

    setState(() {
      // 2. البحث: هل المنتج ده موجود في الليستة قبل كده؟
      final existingIndex = _invoiceItems.indexWhere(
        (item) => item['productId'] == _selectedProduct!['id'],
      );

      if (existingIndex >= 0) {
        // لو موجود -> زود الكمية على القديم
        int newQty = _invoiceItems[existingIndex]['quantity'] + qty;
        _invoiceItems[existingIndex]['quantity'] = newQty;
        _invoiceItems[existingIndex]['total'] = newQty * price;
      } else {
        // لو جديد -> ضيف سطر جديد
        _invoiceItems.add({
          'productId': _selectedProduct!['id'],
          'name': _selectedProduct!['name'],
          'quantity': qty,
          'price': price,
          'total': qty * price,
          'imagePath': _selectedProduct!['imagePath'],
        });
      }

      // 3. إعادة تهيئة حقول الإدخال للمنتج القادم
      _selectedProduct = null;
      _productSearchController.clear();
      _priceController.clear();
      _qtyController.text = '1';
    });
  }

  /// حذف صنف من القائمة
  void _removeItem(int index) {
    setState(() => _invoiceItems.removeAt(index));
  }

  /// 💾 حفظ الفاتورة في قاعدة البيانات
  Future<void> _saveInvoice() async {
    // 1. التحقق من الصلاحيات والبيانات الأساسية
    if (!_canAddOrder) {
      _showError('ليس لديك صلاحية لإضافة فواتير');
      return;
    }
    if (_invoiceItems.isEmpty || _selectedClient == null) {
      _showError('البيانات ناقصة (تأكد من اختيار عميل وإضافة منتجات)');
      return;
    }

    try {
      // 2. استدعاء السيرفيس للحفظ
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

      // 3. نجاح الحفظ -> إظهار رسالة وتصفير الشاشة
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
      _showError('حدث خطأ أثناء الحفظ: $e');
    }
  }

  /// إعادة تعيين الشاشة لوضعها الافتراضي (تفريغ الحقول)
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

  // ============================================================
  // 5️⃣ بناء الواجهة (UI Build Method)
  // ============================================================

  Widget _buildProductImage(String? imagePath, {double size = 25}) {
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

    // ✅ Responsive Logic: تحديد عرض الشاشة لتغيير التخطيط (Layout)
    bool isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيعات'), centerTitle: true),

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 🟥 الجزء الأول: كارت البيانات الأساسية (عميل، تاريخ، رقم فاتورة)
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // الصف الأول: اسم العميل
                      TextField(
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
                      const SizedBox(height: 10),

                      // الصف الثاني: التاريخ ورقم الفاتورة اليدوي
                      Row(
                        children: [
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
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _refController,
                              decoration: const InputDecoration(
                                labelText: 'رقم الفاتورة ',
                                prefixIcon: Icon(Icons.receipt_long, size: 18),
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      const Divider(), // فاصل
                      const SizedBox(height: 5),

                      // الصف الثالث: منطقة إضافة المنتجات (تختلف حسب حجم الشاشة)
                      if (!isWide)
                        // تصميم الموبايل (عناصر فوق بعض)
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
                        // تصميم الكمبيوتر (عناصر بجانب بعض)
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

            // 🟥 الجزء الثاني: قائمة العناصر المضافة (السلة)
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

            // 🟥 الجزء الثالث: لوحة التحكم السفلية (الحسابات والدفع)
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
                        // --- أزرار التحكم في الضرائب والدفع ---
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
                          // كمبيوتر (أفقي وموزع)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildSegmentedPaymentToggle(isDark),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                flex: 2,
                                child: _buildDiscountField(isDark),
                              ),
                              const SizedBox(width: 15),
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

                        // --- ملخص الحسابات (أرقام فقط) ---
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

                        // --- زر الحفظ النهائي ---
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

  // ============================================================
  // 6️⃣ أدوات بناء الواجهة (Widget Builders)
  // ============================================================

  /// إنشاء زر التبديل بين الكاش والآجل
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

  /// حقل إدخال الخصم (Discount Field)
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

  /// زر تبديل الضرائب (Tax Toggle Button)
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

// --- كلاس النص المتحرك (مهم جداً للنصوص الطويلة) ---
/// ويدجت لعرض نص يتحرك تلقائياً (Marquee) إذا كان أطول من المساحة المتاحة
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
