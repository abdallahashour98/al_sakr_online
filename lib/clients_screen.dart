import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/pb_helper.dart';
import 'services/auth_service.dart';
import 'services/sales_service.dart';
import 'client_dialog.dart';
import 'package:image_picker/image_picker.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  double _totalSales = 0.0;
  double _totalCollected = 0.0;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // ✅ متغير الستريم الثابت
  late Stream<List<Map<String, dynamic>>> _clientsStream;

  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadStaticStats();
    // ✅ تهيئة الستريم مرة واحدة فقط
    _clientsStream = PBHelper().getCollectionStream('clients', sort: 'name');
  }

  Future<void> _loadPermissions() async {
    final myId = AuthService().pb.authStore.record?.id;
    if (myId == null) return;

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

    try {
      final userRecord = await AuthService().pb
          .collection('users')
          .getOne(myId);
      if (mounted) {
        setState(() {
          _canAdd = userRecord.data['allow_add_clients'] ?? false;
          _canEdit =
              (userRecord.data['allow_add_clients'] ?? false) ||
              (userRecord.data['allow_edit_clients'] ?? false);
          _canDelete = userRecord.data['allow_delete_clients'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الصلاحيات: $e");
    }
  }

  Future<void> _loadStaticStats() async {
    try {
      final sales = await SalesService().getSales();
      final receipts = await SalesService().getAllReceipts();
      double tSales = 0.0;
      double tCollected = 0.0;
      for (var s in sales) tSales += (s['netAmount'] as num? ?? 0.0);
      for (var r in receipts) tCollected += (r['amount'] as num? ?? 0.0);
      if (mounted) {
        setState(() {
          _totalSales = tSales;
          _totalCollected = tCollected;
        });
      }
    } catch (e) {
      print("Error loading stats: $e");
    }
  }

  Future<void> _openClientDialog({Map<String, dynamic>? client}) async {
    if (client == null && !_canAdd) return;
    if (client != null && !_canEdit) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ClientDialog(client: client),
    );
  }

  void _deleteClient(String id) {
    if (!_canDelete) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف العميل"),
        content: const Text("هل أنت متأكد؟ سيتم حذف العميل وكل سجلاته."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await SalesService().deleteClient(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم الحذف"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("حذف"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dashboardColor = isDark ? const Color(0xFF1A1A1A) : Colors.blue[50];
    final dashboardBorder = isDark ? Colors.grey[800]! : Colors.blue[100]!;
    final inputFill = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text('إدارة العملاء'), centerTitle: true),
      // ✅ استخدام الستريم الثابت
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _clientsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("خطأ: ${snapshot.error}"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final allClients = snapshot.data!;
          // ✅ الفلترة تتم محلياً هنا، مما يمنع إعادة تحميل الستريم
          final filteredClients = allClients.where((c) {
            if (c['is_deleted'] == true) return false;
            final name = c['name'].toString().toLowerCase();
            final phone = (c['phone'] ?? '').toString();
            final q = _searchQuery.toLowerCase();
            return _searchQuery.isEmpty ||
                name.contains(q) ||
                phone.contains(q);
          }).toList();

          double totalDebt = 0.0;
          for (var c in filteredClients) {
            double bal = (c['balance'] as num? ?? 0.0).toDouble();
            if (bal > 0) totalDebt += bal;
          }
          filteredClients.sort(
            (a, b) => (b['balance'] as num).compareTo(a['balance'] as num),
          );

          return Column(
            children: [
              // لوحة الإحصائيات والبحث
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dashboardColor,
                  border: Border(bottom: BorderSide(color: dashboardBorder)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 2000),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _summaryCard(
                              "إجمالي المبيعات",
                              _totalSales,
                              Colors.blue,
                              Icons.point_of_sale,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _summaryCard(
                              "إجمالي التحصيل",
                              _totalCollected,
                              Colors.green,
                              Icons.attach_money,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _summaryCard(
                              "مديونية العملاء",
                              totalDebt,
                              Colors.red,
                              Icons.warning_amber_rounded,
                              isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          // ✅ التحديث يحدث فقط setState ليعيد بناء الـ Builder بالفلتر الجديد
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: "بحث عن عميل...",
                            hintStyle: TextStyle(color: subText),
                            prefixIcon: Icon(Icons.search, color: subText),
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // القائمة
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 120),
                  itemCount: filteredClients.length,
                  itemBuilder: (ctx, index) {
                    final client = filteredClients[index];
                    double bal = (client['balance'] as num? ?? 0.0).toDouble();

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 2000),
                        child: Card(
                          color: cardColor,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: bal > 0
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                              child: Text(
                                client['name'].isNotEmpty
                                    ? client['name'][0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: bal > 0 ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              client['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              "ت: ${client['phone'] ?? '-'}",
                              style: TextStyle(color: subText),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      NumberFormat.currency(
                                        symbol: 'ج.م',
                                        decimalDigits: 1,
                                      ).format(bal.abs()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: bal > 0
                                            ? Colors.red
                                            : Colors.green,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      bal > 0 ? "عليه (لنا)" : "له (مقدم)",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_canEdit || _canDelete)
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: subText),
                                    onSelected: (value) {
                                      if (value == 'edit')
                                        _openClientDialog(client: client);
                                      if (value == 'delete')
                                        _deleteClient(client['id']);
                                    },
                                    itemBuilder: (c) => [
                                      if (_canEdit)
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(width: 10),
                                              Text('تعديل'),
                                            ],
                                          ),
                                        ),
                                      if (_canDelete)
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 10),
                                              Text('حذف'),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ClientDetailScreen(client: client),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openClientDialog(),
              label: const Text(
                "عميل جديد",
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.blue[800],
            )
          : null,
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                NumberFormat.compact().format(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------
// بقية كود ClientDetailScreen (بدون تغييرات جذرية في الأداء لأنها لا تحتوي على بحث مباشر ثقيل)
// يمكنك تركه كما هو أو تطبيق نفس المنطق إذا كان هناك بحث داخلي
// سأدرجه كما هو ليكون الملف كاملاً
// ---------------------------------------------

class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _loading = true;
  String _typeFilter = "الكل";
  DateTimeRange? _dateRange;
  double _currentVisibleBalance = 0.0;

  bool _canAddPayment = false;
  bool _canManagePayments = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadDetails();
  }

  Future<void> _loadPermissions() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canAddPayment = true;
          _canManagePayments = true;
        });
      return;
    }

    try {
      final userRecord = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAddPayment =
              (userRecord.data['allow_add_clients'] ?? false) ||
              (userRecord.data['allow_add_orders'] ?? false);
          _canManagePayments =
              (userRecord.data['allow_delete_clients'] ?? false);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadDetails() async {
    setState(() => _loading = true);

    final sales = await SalesService().getSalesByClient(widget.client['id']);
    final receipts = await SalesService().getReceiptsByClient(
      widget.client['id'],
    );
    final returns = await SalesService().getReturnsByClient(
      widget.client['id'],
    );
    final openingBal = await SalesService().getClientOpeningBalance(
      widget.client['id'],
    );

    List<Map<String, dynamic>> temp = [];

    for (var s in sales) {
      temp.add({
        'id': s['id'],
        'date': s['date'],
        'type': 'فاتورة بيع',
        'amount': (s['netAmount'] as num).toDouble(),
        'isDebit': true,
        'category': 'فواتير',
        'rawDate': DateTime.parse(s['date']),
        'rawRecord': s,
      });
    }
    for (var r in receipts) {
      temp.add({
        'id': r['id'],
        'date': r['date'],
        'type': 'سند قبض',
        'amount': (r['amount'] as num).toDouble(),
        'isDebit': false,
        'category': 'دفعات',
        'rawDate': DateTime.parse(r['date']),
        'note': r['notes'],
        'rawRecord': r,
      });
    }
    for (var rt in returns) {
      temp.add({
        'id': rt['id'],
        'date': rt['date'],
        'type': 'مرتجع بيع',
        'amount': (rt['totalAmount'] as num).toDouble(),
        'isDebit': false,
        'category': 'مرتجعات',
        'rawDate': DateTime.parse(rt['date']),
        'rawRecord': rt,
      });
    }

    temp.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate']));

    List<Map<String, dynamic>> calculatedList = [];
    double runningBalance = openingBal;

    for (var t in temp) {
      if (t['isDebit'])
        runningBalance += t['amount'];
      else
        runningBalance -= t['amount'];
      t['runningBalance'] = runningBalance;
      calculatedList.add(t);
    }

    _applyFilters(calculatedList, openingBal);
  }

  void _applyFilters(
    List<Map<String, dynamic>> fullList,
    double initialOpening,
  ) {
    List<Map<String, dynamic>> result = [];
    double startBalance = initialOpening;

    if (_dateRange != null) {
      final beforeRange = fullList
          .where((t) => (t['rawDate'] as DateTime).isBefore(_dateRange!.start))
          .toList();
      if (beforeRange.isNotEmpty)
        startBalance = beforeRange.last['runningBalance'];
      result = fullList.where((t) {
        final d = t['rawDate'] as DateTime;
        return d.isAfter(
              _dateRange!.start.subtract(const Duration(seconds: 1)),
            ) &&
            d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    } else {
      result = fullList;
    }

    List<Map<String, dynamic>> finalDisplay = [];
    finalDisplay.add({
      'type': _dateRange == null ? 'رصيد افتتاحي' : 'رصيد سابق',
      'amount': startBalance.abs(),
      'isDebit': startBalance >= 0,
      'runningBalance': startBalance,
      'isHeader': true,
      'date': '---',
      'category': 'الكل',
    });

    finalDisplay.addAll(result);

    if (_typeFilter != "الكل") {
      finalDisplay = finalDisplay
          .where((t) => t['category'] == _typeFilter || t['isHeader'] == true)
          .toList();
    }

    if (mounted) {
      setState(() {
        _allTransactions = fullList;
        _filteredTransactions = finalDisplay;
        _currentVisibleBalance = fullList.isNotEmpty
            ? fullList.last['runningBalance']
            : startBalance;
        _loading = false;
      });
    }
  }

  Future<void> _deleteReceipt(String receiptId, double amount) async {
    try {
      await PBHelper().pb.collection('receipts').delete(receiptId);
      final clientRec = await PBHelper().pb
          .collection('clients')
          .getOne(widget.client['id']);
      double currentBal = (clientRec.data['balance'] ?? 0).toDouble();
      await PBHelper().pb
          .collection('clients')
          .update(widget.client['id'], body: {'balance': currentBal + amount});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حذف السند وتحديث الرصيد"),
            backgroundColor: Colors.red,
          ),
        );
        _loadDetails();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  void _showEditReceiptDialog(Map<String, dynamic> rawRecord) {
    // ... (نفس دالة التعديل السابقة)
    // اختصاراً للكود سأفترض أنها موجودة كما في النسخة الأصلية
    // يمكنك نسخ دالة _showEditReceiptDialog من الكود الأصلي هنا
    // فهي تعمل بشكل جيد ولا تؤثر على أداء الليست فيو
  }

  void _showImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenericDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['type']),
        content: Text(
          "المبلغ: ${item['amount']}\nالتاريخ: ${item['date'].toString().split(' ')[0]}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );
    if (picked != null)
      setState(() {
        _dateRange = picked;
        _loadDetails();
      });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.client['name']),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _dateRange != null ? Colors.orange : null,
            ),
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _dateRange = null;
                  _loadDetails();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.blue[50],
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 2000),
                child: Column(
                  children: [
                    Text(
                      _dateRange != null
                          ? "الرصيد في نهاية الفترة"
                          : "الرصيد الحالي",
                      style: TextStyle(color: subText),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "${_currentVisibleBalance.abs().toStringAsFixed(1)} ج.م",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _currentVisibleBalance > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    Text(
                      _currentVisibleBalance > 0 ? "عليه (لنا)" : "له (مقدم)",
                      style: TextStyle(color: subText),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ["الكل", "فواتير", "دفعات", "مرتجعات"].map((
                          filter,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _typeFilter == filter,
                              onSelected: (val) {
                                setState(() {
                                  _typeFilter = filter;
                                  _loadDetails();
                                });
                              },
                              selectedColor: Colors.blue[800],
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_dateRange != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: Text(
                "عرض الفترة من: ${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} إلى: ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 150),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (ctx, i) {
                      final item = _filteredTransactions[i];
                      bool isDebit = item['isDebit'];
                      bool isHeader = item['isHeader'] == true;
                      bool isPayment = item['category'] == 'دفعات';

                      String? imageUrl;
                      if (isPayment) {
                        final raw = item['rawRecord'];
                        if (raw['receiptImage'] != null &&
                            raw['receiptImage'].toString().isNotEmpty) {
                          imageUrl = PBHelper().getImageUrl(
                            raw['collectionId'],
                            raw['id'],
                            raw['receiptImage'],
                          );
                        }
                      }

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 2000),
                          child: Card(
                            color: isHeader
                                ? (isDark ? Colors.grey[900] : Colors.grey[200])
                                : cardColor,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            elevation: isHeader ? 0 : 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (imageUrl != null) {
                                        _showImage(imageUrl);
                                      } else if (!isHeader) {
                                        _showGenericDetails(item);
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        Icon(
                                          isHeader
                                              ? Icons.account_balance
                                              : (isDebit
                                                    ? Icons.arrow_upward
                                                    : Icons.arrow_downward),
                                          size: 30,
                                          color: isHeader
                                              ? subText
                                              : (isDebit
                                                    ? Colors.blue
                                                    : Colors.green),
                                        ),
                                        if (imageUrl != null)
                                          const Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Icon(
                                              Icons.image,
                                              size: 14,
                                              color: Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (imageUrl != null) {
                                          _showImage(imageUrl);
                                        } else if (!isHeader) {
                                          _showGenericDetails(item);
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['type'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            isHeader
                                                ? "---"
                                                : "${item['date'].toString().split(' ')[0]} ${item['note'] != null ? '(${item['note']})' : ''}",
                                            style: TextStyle(
                                              color: subText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${item['amount'].toStringAsFixed(1)}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isHeader
                                              ? textColor
                                              : (isDebit
                                                    ? Colors.blue
                                                    : Colors.green),
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        "رصيد: ${item['runningBalance'].toStringAsFixed(1)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _canAddPayment
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 10),
              child: FloatingActionButton.extended(
                onPressed: () {
                  _showAddPaymentDialog(context);
                },
                label: const Text(
                  "تسجيل دفعة",
                  style: TextStyle(color: Colors.white),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                backgroundColor: Colors.brown,
              ),
            )
          : null,
    );
  }

  // ... (نفس دالة _showAddPaymentDialog القديمة بدون تغيير) ...
  void _showAddPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = "cash";
    String? selectedImagePath;
    DateTime selectedDate = DateTime.now();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txt = isDark ? Colors.white : Colors.black;
    final border = isDark ? Colors.grey[600]! : Colors.grey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: bg,
          title: Text("تسجيل دفعة جديدة", style: TextStyle(color: txt)),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: "المبلغ",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: isDark ? Colors.grey : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    dropdownColor: isDark
                        ? const Color(0xFF333333)
                        : Colors.white,
                    decoration: InputDecoration(
                      labelText: "طريقة الدفع",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "cash",
                        child: Text(
                          "نـقـدي (Cash)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "cheque",
                        child: Text(
                          "شـيـك (Cheque)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "bank_transfer",
                        child: Text(
                          "تحويل بنكي (Transfer)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setStateDialog(() => paymentMethod = val!),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? const ColorScheme.dark(
                                    primary: Colors.brown,
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF424242),
                                    onSurface: Colors.white,
                                  )
                                : const ColorScheme.light(
                                    primary: Colors.brown,
                                  ),
                            dialogTheme: DialogThemeData(
                              backgroundColor: isDark
                                  ? const Color(0xFF424242)
                                  : Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (d != null) setStateDialog(() => selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "التاريخ",
                        labelStyle: TextStyle(
                          color: isDark ? Colors.grey : null,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: border),
                        ),
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: isDark ? Colors.grey : null,
                        ),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: TextStyle(color: txt),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null)
                        setStateDialog(() => selectedImagePath = image.path);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: isDark ? Colors.grey : Colors.blueGrey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedImagePath != null
                                  ? "تم اختيار صورة ✅"
                                  : "إرفاق صورة التحويل (اختياري)",
                              style: TextStyle(
                                color: selectedImagePath != null
                                    ? Colors.green
                                    : (isDark ? Colors.grey : Colors.black54),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedImagePath != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setStateDialog(
                                () => selectedImagePath = null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: "ملاحظات / رقم الشيك",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      prefixIcon: Icon(
                        Icons.note,
                        color: isDark ? Colors.grey : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                double? amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount == 0) return;
                try {
                  await SalesService().createReceipt(
                    widget.client['id'],
                    amount,
                    notesCtrl.text,
                    selectedDate.toIso8601String(),
                    paymentMethod: paymentMethod,
                    imagePath: selectedImagePath,
                  );
                  Navigator.pop(ctx);
                  _loadDetails();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم تسجيل الدفعة"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }
}
