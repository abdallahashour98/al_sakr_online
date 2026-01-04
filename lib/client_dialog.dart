import 'package:flutter/material.dart';
import 'pb_helper.dart';

class ClientDialog extends StatefulWidget {
  final Map<String, dynamic>? client;

  const ClientDialog({super.key, this.client});

  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');

  String _balanceType = 'debit'; // debit = مدين (عليه)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _initData();
    }
  }

  void _initData() async {
    final c = widget.client!;
    _nameController.text = c['name'];
    _phoneController.text = c['phone'] ?? '';
    _addressController.text = c['address'] ?? '';

    // جلب الرصيد الافتتاحي
    double openBal = await PBHelper().getClientOpeningBalance(c['id']);
    _openingBalanceController.text = openBal.abs().toString();
    setState(() {
      _balanceType = openBal >= 0 ? 'debit' : 'credit';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.client != null;

    return AlertDialog(
      title: Text(
        isEdit ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'الهاتف',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const Divider(),

            const Text(
              'الرصيد الافتتاحي (أول المدة)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _openingBalanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile(
                    title: const Text('مدين (عليه)'),
                    value: 'debit',
                    groupValue: _balanceType,
                    activeColor: Colors.blue,
                    onChanged: (v) =>
                        setState(() => _balanceType = v.toString()),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text('دائن (له)'),
                    value: 'credit',
                    groupValue: _balanceType,
                    activeColor: Colors.green,
                    onChanged: (v) =>
                        setState(() => _balanceType = v.toString()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
          onPressed: _isLoading ? null : _saveClient,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('حفظ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _saveClient() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> data = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
    };

    try {
      String clientId;
      if (widget.client == null) {
        data['balance'] = 0.0;
        final rec = await PBHelper().insertClient(data);
        clientId = rec.id;
      } else {
        await PBHelper().updateClient(widget.client!['id'], data);
        clientId = widget.client!['id'];
      }

      // حفظ الرصيد الافتتاحي
      double amount = double.tryParse(_openingBalanceController.text) ?? 0.0;
      double finalBal = (_balanceType == 'debit') ? amount : -amount;
      await PBHelper().updateClientOpeningBalance(clientId, finalBal);

      if (mounted) {
        Navigator.pop(context, {'id': clientId, 'name': data['name']});
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
}
