import 'package:al_sakr/dashboard.dart';
import 'package:flutter/material.dart';
import 'pb_helper.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ استدعاء المكتبة

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailUserPartController =
      TextEditingController(); // نكتب هنا الاسم فقط
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;
  bool _rememberMe = false; // ✅ متغير لحالة "تذكرني"

  // النطاق الثابت
  final String _fixedDomain = "@alsakr.com";

  @override
  void initState() {
    super.initState();
    // 1. إلغاء أي اشتراك قديم
    try {
      PBHelper().pb.realtime.unsubscribe();
    } catch (e) {
      // ignore
    }
    // 2. استرجاع البيانات المحفوظة
    _loadSavedCredentials();
  }

  // ✅ دالة تحميل البيانات المحفوظة
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // نجيب الاسم فقط (بدون الدومين)
      _emailUserPartController.text = prefs.getString('saved_user_part') ?? '';
      _passwordController.text = prefs.getString('saved_password') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  // ✅ دالة تسجيل الدخول المعدلة
  void _login() async {
    if (_emailUserPartController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل البيانات كاملة')));
      return;
    }

    setState(() => _isLoading = true);

    // 1. دمج الاسم مع الدومين الثابت
    String fullEmail = "${_emailUserPartController.text.trim()}$_fixedDomain";

    // 2. محاولة الدخول
    bool success = await PBHelper().login(
      fullEmail,
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success) {
      // ✅ 3. حفظ أو مسح البيانات بناءً على الـ Checkbox
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(
          'saved_user_part',
          _emailUserPartController.text.trim(),
        );
        await prefs.setString(
          'saved_password',
          _passwordController.text.trim(),
        );
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_user_part');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('بيانات الدخول غير صحيحة')));
    }
  }

  // ✅ دالة لمسح البيانات المحفوظة يدوياً
  void _clearSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _emailUserPartController.clear();
      _passwordController.clear();
      _rememberMe = false;
    });
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم مسح البيانات المحفوظة')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الشعار أو الأيقونة
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "تسجيل الدخول",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 40),

              // ✅ التعديل هنا: فصل الجزء الثابت خارج الـ TextField باستخدام Row
              Row(
                children: [
                  // حقل إدخال الجزء الأول من الإيميل
                  Expanded(
                    child: TextField(
                      controller: _emailUserPartController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'الإيميل (الجزء الأول)', // توضيح أكثر
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        // تمت إزالة suffixText من هنا
                      ),
                    ),
                  ),

                  const SizedBox(width: 10), // مسافة صغيرة
                  // ✅ الجزء الثابت من الإيميل (منفصل وبخط كبير)
                  Text(
                    _fixedDomain, // "@alsakr.com"
                    style: const TextStyle(
                      fontSize: 20, // تكبير الخط
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey, // لون واضح لكن غير مزعج
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // حقل كلمة المرور (بدون تغيير)
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.grey,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                ),
              ),

              const SizedBox(height: 15),

              // زر الحفظ (بدون تغيير)
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: Colors.blue,
                    side: const BorderSide(color: Colors.grey),
                    onChanged: (val) {
                      setState(() {
                        _rememberMe = val ?? false;
                      });
                    },
                  ),
                  const Text(
                    "حفظ بيانات الدخول",
                    style: TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (_emailUserPartController.text.isNotEmpty)
                    TextButton(
                      onPressed: _clearSavedData,
                      child: const Text(
                        "مسح المحفوظ",
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 30),

              // زر الدخول (بدون تغيير)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'دخول',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
