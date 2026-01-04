import 'package:flutter/material.dart';
import 'pb_helper.dart';

// تأكد من وجود هذه الملفات أو علق الاستدعاءات التي لا تحتاجها
import 'store_screen.dart';
import 'suppliers_screen.dart';
import 'clients_screen.dart';
// افترضت وجود شاشة لسجل المشتريات
import 'expenses_screen.dart';
import 'returns_list_screen.dart'; // ✅ تم التفعيل

class GeneralReportsScreen extends StatefulWidget {
  const GeneralReportsScreen({super.key});

  @override
  State<GeneralReportsScreen> createState() => _GeneralReportsScreenState();
}

class _GeneralReportsScreenState extends State<GeneralReportsScreen> {
  bool _isLoading = true;
  Map<String, double> _data = {};

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    // جلب البيانات الحقيقية من السيرفر
    final data = await PBHelper().getGeneralReportData();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    ).then((_) => _loadReportData()); // تحديث عند العودة
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 1. استخراج الأرقام (مع الحماية من null)
    double sales = _data['monthlySales'] ?? 0.0;
    double clientReturns = _data['clientReturns'] ?? 0.0; // ✅
    double supplierReturns = _data['supplierReturns'] ?? 0.0; // ✅
    double returns = _data['monthlyReturns'] ?? 0.0;
    double expenses = _data['monthlyExpenses'] ?? 0.0;
    double supplierPayments = _data['monthlyPayments'] ?? 0.0;
    double purchasesBills = _data['monthlyBills'] ?? 0.0;

    // 2. الحسابات المشتقة
    double netSales = sales - returns; // صافي المبيعات
    // صافي السيولة = (اللي دخل) - (اللي خرج)
    // اللي دخل: صافي المبيعات (بافتراض التحصيل)
    // اللي خرج: مصاريف + مدفوعات موردين
    double netCashFlow = netSales - (expenses + supplierPayments);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير المالي الشامل'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReportData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ================= القسم الأول: السيولة (الشهر الحالي) =================
                    _buildSectionHeader("حركة السيولة (الشهر الحالي)"),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          _buildCashRow(
                            "صافي المبيعات (إيراد)",
                            netSales,
                            Colors.green,
                          ),
                          const Divider(),
                          _buildCashRow(
                            "مصاريف تشغيل (خرج)",
                            -expenses,
                            Colors.red,
                          ),
                          _buildCashRow(
                            "مدفوعات موردين (خرج)",
                            -supplierPayments,
                            Colors.orange[800]!,
                          ),
                          const Divider(thickness: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "صافي السيولة :",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "${netCashFlow.toStringAsFixed(1)} ج.م",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: netCashFlow >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ================= القسم الثاني: النشاط التجاري =================
                    _buildSectionHeader("النشاط التجاري (الشهر الحالي)"),

                    _buildListTileCard(
                      "إجمالي المبيعات",
                      sales,
                      Icons.point_of_sale,
                      Colors.teal,
                      cardBg,
                      textColor,
                      () {}, // ممكن توديه لتقرير مبيعات
                    ),
                    _buildListTileCard(
                      "إجمالي فواتير الشراء",
                      purchasesBills,
                      Icons.inventory,
                      Colors.blue,
                      cardBg,
                      textColor,
                      // () => _navigateTo(const PurchaseHistoryScreen()) // فعل هذا السطر لو عندك الشاشة
                      () {},
                    ),
                    _buildListTileCard(
                      "مرتجعات العملاء",
                      -clientReturns, // بالسالب للتوضيح
                      Icons.assignment_return,
                      Colors.deepPurple,
                      cardBg,
                      textColor,
                      // نفتح التاب رقم 0
                      () =>
                          _navigateTo(const ReturnsListScreen(initialIndex: 0)),
                    ),

                    _buildListTileCard(
                      "مرتجعات الموردين",
                      -supplierReturns, // بالسالب للتوضيح
                      Icons.unarchive,
                      Colors.orange,
                      cardBg,
                      textColor,
                      // نفتح التاب رقم 0
                      () =>
                          _navigateTo(const ReturnsListScreen(initialIndex: 1)),
                    ),
                    _buildListTileCard(
                      "المصروفات",
                      -expenses,
                      Icons.money_off,
                      Colors.redAccent,
                      cardBg,
                      textColor,
                      () => _navigateTo(const ExpensesScreen()),
                    ),

                    const SizedBox(height: 25),

                    // ================= القسم الثالث: المركز المالي =================
                    _buildSectionHeader("المركز المالي (الأرصدة الحالية)"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            "قيمة المخزون",
                            _data['inventory'] ?? 0,
                            Icons.store,
                            Colors.blue,
                            isDark,
                            () => _navigateTo(const StoreScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            "لنا عند العملاء",
                            _data['receivables'] ?? 0,
                            Icons.account_balance_wallet,
                            Colors.green,
                            isDark,
                            () => _navigateTo(const ClientsScreen()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryCard(
                            "علينا للموردين",
                            _data['payables'] ?? 0,
                            Icons.money_off,
                            Colors.red,
                            isDark,
                            () => _navigateTo(const SuppliersScreen()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // --- Widgets ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 5),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildCashRow(String title, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Text(
            "${amount.toStringAsFixed(1)} ج.م",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 5),
              Text(
                "${amount.abs().toStringAsFixed(1)} ج.م",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTileCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    Color cardBg,
    Color textColor,
    VoidCallback onTap,
  ) {
    return Card(
      color: cardBg,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Text(
          "${amount.toStringAsFixed(1)} ج.م",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
