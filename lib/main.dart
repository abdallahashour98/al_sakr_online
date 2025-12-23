import 'package:al_sakr/firebase_options.dart';
import 'package:al_sakr/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// متغير التحكم في الثيم
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
Future<void> main() async {
  // تأكد من تهيئة Flutter قبل Sentry
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit(); // تهيئة FFI
    databaseFactory = databaseFactoryFfi; // ضبط المصنع لاستخدام FFI
  }

  if (!Platform.isLinux) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print("Firebase Init Error: $e");
    }
  }
  await SentryFlutter.init((options) {
    options.dsn =
        'https://4426bbe641559b2c132709beb785383b@o4510569137700864.ingest.us.sentry.io/4510569148252160'; // استبدل هذا بالرابط الخاص بك من موقع Sentry

    // لتتبع أداء التطبيق (اختياري)
    options.tracesSampleRate = 1.0;

    // التقاط صور للشاشة عند حدوث الخطأ (مفيد جداً في حل المشاكل)
    options.attachScreenshot = true;
  }, appRunner: () => runApp(const AccountingApp()));
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Al-Sakr',
          navigatorObservers: [
            SentryNavigatorObserver(), // أضف هذا السطر لتتبع حركة المستخدم
          ],
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // =========================
          // ☀️ الوضع الفاتح (Light)
          // =========================
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey[50],

            // إعدادات التول بار الموحدة للفاتح
            appBarTheme: const AppBarTheme(
              backgroundColor: Color.fromARGB(255, 9, 38, 62), // لون ثابت
              foregroundColor: Color.fromARGB(255, 255, 254, 254),
              centerTitle: true,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
            ),

            // إعدادات الكروت الموحدة
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),

          // =========================
          // 🌙 الوضع الداكن (Dark)
          // =========================
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: Colors.blueGrey,
            scaffoldBackgroundColor: const Color(0xFF121212), // أسود رمادي
            // إعدادات التول بار الموحدة للداكن
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E), // نفس لون الكروت
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
            ),

            // إعدادات الكروت الموحدة للداكن
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            iconTheme: const IconThemeData(color: Colors.white70),
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}
