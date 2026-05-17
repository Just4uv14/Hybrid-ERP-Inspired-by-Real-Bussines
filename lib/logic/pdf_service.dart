// =============================================================================
// MAKARYA HYBRID ERP — PDF Service
// File: lib/logic/pdf_service.dart
// =============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/dashboard_provider.dart';
import '../logic/business_logic.dart';

// ── Color palette matching Makarya dark theme ─────────────────────────────────
const _kBrown      = PdfColor.fromInt(0xFF8B6914);
const _kGold       = PdfColor.fromInt(0xFFC9A84C);
const _kDark       = PdfColor.fromInt(0xFF1A1209);
const _kSurface    = PdfColor.fromInt(0xFF2A1F0E);
const _kGreen      = PdfColor.fromInt(0xFF4CAF87);
const _kRed        = PdfColor.fromInt(0xFFE05A4E);
const _kGrey       = PdfColor.fromInt(0xFF888888);
const _kWhite      = PdfColors.white;

String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

// =============================================================================
// FINANCIAL REPORT PDF
// =============================================================================

Future<Uint8List> generateFinancialReportPdf({
  required ProfitabilityResult pnl,
  required List<SkuProfitability> skuList,
  required List<DailyTrendPoint> trendData,
  required String periodLabel,
}) async {
  final pdf = pw.Document();

  final headerStyle  = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,  color: _kGold);
  final titleStyle   = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,  color: _kWhite);
  final valueStyle   = pw.TextStyle(fontSize: 10, color: _kWhite);
  final valueRedStyle   = pw.TextStyle(fontSize: 10, color: _kRed);
  final valueGreenStyle = pw.TextStyle(fontSize: 10, color: _kGreen);
  final totalStyle   = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kGreen);
  final subtitleStyle = pw.TextStyle(fontSize: 10, color: _kGrey);

  // ── PAGE 1: Cover + P&L ──────────────────────────────────────────────────
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _kSurface,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MAKARYA ERP', style: headerStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('Laporan Keuangan — $periodLabel', style: subtitleStyle),
                  ],
                ),
                pw.Text(
                  _formatDate(DateTime.now()),
                  style: pw.TextStyle(fontSize: 10, color: _kGrey),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // KPI Summary Row
          pw.Row(
            children: [
              _kpiBox('Net Revenue',  _rp(pnl.netRevenue),  _kGold),
              pw.SizedBox(width: 12),
              _kpiBox('Net Profit',   _rp(pnl.netProfit),   pnl.netProfit >= 0 ? _kGreen : _kRed),
              pw.SizedBox(width: 12),
              _kpiBox('Net Margin',   _pct(pnl.netMarginPct), pnl.netMarginPct >= 0.18 ? _kGreen : _kRed),
              pw.SizedBox(width: 12),
              _kpiBox('Gross Margin', _pct(pnl.grossMarginPct), _kGold),
            ],
          ),
          pw.SizedBox(height: 24),

          // P&L Detail Table
          pw.Text('Laporan P&L', style: titleStyle),
          pw.SizedBox(height: 12),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _kSurface,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2)},
              children: [
                _pnlTableRow('Gross Revenue',    _rp(pnl.grossRevenue),          valueStyle,  isHeader: true),
                _pnlTableRow('Total Diskon',     '- ${_rp(pnl.totalDiscounts)}', valueRedStyle),
                _pnlTableRow('Net Revenue',      _rp(pnl.netRevenue),            valueStyle,  isBold: true),
                _pnlTableRow('— COGS',           '- ${_rp(pnl.totalCogs)}',      valueRedStyle),
                _pnlTableRow('Gross Profit',     _rp(pnl.grossProfit),           valueGreenStyle, isBold: true),
                _pnlTableRow('Gross Margin',     _pct(pnl.grossMarginPct),       valueStyle),
                _pnlTableRow('— OPEX',           '- ${_rp(pnl.totalOpex)}',      valueRedStyle),
                _pnlTableRow('— Wastage',        '- ${_rp(pnl.totalWastage)}',   valueRedStyle),
                _pnlTableRow('NET PROFIT',       _rp(pnl.netProfit),
                    pnl.netProfit >= 0 ? totalStyle : pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kRed),
                    isTotal: true),
                _pnlTableRow('Net Margin',       _pct(pnl.netMarginPct),         valueStyle),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ── PAGE 2: SKU Profitability Matrix ──────────────────────────────────────
  if (skuList.isNotEmpty) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.interRegular(),
          bold: await PdfGoogleFonts.interBold(),
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _pageHeader('Profitability Matrix per SKU', periodLabel),
            pw.SizedBox(height: 16),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.0),
                6: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _kBrown),
                  children: ['SKU', 'Produk', 'Revenue', 'COGS', 'Gross Profit', 'Units', 'Margin']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: pw.Text(h,
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _kWhite)),
                          ))
                      .toList(),
                ),
                // Data rows
                ...skuList.take(30).map((sku) {
                  final marginColor = sku.grossMarginPct >= 0.4
                      ? _kGreen
                      : sku.grossMarginPct >= 0.2
                          ? _kGold
                          : _kRed;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: skuList.indexOf(sku) % 2 == 0 ? _kSurface : _kDark,
                    ),
                    children: [
                      sku.sku,
                      sku.name,
                      _rp(sku.revenue),
                      _rp(sku.cogs),
                      _rp(sku.grossProfit),
                      '${sku.unitsSold}',
                      _pct(sku.grossMarginPct),
                    ].asMap().map((i, text) => MapEntry(i,
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: pw.Text(text,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: i == 6 ? marginColor : _kWhite,
                              fontWeight: i == 6 ? pw.FontWeight.bold : pw.FontWeight.normal,
                            )),
                      ),
                    )).values.toList(),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── PAGE 3: 30-Day Revenue Trend ──────────────────────────────────────────
  if (trendData.isNotEmpty) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.interRegular(),
          bold: await PdfGoogleFonts.interBold(),
        ),
        build: (ctx) {
          final maxRevenue = trendData.map((d) => d.revenue).reduce((a, b) => a > b ? a : b);
          final totalRev  = trendData.fold(0.0, (s, d) => s + d.revenue);
          final totalProfit = trendData.fold(0.0, (s, d) => s + d.netProfit);
          final avgRev    = totalRev / trendData.length;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pageHeader('Tren Revenue 30 Hari', periodLabel),
              pw.SizedBox(height: 16),

              // Summary chips
              pw.Row(
                children: [
                  _kpiBox('Total Revenue',    _rp(totalRev),    _kGold),
                  pw.SizedBox(width: 12),
                  _kpiBox('Total Profit',     _rp(totalProfit), _kGreen),
                  pw.SizedBox(width: 12),
                  _kpiBox('Avg / Hari',       _rp(avgRev),      _kBrown),
                ],
              ),
              pw.SizedBox(height: 20),

              // Bar chart
              pw.Text('Revenue Harian', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kWhite)),
              pw.SizedBox(height: 12),
              pw.Container(
                height: 160,
                decoration: pw.BoxDecoration(
                  color: _kSurface,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: trendData.map((d) {
                    final double heightPct = maxRevenue > 0 ? (d.revenue / maxRevenue) .toDouble(): 0.0;
                    return pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Container(
                            height: 130.0 * heightPct,
                            margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                            decoration: pw.BoxDecoration(
                              color: d.revenue > avgRev ? _kGold : _kBrown,
                              borderRadius: const pw.BorderRadius.only(
                                topLeft: pw.Radius.circular(2),
                                topRight: pw.Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('* Bar emas = di atas rata-rata harian', style: pw.TextStyle(fontSize: 8, color: _kGrey)),
              pw.SizedBox(height: 20),

              // Daily table (last 10 days)
              pw.Text('Detail 10 Hari Terakhir', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kWhite)),
              pw.SizedBox(height: 8),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: _kBrown),
                    children: ['Tanggal', 'Revenue', 'Net Profit', 'Trx']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kWhite)),
                            ))
                        .toList(),
                  ),
                  ...trendData.reversed.take(10).map((d) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: trendData.reversed.toList().indexOf(d) % 2 == 0 ? _kSurface : _kDark,
                    ),
                    children: [
                      '${d.date.day}/${d.date.month}/${d.date.year}',
                      _rp(d.revenue),
                      _rp(d.netProfit),
                      '${d.transactions}',
                    ].map((text) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _kWhite)),
                    )).toList(),
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  return pdf.save();
}

