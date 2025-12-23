import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 👈 المكتبة الجديدة
import 'dart:convert'; // 👈 عشان نفك تشفير البيانات الراجعة
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // 👇 1. ضع رابط قاعدة البيانات الخاص بك هنا
  // هتلاقيه في الفايربيس كونسول في صفحة Realtime Database من فوق
  // ومهم جداً تزود في آخره كلمة ".json"
  final String databaseUrl =
      "https://al-sakr-default-rtdb.firebaseio.com/app_update.json";

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 2. قراءة البيانات باستخدام رابط إنترنت عادي (يعمل على الويندوز والكل)
      final response = await http.get(Uri.parse(databaseUrl));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        // تحويل النص الراجع إلى Map
        final data = json.decode(response.body);

        // التحقق أن البيانات ليست فارغة (null)
        if (data != null) {
          String serverVersion = data['latest_version'].toString();
          String downloadUrl = data['download_url'].toString();
          String notes =
              data['release_notes'] ?? 'تحديث جديد متاح لتحسين الأداء';

          // 3. معرفة إصدار التطبيق الحالي
          PackageInfo packageInfo = await PackageInfo.fromPlatform();
          String currentVersion = packageInfo.version;

          print("Current: $currentVersion | Server: $serverVersion");

          // 4. المقارنة
          if (_isNewer(serverVersion, currentVersion)) {
            if (context.mounted) {
              _showUpdateDialog(context, serverVersion, notes, downloadUrl);
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('البرنامج محدث لآخر إصدار ✅'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      } else {
        throw "فشل الاتصال بقاعدة البيانات (Status: ${response.statusCode})";
      }
    } catch (e) {
      print("Error checking update: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحقق من التحديثات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isNewer(String server, String current) {
    return server != current;
  }

  void _showUpdateDialog(
    BuildContext context,
    String version,
    String notes,
    String url,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 10),
            Text('تحديث جديد متاح'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإصدار الجديد: $version',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('ما الجديد:'),
            Text(notes),
            const SizedBox(height: 20),
            const Text(
              'سيتم فتح المتصفح لتحميل التحديث.\nيرجى تحميل الملف وتثبيته.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchDownloadUrl(url);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'تحميل التحديث',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDownloadUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}
