import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/business_info.dart';
import '../models/invoice.dart';
import 'format.dart';
import 'number_words.dart';

class PdfService {
  static Future<Uint8List> build(Invoice inv, BusinessInfo biz) async {
    final doc = pw.Document();

    pw.MemoryImage? logo;
    if (biz.logoPath.isNotEmpty && File(biz.logoPath).existsSync()) {
      logo = pw.MemoryImage(File(biz.logoPath).readAsBytesSync());
    }

    const accent = PdfColor.fromInt(0xFF00695C);

    pw.Widget cell(String t, {bool header = false, bool right = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(
          t,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? PdfColors.white : PdfColors.black,
          ),
        ),
      );
    }

    pw.Widget totalRow(String label, String value, {bool strong = false}) {
      final style = pw.TextStyle(
        fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: strong ? 13 : 11,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(label, style: style), pw.Text(value, style: style)],
        ),
      );
    }

    final payableParts = [biz.payableTo, biz.accountNumber, biz.bank]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final contactParts = [biz.contactName, biz.contactPhone]
        .where((s) => s.trim().isNotEmpty)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          if (logo != null)
            pw.Container(
              height: 70,
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Proforma Invoice',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Invoice No: ${inv.invoiceNumber}'),
          pw.Text('Date: ${formatDate(inv.date)}'),
          pw.SizedBox(height: 16),
          pw.Text('Bill To',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (inv.clientName.isNotEmpty) pw.Text(inv.clientName),
          if (inv.clientAddress.isNotEmpty) pw.Text(inv.clientAddress),
          if (inv.clientPhone.isNotEmpty) pw.Text(inv.clientPhone),
          pw.SizedBox(height: 18),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: accent),
                children: [
                  cell('Item Description', header: true),
                  cell('Amount (NGN)', header: true, right: true),
                ],
              ),
              for (final it in inv.items)
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300),
                    ),
                  ),
                  children: [
                    cell(it.description),
                    cell(formatMoney(it.amount), right: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  totalRow('Subtotal', formatMoney(inv.subtotal)),
                  if (inv.taxRate > 0)
                    totalRow('Tax (${inv.taxRate}%)',
                        formatMoney(inv.taxAmount)),
                  if (inv.otherCosts > 0)
                    totalRow('Other Costs', formatMoney(inv.otherCosts)),
                  pw.Divider(color: accent),
                  totalRow('Total Cost', formatMoney(inv.total), strong: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Amount in words: ${amountInWords(inv.total)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          if (payableParts.isNotEmpty)
            pw.Text('Make all payable to ${payableParts.join(', ')}'),
          pw.SizedBox(height: 20),
          pw.Text('Thank you for doing business with us!',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (contactParts.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'If you have any questions concerning this invoice, use the following contact information:',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(contactParts.join(', '),
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
