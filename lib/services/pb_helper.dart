import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart'; // ✅ استدعاء ملف الثوابت

class PBHelper {
  // Singleton Pattern
  static final PBHelper _instance = PBHelper._internal();
  factory PBHelper() => _instance;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ✅ نستخدم late، وسيتم تهيئته في دالة init
  // late PocketBase pb;
  PocketBase pb = PocketBase(AppConfig.baseUrl);
  // Constructor خاص
  PBHelper._internal();

  // ============================================================
  // 🚀 1. التهيئة (Initialization)
  // ============================================================
  static Future<void> init({
    bool requestPermission = false,
    Function(NotificationResponse)? onNotificationTap,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. إعداد مخزن المصادقة
    final store = AsyncAuthStore(
      save: (String data) async => await prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );

    // 2. تهيئة PocketBase
    PBHelper().pb = PocketBase(AppConfig.baseUrl, authStore: store);

    // 3. إعدادات الإشعارات (Notifications)

    // أندرويد
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('notification_icon');

    // لينكس
    final LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    // ✅ ويندوز (الإضافة الجديدة لحل المشكلة)
    // ✅ ويندوز (تمت إضافة المعرفات الإجبارية للإصدار الجديد)
    final WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
          appName: 'Al Sakr',
          appUserModelId: 'com.alsakr.app', // معرف فريد للتطبيق
          guid:
              '81a17932-d603-4f24-9b24-94f712431692', // معرف GUID عشوائي وفريد
        );

    // تجميع الإعدادات
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
      windows: windowsSettings, // 👈 لازم تمرر المتغير ده هنا
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    // طلب الصلاحيات (للأندرويد فقط)
    if (requestPermission) {
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    }
  } // ============================================================
  // 🖼️ 2. دوال مساعدة عامة (Helpers)
  // ============================================================

  bool get isLoggedIn => pb.authStore.isValid;

  // جلب رابط الصورة
  String getImageUrl(String collectionId, String recordId, String filename) {
    if (filename.isEmpty) return '';
    return '${AppConfig.baseUrl}/api/files/$collectionId/$recordId/$filename';
  }

  // تحويل السجل لـ Map (دالة ثابتة ومهمة جداً)
  static Map<String, dynamic> recordToMap(RecordModel record) {
    var data = Map<String, dynamic>.from(record.data);
    data['id'] = record.id;
    data['collectionId'] = record.collectionId;
    data['created'] = record.created;
    data['updated'] = record.updated;

    // فك بيانات العلاقات (Expand)
    if (record.expand.isNotEmpty) {
      if (record.expand.containsKey('supplier')) {
        data['supplierName'] = record.expand['supplier']?.first.data['name'];
      }
      if (record.expand.containsKey('client')) {
        data['clientName'] = record.expand['client']?.first.data['name'];
      }
      if (record.expand.containsKey('product')) {
        data['productName'] = record.expand['product']?.first.data['name'];
      }
      // للمستخدمين (في الإشعارات أو غيره)
      if (record.expand.containsKey('user')) {
        data['userName'] = record.expand['user']?.first.data['name'];
      }
      // للمشاهدين (seen_by)
      if (record.expand.containsKey('seen_by')) {
        final users = record.expand['seen_by'];
        if (users != null && users.isNotEmpty) {
          data['seen_by_names'] = users.map((u) => u.data['name']).toList();
        }
      }
    }
    return data;
  }

  // ============================================================
  // ⚡ 3. البيانات الحية (Real-time Stream)
  // ============================================================
  Stream<List<Map<String, dynamic>>> getCollectionStream(
    String collectionName, {
    String sort = '-created',
    String? expand,
    String? filter,
  }) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    Future<void> fetchData() async {
      try {
        final records = await pb
            .collection(collectionName)
            .getFullList(sort: sort, expand: expand, filter: filter);
        if (!controller.isClosed) {
          final data = records.map((r) => recordToMap(r)).toList();
          controller.add(data);
        }
      } catch (e) {
        print("⚠️ Error fetching stream data ($collectionName): $e");
      }
    }

    // 1. جلب البيانات فوراً
    fetchData();

    // 2. الاشتراك في التغييرات
    Future.delayed(Duration.zero, () async {
      try {
        await pb.collection(collectionName).subscribe('*', (e) {
          if (!controller.isClosed) {
            fetchData(); // تحديث عند أي تغيير
          }
        });
      } catch (e) {
        print("⚠️ Realtime error ($collectionName): $e");
      }
    });

    controller.onCancel = () {
      try {
        pb.collection(collectionName).unsubscribe('*');
      } catch (_) {}
      controller.close();
    };

    return controller.stream;
  }

  // ============================================================
  // 🔔 4. الإشعارات المحلية (Notifications)
  // ============================================================
  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'announcements_channel', // id القناة
          'تنبيهات الإدارة', // اسم القناة
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch % 100000;

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ============================================================
  // 🆔 5. أدوات مساعدة (Utils)
  // ============================================================
  // توليد ID عشوائي (للـ Batch operations)
  static String generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(15, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}
