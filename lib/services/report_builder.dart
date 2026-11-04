import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/dates.dart';
import '../models/models.dart';

class ReportBuilder {
  Future<Uint8List> build({
    required List<MealEntry> meals,
    required DateTime from,
    required DateTime to,
  }) async {
    // Font PDF mặc định không có dấu tiếng Việt.
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    const primary = PdfColor.fromInt(0xFF24523C);

    final doc = pw.Document(title: 'Báo cáo nhật ký bữa ăn');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => [
          pw.Text(
            'Báo cáo nhật ký bữa ăn',
            style: pw.TextStyle(font: bold, fontSize: 20, color: primary),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Từ ${formatDate(from)} đến ${formatDate(to)}'),
          pw.SizedBox(height: 16),
          if (meals.isEmpty)
            pw.Text('Chưa có bữa ăn nào trong khoảng thời gian này.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Ngày', 'Bữa', 'Giờ ghi', 'Món'],
              headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: primary),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: const {
                0: pw.FixedColumnWidth(80),
                1: pw.FixedColumnWidth(70),
                2: pw.FixedColumnWidth(60),
                3: pw.FlexColumnWidth(),
              },
              data: [
                for (final m in meals)
                  [
                    formatDate(parseDateKey(m.date)),
                    m.type.label,
                    formatTime(m.createdAt),
                    m.description,
                  ],
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Tổng cộng ${meals.length} bữa. Báo cáo chỉ tổng hợp dữ liệu bạn tự ghi, không phải chỉ định y tế.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
