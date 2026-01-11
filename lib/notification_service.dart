import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ✅ دالة التهيئة المحدثة
  // تقبل دالة (onNotificationTap) لتحديد ماذا يحدث عند الضغط (اختياري)
  // وتقبل (requestPermission) لتحديد هل نطلب الإذن أم لا (للخلفية نرسل false)
  static Future<void> init({
    bool requestPermission = false,
    Function(NotificationResponse)? onNotificationTap,
  }) async {
    // 1. إعدادات الأندرويد
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. إعدادات اللينكس
    final LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    // تجميع الإعدادات
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    // تهيئة البلاجن
    await _notificationsPlugin.initialize(
      initSettings,
      // نربط دالة الضغط هنا (ستكون null في الخلفية لتجنب الكراش)
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    // طلب الإذن فقط إذا طلبنا ذلك (في الواجهة)
    if (requestPermission) {
      await _requestPermissions();
    }
  }

  // دالة طلب الأذونات (للأندرويد 13+)
  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // ✅ دالة جديدة: هل فتح التطبيق بسبب الضغط على إشعار؟
  // نستخدمها في main.dart لتوجيه المستخدم
  static Future<bool> didAppLaunchFromNotification() async {
    final NotificationAppLaunchDetails? details = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  // دالة إظهار الإشعار
  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // تفاصيل قناة الأندرويد
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'announcements_channel', // نفس الـ ID المستخدم في Background Service
          'تنبيهات الإدارة',
          channelDescription: 'قناة خاصة بإشعارات لوحة التحكم',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );

    // تفاصيل اللينكس
    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    // استخدام ID ممرر أو توليد عشوائي
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch % 100000;

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
