// =============================================================================
// MAKARYA HYBRID ERP — Dashboard Provider (Supabase Live)
// File: lib/providers/dashboard_provider.dart
// percobaan ke 12314212121321321321321141421421x bissmillah bisa yu tanpa error lgi 
// =============================================================================
//
// FIXES APPLIED:
//   [FIX-1] _todayStart() & _periodStart() → pakai .toUtc() biar Supabase
//           baca timezone dengan benar (WIB = UTC+7, bukan UTC midnight)
//   [FIX-2] _periodEnd() → konsisten pakai UTC
//   [FIX-3] Silent catch di _loadOrdersAndVisitors & _loadPnl sekarang
//           log error ke debugPrint agar mudah di-debug
//   [FIX-4] Grouping trend 30 hari pakai local date (bukan UTC) agar bar
//           chart muncul di hari yang benar
// =============================================================================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/business_logic.dart';

// ── Period Filter ──────────────────────────────────────────────────────────────
enum PeriodFilter { today, week, month, custom }

extension PeriodFilterLabel on PeriodFilter {
  String get label => switch (this) {
    PeriodFilter.today  => 'Hari Ini',
    PeriodFilter.week   => '7 Hari',
    PeriodFilter.month  => '30 Hari',
    PeriodFilter.custom => 'Custom',
  };
}

// ── SKU Profitability Model ────────────────────────────────────────────────────
class SkuProfitability {
  final String sku;
  final String name;
  final String categoryCode;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double grossMarginPct;
  final int unitsSold;
  final double revenueContributionPct;

  const SkuProfitability({
    required this.sku,
    required this.name,
    required this.categoryCode,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.unitsSold,
    required this.revenueContributionPct,
  });
}

// ── Daily Trend Point ──────────────────────────────────────────────────────────
class DailyTrendPoint {
  final DateTime date;
  final double revenue;
  final double netProfit;
  final int transactions;

  const DailyTrendPoint({
    required this.date,
    required this.revenue,
    required this.netProfit,
    required this.transactions,
  });
}

class DashboardProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  ProfitabilityResult? _todayPnl;
  ProfitabilityResult? get todayPnl => _todayPnl;

  SalesMixResult? _salesMix;
  SalesMixResult? get salesMix => _salesMix;

  PeakHourResult? _peakHours;
  PeakHourResult? get peakHours => _peakHours;

  BundleAnalyticsResult? _bundleAnalytics;
  BundleAnalyticsResult? get bundleAnalytics => _bundleAnalytics;

  List<InventoryAging> _inventoryAlerts = [];
  List<InventoryAging> get inventoryAlerts => _inventoryAlerts;

  int get alertCount => _inventoryAlerts.where((a) => a.health != StockHealth.healthy).length;

  final List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> get recentTransactions => _recentTransactions;

  // ── Total Orders & Visitors (derived from transactions) ───────────────────
  int _totalOrders   = 0;
  int _totalVisitors = 0;
  int get totalOrders   => _totalOrders;
  int get totalVisitors => _totalVisitors;

  // ── Period Filter ──────────────────────────────────────────────────────────
  PeriodFilter _selectedPeriod = PeriodFilter.today;
  PeriodFilter get selectedPeriod => _selectedPeriod;

  DateTime? _customStart;
  DateTime? _customEnd;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd   => _customEnd;

  // ── 30-day Trend ──────────────────────────────────────────────────────────
  List<DailyTrendPoint> _trendData = [];
  List<DailyTrendPoint> get trendData => _trendData;
  bool _trendLoading = false;
  bool get trendLoading => _trendLoading;

  // ── SKU Profitability ──────────────────────────────────────────────────────
  List<SkuProfitability> _skuProfitability = [];
  List<SkuProfitability> get skuProfitability => _skuProfitability;
  bool _skuLoading = false;
  bool get skuLoading => _skuLoading;

  // ── Filtered PnL ──────────────────────────────────────────────────────────
  ProfitabilityResult? _filteredPnl;
  ProfitabilityResult? get filteredPnl => _filteredPnl;

  Timer?           _refreshTimer;
  RealtimeChannel? _realtimeChannel;
  bool             _hasLoadedOnce = false;
  final _supabase = Supabase.instance.client;

  // ── Initialize ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    _refreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    await _loadAllData();
    await loadTrend30Days();
    await loadSkuProfitability();
    _subscribeRealtime(); // [FIX-RT] mulai listen transaksi baru dari POS
  }

  // ── Realtime Subscription ──────────────────────────────────────────────────
  //
  // Listen ke INSERT & UPDATE di tabel transactions.
  // Setiap ada transaksi baru (dari POS) atau status berubah jadi DONE,
  // dashboard langsung reload data tanpa perlu refresh manual.
  //
  // Kenapa pakai dua event (insert + update)?
  //   - POS mungkin INSERT dulu dengan status PENDING, lalu UPDATE ke DONE.
  //   - Kalau hanya listen INSERT, transaksi yang statusnya diubah belakangan
  //     tidak akan terdeteksi.
  // ──────────────────────────────────────────────────────────────────────────
  void _subscribeRealtime() {
    _realtimeChannel = _supabase
        .channel('dashboard:transactions')
        .onPostgresChanges(
          event:    PostgresChangeEvent.insert,
          schema:   'public',
          table:    'transactions',
          callback: (payload) {
            debugPrint('🔔 Realtime INSERT: ${payload.newRecord['trx_code']}');
            _loadAllData();
            loadSkuProfitability();
          },
        )
        .onPostgresChanges(
          event:    PostgresChangeEvent.update,
          schema:   'public',
          table:    'transactions',
          callback: (payload) {
            // Cek status di dalam callback — hindari FilterType yang
            // tidak tersedia di semua versi supabase_flutter
            if (payload.newRecord['status'] == 'DONE') {
              debugPrint(" Realtime UPDATE→DONE: ${payload.newRecord['trx_code']}");
              _loadAllData();
              loadSkuProfitability();
            }
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            debugPrint(' Realtime subscription error: $error');
          } else {
            debugPrint(' Realtime subscribed — status: $status');
          }
        });
  }

  // ── Manual Refresh ─────────────────────────────────────────────────────────
  Future<void> refresh() async {
    await _loadAllData();
    await loadTrend30Days();
    await loadSkuProfitability();
  }

  // ── Period Filter Control ──────────────────────────────────────────────────
  Future<void> setPeriod(PeriodFilter period, {DateTime? customStart, DateTime? customEnd}) async {
    _selectedPeriod = period;
    if (period == PeriodFilter.custom) {
      _customStart = customStart;
      _customEnd   = customEnd;
    }
    notifyListeners();
    await _loadFilteredPnl();
    await loadSkuProfitability();
  }

  // ── [FIX-1] Period Date Helpers — semua pakai UTC eksplisit ───────────────
  //
  // SEBELUMNYA: DateTime(...).toIso8601String() → "2026-05-06T00:00:00.000"
  //   Supabase baca ini sebagai UTC midnight = jam 07:00 WIB.
  //   Transaksi sebelum jam 7 pagi jadi "kemarin" di mata Supabase!
  //
  // SESUDAHNYA: .toUtc().toIso8601String() → "2026-05-05T17:00:00.000Z"
  //   Supabase tau persis ini midnight WIB (UTC+7). Semua transaksi hari ini
  //   keambil dengan benar.
  // ──────────────────────────────────────────────────────────────────────────
  String _periodStart() {
    final now = DateTime.now(); // local = WIB
    return switch (_selectedPeriod) {
      // midnight WIB hari ini → UTC
      PeriodFilter.today  => DateTime(now.year, now.month, now.day).toUtc().toIso8601String(),
      // midnight WIB 7 hari lalu → UTC
      PeriodFilter.week   => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)).toUtc().toIso8601String(),
      // midnight WIB 30 hari lalu → UTC
      PeriodFilter.month  => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)).toUtc().toIso8601String(),
      PeriodFilter.custom => (_customStart != null
          ? DateTime(_customStart!.year, _customStart!.month, _customStart!.day).toUtc().toIso8601String()
          : DateTime(now.year, now.month, now.day).toUtc().toIso8601String()),
    };
  }

  // _periodEnd → selalu end of day WIB (23:59:59) dikonversi ke UTC
  // Ini penting agar transaksi yang masuk sepanjang hari selalu keambil
  String _periodEnd() {
    final now = DateTime.now();
    if (_selectedPeriod == PeriodFilter.custom && _customEnd != null) {
      return DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();
    }
    // End of day WIB = besok midnight UTC - 1 detik
    return DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
  }

  // ── Load All Data ──────────────────────────────────────────────────────────
  Future<void> _loadAllData() async {
    if (!_hasLoadedOnce) {
      _loading = true;
      _error   = null;
      notifyListeners();
    }

    try {
      await Future.wait([
        _loadPnl(),
        _loadFilteredPnl(),
        _loadSalesMix(),
        _loadPeakHours(),
        _loadBundleAnalytics(),
        _loadInventoryAlerts(),
        _loadRecentTransactions(),
        _loadOrdersAndVisitors(),
      ], eagerError: false);
    } catch (e) {
      _error = e.toString();
        debugPrint(' _loadAllData error: $e');
    } finally {
      _loading       = false;
      _hasLoadedOnce = true;
      debugPrint('🔄 notifyListeners dipanggil — orders: $_totalOrders, pnl: ${_todayPnl?.grossRevenue}');
      notifyListeners();
    }
  }

  // ── Load Filtered PnL (period-aware) ──────────────────────────────────────
  Future<void> _loadFilteredPnl() async {
    try {
      final trxData = await _supabase
          .from('transactions')
          .select('grand_total, total_cogs, discount_amount, subtotal')
          .eq('status', 'DONE')
          .gte('trx_at', _periodStart())
          .lte('trx_at', _periodEnd());

      double grossRevenue = 0, totalCogs = 0, totalDiscounts = 0;
      for (final t in trxData) {
        grossRevenue   += (t['grand_total']     as num).toDouble();
        totalCogs      += (t['total_cogs']      as num).toDouble();
        totalDiscounts += (t['discount_amount'] as num).toDouble();
      }

      final netRevenue     = grossRevenue - totalDiscounts;
      final grossProfit    = netRevenue - totalCogs;
      final grossMarginPct = netRevenue > 0 ? grossProfit / netRevenue : 0.0;
      final netProfit      = grossProfit;
      final netMarginPct   = grossRevenue > 0 ? netProfit / grossRevenue : 0.0;

      _filteredPnl = ProfitabilityResult(
        grossRevenue:          grossRevenue,
        totalDiscounts:        totalDiscounts,
        netRevenue:            netRevenue,
        totalCogs:             totalCogs,
        grossProfit:           grossProfit,
        grossMarginPct:        grossMarginPct,
        totalOpex:             0,
        totalWastage:          0,
        totalTax:              0,
        netProfit:             netProfit,
        netMarginPct:          netMarginPct,
        revenueByCategory:     {},
        cogsByCategory:        {},
        grossProfitByCategory: {},
      );
      notifyListeners();
    } catch (e) {
      // [FIX-3] Log error — jangan ditelan diam-diam
      debugPrint(' _loadFilteredPnl error: $e');
    }
  }

  // ── Load 30-Day Trend ──────────────────────────────────────────────────────
  Future<void> loadTrend30Days() async {
    _trendLoading = true;
    notifyListeners();

    try {
      // [FIX-1] since juga pakai UTC
      final since = DateTime.now().subtract(const Duration(days: 30)).toUtc();
      final data  = await _supabase
          .from('transactions')
          .select('trx_at, grand_total, total_cogs, discount_amount')
          .eq('status', 'DONE')
          .gte('trx_at', since.toIso8601String())
          .order('trx_at');

      // [FIX-4] Group by LOCAL date (bukan UTC) agar bar chart muncul di
      //         hari yang benar di timezone WIB
      final Map<String, List<Map<String, dynamic>>> byDate = {};
      for (final t in data) {
        // DateTime.parse lalu .toLocal() → konversi UTC ke WIB dulu
        final dt  = DateTime.parse(t['trx_at']).toLocal();
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        byDate.putIfAbsent(key, () => []).add(t);
      }

      // Build 30-day array (fill missing days with 0)
      final List<DailyTrendPoint> trend = [];
      for (int i = 29; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key  = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final rows = byDate[key] ?? [];

        double revenue = 0, cogs = 0, discounts = 0;
        for (final r in rows) {
          revenue   += (r['grand_total']     as num).toDouble();
          cogs      += (r['total_cogs']      as num).toDouble();
          discounts += (r['discount_amount'] as num).toDouble();
        }
        final netRevenue  = revenue - discounts;
        final grossProfit = netRevenue - cogs;

        trend.add(DailyTrendPoint(
          date:         date,
          revenue:      revenue,
          netProfit:    grossProfit,
          transactions: rows.length,
        ));
      }

      _trendData = trend;
    } catch (e) {
      // [FIX-3] Log error
      debugPrint(' loadTrend30Days error: $e');
      _error = e.toString();
    } finally {
      _trendLoading = false;
      notifyListeners();
    }
  }

    // ── Load SKU Profitability Matrix ──────────────────────────────────────────
 Future<void> loadSkuProfitability() async {
  _skuLoading = true;
  notifyListeners();

  try {
    debugPrint('🔍 SKU [1] periodStart='+_periodStart()+' periodEnd='+_periodEnd());

    // Step 1: ambil transaction_id yang DONE dalam periode ini
    final trxRows = await _supabase
        .from('transactions')
        .select('id')
        .eq('status', 'DONE')
        .gte('trx_at', _periodStart())
        .lte('trx_at', _periodEnd());

    debugPrint('🔍 SKU [2] trxRows.length='+trxRows.length.toString());

    if (trxRows.isEmpty) {
      _skuProfitability = [];
      return;
    }

    final trxIds = trxRows.map((t) => t['id'] as int).toList();

    // Step 2: ambil detail transaksi + item info (flat, tanpa nested categories)
    final detailRows = await _supabase
        .from('transaction_details')
        .select('qty, unit_sell_price, cost_at_time, unit_discount, item_id, items(id, sku, name, category_id)')
        .inFilter('transaction_id', trxIds);

    debugPrint('🔍 SKU [3] detailRows.length='+detailRows.length.toString());
    if (detailRows.isNotEmpty) debugPrint('🔍 SKU [3] sample row: '+detailRows.first.toString());

    // Step 3: ambil semua categories sekali untuk mapping id → code
    final catRows = await _supabase
        .from('categories')
        .select('id, code');

    debugPrint('🔍 SKU [4] catRows: '+catRows.toString());

    final catMap = <int, String>{
      for (final c in catRows)
        (c['id'] as int): (c['code'] as String),
    };

    // Step 4: aggregate by SKU
    final Map<String, Map<String, dynamic>> skuMap = {};

    for (final row in detailRows) {
      final item = row['items'];
      if (item == null) continue;

      final sku      = item['sku']  as String;
      final name     = item['name'] as String;
      final catId    = item['category_id'] as int? ?? 0;
      final category = catMap[catId] ?? '';
      final qty      = (row['qty']            as num).toDouble();
      final price    = (row['unit_sell_price'] as num).toDouble();
      final cogs     = (row['cost_at_time']    as num? ?? 0).toDouble();
      final discount = (row['unit_discount']   as num? ?? 0).toDouble();

      final lineRevenue = qty * (price - discount);
      final lineCogs    = qty * cogs;
      final lineGP      = lineRevenue - lineCogs;

      skuMap.putIfAbsent(sku, () => {
        'sku':      sku,
        'name':     name,
        'category': category,
        'revenue':  0.0,
        'cogs':     0.0,
        'gp':       0.0,
        'units':    0,
      });

      skuMap[sku]!['revenue'] = (skuMap[sku]!['revenue'] as double) + lineRevenue;
      skuMap[sku]!['cogs']    = (skuMap[sku]!['cogs']    as double) + lineCogs;
      skuMap[sku]!['gp']      = (skuMap[sku]!['gp']      as double) + lineGP;
      skuMap[sku]!['units']   = (skuMap[sku]!['units']   as int)    + qty.toInt();
    }

    debugPrint('🔍 SKU [5] skuMap.length='+skuMap.length.toString());

    final totalRevenue = skuMap.values.fold(0.0, (s, v) => s + (v['revenue'] as double));

    _skuProfitability = skuMap.values.map((v) {
      final rev = v['revenue'] as double;
      final gp  = v['gp']     as double;
      return SkuProfitability(
        sku:                    v['sku'],
        name:                   v['name'],
        categoryCode:           v['category'],
        revenue:                rev,
        cogs:                   v['cogs'],
        grossProfit:            gp,
        grossMarginPct:         rev > 0 ? gp / rev : 0,
        unitsSold:              v['units'],
        revenueContributionPct: totalRevenue > 0 ? rev / totalRevenue : 0,
      );
    }).toList();

    debugPrint('🔍 SKU [6] DONE _skuProfitability.length='+_skuProfitability.length.toString());

  } catch (e, st) {
    debugPrint('🔍 SKU ERROR: $e');
    debugPrint('🔍 SKU STACKTRACE: $st');
  } finally {
    _skuLoading = false;
    notifyListeners();
  }
}

  // ── Fetch Single Transaction for Receipt ───────────────────────────────────
  Future<Map<String, dynamic>?> fetchTransactionForReceipt(String trxCode) async {
    try {
      final data = await _supabase
          .from('transactions')
          .select('''
            trx_code, grand_total, total_cogs, discount_amount, subtotal,
            tax_amount, service_amount, payment_method, cash_tendered, change_given,
            trx_at, has_book, has_cafe, staff_name,
            transaction_details(
              qty, unit_sell_price, cost_at_time, unit_discount,
              items(id, sku, name, name_short, category_id)
            )
          ''')
          .eq('trx_code', trxCode)
          .single();
      return data;
    } catch (_) {
      return null;
    }
  }

  // ── Load PnL (Today only) ──────────────────────────────────────────────────
  Future<void> _loadPnl() async {
    try {
      final trxData = await _supabase
          .from('transactions')
          .select('grand_total, total_cogs, discount_amount, subtotal')
          .eq('status', 'DONE')
          // [FIX-1] _todayStart() sekarang return UTC string
          .gte('trx_at', _todayStart());

      final expData = await _supabase
          .from('expenses')
          .select('amount, expense_categories(affects_profit)')
          .eq('expense_date', _todayDate());

      final wasteData = await _supabase
          .from('wastage_logs')
          .select('net_waste_cost')
          .eq('waste_date', _todayDate());

      double grossRevenue = 0, totalCogs = 0, totalDiscounts = 0;
      for (final t in trxData) {
        grossRevenue   += (t['grand_total']     as num).toDouble();
        totalCogs      += (t['total_cogs']      as num).toDouble();
        totalDiscounts += (t['discount_amount'] as num).toDouble();
      }

      double totalOpex = 0;
      for (final e in expData) {
        final affects = e['expense_categories']?['affects_profit'] ?? true;
        if (affects == true) totalOpex += (e['amount'] as num).toDouble();
      }

      double totalWastage = 0;
      for (final w in wasteData) {
        totalWastage += (w['net_waste_cost'] as num).toDouble();
      }

      final netRevenue     = grossRevenue - totalDiscounts;
      final grossProfit    = netRevenue - totalCogs;
      final grossMarginPct = netRevenue > 0 ? grossProfit / netRevenue : 0.0;
      final netProfit      = grossProfit - totalOpex - totalWastage;
      final netMarginPct   = grossRevenue > 0 ? netProfit / grossRevenue : 0.0;

      _todayPnl = ProfitabilityResult(
        grossRevenue:          grossRevenue,
        totalDiscounts:        totalDiscounts,
        netRevenue:            netRevenue,
        totalCogs:             totalCogs,
        grossProfit:           grossProfit,
        grossMarginPct:        grossMarginPct,
        totalOpex:             totalOpex,
        totalWastage:          totalWastage,
        totalTax:              0,
        netProfit:             netProfit,
        netMarginPct:          netMarginPct,
        revenueByCategory:     {},
        cogsByCategory:        {},
        grossProfitByCategory: {},
      );
    } catch (e) {
      // [FIX-3] Log error — jangan ditelan diam-diam
      debugPrint(' _loadPnl error: $e');
      _error = e.toString();
    }
  }

  // ── Load Sales Mix ─────────────────────────────────────────────────────────
  Future<void> _loadSalesMix() async {
    try {
      final data = await _supabase.from('vw_sales_mix').select();
      if (data.isEmpty) { _salesMix = null; return; }

      final entries = data.map<SalesMixEntry>((row) => SalesMixEntry(
        categoryCode: row['category_code'] as String,
        label:        row['category_label'] as String,
        colorHex:     row['color_hex'] as String,
        revenue:      (row['revenue'] as num).toDouble(),
        units:        (row['units_sold'] as num).toDouble(),
        cogs:         (row['cogs'] as num).toDouble(),
        grossProfit:  (row['gross_profit'] as num).toDouble(),
      )).toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      _salesMix = SalesMixResult(
        entries:      entries,
        totalRevenue: entries.fold(0.0, (s, e) => s + e.revenue),
        totalUnits:   entries.fold(0.0, (s, e) => s + e.units),
      );
    } catch (e) {
      debugPrint(' _loadSalesMix error: $e');
    }
  }

  // ── Load Peak Hours ────────────────────────────────────────────────────────
  Future<void> _loadPeakHours() async {
    try {
      final data = await _supabase.from('vw_peak_hours').select().order('hour_of_day');

      final hourly = List.generate(24, (h) {
        final row = data.firstWhere(
          (r) => (r['hour_of_day'] as num).toInt() == h,
          orElse: () => {
            'hour_of_day': h, 'hour_label': '${h.toString().padLeft(2, '0')}:00',
            'transaction_count': 0, 'revenue': 0, 'avg_transaction_value': 0, 'bundle_count': 0,
          },
        );
        final trxCount    = (row['transaction_count'] as num).toInt();
        final revenue     = (row['revenue'] as num).toDouble();
        final bundleCount = (row['bundle_count'] as num).toInt();
        return HourlyDensity(
          hour: h, label: row['hour_label'] as String,
          transactionCount:    trxCount,
          revenue:             revenue,
          avgTransactionValue: trxCount > 0 ? revenue / trxCount : 0,
          bundleCount:         bundleCount,
          bundlePct:           trxCount > 0 ? bundleCount / trxCount : 0,
        );
      });

      final peakEntry = hourly.reduce((a, b) => a.transactionCount >= b.transactionCount ? a : b);
      final peak1 = peakEntry.hour;
      final peak2 = hourly.where((h) => h.hour != peak1)
          .reduce((a, b) => a.transactionCount >= b.transactionCount ? a : b).hour;

      _peakHours = PeakHourResult(
        hourly: hourly, peakHour: peak1,
        peakTransactionCount: peakEntry.transactionCount,
        recommendation:
          'Tambah barista +1 jam ${peak1.toString().padLeft(2, '0')}:00–'
          '${(peak1 + 2).toString().padLeft(2, '0')}:00 dan '
          '${peak2.toString().padLeft(2, '0')}:00–'
          '${(peak2 + 2).toString().padLeft(2, '0')}:00.',
      );
    } catch (e) {
      debugPrint(' _loadPeakHours error: $e');
    }
  }

  // ── Load Bundle Analytics ──────────────────────────────────────────────────
  Future<void> _loadBundleAnalytics() async {
    try {
      final data = await _supabase
          .from('transactions')
          .select('id, has_book, has_cafe, grand_total')
          .eq('status', 'DONE')
          // [FIX-1] _todayStart() sudah UTC
          .gte('trx_at', _todayStart());

      final bundleData = await _supabase
          .from('bundle_analytics')
          .select('discount_given, book_revenue, cafe_revenue, transactions(trx_at)')
          .gte('recorded_at', _todayStart());

      final totalTransactions  = data.length;
      final bundleTransactions  = data.where((t) => t['has_book'] == true && t['has_cafe'] == true).length;
      final totalRevenue        = data.fold<double>(0, (s, t) => s + (t['grand_total'] as num).toDouble());
      final bundleRevenue       = bundleData.fold<double>(0, (s, b) =>
          s + (b['book_revenue'] as num).toDouble() + (b['cafe_revenue'] as num).toDouble());

      final pairData = await _supabase
          .from('bundle_analytics')
          .select('book_item_id, cafe_item_id, items!bundle_analytics_book_item_id_fkey(name), cafe:items!bundle_analytics_cafe_item_id_fkey(name)')
          .gte('recorded_at', _todayStart());

      final pairCounts = <String, int>{};
      for (final row in pairData) {
        final key = '${row['items']?['name'] ?? 'Book'} + ${row['cafe']?['name'] ?? 'Coffee'}';
        pairCounts[key] = (pairCounts[key] ?? 0) + 1;
      }

      _bundleAnalytics = calculateBundleAnalytics(
        totalTransactions:  totalTransactions,
        bundleTransactions: bundleTransactions,
        bundleRevenue:      bundleRevenue,
        totalRevenue:       totalRevenue,
        bundlePairCounts:   pairCounts,
      );
    } catch (e) {
      debugPrint(' _loadBundleAnalytics error: $e');
    }
  }

  // ── Load Inventory Alerts ──────────────────────────────────────────────────
  Future<void> _loadInventoryAlerts() async {
    try {
      final data = await _supabase.from('vw_inventory_aging').select();

      _inventoryAlerts = data.map<InventoryAging>((row) {
        final item = InventoryItem(
          id:            (row['id'] as num).toInt(),
          sku:           row['sku'] as String,
          name:          row['name'] as String,
          categoryCode:  row['category_code'] as String,
          stock:         (row['stock'] as num).toInt(),
          minStockAlert: (row['min_stock_alert'] as num).toInt(),
          costPrice:     (row['cost_price'] as num).toDouble(),
          sellingPrice:  (row['selling_price'] as num).toDouble(),
          lastSold:      row['last_sold'] != null ? DateTime.parse(row['last_sold']) : null,
          lastRestocked: row['last_restocked'] != null ? DateTime.parse(row['last_restocked']) : null,
          shelfLifeDays: row['shelf_life_days'] != null ? (row['shelf_life_days'] as num).toInt() : null,
          turnoverRate:  (row['turnover_rate'] as num).toDouble(),
        );

        final health = switch (row['stock_health'] as String) {
          'OUT_OF_STOCK'  => StockHealth.outOfStock,
          'EXPIRED_RISK'  => StockHealth.expiredRisk,
          'LOW_STOCK'     => StockHealth.lowStock,
          'SLOW_MOVER'    => StockHealth.slowMover,
          _               => StockHealth.healthy,
        };

        return InventoryAging(
          item:         item,
          health:       health,
          healthLabel:  switch (health) {
            StockHealth.outOfStock  => 'Habis',
            StockHealth.expiredRisk => 'Risiko Kadaluarsa',
            StockHealth.slowMover   => 'Slow Mover',
            StockHealth.lowStock    => 'Stok Rendah',
            StockHealth.healthy     => 'Normal',
          },
          urgencyScore: switch (health) {
            StockHealth.outOfStock  => 1.0,
            StockHealth.expiredRisk => 0.8,
            StockHealth.slowMover   => 0.5,
            StockHealth.lowStock    => 0.4,
            StockHealth.healthy     => 0.0,
          },
        );
      }).toList();
    } catch (e) {
      debugPrint(' _loadInventoryAlerts error: $e');
    }
  }

  // ── Load Recent Transactions ───────────────────────────────────────────────
  Future<void> _loadRecentTransactions() async {
    try {
      final data = await _supabase
          .from('transactions')
          .select('trx_code, grand_total, has_book, has_cafe, trx_at, transaction_details(qty, items(name_short, name))')
          .eq('status', 'DONE')
          .order('trx_at', ascending: false)
          .limit(5);

      _recentTransactions
        ..clear()
        ..addAll(data.map((t) {
          final details   = (t['transaction_details'] as List);
          final itemNames = details
              .map((d) => d['items']?['name_short'] ?? d['items']?['name'] ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ');
          final isBundle = t['has_book'] == true && t['has_cafe'] == true;
          // [FIX-4] .toLocal() agar waktu tampil sesuai WIB
          final trxAt    = DateTime.parse(t['trx_at']).toLocal();
          final diff     = DateTime.now().difference(trxAt);
          return {
            'code':   t['trx_code'],
            'type':   isBundle ? 'bundle' : (t['has_book'] == true ? 'book' : 'coffee'),
            'amount': t['grand_total'],
            'items':  itemNames,
            'time':   diff.inMinutes < 60 ? '${diff.inMinutes} menit lalu' : '${diff.inHours} jam lalu',
          };
        }));
    } catch (e) {
      debugPrint(' _loadRecentTransactions error: $e');
    }
  }

  // ── Load Orders & Visitors count ───────────────────────────────────────────
  Future<void> _loadOrdersAndVisitors() async {
    try {
      // Total orders = semua transaksi COMPLETED hari ini
      // [FIX-1] _todayStart() sekarang return UTC string yang benar
      final ordersData = await _supabase
          .from('transactions')
          .select('id')
          .eq('status', 'DONE')
          .gte('trx_at', _todayStart());
      _totalOrders = ordersData.length;

      // Total visitors = unique customer_id hari ini (fallback: sama dgn totalOrders)
      try {
        final visitorData = await _supabase
            .from('transactions')
            .select('customer_id')
            .eq('status', 'DONE')
            .gte('trx_at', _todayStart())
            .not('customer_id', 'is', null);
        final uniqueIds = visitorData
            .map((t) => t['customer_id'])
            .toSet()
            .length;
        _totalVisitors = uniqueIds > 0 ? uniqueIds : _totalOrders;
      } catch (e) {
        // Kolom customer_id mungkin tidak ada — fallback ke total orders
        debugPrint(' customer_id fallback: $e');
        _totalVisitors = _totalOrders;
      }
    } catch (e) {
      // [FIX-3] Jangan silent — log errornya!
      debugPrint(' _loadOrdersAndVisitors error: $e');
      _error = e.toString();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // [FIX-1] Midnight WIB → UTC untuk filter Supabase timestamptz
  String _todayStart() {
    final now = DateTime.now(); // local = WIB
    return DateTime(now.year, now.month, now.day)
        .toUtc()               // konversi ke UTC
        .toIso8601String();    // → "2026-05-05T17:00:00.000Z"
  }

  // _todayDate tetap local date string — untuk kolom tipe DATE (bukan TIMESTAMPTZ)
  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}