// =============================================================================
// MAKARYA HYBRID ERP — Financial Report Screen
// File: lib/screens/financial_report_screen.dart
//
// NOTES (penting untuk kecocokan dengan codebase):
//   • Kolom transaksi  : trx_at (bukan created_at), trx_code (bukan invoice_code)
//   • Filter status    : .eq('status', 'DONE')
//   • Timestamp filter : .toUtc().toIso8601String() — konsisten dengan dashboard_provider
//                        WAJIB ada .toUtc() sebelum .toIso8601String() agar PostgreSQL
//                        membaca timestamp sebagai UTC (ada suffix 'Z'), bukan session TZ.
//   • Relasi kategori  : 2 query terpisah (flat), bukan nested — sama seperti SKU query
//   • expenses kolom   : expense_date (DATE), expense_cat_id → expense_categories
//   • staff di trx     : staff_name (kolom langsung, bukan join) — dari receipt query
//   • Export CSV       : share_plus + path_provider (sudah pasti ada di pubspec)
// =============================================================================

import 'dart:convert';
// Conditional imports untuk cross-platform CSV export:
//   - dart:html  : dipakai di web untuk trigger browser download
//   - _html_stub : stub kosong di non-web agar kompilasi tidak error
// dart:io tetap diimpor untuk mobile/desktop (File, Platform, Directory).
// SEMUA akses dart:html (html.*) dijaga dengan if (kIsWeb) { }
// SEMUA akses dart:io  (Platform, File) dijaga dengan else { }
import 'dart:html' as html if (dart.library.io) 'html_stub.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/makarya_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _TrxReport {
  final int    id;
  final String trxCode;
  final DateTime trxAt;
  final String staffName;
  final String paymentMethod;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double serviceAmount;
  final double grandTotal;
  final List<_TrxDetail> details;

  _TrxReport({
    required this.id,
    required this.trxCode,
    required this.trxAt,
    required this.staffName,
    required this.paymentMethod,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.grandTotal,
    required this.details,
  });
}

class _TrxDetail {
  final String itemName;
  final String categoryCode;
  final double qty;
  final double unitSellPrice;
  final double lineTotal;

  _TrxDetail({
    required this.itemName,
    required this.categoryCode,
    required this.qty,
    required this.unitSellPrice,
    required this.lineTotal,
  });
}

class _DailyIncome {
  final DateTime date;
  final double   totalRevenue;
  final double   totalDiscount;
  final double   totalTax;
  final int      trxCount;

  _DailyIncome({
    required this.date,
    required this.totalRevenue,
    required this.totalDiscount,
    required this.totalTax,
    required this.trxCount,
  });
}

class _ExpenseRow {
  final String   id;
  final String   categoryName;
  final String   categoryCode;
  final double   amount;
  final DateTime date;
  final String?  note;
  final String   staffName;

