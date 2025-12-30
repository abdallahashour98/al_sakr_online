import 'package:al_sakr/firebase_options.dart';
import 'package:al_sakr/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart'; // تأكد من إضافته
import 'backup_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  // 1. ضمان التهيئة أولاً
  WidgetsFlutterBinding.ensureInitialized();

  // 2. إعداد قاعدة البيانات للديسك توب (Windows/Linux)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. إعداد Firebase (ما عدا Linux)
  if (!Platform.isLinux) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print("Firebase Init Error: $e");
    }
  }

  // 4. تشغيل Sentry والتطبيق
  await SentryFlutter.init((options) {
    options.dsn =
        'https://4426bbe641559b2c132709beb785383b@o4510569137700864.ingest.us.sentry.io/4510569148252160';
    options.tracesSampleRate = 1.0;
    options.attachScreenshot = true;
  }, appRunner: () => runApp(const AccountingApp()));
}

void scheduleAutoBackup() async {
  final backupService = BackupService();
  // SyncfusionLicense.registerLicense(
  //   "Ngo9BigBOggjHTQxAR8/V1JBaF5cXGpCf0x1WmFZfVhgfV9GYVZQTWYuP1ZhSXxWd0dhXn9XcHVUT2VeWEd9XEA=",
  // );
  // 1. هل عملنا باك اب النهاردة بالفعل؟
  bool doneToday = await backupService.isBackupDoneToday();
  if (doneToday) {
    print("info: Auto backup already done for today.");
    return; // خلاص مش محتاجين نعمل حاجة
  }

  DateTime now = DateTime.now();

  // 2. تحديد وقت الهدف (اليوم الساعة 4 عصراً)
  DateTime targetTime = DateTime(
    now.year,
    now.month,
    now.day,
    16,
    0,
    0,
  ); // 16:00 = 4 PM

  // 3. التحقق من السيناريوهات
  if (now.isAfter(targetTime)) {
    // 🅰️ السيناريو الأول: فتحنا البرنامج بعد الساعة 4 ولسة معملناش باك اب
    // (يعني فات معادها أو الجهاز كان مقفول)
    print("⚠️ Missed 4 PM schedule, starting backup now (Catch-up)...");
    await backupService.performAutoBackup();
  } else {
    // 🅱️ السيناريو الثاني: فتحنا البرنامج قبل الساعة 4 (مثلاً الساعة 1 ظهرأ)
    // لازم نضبط تايمر يشتغل لما الساعة تيجي 4 والبرنامج مفتوح
    Duration waitDuration = targetTime.difference(now);
    print("⏰ Scheduling backup in ${waitDuration.inMinutes} minutes (at 4 PM)");

    Timer(waitDuration, () async {
      print("🔔 It's 4 PM! Starting scheduled backup...");
      await backupService.performAutoBackup();
    });
  }
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
