import 'package:flutter/material.dart';
import 'pb_helper.dart';

class SupplierDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;

  const SupplierDialog({super.key, this.supplier});

  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<SupplierDialog> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  String _balanceType = 'debit'; // debit = علينا
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _initData();
    }
  }

  void _initData() async {
    final s = widget.supplier!;
    _codeController.text = s['code'] ?? '';
    _nameController.text = s['name'];
    _phoneController.text = s['phone'] ?? '';
    _addressController.text = s['address'] ?? '';
    _contactController.text = s['contactPerson'] ?? '';
    _notesController.text = s['notes'] ?? '';

    // جلب الرصيد الافتتاحي
    double openBal = await PBHelper().getSupplierOpeningBalance(s['id']);
    _openingBalanceController.text = openBal.abs().toString();
    setState(() {
      _balanceType = openBal >= 0 ? 'debit' : 'credit';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.supplier != null;

    return AlertDialog(
      title: Text(
        isEdit ? 'تعديل بيانات مورد' : 'إضافة مورد جديد',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'الكود',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المورد',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'المسئول',
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
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: Icon(Icons.note),
              ),
            ),

            const Divider(),
            const Text(
              'الرصيد الافتتاحي (أول المدة)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown,
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
                    title: const Text('علينا (له)'),
                    value: 'debit',
                    groupValue: _balanceType,
                    activeColor: Colors.red,
                    onChanged: (v) =>
                        setState(() => _balanceType = v.toString()),
                  ),
                ),
                Expanded(
                  child: RadioListTile(
                    title: const Text('لنا (مقدم)'),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
          onPressed: _isLoading ? null : _saveSupplier,
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

  Future<void> _saveSupplier() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> data = {
      'code': _codeController.text,
      'name': _nameController.text,
      'contactPerson': _contactController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'notes': _notesController.text,
    };

    try {
      String supplierId;
      if (widget.supplier == null) {
        data['balance'] = 0.0;
        final rec = await PBHelper().insertSupplier(data);
        supplierId = rec.id;
      } else {
        await PBHelper().updateSupplier(widget.supplier!['id'], data);
        supplierId = widget.supplier!['id'];
      }

      double amount = double.tryParse(_openingBalanceController.text) ?? 0.0;
      double finalBal = (_balanceType == 'debit') ? amount : -amount;
      await PBHelper().updateSupplierOpeningBalance(supplierId, finalBal);

      if (mounted) {
        Navigator.pop(context, {'id': supplierId, 'name': data['name']});
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