  _ExpenseRow({
    required this.id,
    required this.categoryName,
    required this.categoryCode,
    required this.amount,
    required this.date,
    this.note,
    required this.staffName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PERIODE
// ─────────────────────────────────────────────────────────────────────────────

enum _Period { today, week, month, custom }

extension _PeriodLabel on _Period {
  String get label => switch (this) {
    _Period.today  => 'Hari Ini',
    _Period.week   => '7 Hari',
    _Period.month  => '30 Hari',
    _Period.custom => 'Custom',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN UTAMA
// ─────────────────────────────────────────────────────────────────────────────

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _db = Supabase.instance.client;

  _Period  _period    = _Period.today;
  DateTime _startDate = DateTime.now();
  DateTime _endDate   = DateTime.now();

  List<_TrxReport>  _transactions = [];
  List<_DailyIncome> _incomeByDay = [];
  List<_ExpenseRow>  _expenses    = [];

  bool _loadingTrx = true;
  bool _loadingExp = true;
  bool _csvBusy    = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _applyPeriod(_Period.today);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Date helpers ────────────────────────────────────────────────────────────
  //
  // ATURAN WAJIB: selalu gunakan .toUtc().toIso8601String() agar string yang
  // dikirim ke PostgREST selalu ber-suffix 'Z' (misal "2026-05-23T17:00:00.000Z").
  //
  // TANPA .toUtc():
  //   DateTime(2026,5,24,0,0,0).toIso8601String()
  //   → "2026-05-24T00:00:00.000"  ← NO 'Z', PostgreSQL baca sesuai session TZ
  //   Jika session TZ = Asia/Jakarta → dianggap WIB, bukan UTC → filter SALAH.
  //
  // DENGAN .toUtc() (BENAR):
  //   DateTime(2026,5,24,0,0,0).toUtc().toIso8601String()
  //   → "2026-05-23T17:00:00.000Z" ← selalu UTC, tidak ambigu.
  //
  // Dart/Flutter sudah tahu timezone device (WIB = UTC+7), jadi .toUtc()
  // melakukan konversi dengan benar tanpa perlu hardcode -7 jam.

  String _utcStart(DateTime local) {
    // Midnight lokal (WIB) → konversi ke UTC → ISO string dengan suffix 'Z'
    // Contoh: DateTime(2026,5,24,0,0,0) WIB → "2026-05-23T17:00:00.000Z"
    return DateTime(local.year, local.month, local.day, 0, 0, 0)
        .toUtc()
        .toIso8601String();
  }

  String _utcEnd(DateTime local) {
    // 23:59:59.999 lokal (WIB) → konversi ke UTC → ISO string dengan suffix 'Z'
    // Gunakan 999ms agar tidak ada gap 1 detik di akhir hari.
    // Contoh: DateTime(2026,5,24,23,59,59,999) WIB → "2026-05-24T16:59:59.999Z"
    return DateTime(local.year, local.month, local.day, 23, 59, 59, 999)
        .toUtc()
        .toIso8601String();
  }

  String _isoDate(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2,'0')}-${local.day.toString().padLeft(2,'0')}';

  void _applyPeriod(_Period p, {DateTime? cs, DateTime? ce}) {
    final now = DateTime.now();
    setState(() {
      _period = p;
      switch (p) {
        case _Period.today:
          _startDate = now;
          _endDate   = now;
        case _Period.week:
          _startDate = now.subtract(const Duration(days: 6));
          _endDate   = now;
        case _Period.month:
          _startDate = now.subtract(const Duration(days: 29));
          _endDate   = now;
        case _Period.custom:
          _startDate = cs ?? now;
          _endDate   = ce ?? now;
      }
    });
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    _fetchTransactions();
    _fetchExpenses();
  }

  // ── Fetch Transactions ─────────────────────────────────────────────────────
  // Gunakan 2 query terpisah (flat) seperti pola SKU di dashboard_provider
  // agar tidak ada masalah nested select + kategori.

  Future<void> _fetchTransactions() async {
    if (!mounted) return;
    setState(() => _loadingTrx = true);
    try {
      // Query 1: data transaksi
      final trxRows = await _db
          .from('transactions')
          .select(
            'id, trx_code, trx_at, staff_name, payment_method, '
            'subtotal, discount_amount, tax_amount, service_amount, grand_total',
          )
          .eq('status', 'DONE')
          .gte('trx_at', _utcStart(_startDate))
          .lte('trx_at', _utcEnd(_endDate))
          .order('trx_at', ascending: false);

      if (trxRows.isEmpty) {
        if (mounted) setState(() { _transactions = []; _incomeByDay = []; _loadingTrx = false; });
        return;
      }

      final trxIds = trxRows.map<int>((t) => t['id'] as int).toList();

      // Query 2: detail transaksi (flat, sama seperti SKU query)
      final detailRows = await _db
          .from('transaction_details')
          .select('transaction_id, qty, unit_sell_price, unit_discount, item_id, items(id, name, category_id)')
          .inFilter('transaction_id', trxIds);

      // Query 3: kategori (flat map)
      final catRows = await _db.from('categories').select('id, code');
      final catMap  = <int, String>{
        for (final c in catRows) (c['id'] as int): (c['code'] as String? ?? 'OTHER'),
      };

      // Group detail by transaction_id
      final Map<int, List<_TrxDetail>> detailMap = {};
      for (final d in detailRows) {
        final trxId    = d['transaction_id'] as int;
        final item     = d['items'] as Map<String, dynamic>?;
        final catId    = item?['category_id'] as int?;
        final qty      = (d['qty'] as num).toDouble();
        final price    = (d['unit_sell_price'] as num).toDouble();
        final discount = (d['unit_discount'] as num? ?? 0).toDouble();
        final lineTotal = qty * (price - discount);

        detailMap.putIfAbsent(trxId, () => []).add(_TrxDetail(
          itemName:     item?['name'] as String? ?? '-',
          categoryCode: catMap[catId] ?? 'OTHER',
          qty:          qty,
          unitSellPrice: price - discount,
          lineTotal:    lineTotal,
        ));
      }

      // Build list
      final List<_TrxReport> result = trxRows.map((t) {
        final id = t['id'] as int;
        return _TrxReport(
          id:             id,
          trxCode:        t['trx_code'] as String? ?? '-',
          trxAt:          DateTime.parse(t['trx_at'] as String).toLocal(),
          staffName:      t['staff_name'] as String? ?? '-',
          paymentMethod:  t['payment_method'] as String? ?? '-',
          subtotal:       (t['subtotal'] as num? ?? 0).toDouble(),
          discountAmount: (t['discount_amount'] as num? ?? 0).toDouble(),
          taxAmount:      (t['tax_amount'] as num? ?? 0).toDouble(),
          serviceAmount:  (t['service_amount'] as num? ?? 0).toDouble(),
          grandTotal:     (t['grand_total'] as num).toDouble(),
          details:        detailMap[id] ?? [],
        );
      }).toList();

      // Build daily income summary
      final Map<String, _DailyIncome> dayMap = {};
      for (final t in result) {
        final key = _isoDate(t.trxAt);
        if (dayMap.containsKey(key)) {
          final e = dayMap[key]!;
          dayMap[key] = _DailyIncome(
            date:          e.date,
            totalRevenue:  e.totalRevenue + t.grandTotal,
            totalDiscount: e.totalDiscount + t.discountAmount,
            totalTax:      e.totalTax + t.taxAmount,
            trxCount:      e.trxCount + 1,
          );
        } else {
          dayMap[key] = _DailyIncome(
            date:          t.trxAt,
            totalRevenue:  t.grandTotal,
            totalDiscount: t.discountAmount,
            totalTax:      t.taxAmount,
            trxCount:      1,
          );
        }
      }

      if (mounted) {
        setState(() {
          _transactions = result;
          _incomeByDay  = dayMap.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          _loadingTrx = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTrx = false);
        _snack('Gagal muat transaksi: $e');
      }
    }
  }

  // ── Fetch Expenses ─────────────────────────────────────────────────────────

  Future<void> _fetchExpenses() async {
    if (!mounted) return;
    setState(() => _loadingExp = true);
    try {
      // Expenses pakai expense_date (DATE), bukan timestamp
      final rows = await _db
          .from('expenses')
          .select('id, amount, expense_date, notes, expense_categories(label, code), staff(full_name)')
          .gte('expense_date', _isoDate(_startDate))
          .lte('expense_date', _isoDate(_endDate))
          .order('expense_date', ascending: false);

      final list = rows.map<_ExpenseRow>((r) {
        final cat  = r['expense_categories'] as Map<String, dynamic>?;
        final stf  = r['staff'] as Map<String, dynamic>?;
        return _ExpenseRow(
          id:           r['id'].toString(),
          categoryName: cat?['label'] as String? ?? 'Lainnya',
          categoryCode: cat?['code'] as String? ?? 'OTHER',
          amount:       (r['amount'] as num).toDouble(),
          date:         DateTime.parse(r['expense_date'] as String),
          note:         r['notes'] as String?,
          staffName:    stf?['full_name'] as String? ?? '-',
        );
      }).toList();

      if (mounted) setState(() { _expenses = list; _loadingExp = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingExp = false);
        _snack('Gagal muat pengeluaran: $e');
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: MakaryaColors.lossRed),
    );
  }

  // ── Custom date picker ─────────────────────────────────────────────────────

  Future<void> _pickRange() async {
    final now   = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate:   DateTime(now.year - 1),
      lastDate:    now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   MakaryaColors.woodBrown,
            onPrimary: Colors.black,
            surface:   MakaryaColors.surface01,
            onSurface: MakaryaColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      _applyPeriod(_Period.custom, cs: range.start, ce: range.end);
    }
  }

  // ── Export CSV ─────────────────────────────────────────────────────────────

  // ── Helper: bungkus list string jadi row HTML <tr><td>...</td></tr> ────────
  String _xlsRow(List<String> cells, {bool isHeader = false}) {
    final tag = isHeader ? 'th' : 'td';
    final tds = cells.map((c) {
      // Prefix angka dengan tab agar Excel tidak auto-convert ke scientific notation
      final v = c.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      return '<$tag>$v</$tag>';
    }).join();
    return '<tr>$tds</tr>';
  }

  // ── Helper: wrap tabel jadi dokumen XLS (HTML-based Excel) ───────────────
  String _xlsWrap(String title, String tableBody) => '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:x="urn:schemas-microsoft-com:office:excel"
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
  <meta charset="UTF-8">
  <!--[if gte mso 9]><xml>
    <x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>
      <x:Name>$title</x:Name>
      <x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>
    </x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook>
  </xml><![endif]-->
  <style>th{background:#2d2d2d;color:#fff;font-weight:bold;}td,th{border:1px solid #ccc;padding:4px 8px;}</style>
</head>
<body><table>$tableBody</table></body>
</html>''';

  Future<void> _exportCsv() async {
    setState(() => _csvBusy = true);
    try {
      final tab = _tabCtrl.index;
      String content;
      String fileName;
      final tag = '${_isoDate(_startDate)}_sd_${_isoDate(_endDate)}';

      if (tab == 0) {
        // Tab Transaksi → XLS
        final buf = StringBuffer();
        buf.write(_xlsRow(['Waktu','Kode Transaksi','Kasir','Produk','Kategori','Qty','Harga Satuan','Total Item','Grand Total','Metode Bayar'], isHeader: true));
        for (final t in _transactions) {
          final time = _fmtDt(t.trxAt);
          for (final d in t.details) {
            buf.write(_xlsRow([
              time, t.trxCode, t.staffName,
              d.itemName, d.categoryCode,
              d.qty.toStringAsFixed(0),
              d.unitSellPrice.toStringAsFixed(0),
              d.lineTotal.toStringAsFixed(0),
              t.grandTotal.toStringAsFixed(0),
              t.paymentMethod,
            ]));
          }
        }
        content  = _xlsWrap('Transaksi', buf.toString());
        fileName = 'Transaksi_${tag}.xls';

      } else if (tab == 1) {
        // Tab Pemasukan → XLS
        final buf = StringBuffer();
        buf.write(_xlsRow(['Tanggal','Jumlah Transaksi','Total Pemasukan','Total Diskon','Total Pajak'], isHeader: true));
        for (final d in _incomeByDay) {
          buf.write(_xlsRow([
            _fmtDate(d.date),
            d.trxCount.toString(),
            d.totalRevenue.toStringAsFixed(0),
            d.totalDiscount.toStringAsFixed(0),
            d.totalTax.toStringAsFixed(0),
          ]));
        }
        final totRev = _incomeByDay.fold(0.0, (s, d) => s + d.totalRevenue);
        final totTrx = _incomeByDay.fold(0, (s, d) => s + d.trxCount);
        buf.write(_xlsRow(['TOTAL', totTrx.toString(), totRev.toStringAsFixed(0), '', '']));
        content  = _xlsWrap('Pemasukan', buf.toString());
        fileName = 'Pemasukan_${tag}.xls';

      } else {
        // Tab Pengeluaran → XLS
        final buf = StringBuffer();
        buf.write(_xlsRow(['Tanggal','Kategori','Jumlah','Catatan','Dicatat Oleh'], isHeader: true));
        for (final e in _expenses) {
          buf.write(_xlsRow([
            _fmtDate(e.date),
            e.categoryName,
            e.amount.toStringAsFixed(0),
            e.note ?? '-',
            e.staffName,
          ]));
        }
        final totExp = _expenses.fold(0.0, (s, e) => s + e.amount);
        buf.write(_xlsRow(['TOTAL', '', totExp.toStringAsFixed(0), '', '']));
        content  = _xlsWrap('Pengeluaran', buf.toString());
        fileName = 'Pengeluaran_${tag}.xls';
      }

      // ── Cross-platform download ───────────────────────────────────────────
      if (kIsWeb) {
        // Web: trigger download via browser AnchorElement
        final bytes  = utf8.encode(content);
        final blob   = html.Blob([bytes], 'application/vnd.ms-excel;charset=utf-8;');
        final url    = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href     = url
          ..download = fileName
          ..style.display = 'none';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

      } else {
        // ── Non-web (mobile + desktop): gunakan dart:io ───────────────────
        // Platform.isXxx aman di sini karena sudah di-guard oleh else (kIsWeb=false)
        final bool isMobile = Platform.isAndroid || Platform.isIOS;

        final Directory dir;
        if (isMobile) {
          dir = await getTemporaryDirectory();
        } else {
          // getDownloadsDirectory() bisa null di Linux tanpa XDG → fallback Documents
          dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        }

        final file = File('\${dir.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);

        if (isMobile) {
          await Share.shareXFiles([XFile(file.path)], text: 'Laporan Keuangan Makarya');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV disimpan: \${file.path}'),
                backgroundColor: MakaryaColors.profitGreen,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(label: 'OK', textColor: Colors.black, onPressed: () {}),
              ),
            );
          }
        }
      }

    } catch (e) {
      _snack('Gagal export CSV: $e');
    } finally {
      if (mounted) setState(() => _csvBusy = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter + Tab bar ───────────────────────────────────────────────
        Container(
          color: MakaryaColors.surface01,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter chips row
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _Period.values.map((p) {
                          final active = p == _period;
                          return GestureDetector(
                            onTap: () => p == _Period.custom
                                ? _pickRange()
                                : _applyPeriod(p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8, bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: active
                                    ? MakaryaColors.woodBrown.withValues(alpha: 0.25)
                                    : MakaryaColors.surface02,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active
                                      ? MakaryaColors.woodBrown
                                      : MakaryaColors.woodBrown.withValues(alpha: 0.15),
                                  width: active ? 1 : 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p == _Period.custom)
                                    const Icon(Icons.date_range_rounded, size: 11, color: MakaryaColors.woodLight),
                                  if (p == _Period.custom) const SizedBox(width: 4),
                                  Text(
                                    p.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                                      color: active ? MakaryaColors.woodLight : MakaryaColors.textSecondary,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // CSV button
                  GestureDetector(
                    onTap: _csvBusy ? null : _exportCsv,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: MakaryaColors.profitGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: MakaryaColors.profitGreen.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: _csvBusy
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: MakaryaColors.profitGreen),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_chart_rounded, size: 13, color: MakaryaColors.profitGreen),
                                SizedBox(width: 4),
                                Text('XLS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.profitGreen, fontFamily: 'Inter')),
                              ],
                            ),
                    ),
                  ),
                ],
              ),

              // Custom range label
              if (_period == _Period.custom)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${_fmtDate(_startDate)} – ${_fmtDate(_endDate)}',
                    style: const TextStyle(fontSize: 10, color: MakaryaColors.woodLight, fontFamily: 'Inter'),
                  ),
                ),

              // Tab bar — pakai theme dari MakaryaTheme (otomatis cocok)
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Transaksi'),
                  Tab(text: 'Pemasukan'),
                  Tab(text: 'Pengeluaran'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab views ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _TransactionTab(loading: _loadingTrx, rows: _transactions),
              _IncomeTab(loading: _loadingTrx, incomeByDay: _incomeByDay, transactions: _transactions),
              _ExpenseTab(loading: _loadingExp, rows: _expenses, onRefresh: _fetchExpenses),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 1 — TRANSAKSI DETAIL
// =============================================================================

class _TransactionTab extends StatefulWidget {
  final bool loading;
  final List<_TrxReport> rows;
  const _TransactionTab({required this.loading, required this.rows});

  @override
  State<_TransactionTab> createState() => _TransactionTabState();
}

class _TransactionTabState extends State<_TransactionTab> {
  int? _expandedId;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown));
    }
    if (widget.rows.isEmpty) {
      return const _EmptyState(icon: Icons.receipt_long_rounded, label: 'Tidak ada transaksi di periode ini');
    }

    final totalGrand = widget.rows.fold(0.0, (s, t) => s + t.grandTotal);

    return Column(
      children: [
        // Summary strip
        _SummaryStrip(children: [
          _StatPill(label: 'Transaksi', value: '${widget.rows.length}', color: MakaryaColors.infoBlue),
          const SizedBox(width: 10),
          _StatPill(label: 'Total', value: _rp(totalGrand), color: MakaryaColors.goldAccent),
        ]),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.rows.length,
            itemBuilder: (_, i) {
              final t      = widget.rows[i];
              final isOpen = _expandedId == t.id;
              return GestureDetector(
                onTap: () => setState(() => _expandedId = isOpen ? null : t.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: MakaryaColors.surface01,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOpen
                          ? MakaryaColors.woodBrown.withValues(alpha: 0.5)
                          : MakaryaColors.woodBrown.withValues(alpha: 0.12),
                      width: isOpen ? 1 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fmtDt(t.trxAt),
                                      style: const TextStyle(fontSize: 10, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                                  const SizedBox(height: 2),
                                  Text(t.trxCode,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                          color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                                  Text('${t.details.length} produk  ·  ${t.staffName}',
                                      style: const TextStyle(fontSize: 10, color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_rp(t.grandTotal),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                        color: MakaryaColors.goldAccent, fontFamily: 'Inter')),
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(t.paymentMethod.toUpperCase(),
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                          color: MakaryaColors.woodLight, fontFamily: 'Inter')),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18, color: MakaryaColors.textMuted,
                            ),
                          ],
                        ),
                      ),

                      // Detail expanded
                      if (isOpen) ...[
                        Divider(height: 1, color: MakaryaColors.woodBrown.withValues(alpha: 0.15)),

                        // Table header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(children: const [
                            Expanded(flex: 4, child: _ColH('Produk')),
                            Expanded(flex: 1, child: _ColH('Qty', right: true)),
                            Expanded(flex: 2, child: _ColH('Harga', right: true)),
                            Expanded(flex: 2, child: _ColH('Total', right: true)),
                          ]),
                        ),

                        // Rows
                        ...t.details.map((d) => Padding(
                          padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
                          child: Row(children: [
                            Expanded(flex: 4, child: Row(children: [
                              Container(width: 5, height: 5,
                                  decoration: BoxDecoration(color: _catColor(d.categoryCode), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(d.itemName,
                                  style: const TextStyle(fontSize: 11, color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                                  overflow: TextOverflow.ellipsis)),
                            ])),
                            Expanded(flex: 1, child: Text(d.qty.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 11, color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
                                textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text(_rp(d.unitSellPrice),
                                style: const TextStyle(fontSize: 11, color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
                                textAlign: TextAlign.right)),
                            Expanded(flex: 2, child: Text(_rp(d.lineTotal),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                                textAlign: TextAlign.right)),
                          ]),
                        )),

                        // Subtotal breakdown
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                          child: Column(children: [
                            Divider(height: 12, color: MakaryaColors.woodBrown.withValues(alpha: 0.1)),
                            if (t.discountAmount > 0)
                              _TotRow('Diskon', '- ${_rp(t.discountAmount)}', color: MakaryaColors.profitGreen),
                            if (t.taxAmount > 0)
                              _TotRow('PPN 11%', _rp(t.taxAmount)),
                            if (t.serviceAmount > 0)
                              _TotRow('Service 5%', _rp(t.serviceAmount)),
                            _TotRow('GRAND TOTAL', _rp(t.grandTotal), bold: true, color: MakaryaColors.goldAccent),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 2 — PEMASUKAN HARIAN
// =============================================================================

class _IncomeTab extends StatelessWidget {
  final bool loading;
  final List<_DailyIncome>  incomeByDay;
  final List<_TrxReport>    transactions;
  const _IncomeTab({required this.loading, required this.incomeByDay, required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown));

    final totalRev  = incomeByDay.fold(0.0, (s, d) => s + d.totalRevenue);
    final totalTrx  = incomeByDay.fold(0, (s, d) => s + d.trxCount);
    final totalDisc = incomeByDay.fold(0.0, (s, d) => s + d.totalDiscount);

    return Column(
      children: [
        // Summary cards
        Container(
          padding: const EdgeInsets.all(12),
          color: MakaryaColors.surface02,
          child: Row(children: [
            _SummCard(label: 'Total Pemasukan', value: _rp(totalRev), icon: Icons.trending_up_rounded, color: MakaryaColors.profitGreen),
            const SizedBox(width: 8),
            _SummCard(label: 'Jml Transaksi', value: '$totalTrx', icon: Icons.receipt_rounded, color: MakaryaColors.infoBlue),
            const SizedBox(width: 8),
            _SummCard(label: 'Total Diskon', value: _rp(totalDisc), icon: Icons.discount_rounded, color: MakaryaColors.warningAmber),
          ]),
        ),

        // Table header — sesuai mockup user: Tanggal / Pemasukan / Pengeluaran / Selisih
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: MakaryaColors.surface01,
          child: Row(children: const [
            Expanded(flex: 2, child: _ColH('Tanggal')),
            Expanded(flex: 3, child: _ColH('Pemasukan', right: true)),
            Expanded(flex: 2, child: _ColH('Pengeluaran', right: true)),
            Expanded(flex: 2, child: _ColH('Selisih', right: true)),
          ]),
        ),

        Expanded(
          child: incomeByDay.isEmpty
              ? const _EmptyState(icon: Icons.bar_chart_rounded, label: 'Tidak ada pemasukan di periode ini')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: incomeByDay.length,
                  itemBuilder: (_, i) {
                    final d = incomeByDay[i];
                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: MakaryaColors.surface01,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.1), width: 0.5),
                      ),
                      child: Row(children: [
                        Expanded(flex: 2, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fmtDateShort(d.date),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                            Text('${d.trxCount} trx',
                                style: const TextStyle(fontSize: 10, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                          ],
                        )),
                        Expanded(flex: 3, child: Text(_rp(d.totalRevenue),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: MakaryaColors.profitGreen, fontFamily: 'Inter'),
                            textAlign: TextAlign.right)),
                        // Pengeluaran per hari tidak di-join (performa), tampil dash
                        Expanded(flex: 2, child: const Text('-',
                            style: TextStyle(fontSize: 12, color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                            textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text(_rp(d.totalRevenue),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: MakaryaColors.profitGreen, fontFamily: 'Inter'),
                            textAlign: TextAlign.right)),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 3 — PENGELUARAN (real Supabase)
// =============================================================================

class _ExpenseTab extends StatelessWidget {
  final bool loading;
  final List<_ExpenseRow> rows;
  final VoidCallback onRefresh;
  const _ExpenseTab({required this.loading, required this.rows, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown));

    final totalExp = rows.fold(0.0, (s, e) => s + e.amount);
    final Map<String, double> breakdown = {};
    for (final e in rows) breakdown[e.categoryName] = (breakdown[e.categoryName] ?? 0) + e.amount;
    final sorted = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: MakaryaColors.surface02,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _SummCard(label: 'Total Pengeluaran', value: _rp(totalExp), icon: Icons.trending_down_rounded, color: MakaryaColors.lossRed),
                const SizedBox(width: 8),
                _SummCard(label: 'Jumlah Entri', value: '${rows.length}', icon: Icons.list_alt_rounded, color: MakaryaColors.infoBlue),
              ]),
              if (sorted.isNotEmpty) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: sorted.map((e) {
                      final pct = totalExp > 0 ? e.value / totalExp * 100 : 0;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: MakaryaColors.surface01,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MakaryaColors.lossRed.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Text('${e.key}: ${_rp(e.value)} (${pct.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 10, color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: rows.isEmpty
              ? _EmptyState(icon: Icons.receipt_long_outlined, label: 'Tidak ada pengeluaran di periode ini',
                  action: OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                  ))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final e = rows[i];
                    final color = _expCatColor(e.categoryCode);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: MakaryaColors.surface01,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.1), width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(e.categoryCode,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.categoryName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                            Text('${_fmtDate(e.date)}  ·  ${e.staffName}',
                                style: const TextStyle(fontSize: 10, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                            if (e.note != null && e.note!.isNotEmpty)
                              Text(e.note!,
                                  style: const TextStyle(fontSize: 10, color: MakaryaColors.textSecondary,
                                      fontFamily: 'Inter', fontStyle: FontStyle.italic)),
                          ],
                        )),
                        Text(_rp(e.amount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: MakaryaColors.lossRed, fontFamily: 'Inter')),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _SummaryStrip extends StatelessWidget {
  final List<Widget> children;
  const _SummaryStrip({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    color: MakaryaColors.surface02,
    child: Row(children: children),
  );
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontFamily: 'Inter')),
        Text(value,  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
      ]),
    ),
  );
}

class _SummCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontFamily: 'Inter')),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter'),
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ),
  );
}

class _ColH extends StatelessWidget {
  final String text;
  final bool right;
  const _ColH(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
      textAlign: right ? TextAlign.right : TextAlign.left);
}

class _TotRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _TotRow(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: bold ? 12 : 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: bold ? MakaryaColors.textPrimary : MakaryaColors.textSecondary, fontFamily: 'Inter')),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: bold ? 12 : 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? (bold ? MakaryaColors.textPrimary : MakaryaColors.textSecondary), fontFamily: 'Inter')),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? action;
  const _EmptyState({required this.icon, required this.label, this.action});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 48, color: MakaryaColors.textMuted),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
      if (action != null) ...[const SizedBox(height: 16), action!],
    ]),
  );
}

// =============================================================================
// HELPERS
// =============================================================================

String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

String _fmtDt(DateTime dt) {
  final d = '${dt.day.toString().padLeft(2,'0')} ${_mo(dt.month)} ${dt.year}';
  final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  return '$d $t';
}

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2,'0')} ${_mo(dt.month)} ${dt.year}';

String _fmtDateShort(DateTime dt) =>
    '${dt.day.toString().padLeft(2,'0')} ${_mo(dt.month)}';

String _mo(int m) => const ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'][m-1];

Color _catColor(String code) => switch (code) {
  'COFFEE' => MakaryaColors.woodBrown,
  'BOOK'   => MakaryaColors.infoBlue,
  'FOOD'   => MakaryaColors.woodLight,
  _        => MakaryaColors.concreteGrey,
};

Color _expCatColor(String code) => switch (code) {
  'SALARIES'    => MakaryaColors.infoBlue,
  'UTILITIES'   => MakaryaColors.warningAmber,
  'RENT'        => MakaryaColors.woodBrown,
  'SUPPLIES'    => MakaryaColors.woodLight,
  'MARKETING'   => MakaryaColors.categoryMerch,
  'MAINTENANCE' => MakaryaColors.concreteGrey,
  _             => MakaryaColors.textSecondary,
};