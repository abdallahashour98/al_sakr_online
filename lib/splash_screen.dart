import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors
          .white, // 1. \u063a\u064a\u0631\u0646\u0627 \u0627\u0644\u0644\u0648\u0646 \u0644\u0623\u0628\u064a\u0636
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // \u0627\u0644\u0644\u0648\u062c\u0648
            Image.asset('assets/splash_logo.png', width: 250, height: 250),
            const SizedBox(height: 20),

            // \u0627\u0644\u0627\u0633\u0645
            const SizedBox(height: 30),
            // \u0645\u0624\u0634\u0631 \u0627\u0644\u062a\u062d\u0645\u064a\u0644
            const CircularProgressIndicator(
              color: Colors
                  .teal, // 3. \u063a\u064a\u0631\u0646\u0627 \u0644\u0648\u0646 \u0627\u0644\u062a\u062d\u0645\u064a\u0644
            ),
          ],
        ),
      ),
    );
  }
}
