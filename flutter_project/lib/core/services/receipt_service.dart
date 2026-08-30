import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'arabic_font_data.dart'; // ← يحتوي على const String arabicFontBase64

class ReceiptService {
  ReceiptService._();

  static pw.Font? _arabicFont;

  /// تحميل الخط العربي من السلسلة المضمَّنة
  static void _loadFont() {
    if (_arabicFont != null) return;

    try {
      final bytes = Uint8List.fromList(base64Decode(arabicFontBase64));
      _arabicFont = pw.Font.ttf(bytes.buffer.asByteData());
      debugPrint('✅ Arabic font loaded from embedded base64');
    } catch (e) {
      debugPrint('❌ Failed to load embedded font: $e');
    }
  }

  static Future<void> generateAndShare({
    required String requestId,
    required String clientName,
    required String craftsmanName,
    required String service,
    required double amount,
    required DateTime date,
    double? prepaidAmount,
    double? remainingAmount,
    String? description,   // وصف العميل الأصلي
    String? workDetails,   // تفاصيل العمل المنجز
  }) async {
    _loadFont();
    final font = _arabicFont;

    final pdf = pw.Document();
    final hasBreakdown = prepaidAmount != null && prepaidAmount > 0;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // هيدر الفاتورة
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('الحرفي الكويتي',
                          style: font != null
                              ? pw.TextStyle(font: font, fontSize: 13, fontWeight: pw.FontWeight.bold)
                              : pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.Text('إيصال دفع / فاتورة',
                          style: font != null
                              ? pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey600)
                              : const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('رقم الطلب: $requestId',
                          style: font != null
                              ? pw.TextStyle(font: font, fontSize: 11)
                              : const pw.TextStyle(fontSize: 11)),
                      pw.Text('التاريخ: ${date.day}/${date.month}/${date.year}',
                          style: font != null
                              ? pw.TextStyle(font: font, fontSize: 11)
                              : const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue800),
              pw.SizedBox(height: 20),

              // بيانات الطرفين
              pw.Row(children: [
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('بيانات العميل',
                        style: pw.TextStyle(
                            font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 6),
                    pw.Text('الاسم: $clientName', style: pw.TextStyle(font: font)),
                  ],
                )),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('بيانات الحرفي',
                        style: pw.TextStyle(
                            font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 6),
                    pw.Text('الاسم: $craftsmanName', style: pw.TextStyle(font: font)),
                  ],
                )),
              ]),
              pw.SizedBox(height: 20),

              // وصف العميل (إن وُجد)
              if (description != null && description.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('وصف الخدمة (من العميل)',
                          style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Text(description, style: pw.TextStyle(font: font)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // تفاصيل العمل المنجز (إن وُجد)
              if (workDetails != null && workDetails.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('تفاصيل العمل المنجز',
                          style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      pw.SizedBox(height: 4),
                      pw.Text(workDetails, style: pw.TextStyle(font: font)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // جدول المبالغ
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('البيان', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
                      pw.Text('المبلغ (د.ك)', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(service, style: pw.TextStyle(font: font)),
                      pw.Text(amount.toStringAsFixed(3), style: pw.TextStyle(font: font)),
                    ],
                  ),
                  if (hasBreakdown) ...[
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المدفوع مسبقاً', style: pw.TextStyle(font: font)),
                        pw.Text(prepaidAmount.toStringAsFixed(3), style: pw.TextStyle(font: font)),
                      ],
                    ),
                    if (remainingAmount != null && remainingAmount > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('المتبقي للدفع',
                              style: pw.TextStyle(font: font, color: PdfColors.red)),
                          pw.Text(remainingAmount.toStringAsFixed(3),
                              style: pw.TextStyle(font: font, color: PdfColors.red)),
                        ],
                      ),
                  ],
                ]),
              ),
              pw.SizedBox(height: 16),

              // الإجمالي
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('إجمالي الفاتورة',
                        style: pw.TextStyle(
                            font: font,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14)),
                    pw.Text('${amount.toStringAsFixed(3)} دينار كويتي',
                        style: pw.TextStyle(
                            font: font,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Center(child: pw.Text(
                'شكراً لاستخدامك تطبيق الحرفي الكويتي',
                style: pw.TextStyle(font: font, color: PdfColors.grey600),
              )),
            ],
          ),
        ),
      ),
    ));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'receipt_$requestId.pdf',
    );
  }
}