import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

// ⚠️ تأكد أن هذا الـ IP صحيح وثابت
final String kBaseUrl = AppConfig.baseUrl;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 1. قناة الإشعارات المهمة (للإعلانات) - صوت عالي
  const AndroidNotificationChannel announcementChannel =
      AndroidNotificationChannel(
        'announcements_channel',
        'تنبيهات الإدارة',
        description: 'قناة التنبيهات الإدارية',
        importance: Importance.max, // صوت عالي
        playSound: true,
      );

  // 2. قناة الخدمة (لإشعار "نشط") - صامت تماماً
  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    'my_foreground',
    'حالة التطبيق',
    description: 'يبقي التطبيق متصلاً في الخلفية',
    importance: Importance.low, // 👈 جعلناها منخفضة لعدم الإزعاج
    playSound: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(announcementChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(serviceChannel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground', // 👈 ربطناه بالقناة الصامتة
      initialNotificationTitle: 'تطبيق الصقر',
      initialNotificationContent: 'يعمل في الخلفية',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
  );

  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final pb = PocketBase(kBaseUrl);
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // تجهيز SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  print("🚀 Background Service Started...");

  // دالة تنظيف النص
  String cleanText(String jsonString) {
    try {
      if (!jsonString.trim().startsWith('[')) return jsonString;
      final List<dynamic> delta = jsonDecode(jsonString);
      final StringBuffer buffer = StringBuffer();
      for (var op in delta) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          buffer.write(op['insert']);
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      return jsonString;
    }
  }

  try {
    // إلغاء أي اشتراك سابق
    pb.collection('announcements').unsubscribe();

    // الاشتراك الجديد
    pb.collection('announcements').subscribe('*', (e) async {
      if (e.action == 'create') {
        // تحديث البيانات وقراءة الـ ID للتأكد من هوية المستخدم
        await prefs.reload();
        String? myUserId = prefs.getString('my_user_id');

        // 1. تجاهل الإشعارات الصادرة مني
        String creatorId = e.record!.data['user'] ?? '';
        if (myUserId != null && creatorId == myUserId) {
          return;
        }

        // 2. التحقق من التوجيه
        List targets = e.record!.data['target_users'] ?? [];
        if (targets.isNotEmpty &&
            myUserId != null &&
            !targets.contains(myUserId)) {
          return;
        }

        // 3. عرض الإشعار
        String rawContent = e.record!.data['content'] ?? '...';
        String finalContent = cleanText(rawContent);
        String title = e.record!.data['title'] ?? 'تنبيه إداري';

        flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch % 100000,
          title,
          finalContent,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'announcements_channel',
              'تنبيهات الإدارة',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
          // 👇👇 هذا السطر هو المسؤول عن التوجيه عند الضغط 👇👇
          payload: 'navigate_to_notices',
        );
      }
    });
  } catch (err) {
    print("❌ Error subscribing: $err");
  }

  // ✅ التايمر الآن صامت تماماً (فقط للحفاظ على الاتصال)
  // تم حذف الكود المزعج الذي كان يحدث الإشعار كل دقيقة
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      // فحص خفي للاتصال بالسيرفر لإبقاء الخدمة نشطة دون إزعاج المستخدم
      await pb.health.check();
    } catch (_) {
      // في حالة الخطأ لا نفعل شيئاً، سيحاول مرة أخرى في الدقيقة التالية
    }
  });
}
