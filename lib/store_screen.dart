import 'dart:io';
import 'package:flutter/material.dart';
import 'pb_helper.dart';
import 'product_history_screen.dart';
import 'product_dialog.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'all';

  // ✅ 1. تعريف متغيرات الصلاحيات داخل الكلاس
  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;

  // الآيدي الخاص بالسوبر أدمن
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions(); // ✅ فحص الصلاحيات عند الفتح
  }

  // ✅ 2. دالة تحميل الصلاحيات من الداتا بيز
  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    // لو أنا السوبر أدمن -> كل حاجة مسموحة
    if (myId == _superAdminId) {
      if (mounted) {
        setState(() {
          _canAdd = true;
          _canEdit = true;
          _canDelete = true;
        });
      }
      return;
    }

    // لو يوزر عادي -> نجيب صلاحياته
    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAdd = userRecord.data['allow_add_products'] ?? false;
          _canEdit = userRecord.data['allow_edit_products'] ?? false;
          _canDelete = userRecord.data['allow_delete_products'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الصلاحيات: $e");
    }
  }

  // --- دوال مساعدة ---
  int _checkExpiryStatus(Map<String, dynamic> product) {
    if (product['expiryDate'] == null ||
        product['expiryDate'].toString().isEmpty) {
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

  void _openProductDialog({Map<String, dynamic>? product}) async {
    // حماية إضافية: لو يحاول يفتح ديالوج وهو ممنوع
    if (product == null && !_canAdd) return;
    if (product != null && !_canEdit) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductDialog(product: product),
    );
  }

  void _deleteProduct(String id) {
    if (!_canDelete) return; // حماية

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصنف'),
        content: const Text('هل أنت متأكد؟ سيتم الحذف نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await PBHelper().deleteProduct(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم الحذف'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showZoomedImage(String imagePath) {
    ImageProvider imageProvider;
    if (imagePath.startsWith('http')) {
      imageProvider = NetworkImage(imagePath);
    } else {
      imageProvider = FileImage(File(imagePath));
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image(image: imageProvider),
        ),
      ),
    );
  }

  // --- الفلتر ---
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
                Icons.broken_image,
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
        setState(() => _filterType = value);
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المخزن والأصناف')),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'بحث (اسم، كود، باركود)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
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
                    tooltip: 'تصفية',
                  ),
                ),
              ],
            ),
          ),

          // القائمة
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: PBHelper().getCollectionStream(
                'products',
                sort: '-created',
                expand: 'supplier',
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return const Center(child: Text("خطأ في الاتصال"));

                final allProducts = snapshot.data ?? [];

                // الفلترة
                final filteredList = allProducts.where((product) {
                  final keyword = _searchController.text.toLowerCase();
                  final name = (product['name'] ?? '').toString().toLowerCase();
                  final code = (product['code'] ?? '').toString().toLowerCase();
                  final barcode = (product['barcode'] ?? '')
                      .toString()
                      .toLowerCase();
                  bool matchesSearch =
                      name.contains(keyword) ||
                      code.contains(keyword) ||
                      barcode.contains(keyword);

                  if (!matchesSearch) return false;

                  if (_filterType == 'expired')
                    return _checkExpiryStatus(product) == 1;
                  if (_filterType == 'near_expiry')
                    return _checkExpiryStatus(product) == 2;
                  if (_filterType == 'low_stock') {
                    int stock = (product['stock'] as num).toInt();
                    int reorder =
                        (product['reorderLevel'] as num?)?.toInt() ?? 0;
                    return stock <= reorder;
                  }
                  if (_filterType == 'damaged') {
                    int damaged =
                        (product['damagedStock'] as num?)?.toInt() ?? 0;
                    return damaged > 0;
                  }
                  return true;
                }).toList();

                if (filteredList.isEmpty)
                  return const Center(child: Text('لا توجد أصناف'));

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    top: 5,
                    bottom: 100,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(filteredList[index], isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // ✅ 3. إخفاء زر الإضافة لو مفيش صلاحية
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openProductDialog(),
              label: const Text(
                'صنف جديد',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add_box, color: Colors.white),
              backgroundColor: Colors.blue[900],
            )
          : null,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    int stock = (product['stock'] as num).toInt();
    int reorder = (product['reorderLevel'] as num?)?.toInt() ?? 0;
    int damaged = (product['damagedStock'] as num?)?.toInt() ?? 0;
    bool isLowStock = stock <= reorder;
    int expiryStatus = _checkExpiryStatus(product);

    Color? cardColor;
    Color statusColor = Colors.grey;
    String statusText = "";

    if (expiryStatus == 1) {
      cardColor = isDark ? Colors.red.withOpacity(0.15) : Colors.red[50];
      statusColor = Colors.red;
      statusText = "منتهي!";
    } else if (expiryStatus == 2) {
      cardColor = isDark ? Colors.yellow.withOpacity(0.1) : Colors.yellow[50];
      statusColor = Colors.orange[800]!;
      statusText = "قرب الانتهاء";
    } else if (isLowStock) {
      cardColor = isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50];
      statusColor = Colors.deepOrange;
      statusText = "نواقص";
    }

    ImageProvider? listImageProvider;
    if (product['imagePath'] != null &&
        product['imagePath'].toString().isNotEmpty) {
      if (product['imagePath'].toString().startsWith('http')) {
        listImageProvider = NetworkImage(product['imagePath']);
      } else {
        listImageProvider = FileImage(File(product['imagePath']));
      }
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: GestureDetector(
          onTap: listImageProvider != null
              ? () => _showZoomedImage(product['imagePath'])
              : null,
          child: CircleAvatar(
            backgroundColor: statusText.isNotEmpty
                ? statusColor.withOpacity(0.2)
                : Colors.blue.withOpacity(0.1),
            backgroundImage: listImageProvider,
            child: listImageProvider == null
                ? Icon(
                    expiryStatus == 1
                        ? Icons.warning
                        : (isLowStock
                              ? Icons.trending_down
                              : Icons.inventory_2),
                    color: statusText.isNotEmpty ? statusColor : Colors.blue,
                  )
                : null,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (statusText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
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
                  'سعر: ${product['sellPrice']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.greenAccent : Colors.green,
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  'رصيد: $stock',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (damaged > 0) ...[
                  const SizedBox(width: 15),
                  Text(
                    'تالف: $damaged',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // سجل الحركة (متاح دائماً لمن يرى الشاشة)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.teal),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductHistoryScreen(product: product),
                ),
              ),
            ),

            // ✅ 4. زر التعديل (يظهر فقط لو مسموح)
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _openProductDialog(product: product),
              ),

            // ✅ 5. زر الحذف (يظهر فقط لو مسموح)
            if (_canDelete)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteProduct(product['id']),
              ),
          ],
        ),
      ),
    );
  }
}
