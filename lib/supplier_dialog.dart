import 'package:flutter/material.dart';

import 'services/purchases_service.dart';

class SupplierDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  const SupplierDialog({super.key, this.supplier});

  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<SupplierDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _managerController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController(
    text: '0',
  );

  int _balanceType = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!['name'];
      _phoneController.text = widget.supplier!['phone'] ?? '';
      _managerController.text = widget.supplier!['manager'] ?? '';
      _addressController.text = widget.supplier!['address'] ?? '';
      _notesController.text = widget.supplier!['notes'] ?? '';

      double balance =
          (widget.supplier!['initial_balance'] as num?)?.toDouble() ?? 0.0;
      _balanceController.text = balance.abs().toString();

      String type = widget.supplier!['balance_type'] ?? 'debit';
      _balanceType = type == 'debit' ? 0 : 1;
    }
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final body = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "manager": _managerController.text.trim(),
        "address": _addressController.text.trim(),
        "notes": _notesController.text.trim(),
        "initial_balance": double.tryParse(_balanceController.text) ?? 0,
        "balance_type": _balanceType == 0 ? "debit" : "credit",
      };

      if (widget.supplier == null) {
        final record = await PurchasesService().pb
            .collection('suppliers')
            .create(body: body);
        if (mounted) {
          Navigator.pop(context, {
            'id': record.id,
            'name': record.data['name'],
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة المورد بنجاح ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await PurchasesService().pb
            .collection('suppliers')
            .update(widget.supplier!['id'], body: body);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تعديل المورد بنجاح ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isWide = screenWidth > 600;

    double dialogWidth = isWide ? 700 : screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // ✅ هام جداً: يخلي الديلوج يلم نفسه
          children: [
            Text(
              widget.supplier == null
                  ? "إضافة مورد جديد"
                  : "تعديل بيانات المورد",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ استبدال Expanded بـ Flexible
            Flexible(
              fit: FlexFit.loose, // يسمح بالانكماش لو المحتوى قليل
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _nameController,
                                label: "اسم المورد",
                                icon: Icons.business,
                                validator: (val) =>
                                    val == null || val.isEmpty ? "مطلوب" : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _managerController,
                                label: "المسئول",
                                icon: Icons.person,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _nameController,
                          label: "اسم المورد",
                          icon: Icons.business,
                          validator: (val) =>
                              val == null || val.isEmpty ? "مطلوب" : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _managerController,
                          label: "المسئول",
                          icon: Icons.person,
                        ),
                      ],

                      const SizedBox(height: 12),

                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _phoneController,
                                label: "الهاتف",
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _addressController,
                                label: "العنوان",
                                icon: Icons.location_on,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _phoneController,
                          label: "الهاتف",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _addressController,
                          label: "العنوان",
                          icon: Icons.location_on,
                        ),
                      ],

                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _notesController,
                        label: "ملاحظات",
                        icon: Icons.note,
                        maxLines: 2,
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "الرصيد الافتتاحي",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _balanceController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: "المبلغ",
                                      fillColor: isDark
                                          ? const Color(0xFF303030)
                                          : Colors.white,
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: RadioListTile<int>(
                                          value: 0,
                                          groupValue: _balanceType,
                                          onChanged: (val) => setState(
                                            () => _balanceType = val!,
                                          ),
                                          title: const Text(
                                            "علينا",
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          activeColor: Colors.red,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<int>(
                                          value: 1,
                                          groupValue: _balanceType,
                                          onChanged: (val) => setState(
                                            () => _balanceType = val!,
                                          ),
                                          title: const Text(
                                            "لنا",
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          activeColor: Colors.green,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("إلغاء", style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSupplier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.brown[300]
                          : Colors.brown[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.supplier == null ? "حفظ" : "تعديل",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: isDark ? const Color(0xFF303030) : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        isDense: true,
      ),
    );
  }
}
