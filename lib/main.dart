import 'dart:async';
import 'package:al_sakr/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pb_helper.dart';
import 'login_screen.dart';

// ✅ مفاتيح التحكم العالمية
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
// ✅ 1. متغير جديد للتحكم في اللغة
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('ar'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await PBHelper().init();

    // تحميل الثيم
    final savedTheme = await PBHelper().getThemeMode();
    themeNotifier.value = savedTheme;

    // ✅ 2. تحميل اللغة المحفوظة
    final savedLocale = await PBHelper().getLocale();
    localeNotifier.value = savedLocale;
  } catch (e) {
    print("Init Error: $e");
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('Connection refused') ||
        details.exception.toString().contains('SocketException') ||
        details.exception.toString().contains('ClientException')) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ConnectionCheckWrapper(),
      );
    }
    return Scaffold(
      body: Center(
        child: Text(
          "حدث خطأ غير متوقع!\n${details.exception}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  };

  runZonedGuarded(
    () {
      runApp(const AlSakrApp());
    },
    (error, stack) {
      print("Global Error Caught: $error");
      handleGlobalError(error);
    },
  );
}

void handleGlobalError(Object error) {
  String errStr = error.toString();
  if (errStr.contains('Connection refused') ||
      errStr.contains('ClientException') ||
      errStr.contains('SocketException')) {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConnectionCheckWrapper()),
        (route) => false,
      );
    }
  }
}

class AlSakrApp extends StatefulWidget {
  const AlSakrApp({super.key});

  @override
  State<AlSakrApp> createState() => _AlSakrAppState();
}

class _AlSakrAppState extends State<AlSakrApp> {
  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      handleGlobalError(details.exception);
    };
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3. الاستماع لتغييرات اللغة والثيم معاً
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier, // الاستماع للغة
          builder: (context, currentLocale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Al Sakr System',
              debugShowCheckedModeBanner: false,

              // ✅ 4. إعدادات اللوكاليزيشن
              locale: currentLocale, // اللغة الحالية
              supportedLocales: const [
                Locale('ar'), // العربية
                Locale('en'), // الإنجليزية
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              themeMode: currentTheme,
              theme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.blue,
                brightness: Brightness.light,
                fontFamily: 'Cairo',
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.blue,
                brightness: Brightness.dark,
                fontFamily: 'Cairo',
              ),

              home: const ConnectionCheckWrapper(),
            );
          },
        );
      },
    );
  }
}

// ... (كلاس ConnectionCheckWrapper يفضل زي ما هو في الكود السابق)
// انسخ كلاس ConnectionCheckWrapper من ردودي السابقة وضعه هنا
class ConnectionCheckWrapper extends StatefulWidget {
  const ConnectionCheckWrapper({super.key});

  @override
  State<ConnectionCheckWrapper> createState() => _ConnectionCheckWrapperState();
}

class _ConnectionCheckWrapperState extends State<ConnectionCheckWrapper> {
  bool _isConnected = false;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final health = await PBHelper().pb.health.check();
      if (health.code == 200) {
        await PBHelper().init();
        setState(() {
          _isConnected = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _errorMessage = 'السيرفر لا يستجيب.\nتأكد من تشغيل PocketBase.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isConnected) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                "فشل الاتصال بالسيرفر",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _checkServer,
                icon: const Icon(Icons.refresh),
                label: const Text("إعادة المحاولة"),
              ),
            ],
          ),
        ),
      );
    }
    return PBHelper().isLoggedIn ? const SplashScreen() : const LoginScreen();
  }
}
