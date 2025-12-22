import 'package:flutter/material.dart';
import 'db_helper.dart';

// استيراد الشاشات
import 'store_screen.dart';
import 'client_statement.dart';
import 'supplier_statement.dart';
import 'reports_screen.dart';
import 'returns_list_screen.dart';
import 'purchase_history_screen.dart'; // لعرض سجل فواتير الشراء

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
    final data = await DatabaseHelper().getGeneralReportData();
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
    ).then((_) => _loadReportData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // الألوان
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // استخراج البيانات لسهولة القراءة
    double sales = _data['monthlySales'] ?? 0;
    double returns = _data['monthlyReturns'] ?? 0;
    double expenses = _data['monthlyExpenses'] ?? 0;

    double billPurchases = _data['monthlyBills'] ?? 0; // قيمة البضاعة
    double cashPayments =
        _data['monthlyPayments'] ?? 0; // اللي اندفع فعلياً للموردين

    // صافي المبيعات
    double netSales = sales - returns;

    // صافي السيولة النقدية (الكاش اللي في الدرج)
    // = (مبيعات - مرتجعات) - (مصاريف + مدفوعات موردين)
    double netCashFlow = netSales - (expenses + cashPayments);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير المالي الشامل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ================= القسم الأول: السيولة النقدية (Cash Flow) =================
                  _buildSectionHeader("حركة السيولة (الكاش الفعلي) هذا الشهر"),
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
                          "صافي المبيعات (دخل)",
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
                          "مدفوعات للموردين (خرج)",
                          -cashPayments,
                          Colors.orange[800]!,
                        ),
                        const Divider(thickness: 1.5),
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
                              "${netCashFlow.toStringAsFixed(2)} ج.م",
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

                  // ================= القسم الثاني: النشاط التجاري (Accrual) =================
                  _buildSectionHeader("نشاط المحل (فواتير وبضاعة) هذا الشهر"),
                  // هنا بنعرض حجم الشغل بغض النظر عن الدفع
                  _buildListTileCard(
                    title: "إجمالي قيمة المبيعات",
                    amount: sales,
                    icon: Icons.point_of_sale,
                    color: Colors.teal,
                    cardBg: cardBg,
                    textColor: textColor,
                    onTap: () => _navigateTo(const ReportsScreen()),
                  ),
                  _buildListTileCard(
                    title: "إجمالي فواتير الشراء (بضاعة دخلت)",
                    amount: billPurchases, // 🔥 هنا قيمة الفواتير
                    icon: Icons.inventory,
                    color: Colors.blue,
                    cardBg: cardBg,
                    textColor: textColor,
                    onTap: () => _navigateTo(const PurchaseHistoryScreen()),
                  ),
                  _buildListTileCard(
                    title: "قيمة المرتجعات",
                    amount: -returns,
                    icon: Icons.assignment_return,
                    color: Colors.deepPurple,
                    cardBg: cardBg,
                    textColor: textColor,
                    onTap: () => _navigateTo(const ReturnsListScreen()),
                  ),

                  const SizedBox(height: 25),

                  // ================= القسم الثالث: المركز المالي (Balances) =================
                  _buildSectionHeader("المركز المالي (أصول وديون)"),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: "قيمة المخزون",
                          amount: _data['inventory']!,
                          icon: Icons.store,
                          color: Colors.blue,
                          isDark: isDark,
                          onTap: () => _navigateTo(const StoreScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: "لنا عند العملاء",
                          amount: _data['receivables']!,
                          icon: Icons.account_balance_wallet,
                          color: Colors.green,
                          isDark: isDark,
                          onTap: () =>
                              _navigateTo(const ClientStatementScreen()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          title: "علينا للموردين", // 🔥 إجمالي الديون
                          amount: _data['payables']!,
                          icon: Icons.money_off,
                          color: Colors.red,
                          isDark: isDark,
                          onTap: () =>
                              _navigateTo(const SupplierStatementScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
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

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
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

  Widget _buildListTileCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Card(
      color: cardBg,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        title: Text(title, style: TextStyle(color: textColor, fontSize: 14)),
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