// =============================================================================
// RECEIPT PDF
// =============================================================================

Future<Uint8List> generateReceiptPdf({
  required Map<String, dynamic> transaction,
}) async {
  final pdf = pw.Document();

  final trxCode     = transaction['trx_code'] as String;
  final grandTotal  = (transaction['grand_total'] as num).toDouble();
  final discount    = (transaction['discount_amount'] as num? ?? 0).toDouble();
  final tax         = (transaction['tax_amount'] as num? ?? 0).toDouble();
  final service     = (transaction['service_amount'] as num? ?? 0).toDouble();
  final payMethod   = transaction['payment_method'] as String? ?? '-';
  final cashTender  = transaction['cash_tendered'] != null ? (transaction['cash_tendered'] as num).toDouble() : null;
  final change      = transaction['change_given'] != null ? (transaction['change_given'] as num).toDouble() : null;
  final staffName   = transaction['staff_name'] as String? ?? 'Staff';
  final trxAt       = DateTime.parse(transaction['trx_at'] as String);
  final details     = (transaction['transaction_details'] as List);
  final subtotal    = details.fold<double>(0, (s, d) => s + (d['qty'] as num).toDouble() * (d['unit_price'] as num).toDouble());

  pdf.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 8 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.sourceCodeProRegular(),
        bold: await PdfGoogleFonts.sourceCodeProBold(),
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Store header
          pw.Text('MAKARYA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _kDark)),
          pw.Text('Kafe Buku & Kopi', style: pw.TextStyle(fontSize: 8, color: _kGrey)),
          pw.Text('Jl. Contoh No. 123, Jakarta', style: pw.TextStyle(fontSize: 7, color: _kGrey)),
          pw.Divider(color: _kDark, thickness: 0.5),

          // Transaction info
          _receiptRow('No Trx',  trxCode,  isSmall: true),
          _receiptRow('Kasir',   staffName, isSmall: true),
          _receiptRow('Waktu',   _formatDateTime(trxAt), isSmall: true),
          pw.Divider(color: _kGrey, thickness: 0.3),

          // Items
          ...details.map((d) {
            final name  = d['items']?['name'] ?? 'Item';
            final qty   = (d['qty'] as num).toDouble();
            final price = (d['unit_price'] as num).toDouble();
            final disc  = (d['discount'] as num? ?? 0).toDouble();
            final line  = qty * (price - disc);
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kDark)),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('  ${qty.toInt()}x ${_rp(price - disc)}',
                          style: pw.TextStyle(fontSize: 8, color: _kGrey)),
                      pw.Text(_rp(line), style: pw.TextStyle(fontSize: 8, color: _kDark)),
                    ],
                  ),
                ],
              ),
            );
          }),

          pw.Divider(color: _kGrey, thickness: 0.3),

          // Totals
          _receiptRow('Subtotal',  _rp(subtotal)),
          if (discount > 0) _receiptRow('Diskon', '- ${_rp(discount)}', valueColor: _kRed),
          if (tax > 0)      _receiptRow('PPN 11%', _rp(tax)),
          if (service > 0)  _receiptRow('Service 5%', _rp(service)),
          pw.Divider(color: _kDark, thickness: 0.8),
          _receiptRow('TOTAL', _rp(grandTotal), isBold: true),
          pw.SizedBox(height: 4),
          _receiptRow('Bayar ($payMethod)', cashTender != null ? _rp(cashTender) : '-'),
          if (change != null && change > 0) _receiptRow('Kembali', _rp(change)),

          pw.Divider(color: _kGrey, thickness: 0.3),
          pw.SizedBox(height: 6),
          pw.Text('Terima kasih!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kDark)),
          pw.Text('Selamat membaca & menikmati kopi ☕', style: pw.TextStyle(fontSize: 7, color: _kGrey)),
          pw.SizedBox(height: 8),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: 'MAKARYA:$trxCode',
            width: 60, height: 60,
          ),
          pw.SizedBox(height: 4),
          pw.Text(trxCode, style: pw.TextStyle(fontSize: 7, color: _kGrey)),
          pw.SizedBox(height: 16),
        ],
      ),
    ),
  );

  return pdf.save();
}

