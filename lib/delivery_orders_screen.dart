import 'dart:io'; // للتعامل مع الملفات
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // مكتبة الصور
import 'package:path_provider/path_provider.dart'; // مسار الحفظ
import 'package:open_file/open_file.dart'; // لفتح الصورة
import 'PdfService.dart';
import 'db_helper.dart';
import 'product_search_dialog.dart'; // تأكد أن الاسم مطابق لاسم الملف اللي عملته

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rawOrders = await DatabaseHelper().getAllDeliveryOrders();
    final clients = await DatabaseHelper().getClients();
    final products = await DatabaseHelper().getProducts();

    List<Map<String, dynamic>> enrichedOrders = [];
    for (var order in rawOrders) {
      final items = await DatabaseHelper().getDeliveryOrderItems(order['id']);
      Set<String> allNumbers = {};
      if (order['supplyOrderNumber'] != null &&
          order['supplyOrderNumber'].toString().isNotEmpty) {
        allNumbers.add(order['supplyOrderNumber'].toString());
      }
      for (var item in items) {
        if (item['relatedSupplyOrder'] != null &&
            item['relatedSupplyOrder'].toString().isNotEmpty) {
          allNumbers.add(item['relatedSupplyOrder'].toString());
        }
      }
      Map<String, dynamic> newOrder = Map.from(order);
      newOrder['displaySupplyOrders'] = allNumbers.join(' - ');
      enrichedOrders.add(newOrder);
    }

    setState(() {
      _orders = enrichedOrders;
      _filteredOrders = enrichedOrders;
      _clients = clients;
      _products = products;
    });
  }

  void _filterOrders(String query) {
    setState(() {
      _filteredOrders = _orders.where((order) {
        final client = order['clientName'].toString().toLowerCase();
        final manualNo = order['manualNo']?.toString().toLowerCase() ?? '';
        final allSupplyNums = order['displaySupplyOrders']
            .toString()
            .toLowerCase();
        final q = query.toLowerCase();
        return client.contains(q) ||
            manualNo.contains(q) ||
            allSupplyNums.contains(q);
      }).toList();
    });
  }

  bool hasArabicCharacters(String text) {
    final RegExp arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }

  void _showOrderDialog({
    Map<String, dynamic>? existingOrder,
    List<Map<String, dynamic>>? existingItems,
  }) {
    final isEditing = existingOrder != null;
    final manualNoController = TextEditingController(
      text: isEditing ? existingOrder['manualNo'] : '',
    );
    final addressController = TextEditingController(
      text: isEditing ? existingOrder['address'] : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? existingOrder['notes'] : '',
    );
    final supplyOrderNumber = TextEditingController(
      text: isEditing ? existingOrder['supplyOrderNumber'] : '',
    );
    String? selectedClientName = isEditing ? existingOrder['clientName'] : null;
    DateTime selectedDate = isEditing
        ? DateTime.parse(existingOrder['deliveryDate'])
        : DateTime.now();
    List<Map<String, dynamic>> tempItems = isEditing
        ? List.from(existingItems!)
        : [];

    Set<String> sectionsSet = {''};
    if (isEditing) {
      for (var item in tempItems) {
        if (item['relatedSupplyOrder'] != null &&
            item['relatedSupplyOrder'].toString().isNotEmpty) {
          sectionsSet.add(item['relatedSupplyOrder']);
        }
      }
    }
    List<String> activeSections = sectionsSet.toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          bool isDark = Theme.of(context).brightness == Brightness.dark;
          Color cardColor = isDark ? Colors.grey[850]! : Colors.white;
          Color mainHeaderColor = isDark
              ? Colors.blue.withOpacity(0.2)
              : Colors.blue[50]!;
          Color subHeaderColor = isDark
              ? Colors.orange.withOpacity(0.2)
              : Colors.orange[50]!;
          Color textColor = isDark ? Colors.white : Colors.black87;

          void addItemToSection(String sectionOrderNumber) {
            String? prodName;
            // حقل تحكم لعرض الاسم المختار
            final nameController = TextEditingController();
            final qtyCtrl = TextEditingController(text: '1');
            final descCtrl = TextEditingController();

            showDialog(
              context: context,
              builder: (innerCtx) => AlertDialog(
                title: Text(
                  sectionOrderNumber.isEmpty
                      ? 'إضافة صنف'
                      : 'إضافة لـ ($sectionOrderNumber)',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- بدلاً من القائمة المنسدلة، نستخدم حقل يفتح النافذة ---
                      TextFormField(
                        controller: nameController,
                        readOnly:
                            true, // عشان يمنع الكتابة اليدوية ويجبره يختار
                        decoration: const InputDecoration(
                          labelText: "اختر الصنف",
                          hintText: "اضغط للبحث...",
                          suffixIcon: Icon(Icons.arrow_drop_down),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          // 1. فتح نافذة البحث واستقبال النتيجة
                          final selectedProduct =
                              await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (ctx) =>
                                    ProductSearchDialog(allProducts: _products),
                              );

                          // 2. معالجة الاختيار
                          if (selectedProduct != null) {
                            prodName = selectedProduct['name'];
                            nameController.text =
                                prodName!; // عرض الاسم للمستخدم

                            // تعبئة الوصف تلقائياً (الاسم + الكود)
                            descCtrl.text = "${selectedProduct['name']} ";
                          }
                        },
                      ),

                      // --------------------------------------------------------
                      const SizedBox(height: 10),
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'العدد',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'الوصف',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(innerCtx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (prodName != null) {
                        // الكود القديم للتحقق من العربي (لو لسه محتاجه)
                        if (hasArabicCharacters(prodName!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الاسم يحتوي على عربي!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setStateSB(() {
                          tempItems.add({
                            'productName': prodName,
                            'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                            'description': descCtrl.text,
                            'relatedSupplyOrder': sectionOrderNumber.isEmpty
                                ? null
                                : sectionOrderNumber,
                          });
                        });
                        Navigator.pop(innerCtx);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('برجاء اختيار صنف')),
                        );
                      }
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            );
          }

          void addSection() {
            final sectionCtrl = TextEditingController();
            showDialog(
              context: context,
              builder: (innerCtx) => AlertDialog(
                title: const Text('إضافة أمر توريد فرعي'),
                content: TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الأمر',
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(innerCtx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (sectionCtrl.text.isNotEmpty &&
                          !activeSections.contains(sectionCtrl.text)) {
                        setStateSB(() => activeSections.add(sectionCtrl.text));
                        Navigator.pop(innerCtx);
                      }
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            );
          }

          void deleteSection(String sectionName) {
            setStateSB(() {
              activeSections.remove(sectionName);
              tempItems.removeWhere(
                (item) => (item['relatedSupplyOrder'] ?? '') == sectionName,
              );
            });
          }

          return AlertDialog(
            title: Text(isEditing ? 'تعديل الإذن' : 'إذن تسليم جديد'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedClientName,
                      decoration: const InputDecoration(labelText: 'العميل'),
                      items: _clients
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['name'] as String,
                              child: Text(c['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        selectedClientName = val;
                        final c = _clients.firstWhere((e) => e['name'] == val);
                        addressController.text = c['address'] ?? '';
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: manualNoController,
                            onChanged: (val) => setStateSB(() {}),
                            decoration: const InputDecoration(
                              labelText: 'رقم الإذن',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: TextField(
                            controller: supplyOrderNumber,
                            onChanged: (val) => setStateSB(() {}),
                            decoration: const InputDecoration(
                              labelText: 'أمر توريد رئيسي',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setStateSB(() => selectedDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ التسليم',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}",
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "الأصناف",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: addSection,
                          icon: const Icon(Icons.add),
                          label: const Text("فرعي جديد"),
                        ),
                      ],
                    ),

                    ...activeSections.map((sectionName) {
                      List<Map<String, dynamic>> sectionItems = tempItems.where(
                        (item) {
                          String itemSection = item['relatedSupplyOrder'] ?? '';
                          return itemSection == sectionName;
                        },
                      ).toList();
                      bool isMain = sectionName.isEmpty;

                      String displayTitle;
                      if (isMain) {
                        if (manualNoController.text.isNotEmpty) {
                          displayTitle = manualNoController.text;
                        } else if (supplyOrderNumber.text.isNotEmpty) {
                          displayTitle = "${supplyOrderNumber.text} (توريد)";
                        } else {
                          displayTitle = "عام (بدون رقم)";
                        }
                      } else {
                        displayTitle = "أمر توريد: $sectionName";
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardColor,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isMain
                                    ? mainHeaderColor
                                    : subHeaderColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.green,
                                        ),
                                        onPressed: () =>
                                            addItemToSection(sectionName),
                                      ),
                                      if (!isMain)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              deleteSection(sectionName),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (sectionItems.isNotEmpty)
                              ...sectionItems.map((item) {
                                final realIdx = tempItems.indexOf(item);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    item['productName'],
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => setStateSB(
                                      () => tempItems.removeAt(realIdx),
                                    ),
                                  ),
                                );
                              }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
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
                icon: Icon(isEditing ? Icons.edit : Icons.save),
                label: Text(isEditing ? 'تعديل وحفظ' : 'حفظ جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (selectedClientName != null &&
                      supplyOrderNumber.text.isNotEmpty &&
                      tempItems.isNotEmpty) {
                    if (isEditing) {
                      await DatabaseHelper().updateDeliveryOrder(
                        existingOrder['id'],
                        selectedClientName!,
                        supplyOrderNumber.text,
                        manualNoController.text,
                        addressController.text,
                        selectedDate.toString(),
                        notesController.text,
                        tempItems,
                      );
                    } else {
                      await DatabaseHelper().createDeliveryOrder(
                        selectedClientName!,
                        supplyOrderNumber.text,
                        manualNoController.text,
                        addressController.text,
                        selectedDate.toString(),
                        notesController.text,
                        tempItems,
                      );
                    }
                    Navigator.pop(ctx);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing ? 'تم التعديل بنجاح ✅' : 'تم الحفظ بنجاح ✅',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('برجاء استكمال البيانات'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteOrder(int id, bool isLocked) {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ هذا الإذن موقع ومقفل، قم بإلغاء القفل أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف"),
        content: const Text("هل أنت متأكد من حذف هذا الإذن؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteDeliveryOrder(id);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 🔥 دالة القفل الجديدة (مع رفع الصورة)
  void _toggleLock(int id, bool currentStatus) async {
    if (currentStatus) {
      // لو كان مقفول وهنفتحه (ممكن نضيف تأكيد هنا لو تحب)
      await DatabaseHelper().toggleOrderLock(id, false);
      _loadData();
    } else {
      // لو كان مفتوح وهنقفله -> نعرض ديالوج الصورة
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("تأكيد القفل"),
          content: const Text("هل تريد إرفاق صورة الإذن الموقع من العميل؟"),
          actions: [
            // خيار 1: قفل بدون صورة
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await DatabaseHelper().toggleOrderLock(id, true);
                _loadData();
              },
              child: const Text("لا (قفل فقط)"),
            ),
            // خيار 2: رفع صورة ثم القفل
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("نعم (إرفاق صورة)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );

                if (image != null) {
                  // حفظ الصورة في مجلد التطبيق
                  final appDir = await getApplicationDocumentsDirectory();
                  final fileName =
                      'signed_order_${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final savedImage = await File(
                    image.path,
                  ).copy('${appDir.path}/$fileName');

                  // حفظ المسار في الداتا بيز وقفل الإذن
                  await DatabaseHelper().toggleOrderLock(
                    id,
                    true,
                    imagePath: savedImage.path,
                  );
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ الصورة وقفل الإذن ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  // لو فتح المعرض ومختارش حاجة، مش هنقفل
                }
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('أذونات التسليم')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterOrders('');
                  },
                ),
              ),
              onChanged: _filterOrders,
            ),
          ),

          Expanded(
            child: _filteredOrders.isEmpty
                ? const Center(child: Text("لا توجد نتائج"))
                : ListView.builder(
                    itemCount: _filteredOrders.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      bool isLocked = (order['isLocked'] == 1);
                      // هل يوجد صورة محفوظة؟
                      bool hasImage =
                          order['signedImagePath'] != null &&
                          order['signedImagePath'].toString().isNotEmpty;

                      Color tileColor = isLocked
                          ? (isDark
                                ? Colors.green.withOpacity(0.15)
                                : Colors.green[50]!)
                          : Theme.of(context).cardColor;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: tileColor,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isLocked
                                ? Colors.green
                                : Colors.blue,
                            child: Icon(
                              isLocked ? Icons.check : Icons.description,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                order['clientName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isLocked)
                                const Text(
                                  " (مغلق)",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            "أوامر توريد: ${order['displaySupplyOrders']}",
                            style: TextStyle(
                              color: isLocked ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (order['manualNo'] != null &&
                                      order['manualNo'].toString().isNotEmpty)
                                    Text("رقم الإذن: ${order['manualNo']}"),
                                  Text(
                                    "التاريخ: ${order['deliveryDate'].toString().split(' ')[0]}",
                                  ),
                                  const Divider(),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Switch(
                                            value: isLocked,
                                            activeThumbColor: Colors.green,
                                            onChanged: (val) => _toggleLock(
                                              order['id'],
                                              isLocked,
                                            ),
                                          ),
                                          Text(
                                            isLocked ? "مغلق" : "تعديل",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isLocked
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                          ),

                                          // 🔥 زر عرض الصورة (يظهر فقط لو فيه صورة)
                                          if (hasImage)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8.0,
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.image,
                                                  color: Colors.purple,
                                                ),
                                                tooltip: "خيارات الصورة",
                                                // التعديل هنا 👇
                                                onPressed: () => _manageImage(
                                                  order['id'],
                                                  order['signedImagePath'],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: isLocked
                                                  ? Colors.grey
                                                  : Colors.red,
                                            ),
                                            onPressed: () => _deleteOrder(
                                              order['id'],
                                              isLocked,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              color: isLocked
                                                  ? Colors.grey
                                                  : Colors.orange,
                                            ),
                                            onPressed: isLocked
                                                ? null
                                                : () async {
                                                    int orderId =
                                                        int.tryParse(
                                                          order['id']
                                                              .toString(),
                                                        ) ??
                                                        0;
                                                    List<Map<String, dynamic>>
                                                    orderItems =
                                                        await DatabaseHelper()
                                                            .getDeliveryOrderItems(
                                                              orderId,
                                                            );
                                                    _showOrderDialog(
                                                      existingOrder: order,
                                                      existingItems: orderItems,
                                                    );
                                                  },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.print,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () async {
                                              int orderId =
                                                  int.tryParse(
                                                    order['id'].toString(),
                                                  ) ??
                                                  0;
                                              List<Map<String, dynamic>>
                                              orderItems =
                                                  await DatabaseHelper()
                                                      .getDeliveryOrderItems(
                                                        orderId,
                                                      );
                                              await PdfService.generateDeliveryOrderPdf(
                                                order,
                                                orderItems,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOrderDialog(),
        backgroundColor: Colors.blue[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // دالة إدارة الصورة (عرض - تغيير - حذف)
  void _manageImage(int orderId, String imagePath) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "خيارات صورة الإذن",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),

            // 1. عرض الصورة
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text("عرض الصورة"),
              onTap: () {
                Navigator.pop(ctx);
                OpenFile.open(imagePath);
              },
            ),

            // 2. تغيير الصورة
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text("تغيير الصورة"),
              onTap: () async {
                Navigator.pop(ctx);
                // التقاط صورة جديدة
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  final appDir = await getApplicationDocumentsDirectory();
                  final fileName =
                      'signed_order_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final savedImage = await File(
                    image.path,
                  ).copy('${appDir.path}/$fileName');

                  // تحديث الداتابيز
                  await DatabaseHelper().updateOrderImage(
                    orderId,
                    savedImage.path,
                  );
                  _loadData(); // تحديث الشاشة
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير الصورة بنجاح ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),

            // 3. حذف الصورة
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("حذف الصورة"),
              onTap: () async {
                Navigator.pop(ctx);
                // تأكيد الحذف
                showDialog(
                  context: context,
                  builder: (alertCtx) => AlertDialog(
                    title: const Text("حذف الصورة"),
                    content: const Text("هل أنت متأكد من حذف صورة الإذن؟"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(alertCtx),
                        child: const Text("إلغاء"),
                      ),
                      TextButton(
                        onPressed: () async {
                          await DatabaseHelper().updateOrderImage(
                            orderId,
                            null,
                          ); // نبعت null عشان نمسح
                          Navigator.pop(alertCtx);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف الصورة 🗑️'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: const Text(
                          "حذف",
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
  }
}
