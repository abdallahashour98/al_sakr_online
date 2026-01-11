import 'pb_helper.dart';

class ReportsService {
  final pb = PBHelper().pb;

  Future<Map<String, double>> getGeneralReportData() async {
    final now = DateTime.now();
    String startOfMonth =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-01 00:00:00";
    String nextMonth = now.month == 12
        ? "${now.year + 1}-01-01 00:00:00"
        : "${now.year}-${(now.month + 1).toString().padLeft(2, '0')}-01 00:00:00";
    String dateFilter = "date >= '$startOfMonth' && date < '$nextMonth'";

    try {
      // 1. مرتجعات العملاء
      final clientReturnsRec = await pb
          .collection('returns')
          .getFullList(filter: dateFilter);
      double monthlyClientReturns = clientReturnsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 2. مرتجعات الموردين
      final supplierReturnsRec = await pb
          .collection('purchase_returns')
          .getFullList(filter: dateFilter);
      double monthlySupplierReturns = supplierReturnsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 3. المبيعات
      final salesRec = await pb
          .collection('sales')
          .getFullList(filter: dateFilter);
      double monthlySales = salesRec.fold(
        0.0,
        (sum, item) => sum + (item.data['netAmount'] ?? 0),
      );

      // 4. المرتجعات (إجمالي)
      final returnsRec = await pb
          .collection('returns')
          .getFullList(filter: dateFilter);
      double monthlyReturns = returnsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 5. المصروفات
      final expensesRec = await pb
          .collection('expenses')
          .getFullList(filter: dateFilter);
      double monthlyExpenses = expensesRec.fold(
        0.0,
        (sum, item) => sum + (item.data['amount'] ?? 0),
      );

      // 6. المشتريات (الفواتير)
      final purchasesRec = await pb
          .collection('purchases')
          .getFullList(filter: dateFilter);
      double monthlyBills = purchasesRec.fold(
        0.0,
        (sum, item) => sum + (item.data['totalAmount'] ?? 0),
      );

      // 7. مدفوعات الموردين
      final supplierPayRec = await pb
          .collection('supplier_payments')
          .getFullList(filter: dateFilter);
      double monthlyPayments = supplierPayRec.fold(
        0.0,
        (sum, item) => sum + (item.data['amount'] ?? 0),
      );

      // 8. قيمة المخزون
      final productsRec = await pb.collection('products').getFullList();
      double inventoryVal = productsRec.fold(0.0, (sum, item) {
        double qty = (item.data['stock'] ?? 0).toDouble();
        double cost = (item.data['buyPrice'] ?? 0).toDouble();
        return sum + (qty * cost);
      });

      // 9. مديونيات العملاء (لنا)
      final clientsRec = await pb.collection('clients').getFullList();
      double receivables = clientsRec.fold(
        0.0,
        (sum, item) => sum + (item.data['balance'] ?? 0),
      );

      // 10. مديونيات الموردين (علينا)
      final suppliersRec = await pb.collection('suppliers').getFullList();
      double payables = suppliersRec.fold(
        0.0,
        (sum, item) => sum + (item.data['balance'] ?? 0),
      );

      return {
        'monthlySales': monthlySales,
        'clientReturns': monthlyClientReturns,
        'supplierReturns': monthlySupplierReturns,
        'monthlyReturns': monthlyReturns,
        'monthlyExpenses': monthlyExpenses,
        'monthlyBills': monthlyBills,
        'monthlyPayments': monthlyPayments,
        'inventory': inventoryVal,
        'receivables': receivables,
        'payables': payables,
      };
    } catch (e) {
      return {};
    }
  }
}
