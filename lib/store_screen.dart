import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🆕 مكتبة ضرورية للتحكم في المدخلات (أرقام فقط)
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'db_helper.dart';
import 'product_history_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<String> _units = [];

  // Controllers
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _minSellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  final _damagedStockController = TextEditingController();
  String _selectedUnit = 'قطعة';
  DateTime? _expiryDate;
  String? _selectedImagePath;

  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    final products = await DatabaseHelper().getProducts();
    final unitsData = await DatabaseHelper().getUnits();

    setState(() {
      _products = products;
      _units = unitsData.map((u) => u['name'] as String).toList();
      if (_units.isNotEmpty && !_units.contains(_selectedUnit)) {
        _selectedUnit = _units.first;
      } else if (_units.isEmpty) {
        _selectedUnit = '';
      }
      _runFilter(_searchController.text);
    });
  }

  Future<void> _pickImage(StateSetter setStateDialog) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // 1. التغيير هنا: نستخدم getApplicationSupportDirectory بدلاً من Documents
      // هذا المسار مخفي وآمن ومخصص لبيانات البرنامج
      final appDir = await getApplicationSupportDirectory();

      // 2. إنشاء فولدر فرعي مخصص للصور داخل مسار البرنامج
      // في ويندوز هيكون: AppData/Roaming/com.example.al_sakr/product_images
      final imagesDir = Directory('${appDir.path}/product_images');

      // لو الفولدر مش موجود، ننشئه
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // 3. تسمية الصورة وحفظها
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(
        pickedFile.path,
      ).copy('${imagesDir.path}/$fileName');

      // طباعة المسار للتأكد (اختياري)
      print("تم حفظ الصورة في مكان آمن: ${savedImage.path}");

      setStateDialog(() {
        _selectedImagePath = savedImage.path;
      });
    }
  }

  // --- 🆕 دالة عرض الصورة المكبرة (Zoom) ---
  void _showZoomedImage(String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, // خلفية شفافة
        insetPadding: const EdgeInsets.all(10), // حواف قليلة لتعظيم الصورة
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // عارض الصور التفاعلي (يسمح بالتكبير والتصغير)
            InteractiveViewer(
              panEnabled: true, // السماح بالتحريك
              minScale: 0.5,
              maxScale: 4, // تكبير حتى 4 أضعاف
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(File(imagePath)),
              ),
            ),
            // زر إغلاق صغير
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runFilter(String keyword) {
    List<Map<String, dynamic>> results = _products;

    if (_filterType == 'expired') {
      results = results.where((p) => _checkExpiryStatus(p) == 1).toList();
    } else if (_filterType == 'near_expiry') {
      results = results.where((p) => _checkExpiryStatus(p) == 2).toList();
    } else if (_filterType == 'low_stock') {
      results = results.where((p) {
        int stock = p['stock'] ?? 0;
        int reorder = p['reorderLevel'] ?? 0;
        return stock <= reorder;
      }).toList();
    } else if (_filterType == 'damaged') {
      results = results.where((p) {
        int damaged = p['damagedStock'] ?? 0;
        return damaged > 0; // هات الأصناف اللي التالف فيها أكبر من صفر
      }).toList();
    }
    if (keyword.isNotEmpty) {
      results = results.where((product) {
        final name = product['name'].toString().toLowerCase();
        final code = product['code']?.toString().toLowerCase() ?? '';
        final barcode = product['barcode']?.toString().toLowerCase() ?? '';
        final input = keyword.toLowerCase();
        return name.contains(input) ||
            code.contains(input) ||
            barcode.contains(input);
      }).toList();
    }

    setState(() {
      _filteredProducts = results;
    });
  }

  int _checkExpiryStatus(Map<String, dynamic> product) {
    if (product['expiryDate'] == null || product['expiryDate'] == 'null') {
      return 0;
    }
    DateTime exp = DateTime.parse(product['expiryDate']);
    DateTime now = DateTime.now();
    DateTime expDateOnly = DateTime(exp.year, exp.month, exp.day);
    DateTime nowDateOnly = DateTime(now.year, now.month, now.day);
    int daysLeft = expDateOnly.difference(nowDateOnly).inDays;

    if (daysLeft < 0) return 1;
    if (daysLeft <= 30) return 2;
    return 0;
  }

  void _showFilterOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "تصفية المنتجات",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _buildFilterOption(ctx, "الكل", 'all', Icons.list, Colors.blue),
              _buildFilterOption(
                ctx,
                "النواقص",
                'low_stock',
                Icons.trending_down,
                Colors.orange,
              ),
              _buildFilterOption(
                ctx,
                "التوالف",
                'damaged',
                Icons.broken_image, // أيقونة معبرة
                Colors.redAccent,
              ),
              _buildFilterOption(
                ctx,
                "منتهي الصلاحية",
                'expired',
                Icons.warning,
                Colors.red,
              ),
              _buildFilterOption(
                ctx,
                "قرب الانتهاء",
                'near_expiry',
                Icons.access_time,
                Colors.yellow[700]!,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    BuildContext ctx,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _filterType == value;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? color : null,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: color) : null,
      onTap: () {
        setState(() {
          _filterType = value;
          _runFilter(_searchController.text);
        });
        Navigator.pop(ctx);
      },
    );
  }

  Future<void> _showManageUnitsDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدارة الوحدات'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StatefulBuilder(
            builder: (context, setStateList) {
              return _units.isEmpty
                  ? const Center(child: Text('لا توجد وحدات'))
                  : ListView.separated(
                      itemCount: _units.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (c, i) {
                        final u = _units[i];
                        return ListTile(
                          title: Text(u),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await DatabaseHelper().deleteUnit(u);
                              final updated = await DatabaseHelper().getUnits();
                              final newUnits = updated
                                  .map((x) => x['name'] as String)
                                  .toList();
                              setStateList(() {
                                _units = newUnits;
                              });
                              _refreshData();
                            },
                          ),
                        );
                      },
                    );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddUnitDialog() async {
    TextEditingController c = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('وحدة جديدة'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'أدخل اسم الوحدة'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (c.text.isNotEmpty) {
                await DatabaseHelper().insertUnit(c.text);
                if (!mounted) return;
                Navigator.pop(ctx);
                _refreshData();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تمت الإضافة')));
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(int id) async {
    await DatabaseHelper().deleteProduct(id);
    _refreshData();
  }

  void _clearControllers() {
    _nameController.clear();
    _codeController.clear();
    _barcodeController.clear();
    _buyPriceController.clear();
    _sellPriceController.clear();
    _minSellPriceController.clear();
    _stockController.clear();
    _reorderLevelController.clear();
    _notesController.clear();
    _damagedStockController.clear(); // 🆕 ضيف ده
    _selectedUnit = _units.isNotEmpty ? _units.first : 'قطعة';
    _expiryDate = null;
    _selectedImagePath = null;
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (product != null) {
      _nameController.text = product['name'];
      _codeController.text = product['code'] ?? '';
      _barcodeController.text = product['barcode'] ?? '';
      _buyPriceController.text = product['buyPrice'].toString();
      _sellPriceController.text = product['sellPrice'].toString();
      _minSellPriceController.text = product['minSellPrice']?.toString() ?? '0';
      _stockController.text = product['stock'].toString();
      _reorderLevelController.text = product['reorderLevel']?.toString() ?? '0';
      _damagedStockController.text = (product['damagedStock'] ?? 0).toString();
      _notesController.text = product['notes'] ?? '';
      _selectedUnit =
          product['unit'] ?? (_units.isNotEmpty ? _units.first : 'قطعة');
      _expiryDate = product['expiryDate'] != null
          ? DateTime.parse(product['expiryDate'])
          : null;
      _selectedImagePath = product['imagePath'];
    } else {
      _clearControllers();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSB) {
          Future<void> refreshUnitsInsideDialog() async {
            final uData = await DatabaseHelper().getUnits();
            final newUnits = uData.map((e) => e['name'] as String).toList();
            setStateSB(() {
              _units = newUnits;
              if (!_units.contains(_selectedUnit)) {
                _selectedUnit = _units.isNotEmpty ? _units.first : '';
              }
            });
          }

          return AlertDialog(
            title: Text(
              product == null ? 'تسجيل صنف جديد' : 'تعديل بيانات الصنف',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(setStateSB),
                        // 🆕 عند الضغط على الصورة في وضع التعديل، اعرضها مكبرة
                        onLongPress: (_selectedImagePath != null)
                            ? () => _showZoomedImage(_selectedImagePath!)
                            : null,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          backgroundImage: _selectedImagePath != null
                              ? FileImage(File(_selectedImagePath!))
                              : null,
                          child: _selectedImagePath == null
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 30,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (_selectedImagePath != null)
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              setStateSB(() => _selectedImagePath = null),
                          child: const Text(
                            "حذف الصورة",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),

                    _buildSectionTitle('البيانات الأساسية'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _codeController,
                            'كود داخلي',
                            Icons.qr_code,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _barcodeController,
                            'باركود',
                            Icons.qr_code_scanner,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      _nameController,
                      'اسم الصنف',
                      Icons.shopping_bag,
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _units.isEmpty
                              ? const Text("لا توجد وحدات، أضف واحدة +")
                              : DropdownButtonFormField<String>(
                                  initialValue: _units.contains(_selectedUnit)
                                      ? _selectedUnit
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'الوحدة',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.scale),
                                  ),
                                  items: _units
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(u),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setStateSB(() => _selectedUnit = val!),
                                ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.blue),
                            tooltip: 'إضافة وحدة',
                            onPressed: () async {
                              await _showAddUnitDialog();
                              await refreshUnitsInsideDialog();
                            },
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.red.withOpacity(0.2)
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'حذف وحدات',
                            onPressed: () async {
                              await _showManageUnitsDialog();
                              await refreshUnitsInsideDialog();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('التسعير والصلاحية'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _buyPriceController,
                            'سعر الشراء',
                            Icons.attach_money,
                            isNumber: true, // ✅ تقبل أرقام فقط
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _sellPriceController,
                            'سعر البيع',
                            Icons.sell,
                            isNumber: true, // ✅ تقبل أرقام فقط
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      _minSellPriceController,
                      'أقل سعر بيع',
                      Icons.price_check,
                      isNumber: true, // ✅ تقبل أرقام فقط
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate:
                              _expiryDate ??
                              DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? const ColorScheme.dark(primary: Colors.blue)
                                  : const ColorScheme.light(
                                      primary: Colors.blue,
                                    ),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setStateSB(() => _expiryDate = d);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تاريخ الصلاحية (اختياري)',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: const OutlineInputBorder(),
                          suffixIcon: _expiryDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () =>
                                      setStateSB(() => _expiryDate = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _expiryDate != null
                              ? "${_expiryDate!.year}-${_expiryDate!.month}-${_expiryDate!.day}"
                              : 'لا يوجد تاريخ',
                          style: TextStyle(
                            color: _expiryDate != null
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('المخزون'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _stockController,
                            'الرصيد السليم',
                            Icons.inventory,
                            isNumber: true, // ✅ تقبل أرقام فقط
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _damagedStockController, // 🆕 خانة التوالف
                            'التوالف/هالك',
                            Icons.broken_image_outlined,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _reorderLevelController,
                            'حد الطلب',
                            Icons.warning_amber,
                            isNumber: true, // ✅ تقبل أرقام فقط
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.blue[800] : Colors.blue[900],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                onPressed: () async {
                  if (_nameController.text.isEmpty) return;
                  Map<String, dynamic> row = {
                    'name': _nameController.text,
                    'code': _codeController.text,
                    'barcode': _barcodeController.text,
                    'unit': _selectedUnit,
                    'buyPrice': double.tryParse(_buyPriceController.text) ?? 0,
                    'sellPrice':
                        double.tryParse(_sellPriceController.text) ?? 0,
                    'minSellPrice':
                        double.tryParse(_minSellPriceController.text) ?? 0,
                    'stock': int.tryParse(_stockController.text) ?? 0,
                    'reorderLevel':
                        int.tryParse(_reorderLevelController.text) ?? 0,
                    'damagedStock':
                        int.tryParse(_damagedStockController.text) ?? 0,
                    'supplierId': null,
                    'notes': _notesController.text,
                    'expiryDate': _expiryDate?.toString(),
                    'imagePath': _selectedImagePath,
                  };
                  if (product == null)
                    await DatabaseHelper().insertProduct(row);
                  else {
                    row['id'] = product['id'];
                    await DatabaseHelper().updateProduct(row);
                  }
                  _clearControllers();
                  Navigator.pop(context);
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم الحفظ بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'حفظ البيانات',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 🆕 الودجت المعدلة لإجبار الخانات على الأرقام ---
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      // 🆕 هذا السطر هو السحر: يسمح فقط بالأرقام والنقطة
      inputFormatters: isNumber
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ] // أرقام وكسور عشرية فقط
          : [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isDark ? Colors.tealAccent : Colors.teal[800],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المخزن والأصناف')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _runFilter(val),
                    decoration: InputDecoration(
                      labelText: 'بحث (اسم، كود، باركود)...',
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
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _filterType == 'all'
                        ? (isDark ? Colors.grey[800] : Colors.white)
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: _filterType == 'all'
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.white,
                    ),
                    onPressed: _showFilterOptions,
                    tooltip: 'تصفية المنتجات',
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('لا توجد أصناف تطابق البحث'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];

                      int stock = product['stock'] ?? 0;
                      int reorder = product['reorderLevel'] ?? 0;
                      int damaged = product['damagedStock'] ?? 0;
                      bool isLowStock = stock <= reorder;
                      int expiryStatus = _checkExpiryStatus(product);

                      Color? cardColor;
                      Color statusColor = Colors.grey;
                      String statusText = "";

                      if (expiryStatus == 1) {
                        cardColor = isDark
                            ? Colors.red.withOpacity(0.15)
                            : Colors.red[50];
                        statusColor = Colors.red;
                        statusText = "منتهي الصلاحية!";
                      } else if (expiryStatus == 2) {
                        cardColor = isDark
                            ? Colors.yellow.withOpacity(0.1)
                            : Colors.yellow[50];
                        statusColor = Colors.orange[800]!;
                        statusText = "قرب الانتهاء";
                      } else if (isLowStock) {
                        cardColor = isDark
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.orange[50];
                        statusColor = Colors.deepOrange;
                        statusText = "الكمية منخفضة ($stock)";
                      }

                      // 🆕 عرض الصورة في القائمة (قابلة للتكبير)
                      Widget productLeading;
                      if (product['imagePath'] != null &&
                          File(product['imagePath']).existsSync()) {
                        productLeading = GestureDetector(
                          // عند الضغط على الصورة في القائمة، تفتح مكبرة
                          onTap: () => _showZoomedImage(product['imagePath']),
                          child: CircleAvatar(
                            backgroundImage: FileImage(
                              File(product['imagePath']),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                        );
                      } else {
                        productLeading = CircleAvatar(
                          backgroundColor: statusText.isNotEmpty
                              ? statusColor.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.1),
                          child: Icon(
                            expiryStatus == 1
                                ? Icons.warning
                                : (isLowStock
                                      ? Icons.trending_down
                                      : Icons.inventory_2),
                            color: statusText.isNotEmpty
                                ? statusColor
                                : Colors.blue,
                          ),
                        );
                      }

                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: productLeading, // ✅ الصورة هنا
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (statusText.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'سعر: ${product['sellPrice']} ج.م',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.greenAccent
                                          : Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    'المخزون: $stock',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (damaged > 0) ...[
                                    const SizedBox(width: 15),
                                    Text(
                                      'تالف: $damaged',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red, // لون مميز
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (product['expiryDate'] != null)
                                Text(
                                  'الصلاحية: ${product['expiryDate'].toString().split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: expiryStatus == 1
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.history,
                                  color: Colors.teal,
                                ),
                                tooltip: 'سجل الحركات',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProductHistoryScreen(
                                            product: product,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () =>
                                    _showProductDialog(product: product),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('حذف الصنف'),
                                      content: const Text('تأكيد الحذف؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteProduct(product['id']);
                                          },
                                          child: const Text(
                                            'حذف',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
        onPressed: () => _showProductDialog(),
        label: const Text('صنف جديد', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_box, color: Colors.white),
        backgroundColor: Colors.blue[900],
      ),
    );
  }
}
