import 'package:flutter/material.dart';
import 'db_helper.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  // 1. القوائم والتحكم في البحث
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  final TextEditingController _searchController = TextEditingController();

  // 2. معرفات الحقول (Controllers)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  String _balanceType = 'debit';

  @override
  void initState() {
    super.initState();
    _refreshClients();
  }

  // تحديث البيانات من القاعدة
  void _refreshClients() async {
    final data = await DatabaseHelper().getClients();
    setState(() {
      _clients = data;
      _filteredClients = data;
      _runFilter(_searchController.text);
    });
  }

  // دالة البحث
  void _runFilter(String keyword) {
    List<Map<String, dynamic>> results = [];
    if (keyword.isEmpty) {
      results = _clients;
    } else {
      results = _clients.where((c) {
        final name = c['name'].toString().toLowerCase();
        final phone = c['phone']?.toString().toLowerCase() ?? '';
        final input = keyword.toLowerCase();
        return name.contains(input) || phone.contains(input);
      }).toList();
    }
    setState(() {
      _filteredClients = results;
    });
  }

  // تصفير الحقول
  void _clearControllers() {
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
    _balanceController.clear();
    setState(() {
      _balanceType = 'debit';
    });
  }

  // دالة حذف عميل
  void _deleteClient(int id) async {
    await DatabaseHelper().deleteClient(id);
    _refreshClients();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف العميل'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // دالة حفظ العميل (إضافة أو تعديل)
  void _saveClient({int? id}) async {
    if (_nameController.text.isEmpty) return;
    double initialBalance = double.tryParse(_balanceController.text) ?? 0.0;

    Map<String, dynamic> row = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'balance': 0.0,
    };

    if (id == null) {
      int clientId = await DatabaseHelper().insertClient(row);
      if (initialBalance > 0) {
        double finalBal = (_balanceType == 'debit')
            ? initialBalance
            : -initialBalance;
        await DatabaseHelper().addOpeningBalance(clientId, finalBal);
      }
    } else {
      row['id'] = id;
      await DatabaseHelper().updateClient(row);
    }

    _clearControllers();
    if (!mounted) return;
    Navigator.of(context).pop();
    _refreshClients();
  }

  // دالة إظهار الديالوج (التي يظهر عليها الايرور)
  void _showClientDialog({Map<String, dynamic>? client}) {
    if (client != null) {
      _nameController.text = client['name'];
      _phoneController.text = client['phone'] ?? '';
      _addressController.text = client['address'] ?? '';
    } else {
      _clearControllers();
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: Text(
            client == null ? 'إضافة عميل جديد' : 'تعديل بيانات العميل',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل',
                    icon: Icon(Icons.person),
                  ),
                ),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    icon: Icon(Icons.phone),
                  ),
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    icon: Icon(Icons.location_on),
                  ),
                ),
                if (client == null) ...[
                  const Divider(),
                  TextField(
                    controller: _balanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي',
                      icon: Icon(Icons.money),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile(
                          title: const Text(
                            'مدين',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: 'debit',
                          groupValue: _balanceType,
                          onChanged: (v) =>
                              setStateSB(() => _balanceType = v.toString()),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile(
                          title: const Text(
                            'دائن',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: 'credit',
                          groupValue: _balanceType,
                          onChanged: (v) =>
                              setStateSB(() => _balanceType = v.toString()),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => _saveClient(id: client?['id']),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // دالة تعديل الرصيد الافتتاحي
  void _showEditBalanceDialog(int clientId, String clientName) async {
    double currentOpBalance = await DatabaseHelper().getOpeningBalanceAmount(
      clientId,
    );
    _balanceController.text = currentOpBalance.abs().toString();
    String currentType = currentOpBalance >= 0 ? 'debit' : 'credit';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: Text('تعديل رصيد: $clientName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'القيمة'),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text('مدين'),
                      value: 'debit',
                      groupValue: currentType,
                      onChanged: (v) =>
                          setStateSB(() => currentType = v.toString()),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text('دائن'),
                      value: 'credit',
                      groupValue: currentType,
                      onChanged: (v) =>
                          setStateSB(() => currentType = v.toString()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                double amount = double.tryParse(_balanceController.text) ?? 0.0;
                if (currentType == 'credit') amount = -amount;
                await DatabaseHelper().updateClientOpeningBalance(
                  clientId,
                  amount,
                );
                Navigator.pop(context);
                _refreshClients();
              },
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة العملاء')),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _runFilter,
              decoration: InputDecoration(
                labelText: 'بحث باسم العميل أو الهاتف...',
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
          Expanded(
            child: _filteredClients.isEmpty
                ? const Center(child: Text('لا يوجد نتائج'))
                : ListView.builder(
                    itemCount: _filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(client['name'][0].toUpperCase()),
                          ),
                          title: Text(
                            client['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('هاتف: ${client['phone'] ?? '-'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FutureBuilder<double>(
                                future: DatabaseHelper()
                                    .getClientCurrentBalance(client['id']),
                                builder: (context, snapshot) {
                                  double balance = snapshot.data ?? 0.0;
                                  return Text(
                                    '${balance.abs().toStringAsFixed(1)} ج.م',
                                    style: TextStyle(
                                      color: balance < 0
                                          ? Colors.green
                                          : (balance > 0
                                                ? Colors.red
                                                : Colors.grey),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit_info')
                                    _showClientDialog(client: client);
                                  if (value == 'edit_balance')
                                    _showEditBalanceDialog(
                                      client['id'],
                                      client['name'],
                                    );
                                  if (value == 'delete')
                                    _deleteClient(client['id']);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit_info',
                                    child: Text('تعديل البيانات'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit_balance',
                                    child: Text('الرصيد الافتتاحي'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'حذف',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
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
        onPressed: () => _showClientDialog(), // الآن ستعمل بنجاح
        label: const Text('إضافة عميل'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
