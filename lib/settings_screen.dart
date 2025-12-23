import 'dart:io'; // 🆕 ضروري عشان نعرف إحنا على لينكس ولا ويندوز
import 'package:flutter/material.dart';
import 'excel_service.dart';
import 'backup_service.dart';
import 'update_service.dart'; // 🆕 استدعاء كلاس التحديث
import 'db_helper.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;

  // متغيرات الإصدار
  int _dbVer = 0;
  final String _appVersion =
      "1.0.1"; // 👈 يفضل تحديثه يدوياً ليتطابق مع pubspec.yaml

  @override
  void initState() {
    super.initState();
    _getDbVersion();
  }

  void _getDbVersion() {
    setState(() {
      _dbVer = DatabaseHelper().currentDbVersion;
    });
  }

  Future<void> _performAction(Future<void> Function() action) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.grey[800];

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'الإعدادات والبيانات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- قسم المظهر ---
                  const Text(
                    'المظهر',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeNotifier,
                        builder: (context, currentMode, child) {
                          return DropdownButtonHideUnderline(
                            child: DropdownButton<ThemeMode>(
                              value: currentMode,
                              isExpanded: true,
                              icon: const Icon(Icons.brightness_6),
                              items: const [
                                DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text('النظام (الافتراضي)'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text('فاتح (Light Mode)'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text('داكن (Dark Mode)'),
                                ),
                              ],
                              onChanged: (ThemeMode? newMode) {
                                if (newMode != null) {
                                  themeNotifier.value = newMode;
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 20),

                  // --- قسم قاعدة البيانات (النسخ الاحتياطي الشامل) ---
                  const Text(
                    'النسخ الاحتياطي (بيانات + صور)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      // زر التصدير (ZIP)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading
                                ? Colors.grey
                                : Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  await _performAction(() async {
                                    await BackupService().exportBackup(context);
                                  });
                                },
                          icon: const Icon(Icons.archive),
                          label: const Text('تصدير نسخة (ZIP)'),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // زر الاستعادة (ZIP)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading
                                ? Colors.grey
                                : Colors.orange[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تنبيه هام'),
                                      content: const Text(
                                        'أنت على وشك استعادة نسخة قديمة.\n\n'
                                        '⚠️ سيتم مسح جميع البيانات الحالية واستبدالها ببيانات النسخة الاحتياطية.\n\n'
                                        'أي فواتير أو أصناف أضيفت بعد تاريخ هذه النسخة سوف تُحذف نهائياً.',
                                        style: TextStyle(height: 1.5),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _performAction(() async {
                                              await BackupService()
                                                  .importBackup(context);
                                            });
                                          },
                                          child: const Text(
                                            'نعم، استعادة',
                                            style: TextStyle(
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.unarchive),
                          label: const Text('استعادة نسخة'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 20),

                  // --- قسم الإكسيل ---
                  const Text(
                    'التعامل مع Excel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // زر التصدير للإكسيل
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading
                            ? Colors.grey
                            : Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await _performAction(() async {
                                await ExcelService().exportFullBackup();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم تصدير ملف الإكسيل بنجاح',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              });
                            },
                      icon: const Icon(Icons.download),
                      label: const Text('تصدير البيانات للإكسيل'),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // زر الاستيراد من إكسيل
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading
                            ? Colors.grey
                            : Colors.green[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await _performAction(() async {
                                String res = await ExcelService()
                                    .importFullBackup();
                                if (mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تقرير الاستيراد'),
                                      content: SingleChildScrollView(
                                        child: Text(res),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('حسنًا'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              });
                            },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('استيراد أصناف من إكسيل'),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 20),

                  // --- 🆕 قسم تحديث النظام ---
                  const Text(
                    'تحديث النظام',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading
                            ? Colors.grey
                            : Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              // التحقق من النظام لتجنب الكراش على لينكس
                              if (Platform.isLinux) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'التحديث التلقائي غير مدعوم على نسخة اللينكس التجريبية',
                                    ),
                                  ),
                                );
                                return;
                              }

                              await _performAction(() async {
                                // استدعاء دالة التحقق من التحديث
                                await UpdateService().checkForUpdate(context);
                              });
                            },
                      icon: const Icon(Icons.system_update),
                      label: const Text('التحقق من وجود تحديثات'),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- الفوتر (يحتوي على الإصدارات) ---
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Developed by',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Roboto',
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Abdallah Ashour',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            letterSpacing: 1.5,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 10),

                        // مستطيل عرض الإصدارات
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'App Version: $_appVersion  |  DB Version: $_dbVer',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // طبقة التحميل
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
