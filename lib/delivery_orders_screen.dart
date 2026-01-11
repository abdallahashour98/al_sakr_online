import 'package:al_sakr/services/sales_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'PdfService.dart';
import 'services/inventory_service.dart';
import 'product_search_dialog.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  List<Map<String, dynamic>> _allOrdersFlat = [];
  Map<String, List<Map<String, dynamic>>> _groupedOrders = {};

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  bool _canAdd = false;
  bool _canDelete = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData(); // تحميل أولي

    // ✅ الاشتراك في التحديثات اللحظية (Real-time)
    // عند حدوث أي تغيير (إضافة/تعديل/حذف) في جدول الأذونات، نعيد تحميل البيانات
    InventoryService().pb.collection('delivery_orders').subscribe('*', (e) {
      if (mounted) {
        // نمرر false عشان الشاشة متعملش وميض (Loading) مزعج، بل تحدث البيانات في الخلفية
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    // ✅ إلغاء الاشتراك عند الخروج لتوفير الموارد
    InventoryService().pb.collection('delivery_orders').unsubscribe('*');
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final myId = InventoryService().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canAdd = true;
          _canDelete = true;
        });
      return;
    }

    try {
      final userRecord = await InventoryService().pb
          .collection('users')
          .getOne(myId);
      if (mounted) {
        setState(() {
          _canAdd = userRecord.data['allow_add_delivery'] ?? false;
          _canDelete = userRecord.data['allow_delete_delivery'] ?? false;
        });
      }
    } catch (e) {
      //
    }
  }

  // ✅ تعديل الدالة لتقبل showLoading للتحكم في ظهور التحميل
  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    final rawOrders = await SalesService().getAllDeliveryOrders();
    // نجلب العملاء والمنتجات فقط إذا كانت القوائم فارغة (تحسين للأداء)
    if (_clients.isEmpty) {
      final clients = await SalesService().getClients();
      final products = await InventoryService().getProducts();
      if (mounted) {
        setState(() {
          _clients = clients;
          _products = products;
        });
      }
    }

    List<Map<String, dynamic>> enrichedOrders = [];

    // معالجة البيانات (تجميع أرقام أوامر التوريد)
    for (var order in rawOrders) {
      final items = await SalesService().getDeliveryOrderItems(order['id']);
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

    enrichedOrders.sort((a, b) {
      String dateA = a['created'] ?? '';
      String dateB = b['created'] ?? '';
      return dateB.compareTo(dateA);
    });

    _allOrdersFlat = enrichedOrders;
    _groupOrders(_allOrdersFlat);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _groupOrders(List<Map<String, dynamic>> ordersList) {
    Map<String, List<Map<String, dynamic>>> tempGrouped = {};

    for (var order in ordersList) {
      String clientName = order['clientName'] ?? 'عميل غير معروف';
      if (!tempGrouped.containsKey(clientName)) {
        tempGrouped[clientName] = [];
      }
      tempGrouped[clientName]!.add(order);
    }

    if (mounted) {
      setState(() {
        _groupedOrders = tempGrouped;
      });
    }
  }

  void _filterOrders(String query) {
    if (query.isEmpty) {
      _groupOrders(_allOrdersFlat);
      return;
    }

    final filtered = _allOrdersFlat.where((order) {
      final client = (order['clientName'] ?? '').toString().toLowerCase();
      final manualNo = order['manualNo']?.toString().toLowerCase() ?? '';
      final allSupplyNums =
          order['displaySupplyOrders']?.toString().toLowerCase() ?? '';
      final q = query.toLowerCase();
      return client.contains(q) ||
          manualNo.contains(q) ||
          allSupplyNums.contains(q);
    }).toList();

    _groupOrders(filtered);
  }

  String _formatDateForSerial(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString();
    return "$day$month$year";
  }

  void _showOrderDialog({
    Map<String, dynamic>? existingOrder,
    List<Map<String, dynamic>>? existingItems,
  }) {
    if (existingOrder == null && !_canAdd) return;
    if (existingOrder != null && !_canAdd) return;

    final isEditing = existingOrder != null;
    DateTime selectedDate = isEditing && existingOrder['date'] != null
        ? DateTime.parse(existingOrder['date'])
        : DateTime.now();
    String initialManualNo = isEditing
        ? (existingOrder['manualNo'] ?? '')
        : _formatDateForSerial(selectedDate);

    final manualNoController = TextEditingController(text: initialManualNo);
    final addressController = TextEditingController(
      text: isEditing ? existingOrder['address'] : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? existingOrder['notes'] : '',
    );
    final supplyOrderNumber = TextEditingController(
      text: isEditing ? existingOrder['supplyOrderNumber'] : '',
    );

    String? selectedClientId;
    if (isEditing) {
      selectedClientId = existingOrder['client'];
      if (selectedClientId == null && existingOrder['clientName'] != null) {
        try {
          final c = _clients.firstWhere(
            (c) => c['name'] == existingOrder['clientName'],
          );
          selectedClientId = c['id'];
        } catch (e) {}
      }
    }

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
            String? prodId;
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
                content: SizedBox(
                  width: double.maxFinite,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "اختر الصنف",
                              hintText: "اضغط للبحث...",
                              suffixIcon: Icon(Icons.arrow_drop_down),
                              border: OutlineInputBorder(),
                            ),
                            onTap: () async {
                              final selectedProduct =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (ctx) => ProductSearchDialog(
                                      allProducts: _products,
                                    ),
                                  );
                              if (selectedProduct != null) {
                                prodName = selectedProduct['name'];
                                prodId = selectedProduct['id'];
                                nameController.text = prodName!;
                                descCtrl.text = "${selectedProduct['name']} ";
                              }
                            },
                          ),
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
                            minLines: 1,
                            maxLines: 10,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              labelText: 'الوصف',
                              hintText: 'اكتب كل سيريال في سطر جديد...',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        setStateSB(() {
                          tempItems.add({
                            'productId': prodId,
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

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                children: [
                  Text(
                    isEditing ? 'تعديل الإذن' : 'إذن تسليم جديد',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedClientId,
                            decoration: const InputDecoration(
                              labelText: 'العميل',
                              border: OutlineInputBorder(),
                            ),
                            items: _clients
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'] as String,
                                    child: Text(c['name']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              selectedClientId = val;
                              final c = _clients.firstWhere(
                                (e) => e['id'] == val,
                              );
                              addressController.text = c['address'] ?? '';
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: manualNoController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الإذن',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: supplyOrderNumber,
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
                              if (d != null) {
                                setStateSB(() {
                                  selectedDate = d;
                                  manualNoController.text =
                                      _formatDateForSerial(d);
                                });
                              }
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
                          const SizedBox(height: 20),
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
                            List<Map<String, dynamic>> sectionItems = tempItems
                                .where((item) {
                                  String itemSection =
                                      item['relatedSupplyOrder'] ?? '';
                                  return itemSection == sectionName;
                                })
                                .toList();
                            bool isMain = sectionName.isEmpty;
                            String displayTitle = isMain
                                ? "عام / الرئيسي"
                                : "أمر توريد: $sectionName";
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 10),
                      // هذا الكود يوضع مكان زر الحفظ القديم
                      ElevatedButton.icon(
                        icon: Icon(isEditing ? Icons.edit : Icons.save),
                        label: Text(isEditing ? 'تعديل وحفظ' : 'حفظ جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          // دالة الحفظ الفعلية
                          Future<void> submitOrder() async {
                            if (selectedClientId != null &&
                                supplyOrderNumber.text.isNotEmpty &&
                                tempItems.isNotEmpty) {
                              if (isEditing) {
                                await SalesService().updateDeliveryOrder(
                                  existingOrder['id'],
                                  selectedClientId!,
                                  supplyOrderNumber.text,
                                  manualNoController.text,
                                  addressController.text,
                                  selectedDate.toIso8601String(),
                                  notesController.text,
                                  tempItems,
                                );
                              } else {
                                await SalesService().createDeliveryOrder(
                                  selectedClientId!,
                                  supplyOrderNumber.text,
                                  manualNoController.text,
                                  addressController.text,
                                  selectedDate.toIso8601String(),
                                  notesController.text,
                                  tempItems,
                                );
                              }
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'تم التعديل بنجاح ✅'
                                        : 'تم الحفظ بنجاح ✅',
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
                          }

                          // ✅ التحقق من عدد العناصر قبل الحفظ
                          if (tempItems.length > 7) {
                            showDialog(
                              context: context,
                              builder: (alertCtx) => AlertDialog(
                                title: const Text("تنبيه: عدد الأصناف كبير"),
                                content: Text(
                                  "عدد الأصناف الحالي (${tempItems.length}) قد يتجاوز مساحة الصفحة الواحدة في ملف PDF.\n\nهل تريد المتابعة والحفظ؟",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(alertCtx),
                                    child: const Text("مراجعة"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(alertCtx); // إغلاق التحذير
                                      submitOrder(); // تنفيذ الحفظ
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                    ),
                                    child: const Text(
                                      "حفظ على أي حال",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // لو العدد تمام، احفظ علطول
                            submitOrder();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteOrder(String id, bool isLocked) {
    if (!_canDelete) return;

    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ هذا الإذن موقع ومقفل'),
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
              await SalesService().deleteDeliveryOrder(id);
              Navigator.pop(ctx);
              // _loadData(); // ❌ لا حاجة له
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleLock(String id, bool currentStatus) async {
    if (!_canAdd) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية التعديل')));
      return;
    }

    if (currentStatus) {
      await SalesService().toggleOrderLock(id, false);
      // _loadData(); // ❌ لا حاجة له
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("تأكيد القفل"),
          content: const Text("هل تريد إرفاق صورة الإذن الموقع من العميل؟"),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SalesService().toggleOrderLock(id, true);
                // _loadData(); // ❌ لا حاجة له
              },
              child: const Text("لا (قفل فقط)"),
            ),
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
                  await SalesService().toggleOrderLock(
                    id,
                    true,
                    imagePath: image.path,
                  );
                  // _loadData(); // ❌ لا حاجة له
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم رفع الصورة وقفل الإذن ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  }

  void _manageImage(String orderId, String imagePath) {
    if (!_canAdd) return;

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
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text("عرض الصورة"),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: Image.network(imagePath, fit: BoxFit.contain),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text("تغيير الصورة"),
              onTap: () async {
                Navigator.pop(ctx);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  await SalesService().updateOrderImage(orderId, image.path);
                  // _loadData(); // ❌ لا حاجة له
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير الصورة بنجاح ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("حذف الصورة"),
              onTap: () async {
                Navigator.pop(ctx);
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
                          await SalesService().updateOrderImage(orderId, null);
                          Navigator.pop(alertCtx);
                          // _loadData(); // ❌ لا حاجة له
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('أذونات التسليم')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
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
                      child: _groupedOrders.isEmpty
                          ? const Center(child: Text("لا توجد نتائج"))
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                left: 10,
                                right: 10,
                                bottom: 100,
                              ),
                              itemCount: _groupedOrders.length,
                              itemBuilder: (context, index) {
                                String clientName = _groupedOrders.keys
                                    .elementAt(index);
                                List<Map<String, dynamic>> clientOrders =
                                    _groupedOrders[clientName]!;
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.blue.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: true,
                                    shape: const Border(),
                                    title: Text(
                                      clientName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.blue[200]
                                            : Colors.blue[900],
                                      ),
                                    ),
                                    leading: const Icon(
                                      Icons.business,
                                      color: Colors.orange,
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.grey[850]
                                        : Colors.blue[50]?.withOpacity(0.3),
                                    childrenPadding: const EdgeInsets.all(5),
                                    children: clientOrders.map((order) {
                                      bool isLocked = order['isLocked'] == true;
                                      bool hasImage =
                                          order['signedImagePath'] != null &&
                                          order['signedImagePath']
                                              .toString()
                                              .isNotEmpty;
                                      Color tileColor = isLocked
                                          ? (isDark
                                                ? Colors.green.withOpacity(0.15)
                                                : Colors.green[50]!)
                                          : Theme.of(context).cardColor;
                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                          left: 5,
                                          right: 5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        color: tileColor,
                                        child: ExpansionTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isLocked
                                                ? Colors.green
                                                : Colors.blue,
                                            child: Icon(
                                              isLocked
                                                  ? Icons.check
                                                  : Icons.description,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(
                                            "رقم الإذن: ${order['manualNo'] ?? '---'}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            "أوامر توريد: ${order['displaySupplyOrders']}",
                                            style: TextStyle(
                                              color: isLocked
                                                  ? Colors.green
                                                  : Colors.blue,
                                              fontSize: 12,
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                15.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "التاريخ: ${order['date'].toString().split(' ')[0]}",
                                                  ),
                                                  const Divider(),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Switch(
                                                            value: isLocked,
                                                            activeThumbColor:
                                                                Colors.green,
                                                            onChanged: (val) =>
                                                                _toggleLock(
                                                                  order['id'],
                                                                  isLocked,
                                                                ),
                                                          ),
                                                          Text(
                                                            isLocked
                                                                ? "مغلق"
                                                                : "تعديل",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isLocked
                                                                  ? Colors.green
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                          if (hasImage)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8.0,
                                                                  ),
                                                              child: IconButton(
                                                                icon: const Icon(
                                                                  Icons.image,
                                                                  color: Colors
                                                                      .purple,
                                                                ),
                                                                tooltip:
                                                                    "عرض الصورة",
                                                                onPressed: () {
                                                                  if (isLocked) {
                                                                    showDialog(
                                                                      context:
                                                                          context,
                                                                      builder: (_) => Dialog(
                                                                        child: Image.network(
                                                                          order['signedImagePath'],
                                                                          fit: BoxFit
                                                                              .contain,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    _manageImage(
                                                                      order['id'],
                                                                      order['signedImagePath'],
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          if (_canDelete)
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.delete,
                                                                color: isLocked
                                                                    ? Colors
                                                                          .grey
                                                                    : Colors
                                                                          .red,
                                                              ),
                                                              onPressed: () =>
                                                                  _deleteOrder(
                                                                    order['id'],
                                                                    isLocked,
                                                                  ),
                                                            ),
                                                          if (_canAdd)
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.edit,
                                                                color: isLocked
                                                                    ? Colors
                                                                          .grey
                                                                    : Colors
                                                                          .orange,
                                                              ),
                                                              onPressed:
                                                                  isLocked
                                                                  ? null
                                                                  : () async {
                                                                      List<
                                                                        Map<
                                                                          String,
                                                                          dynamic
                                                                        >
                                                                      >
                                                                      orderItems =
                                                                          await SalesService().getDeliveryOrderItems(
                                                                            order['id'],
                                                                          );
                                                                      _showOrderDialog(
                                                                        existingOrder:
                                                                            order,
                                                                        existingItems:
                                                                            orderItems,
                                                                      );
                                                                    },
                                                            ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.print,
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                            onPressed: () async {
                                                              List<
                                                                Map<
                                                                  String,
                                                                  dynamic
                                                                >
                                                              >
                                                              orderItems =
                                                                  await SalesService()
                                                                      .getDeliveryOrderItems(
                                                                        order['id'],
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
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: _canAdd
          ? FloatingActionButton(
              onPressed: () => _showOrderDialog(),
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
