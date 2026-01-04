import 'dart:io'; // عشان نستخدم Platform
// عشان نستخدم kIsWeb لو احتجتها مستقبلاً

class ApiConfig {
  static String get baseUrl {
    // لو التطبيق شغال على أندرويد (تحديداً الإيميلاتور)
    if (Platform.isAndroid) {
      // ملحوظة: لو بتجرب على موبايل حقيقي لازم تحط هنا الـ IP بتاع اللابتوب (192.168.x.x)
      // أما لو إيميلاتور (محاكي) بنستخدم 10.0.2.2
      return "http://10.0.2.2:8090";
    }

    // لو التطبيق شغال ويندوز أو لينكس
    if (Platform.isWindows || Platform.isLinux) {
      return "http://127.0.0.1:8090";
    }

    // افتراضي
    return "http://127.0.0.1:8090";
  }
}