// =============================================================================
// SAVE & SHARE HELPERS
// =============================================================================

/// Save PDF bytes to temp file and return path
Future<String> savePdfToTemp(Uint8List bytes, String fileName) async {
  final dir  = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Print / share via system share sheet (works on Android & iOS)
Future<void> sharePdf(Uint8List bytes, {required String fileName}) async {
  await Printing.sharePdf(bytes: bytes, filename: fileName);
}

/// Open email client pre-filled with subject and receipt PDF as attachment
/// Uses mailto: deep-link — attachment not supported on all clients,
/// but opens correct email app. For real attachment use a backend mailer.
Future<void> openEmailWithReceipt({
  required String trxCode,
  required String recipientEmail,
}) async {
  final subject = Uri.encodeComponent('Struk Transaksi Makarya — $trxCode');
  final body    = Uri.encodeComponent(
    'Halo,\n\nTerlampir struk transaksi Anda dengan nomor $trxCode.\n\nTerima kasih telah mengunjungi Makarya!\n\nSalam,\nTim Makarya');
  final uri = Uri.parse('mailto:$recipientEmail?subject=$subject&body=$body');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

pw.Widget _kpiBox(String label, String value, PdfColor color) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _kSurface,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _kGrey)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    ),
  );
}

pw.TableRow _pnlTableRow(String label, String value, pw.TextStyle valStyle, {
  bool isHeader = false, bool isBold = false, bool isTotal = false,
}) {
  return pw.TableRow(
    decoration: isTotal
        ? pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E2E1E))
        : isHeader
            ? pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1209))
            : null,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: pw.Text(label,
            style: pw.TextStyle(
              fontSize: isTotal ? 11 : 10,
              fontWeight: (isBold || isTotal) ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _kWhite,
            )),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: pw.Text(value, style: valStyle, textAlign: pw.TextAlign.right),
      ),
    ],
  );
}

pw.Widget _pageHeader(String title, String period) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _kSurface,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _kGold)),
        pw.Text(period, style: pw.TextStyle(fontSize: 9, color: _kGrey)),
      ],
    ),
  );
}

pw.Widget _receiptRow(String label, String value, {bool isBold = false, bool isSmall = false, PdfColor? valueColor}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: isSmall ? 8 : 9, color: _kGrey)),
      pw.Text(value, style: pw.TextStyle(
        fontSize: isSmall ? 8 : 9,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: valueColor ?? _kDark,
      )),
    ],
  );
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String _formatDateTime(DateTime dt) =>
    '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
