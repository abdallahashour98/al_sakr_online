import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // مرجع لقاعدة البيانات
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('app_update');

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. قراءة البيانات من فايربيس
      final snapshot = await _dbRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        String serverVersion = data['latest_version'];
        String downloadUrl = data['download_url'];
        String notes = data['release_notes'] ?? 'تحديث جديد متاح لتحسين الأداء';

        // 2. معرفة إصدار التطبيق الحالي
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version;

        print("Current: $currentVersion | Server: $serverVersion");

        // 3. المقارنة (لو الإصدار الجديد مختلف عن الحالي)
        if (_isNewer(serverVersion, currentVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, serverVersion, notes, downloadUrl);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('البرنامج محدث لآخر إصدار ✅')),
            );
          }
        }
      }
    } catch (e) {
      print("Error checking update: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل التحقق من التحديثات: $e')));
      }
    }
  }

  // دالة بسيطة لمقارنة الأرقام
  bool _isNewer(String server, String current) {
    // هذه طريقة مبسطة، يفضل استخدام مكتبة pub_semver للمقارنة الدقيقة
    // لكن بما أنك المتحكم، فقط تأكد أن ترفع الرقم دائماً
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
        title: Row(
          children: const [
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
