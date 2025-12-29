import 'package:al_sakr/GeneralReportsScreen.dart';
import 'package:al_sakr/clients_screen.dart';
import 'package:al_sakr/delivery_orders_screen.dart';
import 'package:flutter/material.dart';
import 'sales_screen.dart';
import 'store_screen.dart';
import 'client_statement.dart';
import 'reports_screen.dart';
import 'returns_list_screen.dart';
import 'suppliers_screen.dart';
import 'purchase_screen.dart';
import 'purchase_history_screen.dart';
import 'supplier_report_screen.dart';
import 'settings_screen.dart';
import 'expenses_screen.dart'; // تأكد من إنشاء الملف أولاً

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // التحقق من الوضع الحالي (هل هو ليلي أم نهاري؟)
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, dynamic>> menuItems = [
      // ================== 1. العمليات الأساسية (الأكثر تكراراً) ==================
      {
        'title': 'فاتورة مبيعات', // أهم زر، لازم يكون الأول
        'icon': Icons.point_of_sale,
        'color': Colors.blue[700],
        'page': const SalesScreen(),
      },
      {
        'title': 'شراء (توريد)', // توريد بضاعة جديدة
        'icon': Icons.add_shopping_cart,
        'color': Colors.blue[700],
        'page': const PurchaseScreen(),
      },
      {
        'title': 'المخزن والأصناف', // عشان تشوف البضاعة بسرعة
        'icon': Icons.inventory_2,
        'color': Colors.orange[800],
        'page': const StoreScreen(),
      },

      {
        'title': 'المرتجعات', // عملية متكررة
        'icon': Icons.assignment_return,
        'color': Colors.red[700],
        'page': const ReturnsListScreen(),
      },

      // ================== 2. المبيعات والعملاء ==================
      {
        'title': 'سجل المبيعات', // مراجعة الفواتير السابقة
        'icon': Icons.history_edu,
        'color': Colors.green[900],
        'page': const ReportsScreen(),
      },
      {
        'title': 'سجل المشتريات', // مراجعة فواتير الشراء
        'icon': Icons.receipt_long,
        'color': Colors.green[900],
        'page': const PurchaseHistoryScreen(),
      },
      {
        'title': 'كشف حسابات العملاء', // معرفة الديون
        'icon': Icons.account_balance_wallet,
        'color': Colors.purple[900],
        'page': const ClientStatementScreen(),
      },
      {
        'title': 'كشف حسابات الموردين', // كشف حساب المورد
        'icon': Icons.analytics,
        'color': Colors.purple[900],
        'page': const SupplierReportScreen(),
      },
      {
        'title': 'إدارة العملاء', // إضافة وتعديل بيانات العملاء
        'icon': Icons.people,
        'color': Colors.brown[600],
        // تأكد من وجود ClientsScreen لديك أو استبدالها
        'page': const ClientsScreen(),
      },

      // ================== 3. المشتريات والموردين ==================
      {
        'title': 'إدارة الموردين', // إضافة وتعديل الموردين
        'icon': Icons.local_shipping,
        'color': Colors.brown[600],
        'page': const SuppliersScreen(),
      },
      {
        'title': 'أذونات التسليم', // تسجيل المصاريف
        'icon': Icons.receipt_long,
        'color': Colors.redAccent,
        'page': const DeliveryOrdersScreen(),
      },
      {
        'title': 'المصروفات', // تسجيل المصاريف
        'icon': Icons.money_off,
        'color': Colors.redAccent,
        'page': const ExpensesScreen(),
      },
      // ================== 4. المالية والإعدادات ==================
      {
        'title': 'التقارير الشاملة', // عينك على البزنس كله
        'icon': Icons.bar_chart,
        'color': const Color(0xFFFBC02D), // لون ذهبي مميز للتقارير
        'page': const GeneralReportsScreen(),
      },

      {
        'title': 'الإعدادات', // آخر حاجة تحت
        'icon': Icons.settings,
        'color': Colors.grey[700],
        'page': const SettingsScreen(),
      },
    ];

    return Scaffold(
      // استخدام لون الخلفية من الثيم بدلاً من تثبيته على الأبيض
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // LayoutBuilder هو السر لجعل التصميم متجاوباً
      body: LayoutBuilder(
        builder: (context, constraints) {
          // تحديد عدد الأعمدة بناءً على عرض الشاشة
          int crossAxisCount;
          if (constraints.maxWidth > 1100) {
            crossAxisCount = 5; // شاشات كبيرة جداً
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 4; // لابتوب
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 3; // تابلت
          } else {
            crossAxisCount = 2; // موبايل
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: GridView.builder(
              itemCount: menuItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildDashboardCard(
                  context,
                  item['title'],
                  item['icon'],
                  item['color'],
                  item['page'],
                  isDark, // نمرر حالة الوضع الليلي للكارت
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
    bool isDark,
  ) {
    return Card(
      elevation: 4,
      // تغيير لون الكارت بناءً على الوضع
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              // تعديل التدرج ليكون مناسباً للوضع الليلي والنهاري
              colors: isDark
                  ? [color.withOpacity(0.2), Colors.black12]
                  : [color.withOpacity(0.05), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 35, color: color),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  // لون النص يتغير حسب الوضع
                  color: isDark ? Colors.white70 : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
