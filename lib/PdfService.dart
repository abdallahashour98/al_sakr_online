import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'pb_helper.dart';

class PdfService {
  static Future<void> generateDeliveryOrderPdf(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();

    // 1. جلب البيانات من الإعدادات
    final companyData = await PBHelper().getCompanySettings();
    String address =
        companyData['address'] ??
        '18 Al-Ansar st. Dokki – Giza – Postal Code 12311';
    String phone = companyData['phone'] ?? '0237622293';
    String mobile = companyData['mobile'] ?? '01001409814 - 01280973000';
    String email = companyData['email'] ?? 'info@alsakr-computer.com';
    String website = "www.alsakr-computer.com";

    // 2. معالجة التاريخ
    String rawDate =
        order['date'] ?? order['deliveryDate'] ?? DateTime.now().toString();
    String formattedDate = rawDate.split(' ')[0];

    // تحميل الخطوط والصور
    final fontDataAr = await rootBundle.load(
      "assets/fonts/Traditional-Arabic.ttf",
    );
    final ttfAr = pw.Font.ttf(fontDataAr);
    final fontDataEn = await rootBundle.load("assets/fonts/Tinos-Regular.ttf");
    final ttfEn = pw.Font.ttf(fontDataEn);
    final fontDataEnBold = await rootBundle.load("assets/fonts/Tinos-Bold.ttf");
    final ttfEnBold = pw.Font.ttf(fontDataEnBold);

    final logoImage = await rootBundle.load('assets/splash_logo.png');
    final imageProvider = pw.MemoryImage(logoImage.buffer.asUint8List());

    // تجهيز الجدول
    List<Map<String, dynamic>> processedRows = [];
    Map<String, List<Map<String, dynamic>>> groups = {};
    String mainOrderNumber = order['supplyOrderNumber'] ?? '---';
    Set<String> allSupplyOrders = {};
    if (order['supplyOrderNumber'] != null &&
        order['supplyOrderNumber'].toString().isNotEmpty) {
      allSupplyOrders.add(order['supplyOrderNumber'].toString());
    }
    for (var item in items) {
      if (item['relatedSupplyOrder'] != null &&
          item['relatedSupplyOrder'].toString().isNotEmpty) {
        allSupplyOrders.add(item['relatedSupplyOrder'].toString());
      }
    }
    String combinedSupplyOrdersText = allSupplyOrders.isEmpty
        ? "---"
        : (allSupplyOrders.length == 1
              ? allSupplyOrders.first
              : "[ ${allSupplyOrders.join(' - ')} ]");

    for (var item in items) {
      String key =
          item['relatedSupplyOrder'] != null &&
              item['relatedSupplyOrder'].toString().isNotEmpty
          ? item['relatedSupplyOrder']
          : 'MAIN_ORDER';
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(item);
    }

    bool showSectionHeaders = groups.length > 1;
    void addGroupToRows(
      String title,
      List<Map<String, dynamic>> groupItems,
      bool isMain,
    ) {
      if (showSectionHeaders) {
        processedRows.add({
          'type': 'header',
          'title': isMain ? mainOrderNumber : title,
          'isMain': isMain,
        });
      }
      for (int i = 0; i < groupItems.length; i++) {
        processedRows.add({
          'type': 'item',
          'data': groupItems[i],
          'isLastInGroup': (i == groupItems.length - 1),
        });
      }
    }

    if (groups.containsKey('MAIN_ORDER')) {
      addGroupToRows(mainOrderNumber, groups['MAIN_ORDER']!, true);
      groups.remove('MAIN_ORDER');
    }
    groups.forEach(
      (orderNum, groupItems) => addGroupToRows(orderNum, groupItems, false),
    );

    final int targetRows = 14;
    while (processedRows.length < targetRows)
      processedRows.add({'type': 'empty'});

    int totalQty = 0;
    for (var item in items)
      totalQty += int.tryParse(item['quantity'].toString()) ?? 0;

    const borderSide = pw.BorderSide(color: PdfColors.black, width: 0.8);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(
          base: ttfAr,
          fontFallback: [ttfEn, ttfEnBold],
        ),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // ======================= الهيدر (Header) =======================
              // قمت بزيادة الارتفاع قليلاً ليتسع للسطر الإضافي (الإيميل)
              pw.Container(
                height: 220,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // اللوجو
                    pw.Container(
                      width: 150,
                      padding: const pw.EdgeInsets.all(10),
                      alignment: pw.Alignment.center,
                      child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
                    ),
                    pw.Container(width: 1, color: PdfColors.black),

                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // بيانات الشركة
                          pw.Expanded(
                            flex: 5, // مساحة أكبر للبيانات
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.only(
                                left: 15,
                                top: 5,
                                bottom: 5,
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  // 1. العنوان (خط 13)
                                  _buildHeaderLine(
                                    "Address :",
                                    address,
                                    ttfEnBold,
                                    ttfEn,
                                  ),

                                  // 2. التليفون والموبايل (خط 13)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                      bottom: 2,
                                    ),
                                    child: pw.RichText(
                                      text: pw.TextSpan(
                                        children: [
                                          pw.TextSpan(
                                            text: "TeleFax :",
                                            style: pw.TextStyle(
                                              color: PdfColors.red,
                                              font: ttfEnBold,
                                              fontSize: 13,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                          pw.TextSpan(
                                            text: " $phone",
                                            style: pw.TextStyle(
                                              color: PdfColors.black,
                                              font: ttfEn,
                                              fontSize: 13,
                                            ),
                                          ),

                                          pw.TextSpan(text: "   "),

                                          pw.TextSpan(
                                            text: "MOB :",
                                            style: pw.TextStyle(
                                              color: PdfColors.red,
                                              font: ttfEnBold,
                                              fontSize: 13,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                          pw.TextSpan(
                                            text: " $mobile",
                                            style: pw.TextStyle(
                                              color: PdfColors.black,
                                              font: ttfEn,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 3. الموقع (سطر منفصل - خط 13)
                                  _buildHeaderLine(
                                    "Website :",
                                    website,
                                    ttfEnBold,
                                    ttfEn,
                                    isLink: true,
                                  ),

                                  // 4. الإيميل (سطر منفصل - خط 13)
                                  _buildHeaderLine(
                                    "E-mail :",
                                    email,
                                    ttfEnBold,
                                    ttfEn,
                                    isLink: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.Container(height: 1, color: PdfColors.black),

                          // بيانات العميل
                          pw.Expanded(
                            flex: 5,
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: pw.Column(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceAround,
                                children: [
                                  pw.Center(
                                    child: pw.RichText(
                                      textDirection: pw.TextDirection.rtl,
                                      text: pw.TextSpan(
                                        children: [
                                          pw.TextSpan(
                                            text: "إذن تسليم خاص ",
                                            style: pw.TextStyle(
                                              fontSize: 20,
                                              fontWeight: pw.FontWeight.bold,
                                              font: ttfAr,
                                              color: PdfColors.blue900,
                                            ),
                                          ),
                                          if (order['manualNo'] != null &&
                                              order['manualNo']
                                                  .toString()
                                                  .isNotEmpty)
                                            pw.TextSpan(
                                              text: "(${order['manualNo']})",
                                              style: pw.TextStyle(
                                                fontSize: 20,
                                                fontWeight: pw.FontWeight.bold,
                                                font: ttfEnBold,
                                                color: PdfColors.blue900,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  pw.Directionality(
                                    textDirection: pw.TextDirection.rtl,
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        _buildLabelValueRow(
                                          "التاريخ",
                                          formattedDate,
                                          ttfAr,
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Row(
                                          children: [
                                            pw.Text(
                                              "السادة : ",
                                              style: pw.TextStyle(
                                                font: ttfAr,
                                                fontSize: 12,
                                                fontWeight: pw.FontWeight.bold,
                                              ),
                                            ),
                                            pw.Text(
                                              "..... ${order['clientName']} ......",
                                              style: pw.TextStyle(
                                                font: ttfAr,
                                                fontSize: 12,
                                              ),
                                            ),
                                            pw.SizedBox(width: 30),
                                            pw.Text(
                                              "رقم أمر التوريد : ",
                                              style: pw.TextStyle(
                                                font: ttfAr,
                                                fontSize: 12,
                                                fontWeight: pw.FontWeight.bold,
                                              ),
                                            ),
                                            pw.Text(
                                              combinedSupplyOrdersText,
                                              style: pw.TextStyle(
                                                font: ttfEnBold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        pw.SizedBox(height: 4),
                                        _buildLabelValueRow(
                                          "العنوان",
                                          "..... ${order['address']} .....",
                                          ttfAr,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ======================= الجدول =======================
              pw.Expanded(
                child: pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: borderSide,
                      left: borderSide,
                      right: borderSide,
                      bottom: borderSide,
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      // Header
                      pw.Container(
                        height: 30,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: borderSide),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 4,
                              child: _buildHeaderCell(
                                "البيان",
                                "Description",
                                ttfAr,
                                ttfEnBold,
                                borderRight: true,
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: _buildHeaderCell(
                                "العدد",
                                "Quantity",
                                ttfAr,
                                ttfEnBold,
                                borderRight: true,
                              ),
                            ),
                            // ✅ تعديل اسم العمود ليصبح "الوحدة" أو "Unit"
                            pw.Expanded(
                              flex: 1,
                              child: _buildHeaderCell(
                                "الوحدة",
                                "Unit",
                                ttfAr,
                                ttfEnBold,
                                borderRight: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rows
                      ...processedRows.map((row) {
                        if (row['type'] == 'header') {
                          return pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 5,
                            ),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(bottom: borderSide),
                              color: PdfColors.grey200,
                            ),
                            child: pw.Text(
                              "${row['title']}",
                              style: pw.TextStyle(
                                font: ttfEnBold,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        if (row['type'] == 'item') {
                          final data = row['data'] as Map<String, dynamic>;

                          // ✅ هنا نجلب الوحدة المتغيرة (Unit/Category)
                          // بنحاول نجيب 'unit' لو مفيش نجيب 'category' لو مفيش نكتب 'Piece'
                          String unitText =
                              data['unit'] ?? data['category'] ?? 'Piece';

                          return pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(bottom: borderSide),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 4,
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 8,
                                    ),
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(right: borderSide),
                                    ),
                                    child: pw.Text(
                                      data['productName'],
                                      style: pw.TextStyle(
                                        font: ttfEnBold,
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(right: borderSide),
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      "${data['quantity']}",
                                      style: pw.TextStyle(
                                        font: ttfEn,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                // ✅ هنا تم وضع المتغير بدلاً من MONITOR
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      unitText,
                                      style: pw.TextStyle(
                                        font: ttfEn,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return pw.Expanded(
                          child: pw.Container(
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 4,
                                  child: pw.Container(
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(right: borderSide),
                                    ),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Container(
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(right: borderSide),
                                    ),
                                  ),
                                ),
                                pw.Expanded(flex: 1, child: pw.Container()),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      // Total
                      pw.Container(
                        height: 35,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: borderSide),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 4,
                              child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(right: borderSide),
                                ),
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  "Total",
                                  style: pw.TextStyle(
                                    font: ttfEnBold,
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Container(
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(right: borderSide),
                                ),
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  "$totalQty",
                                  style: pw.TextStyle(
                                    font: ttfEnBold,
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Center(
                                child: pw.Text(
                                  "ITEMS",
                                  style: pw.TextStyle(
                                    font: ttfEnBold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Text Row
                      pw.Container(
                        height: 30,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: borderSide),
                        ),
                        child: pw.Directionality(
                          textDirection: pw.TextDirection.rtl,
                          child: pw.Row(
                            children: [
                              pw.Text(
                                "فقط وقدره : .......................................................................",
                                style: pw.TextStyle(
                                  font: ttfAr,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              // ======================= الفوتر (Footer) =======================
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "أستلمت الأصناف والأعداد الموضحة بعاليه بحالة جيدة وخالية من عيوب الصناعة.",
                      style: pw.TextStyle(font: ttfAr, fontSize: 15),
                    ),
                    pw.SizedBox(height: 15),

                    // ✅ تقليل المسافات بين التوقيعات
                    pw.Row(
                      // استخدام spaceEvenly بدلاً من spaceBetween لجعلهم أقرب للمركز وأقرب لبعضهم
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSignature("مسئول البيع", ttfAr),
                        _buildSignature("اسم المستلم", ttfAr),
                        _buildSignature("التوقيع", ttfAr),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
            ],
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File("${output.path}/Delivery_Order.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // Helper Functions
  static pw.Widget _buildHeaderLine(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont, {
    bool isLink = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            // ✅ تم تكبير الخط لـ 13
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(
                color: PdfColors.red,
                font: labelFont,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: "   $value",
              style: pw.TextStyle(
                color: isLink ? PdfColors.blue : PdfColors.black,
                font: valueFont,
                fontSize: 13,
                decoration: isLink ? pw.TextDecoration.underline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildLabelValueRow(
    String label,
    String value,
    pw.Font font,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            "$label : ",
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(
    String ar,
    String en,
    pw.Font arFont,
    pw.Font enFont, {
    required bool borderRight,
  }) {
    return pw.Container(
      decoration: borderRight
          ? const pw.BoxDecoration(
              border: pw.Border(right: pw.BorderSide(width: 0.8)),
            )
          : null,
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              ar,
              style: pw.TextStyle(
                font: arFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(en, style: pw.TextStyle(font: enFont, fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildSignature(String title, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text("......................................"),
      ],
    );
  }
}
