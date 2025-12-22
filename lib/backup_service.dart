import 'dart:io';
import 'package:archive/archive_io.dart'; // مكتبة التعامل مع ZIP
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
// import 'package:sqflite/sqflite.dart'; // ❌ لم نعد نحتاجها هنا
import 'db_helper.dart';

class BackupService {
  final String _dbName = 'SmartAccountingDB.db';

  // =================================================================
  // 1️⃣ دالة التصدير (Export): داتا بيز + صور -> ملف ZIP
  // =================================================================
  Future<bool> exportBackup(BuildContext context) async {
    try {
      // 🔥 تصحيح المسار: استخدام نفس مسار db_helper 🔥
      final appDir = await getApplicationSupportDirectory();
      String dbPath = p.join(appDir.path, _dbName);
      final dbFile = File(dbPath);

      // تحديد مسار مجلد الصور
      final imagesDir = Directory('${appDir.path}/product_images');

      // إغلاق قاعدة البيانات لضمان عدم تلف البيانات أثناء النسخ
      final dbHelper = DatabaseHelper();
      await dbHelper.close();

      // تجهيز ملف الـ ZIP المؤقت
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .split('.')[0];
      final zipPath = '${tempDir.path}/AL-SAKR_Backup_$dateStr.zip';

      // إنشاء المشفر
      var encoder = ZipFileEncoder();
      encoder.create(zipPath);

      // أ. إضافة ملف قاعدة البيانات للأرشيف
      if (await dbFile.exists()) {
        await encoder.addFile(dbFile, 'database.db');
      } else {
        // طباعة المسار للتأكد في حالة الخطأ
        print("Could not find DB at: $dbPath");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطأ: لم يتم العثور على قاعدة البيانات!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // ب. إضافة مجلد الصور للأرشيف
      if (await imagesDir.exists()) {
        await encoder.addDirectory(imagesDir, includeDirName: true);
      }

      encoder.close();

      // مشاركة الملف أو حفظه
      if (Platform.isAndroid || Platform.isIOS) {
        await Share.shareXFiles([XFile(zipPath)], text: 'نسخة احتياطية شاملة (AL-SAKR)');
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ النسخة الاحتياطية',
          fileName: 'AL-SAKR_Backup_$dateStr.zip',
          allowedExtensions: ['zip'],
          type: FileType.custom,
        );

        if (outputFile != null) {
          if (!outputFile.toLowerCase().endsWith('.zip')) {
            outputFile = '$outputFile.zip';
          }
          await File(zipPath).copy(outputFile);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم الحفظ في: $outputFile'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }

      return true;
    } catch (e) {
      print("Export Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التصدير: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // =================================================================
  // 2️⃣ دالة الاستيراد (Import): فك الضغط -> استعادة داتا بيز + صور
  // =================================================================
  Future<bool> importBackup(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        File zipFile = File(result.files.single.path!);
        final bytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        // 🔥 تصحيح المسار: استخدام نفس مسار db_helper 🔥
        final appDir = await getApplicationSupportDirectory();
        String dbPath = p.join(appDir.path, _dbName);
        final imagesDestDir = Directory('${appDir.path}/product_images');

        // إغلاق وحذف قاعدة البيانات القديمة
        final dbHelper = DatabaseHelper();
        await dbHelper.close();

        final oldDbFile = File(dbPath);
        if (await oldDbFile.exists()) {
          try {
            await oldDbFile.delete();
          } catch (e) {
            print("Warning deleting old DB: $e");
          }
        }

        // تنظيف وإعادة إنشاء مجلد الصور
        if (await imagesDestDir.exists()) {
          try {
            await imagesDestDir.delete(recursive: true);
          } catch (e) {
            print("Warning deleting old images: $e");
          }
        }
        await imagesDestDir.create(recursive: true);

        // فك الضغط
        for (final file in archive) {
          if (file.isFile) {
            if (file.name == 'database.db') {
              final data = file.content as List<int>;
              File(dbPath)
                ..createSync(recursive: true)
                ..writeAsBytesSync(data);
            } else if (file.name.startsWith('product_images/')) {
              final filename = p.basename(file.name);
              if (filename.isNotEmpty && !filename.startsWith('.')) {
                final data = file.content as List<int>;
                File('${imagesDestDir.path}/$filename')
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(data);
              }
            }
          }
        }

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('تمت الاستعادة بنجاح', style: TextStyle(color: Colors.green)),
              content: const Text('تم استرجاع البيانات والصور.\nيرجى إعادة تشغيل التطبيق لتطبيق التغييرات.'),
              actions: [
                ElevatedButton(
                  onPressed: () => exit(0),
                  child: const Text('إغلاق التطبيق'),
                ),
              ],
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      print("Import Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الاستيراد: الملف تالف أو غير مدعوم ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
