import 'package:flutter/material.dart';
import 'pb_helper.dart';

// ✅ استيراد جميع الشاشات
import 'sales_screen.dart';
import 'store_screen.dart';
import 'clients_screen.dart';
import 'suppliers_screen.dart';
import 'purchase_screen.dart';
import 'purchase_history_screen.dart';
import 'reports_screen.dart'; // سجل المبيعات
import 'GeneralReportsScreen.dart'; // التقارير الشاملة
import 'delivery_orders_screen.dart';
import 'returns_list_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;

  MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.page,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _currentUserData = {};

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeToUserUpdates();
  }

  Future<void> _loadUserData() async {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    try {
      final record = await PBHelper().pb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _currentUserData = record.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في جلب بيانات المستخدم: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToUserUpdates() {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId == null) return;

    PBHelper().pb.collection('users').subscribe(myId, (e) {
      if (e.record != null && mounted) {
        setState(() {
          _currentUserData = e.record!.data;
        });
      }
    });
  }

  @override
  void dispose() {
    final myId = PBHelper().pb.authStore.record?.id;
    if (myId != null) {
      PBHelper().pb.collection('users').unsubscribe(myId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = PBHelper().pb.authStore.record;
    final bool amISuperAdmin = (currentUser?.id == _superAdminId);

    final List<MenuItem> menuItems = [];

    void addIfAllowed(
      String title,
      IconData icon,
      Color color,
      Widget page,
      String permissionKey,
    ) {
      if (amISuperAdmin || (_currentUserData[permissionKey] == true)) {
        menuItems.add(
          MenuItem(title: title, icon: icon, color: color, page: page),
        );
      }
    }

    // --- المبيعات ---
    addIfAllowed(
      'فاتورة مبيعات',
      Icons.point_of_sale,
      Colors.blue[700]!,
      const SalesScreen(),
      'show_sales',
    );
    addIfAllowed(
      'شراء (توريد)',
      Icons.add_shopping_cart,
      Colors.blue[700]!,
      const PurchaseScreen(),
      'show_purchases',
    );

    addIfAllowed(
      'المخزن والأصناف',
      Icons.inventory_2,
      Colors.orange[800]!,
      const StoreScreen(),
      'show_stock',
    );
    addIfAllowed(
      'المرتجعات',
      Icons.assignment_return,
      Colors.red[700]!,
      const ReturnsListScreen(),
      'show_returns',
    );
    addIfAllowed(
      'إدارة العملاء',
      Icons.people,
      Colors.brown[600]!,
      const ClientsScreen(),
      'show_clients',
    );

    addIfAllowed(
      'إدارة الموردين',
      Icons.local_shipping,
      Colors.brown[600]!,
      const SuppliersScreen(),
      'show_suppliers',
    );
    addIfAllowed(
      'سجل المبيعات',
      Icons.history_edu,
      Colors.green[900]!,
      const ReportsScreen(),
      'show_sales_history',
    );

    addIfAllowed(
      'سجل المشتريات',
      Icons.receipt_long,
      Colors.green[900]!,
      const PurchaseHistoryScreen(),
      'show_purchase_history',
    );

    // --- المصروفات والتقارير ---
    addIfAllowed(
      'المصروفات',
      Icons.money_off,
      Colors.redAccent,
      const ExpensesScreen(),
      'show_expenses',
    );
    addIfAllowed(
      'التقارير الشاملة',
      Icons.bar_chart,
      const Color(0xFFFBC02D),
      const GeneralReportsScreen(),
      'show_reports',
    );
    addIfAllowed(
      'أذونات التسليم',
      Icons.receipt,
      Colors.redAccent,
      const DeliveryOrdersScreen(),
      'show_delivery',
    );

    // --- الإعدادات ---
    menuItems.add(
      MenuItem(
        title: 'الإعدادات',
        icon: Icons.settings,
        color: Colors.grey[700]!,
        page: const SettingsScreen(),
      ),
    );

    // ❌❌❌ هنا التغيير: شيلنا Directionality عشان الاتجاه يتغير حسب اللغة
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : Colors.grey[100],

      body: (_isLoading && !amISuperAdmin)
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Text(
                        "${currentUser?.data['name'] ?? 'مستخدم'} أهلاً بك ",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          double width = constraints.maxWidth;
                          if (width > 1200)
                            crossAxisCount = 5;
                          else if (width > 900)
                            crossAxisCount = 4;
                          else if (width > 600)
                            crossAxisCount = 3;

                          return GridView.builder(
                            itemCount: menuItems.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: 1.1,
                                ),
                            itemBuilder: (context, index) {
                              return DashboardCard(item: menuItems[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final MenuItem item;
  const DashboardCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 4,
      shadowColor: item.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item.page),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [item.color.withOpacity(0.15), Colors.transparent]
                  : [item.color.withOpacity(0.08), Colors.white],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 32, color: item.color),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.grey[800],
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
