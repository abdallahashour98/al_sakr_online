import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'pb_helper.dart';

class ProductDialog extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductDialog({super.key, this.product});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  // Controllers
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _minSellPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _damagedStockController = TextEditingController(
    text: '0',
  ); // حقل التالف
  final _reorderLevelController = TextEditingController(text: '5');
  final _notesController = TextEditingController();

  List<String> _units = [];
  String _selectedUnit = 'قطعة';
  DateTime? _expiryDate;
  String? _selectedImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    if (widget.product != null) {
      _initExistingData();
    }
  }

  void _initExistingData() {
    final p = widget.product!;
    _nameController.text = p['name'];
    _codeController.text = p['code'] ?? '';
    _barcodeController.text = p['barcode'] ?? '';
    _buyPriceController.text = p['buyPrice'].toString();
    _sellPriceController.text = p['sellPrice'].toString();
    _minSellPriceController.text = p['minSellPrice']?.toString() ?? '0';
    _stockController.text = p['stock'].toString();
    _damagedStockController.text = (p['damagedStock'] ?? 0).toString();
    _reorderLevelController.text = p['reorderLevel']?.toString() ?? '0';
    _notesController.text = p['notes'] ?? '';
    _selectedUnit = p['unit'] ?? 'قطعة';
    if (p['expiryDate'] != null && p['expiryDate'].toString().isNotEmpty) {
      _expiryDate = DateTime.parse(p['expiryDate']);
    }
    _selectedImagePath = p['imagePath'];
  }

  Future<void> _loadUnits() async {
    final unitsData = await PBHelper().getUnits();
    if (mounted) {
      setState(() {
        _units = unitsData;
        if (_units.isEmpty) {
          _units = ['قطعة', 'كرتونة'];
        }
        if (!_units.contains(_selectedUnit) && _units.isNotEmpty) {
          _selectedUnit = _units.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // نستخدم ثيم غامق افتراضي للتصميم
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1E1E1E), // لون خلفية غامق (مثل الصورة)
      child: Container(
        width: 650, // عرض مناسب
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- العنوان ---
              Text(
                widget.product == null
                    ? 'تسجيل صنف جديد'
                    : 'تعديل بيانات الصنف',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // --- الصورة ---
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _getImageProvider(),
                    child: _selectedImagePath == null
                        ? const Icon(
                            Icons.camera_alt,
                            size: 35,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
              if (_selectedImagePath != null)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _selectedImagePath = null),
                    child: const Text(
                      "حذف الصورة",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ================= القسم الأول: البيانات الأساسية =================
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
              _buildTextField(_nameController, 'اسم الصنف', Icons.shopping_bag),
              const SizedBox(height: 10),

              // --- صف الوحدات ---
              Stack(
                children: [
                  Container(
                    height: 50, // نفس ارتفاع الـ TextFields
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey[600]!),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.scale,
                          color: Colors.grey,
                          size: 20,
                        ), // أيقونة الميزان
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _units.contains(_selectedUnit)
                                  ? _selectedUnit
                                  : null,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              hint: const Text(
                                "الوحدة",
                                style: TextStyle(color: Colors.grey),
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
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
                                  setState(() => _selectedUnit = val!),
                            ),
                          ),
                        ),
                        // الخط الفاصل
                        Container(
                          width: 1,
                          color: Colors.grey[600],
                          margin: const EdgeInsets.symmetric(vertical: 5),
                        ),
                        // أزرار التحكم
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          tooltip: "إضافة وحدة",
                          onPressed: _showAddUnitDialog,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: "حذف وحدة",
                          onPressed: _showManageUnitsDialog,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      color: const Color(
                        0xFF1E1E1E,
                      ), // نفس لون الخلفية عشان يغطي الخط
                      child: Text(
                        'الوحدة',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ================= القسم الثاني: التسعير والصلاحية =================
              _buildSectionTitle('التسعير والصلاحية'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _buyPriceController,
                      'سعر الشراء',
                      Icons.attach_money,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _sellPriceController,
                      'سعر البيع',
                      Icons.local_offer,
                      isNumber: true,
                    ), // أيقونة التاج
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _minSellPriceController,
                'أقل سعر بيع',
                Icons.price_check,
                isNumber: true,
              ),
              const SizedBox(height: 10),

              // --- تاريخ الصلاحية ---
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        _expiryDate ??
                        DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _expiryDate = d);
                },
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _expiryDate != null
                            ? "${_expiryDate!.year}-${_expiryDate!.month}-${_expiryDate!.day}"
                            : 'لا يوجد تاريخ',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      if (_expiryDate != null)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _expiryDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              // Label لتاريخ الصلاحية
              Transform.translate(
                offset: const Offset(0, -58),
                child: Padding(
                  padding: const EdgeInsets.only(right: 15), // حسب اتجاه اللغة
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.start, // لو انجليزي end
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        color: const Color(0xFF1E1E1E),
                        child: Text(
                          'تاريخ الصلاحية (اختياري)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 0), // قللنا المسافة عشان الترحيل اللي فوق
              // ================= القسم الثالث: المخزون =================
              _buildSectionTitle('المخزون'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _stockController,
                      'الرصيد السليم',
                      Icons.inventory_2,
                      isNumber: true,
                    ), // الصندوق
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _damagedStockController,
                      'التوالف/هالك',
                      Icons.broken_image,
                      isNumber: true,
                    ), // صورة مكسورة
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      _reorderLevelController,
                      'حد الطلب',
                      Icons.warning_amber,
                      isNumber: true,
                    ), // المثلث
                  ),
                ],
              ),

              const SizedBox(height: 10),
              _buildTextField(_notesController, 'ملاحظات', Icons.note),

              const SizedBox(height: 30),

              // ================= الأزرار (Footer) =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: _isLoading ? null : _saveProduct,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'حفظ البيانات',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets مساعدة للتصميم (Helper Widgets) ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.tealAccent, // اللون السماوي
        ),
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
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : [],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 10,
        ),
        isDense: true,
      ),
    );
  }

  // --- Logic Functions (نفس المنطق السابق) ---

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم الصنف')));
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> data = {
      'name': _nameController.text,
      'code': _codeController.text,
      'barcode': _barcodeController.text,
      'unit': _selectedUnit,
      'buyPrice': double.tryParse(_buyPriceController.text) ?? 0.0,
      'sellPrice': double.tryParse(_sellPriceController.text) ?? 0.0,
      'minSellPrice': double.tryParse(_minSellPriceController.text) ?? 0.0,
      'stock': int.tryParse(_stockController.text) ?? 0,
      'reorderLevel': int.tryParse(_reorderLevelController.text) ?? 0,
      'damagedStock':
          int.tryParse(_damagedStockController.text) ?? 0, // ✅ إضافة التالف
      'notes': _notesController.text,
      'expiryDate': _expiryDate?.toIso8601String(),
    };

    try {
      if (widget.product == null) {
        final record = await PBHelper().insertProduct(data, _selectedImagePath);
        if (mounted) {
          Navigator.pop(context, {
            'id': record.id,
            'name': data['name'],
            'buyPrice': data['buyPrice'],
            'sellPrice': data['sellPrice'],
            'stock': data['stock'],
            'imagePath': _selectedImagePath,
          });
        }
      } else {
        String? imageToUpload;
        if (_selectedImagePath != null &&
            !_selectedImagePath!.startsWith('http')) {
          imageToUpload = _selectedImagePath;
        }
        await PBHelper().updateProduct(
          widget.product!['id'],
          data,
          imageToUpload,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider? _getImageProvider() {
    if (_selectedImagePath != null && _selectedImagePath!.isNotEmpty) {
      if (_selectedImagePath!.startsWith('http')) {
        return NetworkImage(_selectedImagePath!);
      } else {
        return FileImage(File(_selectedImagePath!));
      }
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImagePath = picked.path);
    }
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
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (c.text.isNotEmpty) {
                await PBHelper().insertUnit(c.text);
                Navigator.pop(ctx);
                _loadUnits();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageUnitsDialog() async {
    List<String> localUnits = List.from(_units);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('حذف الوحدات'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: localUnits.isEmpty
                  ? const Center(child: Text("لا توجد وحدات"))
                  : ListView.separated(
                      itemCount: localUnits.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (c, i) {
                        final u = localUnits[i];
                        return ListTile(
                          title: Text(u),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              try {
                                await PBHelper().deleteUnit(u);
                                setStateDialog(() {
                                  localUnits.removeAt(i);
                                });
                              } catch (e) {
                                print(e);
                              }
                            },
                          ),
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
          );
        },
      ),
    );
    await _loadUnits();
  }
}
