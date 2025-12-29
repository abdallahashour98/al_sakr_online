import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class PdfService {
  static Future<void> generateDeliveryOrderPdf(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();

    // 1. تحميل الخطوط والصور
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

    // ============================================================
    // 2. تجهيز الجدول
    // ============================================================

    List<Map<String, dynamic>> processedRows = [];
    Map<String, List<Map<String, dynamic>>> groups = {};

    String mainOrderNumber = order['supplyOrderNumber'] ?? '---';
    Set<String> allSupplyOrders = {};
    if (order['supplyOrderNumber'] != null &&
        order['supplyOrderNumber'].toString().isNotEmpty) {
      allSupplyOrders.add(order['supplyOrderNumber'].toString());
    }

    // 2. نلف على الأصناف ونشوف لو فيها أرقام توريد فرعية
    for (var item in items) {
      if (item['relatedSupplyOrder'] != null &&
          item['relatedSupplyOrder'].toString().isNotEmpty) {
        allSupplyOrders.add(item['relatedSupplyOrder'].toString());
      }
    }

    // 3. نحولهم لنص واحد مفصول بـ " / "
    String combinedSupplyOrdersText = "";
    if (allSupplyOrders.isEmpty) {
      combinedSupplyOrdersText = "---";
    } else if (allSupplyOrders.length == 1) {
      // لو رقم واحد بس، نعرضه زي ما هو من غير أقواس
      combinedSupplyOrdersText = allSupplyOrders.first;
    } else {
      // لو أكتر من رقم، نفصل بـ داش ونحط أقواس
      combinedSupplyOrdersText = "[ ${allSupplyOrders.join(' - ')} ]";
    } // أ: تجميع العناصر
    for (var item in items) {
      String key =
          item['relatedSupplyOrder'] != null &&
              item['relatedSupplyOrder'].toString().isNotEmpty
          ? item['relatedSupplyOrder']
          : 'MAIN_ORDER';

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(item);
    }

    // ب: تحديد هل نحتاج عناوين ولا لأ؟
    bool showSectionHeaders = groups.length > 1;

    // ج: دالة الإضافة
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

    // إضافة الرئيسي أولاً
    if (groups.containsKey('MAIN_ORDER')) {
      addGroupToRows(mainOrderNumber, groups['MAIN_ORDER']!, true);
      groups.remove('MAIN_ORDER');
    }

    // إضافة الفرعي
    groups.forEach((orderNum, groupItems) {
      addGroupToRows(orderNum, groupItems, false);
    });

    // إكمال الصفوف الفاضية
    final int targetRows = 14;
    while (processedRows.length < targetRows) {
      processedRows.add({'type': 'empty'});
    }

    // حساب الإجمالي
    int totalQty = 0;
    for (var item in items) {
      totalQty += int.tryParse(item['quantity'].toString()) ?? 0;
    }

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
              pw.Container(
                height: 180,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      width: 160,
                      padding: const pw.EdgeInsets.all(10),
                      alignment: pw.Alignment.center,
                      child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
                    ),
                    pw.Container(width: 1, color: PdfColors.black),

                    // الجزء الأيمن (بيانات الشركة والعميل)
                    pw.Expanded(
                      child: pw.Column(
                        // 1. التعديل هنا: إضافة stretch عشان المحاذاة تبدأ صح من الشمال
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          // بيانات الشركة
                          pw.Expanded(
                            flex: 4,
                            child: pw.Padding(
                              // 2. التعديل هنا: زيادة المسافة اليسرى لـ 15
                              padding: const pw.EdgeInsets.only(
                                left: 15,
                                top: 5,
                                bottom: 5,
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  _buildHeaderLine(
                                    "Address :",
                                    "18 Al-Ansar st. Dokki – Giza – Postal Code 12311",
                                    ttfEnBold,
                                    ttfEn,
                                  ),
                                  _buildHeaderLine(
                                    "TeleFax :",
                                    "0237622293   MOB. :01001409814 - 01280973000",
                                    ttfEnBold,
                                    ttfEn,
                                  ),
                                  _buildHeaderLine(
                                    "Website :",
                                    "www.alsakr-computer.com",
                                    ttfEnBold,
                                    ttfEn,
                                    isLink: true,
                                  ),
                                  _buildHeaderLine(
                                    "E-mail :",
                                    "info@alsakr-computer.com",
                                    ttfEnBold,
                                    ttfEn,
                                    isLink: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.Container(height: 1, color: PdfColors.black),

                          // بيانات الإذن والعميل
                          pw.Expanded(
                            flex: 6,
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: pw.Column(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceEvenly,
                                children: [
                                  // العنوان ورقم الإذن اليدوي (RichText لحل مشكلة الأقواس)
                                  pw.Center(
                                    child: pw.RichText(
                                      textDirection: pw.TextDirection.rtl,
                                      text: pw.TextSpan(
                                        children: [
                                          // 1. الكلمة العربي (بخط Traditional Arabic)
                                          pw.TextSpan(
                                            text: "إذن تسليم خاص ",
                                            style: pw.TextStyle(
                                              fontSize: 20, // حجم الخط
                                              fontWeight: pw.FontWeight.bold,
                                              font: ttfAr,
                                              color: PdfColors.blue900,
                                            ),
                                          ),
                                          // 2. الرقم والأقواس (بالخط الإنجليزي Tinos Bold)
                                          if (order['manualNo'] != null &&
                                              order['manualNo']
                                                  .toString()
                                                  .isNotEmpty)
                                            pw.TextSpan(
                                              text: "(${order['manualNo']})",
                                              style: pw.TextStyle(
                                                fontSize: 20, // نفس الحجم
                                                fontWeight: pw.FontWeight.bold,
                                                font: ttfEnBold, //
                                                color: PdfColors.blue900,
                                                // تعديل بسيط لرفع الأقواس قليلاً لو حسيت انها نازلة (اختياري)
                                                // baseline: -2
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
                                          "${order['deliveryDate'].toString().split(' ')[0]}",
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
                                              combinedSupplyOrdersText, // كان order['supplyOrderNumber']
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

              // ======================= 4. الجدول (Table) =======================
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
                      // --- رأس الجدول ---
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
                            pw.Expanded(
                              flex: 1,
                              child: _buildHeaderCell(
                                "الفئة",
                                ".AT",
                                ttfAr,
                                ttfEnBold,
                                borderRight: false,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- الصفوف ---
                      ...processedRows.map((row) {
                        // 1. عنوان المجموعة
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
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              "${row['title']}",
                              style: pw.TextStyle(
                                font: ttfEnBold,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        // 2. العنصر (Item)
                        if (row['type'] == 'item') {
                          final data = row['data'] as Map<String, dynamic>;

                          return pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(bottom: borderSide),
                            ),
                            child: pw.Row(
                              children: [
                                // عمود البيان
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
                                    alignment: pw.Alignment.topLeft,
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        // الاسم فقط (Bold)
                                        pw.Text(
                                          data['productName'],
                                          style: pw.TextStyle(
                                            font: ttfEnBold,
                                            fontSize: 10,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                        ),
                                        // 3. التعديل هنا: تم حذف الوصف المكرر (description)
                                      ],
                                    ),
                                  ),
                                ),
                                // عمود العدد
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
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                // عمود الفئة
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      "MONITOR",
                                      style: pw.TextStyle(
                                        font: ttfEn,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // 3. صف فارغ
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

                      // --- صف المجموع (Total) ---
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
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                alignment: pw.Alignment.center, // وسط
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
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // فقط وقدره
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
                              pw.Expanded(
                                child: pw.Container(
                                  margin: const pw.EdgeInsets.only(top: 14),
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                      bottom: pw.BorderSide(
                                        style: pw.BorderStyle.dotted,
                                        width: 1,
                                      ),
                                    ),
                                  ),
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

              pw.SizedBox(height: 10),

              // التذييل
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "أستلمت الأصناف والأعداد الموضحة بعاليه بحالة جيدة وخالية من عيوب الصناعة.",
                      style: pw.TextStyle(font: ttfAr, fontSize: 15),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSignature("مسئول البيع", ttfAr),
                        _buildSignature("اسم المستلم", ttfAr),
                        _buildSignature("التوقيع", ttfAr),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 50), // زود الرقم ده (50) لو عاوز ترفعها أكتر
            ],
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File("${output.path}/Delivery_Order_Final_Fixed.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  // دوال المساعدة
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
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(
                color: PdfColors.red,
                font: labelFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: "   $value",
              style: pw.TextStyle(
                color: isLink ? PdfColors.blue : PdfColors.black,
                font: valueFont,
                fontSize: 10,
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
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11)),
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
          pw.Text(en, style: pw.TextStyle(font: enFont, fontSize: 9)),
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
