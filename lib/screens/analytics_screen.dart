// =============================================================================
// MAKARYA HYBRID ERP — Analytics Screen (UPDATED)
// File: lib/screens/analytics_screen.dart
//
// NEW FEATURES:
//   ① Period filter (Hari Ini / 7 Hari / 30 Hari / Custom)
//   ② Grafik tren 30 hari (revenue + profit)
//   ③ Profitability matrix per SKU
//   ④ Export PDF laporan keuangan lengkap
//   ⑤ Best Seller — ranking produk terlaris by unit / revenue / margin
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../logic/business_logic.dart';
import '../logic/pdf_service.dart';
import '../theme/makarya_theme.dart';
import 'financial_report_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _pdfExporting = false;
  late TabController _mainTabCtrl;
  String _skuSort       = 'revenue'; // 'revenue' | 'margin' | 'units'
  String _bestSellerSort = 'units';  // 'units' | 'revenue' | 'margin'
  int    _bestSellerLimit = 5;        // 5 | 10

  @override
  void initState() {
    super.initState();
    _mainTabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(DashboardProvider dash) async {
    setState(() => _pdfExporting = true);
    try {
      final pnl = dash.filteredPnl ?? dash.todayPnl;
      if (pnl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data P&L untuk diekspor.'),
              backgroundColor: MakaryaColors.lossRed),
        );
        return;
      }
      final bytes = await generateFinancialReportPdf(
        pnl:         pnl,
        skuList:     dash.skuProfitability,
        trendData:   dash.trendData,
        periodLabel: dash.selectedPeriod.label,
      );
      await sharePdf(bytes, fileName: 'Laporan_Makarya_${dash.selectedPeriod.label}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export PDF: $e'), backgroundColor: MakaryaColors.lossRed),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfExporting = false);
    }
  }

  Future<void> _pickCustomRange(DashboardProvider dash) async {
    final now   = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate:   DateTime(now.year - 1),
      lastDate:    now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end:   now,
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   MakaryaColors.woodBrown,
            onPrimary: Colors.white,
            surface:   MakaryaColors.surface01,
            onSurface: MakaryaColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      await dash.setPeriod(PeriodFilter.custom,
          customStart: range.start, customEnd: range.end);
    }
  }

  List<SkuProfitability> _sortedSkus(List<SkuProfitability> skus) {
    final list = List<SkuProfitability>.from(skus);
    switch (_skuSort) {
      case 'margin':
        list.sort((a, b) => b.grossMarginPct.compareTo(a.grossMarginPct));
      case 'units':
        list.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
      default:
        list.sort((a, b) => b.revenue.compareTo(a.revenue));
    }
    return list;
  }

  List<SkuProfitability> _sortedBestSellers(List<SkuProfitability> skus) {
    final list = List<SkuProfitability>.from(skus);
    switch (_bestSellerSort) {
      case 'revenue':
        list.sort((a, b) => b.revenue.compareTo(a.revenue));
      case 'margin':
        list.sort((a, b) => b.grossMarginPct.compareTo(a.grossMarginPct));
      default: // 'units'
        list.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));
    }
    return list.take(_bestSellerLimit).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar utama ──────────────────────────────────────────────────
        Container(
          color: MakaryaColors.surface01,
          child: TabBar(
            controller: _mainTabCtrl,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 14),
                    SizedBox(width: 6),
                    Text('Analitik'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 14),
                    SizedBox(width: 6),
                    Text('Laporan'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Tab content ────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _mainTabCtrl,
            children: [
              // Tab 1: Analitik (konten lama)
              Consumer<DashboardProvider>(
                builder: (context, dash, _) {
                  if (dash.loading) {
                    return const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown));
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PeriodFilterBar(
                          selected:   dash.selectedPeriod,
                          onSelected: (p) async {
                            if (p == PeriodFilter.custom) {
                              await _pickCustomRange(dash);
                            } else {
                              await dash.setPeriod(p);
                            }
                          },
                          onExportPdf:  () => _exportPdf(dash),
                          pdfExporting: _pdfExporting,
                        ),
                        const SizedBox(height: 16),
                        if (dash.filteredPnl != null)
                          _FilteredPnlSummary(pnl: dash.filteredPnl!),
                        const SizedBox(height: 16),
                        _TrendChartCard(dash: dash),
                        const SizedBox(height: 16),
                        _PnlBreakdownCard(pnl: dash.todayPnl),
                        const SizedBox(height: 16),
                        _SkuMatrixCard(
                          skus:    _sortedSkus(dash.skuProfitability),
                          loading: dash.skuLoading,
                          sortKey: _skuSort,
                          onSort:  (k) => setState(() => _skuSort = k),
                        ),
                        const SizedBox(height: 16),
                        _BestSellerCard(
                          skus:          _sortedBestSellers(dash.skuProfitability),
                          loading:       dash.skuLoading,
                          sortKey:       _bestSellerSort,
                          limit:         _bestSellerLimit,
                          onSort:        (k) => setState(() => _bestSellerSort = k),
                          onLimitChange: (l) => setState(() => _bestSellerLimit = l),
                        ),
                        const SizedBox(height: 16),
                        _BundleAnalyticsCard(bundle: dash.bundleAnalytics),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),

              // Tab 2: Laporan Keuangan
              const FinancialReportScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── ① Period Filter Bar ────────────────────────────────────────────────────────

class _PeriodFilterBar extends StatelessWidget {
  final PeriodFilter selected;
  final ValueChanged<PeriodFilter> onSelected;
  final VoidCallback onExportPdf;
  final bool pdfExporting;

  const _PeriodFilterBar({
    required this.selected, required this.onSelected,
    required this.onExportPdf, required this.pdfExporting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PeriodFilter.values.map((p) {
                final isActive = p == selected;
                return GestureDetector(
                  onTap: () => onSelected(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive ? MakaryaColors.woodBrown.withValues(alpha: 0.25) : MakaryaColors.surface02,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? MakaryaColors.woodBrown : MakaryaColors.woodBrown.withValues(alpha: 0.15),
                        width: isActive ? 1 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p == PeriodFilter.custom)
                          const Icon(Icons.date_range_rounded, size: 12, color: MakaryaColors.woodLight),
                        if (p == PeriodFilter.custom) const SizedBox(width: 4),
                        Text(p.label, style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? MakaryaColors.woodLight : MakaryaColors.textSecondary,
                          fontFamily: 'Inter',
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // PDF Export button
        GestureDetector(
          onTap: pdfExporting ? null : onExportPdf,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: MakaryaColors.goldAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MakaryaColors.goldAccent.withValues(alpha: 0.4), width: 0.5),
            ),
            child: pdfExporting
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MakaryaColors.goldAccent))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 14, color: MakaryaColors.goldAccent),
                      SizedBox(width: 4),
                      Text('PDF', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: MakaryaColors.goldAccent, fontFamily: 'Inter')),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Filtered PnL Summary ───────────────────────────────────────────────────────

class _FilteredPnlSummary extends StatelessWidget {
  final ProfitabilityResult pnl;
  const _FilteredPnlSummary({required this.pnl});

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(label: 'Revenue',    value: _rp(pnl.netRevenue),  color: MakaryaColors.goldAccent),
        const SizedBox(width: 10),
        _Chip(label: 'Net Profit', value: _rp(pnl.netProfit),
            color: pnl.netProfit >= 0 ? MakaryaColors.profitGreen : MakaryaColors.lossRed),
        const SizedBox(width: 10),
        _Chip(label: 'Margin',
            value: '${(pnl.netMarginPct * 100).toStringAsFixed(1)}%',
            color: pnl.netMarginPct >= 0.18 ? MakaryaColors.profitGreen : MakaryaColors.warningAmber),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontFamily: 'Inter')),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter'),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

// ── ② Trend Chart Card ─────────────────────────────────────────────────────────

class _TrendChartCard extends StatefulWidget {
  final DashboardProvider dash;
  const _TrendChartCard({required this.dash});

  @override
  State<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<_TrendChartCard> {
  bool _showProfit = false;

  @override
  Widget build(BuildContext context) {
    final dash   = widget.dash;
    final data   = dash.trendData;
    final isLoad = dash.trendLoading;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(title: 'Tren 30 Hari', subtitle: 'Revenue & profit harian'),
              ),
              // Toggle revenue / profit
              GestureDetector(
                onTap: () => setState(() => _showProfit = !_showProfit),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showProfit
                        ? MakaryaColors.profitGreen.withValues(alpha: 0.15)
                        : MakaryaColors.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showProfit ? MakaryaColors.profitGreen : MakaryaColors.goldAccent,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    _showProfit ? 'Profit' : 'Revenue',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter',
                      color: _showProfit ? MakaryaColors.profitGreen : MakaryaColors.goldAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh trend
              GestureDetector(
                onTap: () => dash.loadTrend30Days(),
                child: const Icon(Icons.refresh_rounded, size: 18, color: MakaryaColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoad)
            const SizedBox(height: 160,
                child: Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown, strokeWidth: 2)))
          else if (data.isEmpty)
            const SizedBox(height: 100,
                child: Center(child: Text('Belum ada data tren.',
                    style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter', fontSize: 12))))
          else
            _buildChart(data),
        ],
      ),
    );
  }

  Widget _buildChart(List<DailyTrendPoint> data) {
    final values = _showProfit ? data.map((d) => d.netProfit).toList() : data.map((d) => d.revenue).toList();
    final maxY   = values.reduce((a, b) => a > b ? a : b);
    final minY   = values.reduce((a, b) => a < b ? a : b);
    final color  = _showProfit ? MakaryaColors.profitGreen : MakaryaColors.goldAccent;

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: (minY * 0.9).clamp(0, double.infinity),
              maxY: maxY > 0 ? maxY * 1.15 : 100,
              lineBarsData: [
                LineChartBarData(
                  spots: data.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.netProfit < 0 && !_showProfit ? 0 : values[e.key])).toList(),
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.08),
                  ),
                  dotData: FlDotData(show: false),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval:   6,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      final d = data[idx].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${d.day}/${d.month}',
                            style: const TextStyle(fontSize: 9, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (_) => FlLine(color: MakaryaColors.woodBrown.withValues(alpha: 0.1), strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.x.toInt();
                    final d   = idx < data.length ? data[idx] : null;
                    return LineTooltipItem(
                      d != null ? '${d.date.day}/${d.date.month}\n${_rp(s.y)}' : _rp(s.y),
                      const TextStyle(fontSize: 10, color: Colors.white, fontFamily: 'Inter'),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Summary row
        Row(
          children: [
            _TrendStat(label: 'Total', value: _rp(values.fold(0.0, (s, v) => s + v)), color: color),
            _TrendStat(label: 'Terbaik', value: _rp(maxY), color: color),
            _TrendStat(label: 'Rata-rata', value: _rp(values.fold(0.0, (s, v) => s + v) / values.length), color: color),
          ],
        ),
      ],
    );
  }

  String _rp(double v) => v < 0
      ? '- Rp ${(-v).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}'
      : 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

class _TrendStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TrendStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter'),
            overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      ],
    ),
  );
}

// ── ③ SKU Profitability Matrix ─────────────────────────────────────────────────

class _SkuMatrixCard extends StatelessWidget {
  final List<SkuProfitability> skus;
  final bool loading;
  final String sortKey;
  final ValueChanged<String> onSort;

  const _SkuMatrixCard({
    required this.skus, required this.loading,
    required this.sortKey, required this.onSort,
  });

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(title: 'Profitability per SKU', subtitle: 'Matrix kontribusi produk'),
              ),
              // Sort selector
              _SortChip(label: 'Revenue', active: sortKey == 'revenue', onTap: () => onSort('revenue')),
              const SizedBox(width: 6),
              _SortChip(label: 'Margin',  active: sortKey == 'margin',  onTap: () => onSort('margin')),
              const SizedBox(width: 6),
              _SortChip(label: 'Units',   active: sortKey == 'units',   onTap: () => onSort('units')),
            ],
          ),
          const SizedBox(height: 16),

          if (loading)
            const SizedBox(height: 100,
                child: Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown, strokeWidth: 2)))
          else if (skus.isEmpty)
            const Text('Tidak ada data SKU untuk periode ini.',
                style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter', fontSize: 12))
          else ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _TableHeader('Produk')),
                  Expanded(flex: 2, child: _TableHeader('Revenue', align: TextAlign.right)),
                  Expanded(flex: 2, child: _TableHeader('Gross Profit', align: TextAlign.right)),
                  Expanded(flex: 1, child: _TableHeader('Margin', align: TextAlign.right)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Table rows
            ...skus.take(15).map((sku) {
              final marginColor = sku.grossMarginPct >= 0.4
                  ? MakaryaColors.profitGreen
                  : sku.grossMarginPct >= 0.2
                      ? MakaryaColors.warningAmber
                      : MakaryaColors.lossRed;
              final catColor = switch (sku.categoryCode) {
                'COFFEE' => MakaryaColors.woodBrown,
                'BOOK'   => MakaryaColors.infoBlue,
                'FOOD'   => MakaryaColors.woodLight,
                _        => MakaryaColors.concreteGrey,
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: MakaryaColors.surface02,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sku.name, style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                                    overflow: TextOverflow.ellipsis),
                                Text('${sku.unitsSold} unit  ·  ${(sku.revenueContributionPct * 100).toStringAsFixed(1)}% share',
                                    style: const TextStyle(
                                        fontSize: 9, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_rp(sku.revenue),
                          style: const TextStyle(fontSize: 10, color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                          textAlign: TextAlign.right),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(_rp(sku.grossProfit),
                          style: TextStyle(fontSize: 10, color: marginColor, fontFamily: 'Inter', fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: marginColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${(sku.grossMarginPct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                color: marginColor, fontFamily: 'Inter'),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (skus.length > 15)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('+${skus.length - 15} produk lainnya — export PDF untuk data lengkap',
                    style: const TextStyle(fontSize: 10, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
              ),
          ],
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? MakaryaColors.woodBrown.withValues(alpha: 0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: active ? 0.6 : 0.2), width: 0.5),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 9, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? MakaryaColors.woodLight : MakaryaColors.textMuted, fontFamily: 'Inter')),
    ),
  );
}

class _TableHeader extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _TableHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
          color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
      textAlign: align);
}

// ── P&L Breakdown (unchanged, kept) ──────────────────────────────────────────

class _PnlBreakdownCard extends StatelessWidget {
  final ProfitabilityResult? pnl;
  const _PnlBreakdownCard({this.pnl});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Laporan P&L', subtitle: 'Profit & Loss hari ini'),
          const SizedBox(height: 16),
          if (pnl == null)
            const Text('Tidak ada data', style: TextStyle(color: MakaryaColors.textMuted))
          else
            ...pnl!.toDisplayMap().entries.map((e) => _PnlRow(label: e.key, value: e.value)),
        ],
      ),
    );
  }
}

class _PnlRow extends StatelessWidget {
  final String label, value;
  const _PnlRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isTotal  = label == 'NET PROFIT';
    final isDeduct = value.startsWith('-');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isTotal ? MakaryaColors.surface02 : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: isTotal ? MakaryaColors.textPrimary : MakaryaColors.textSecondary,
              fontFamily: 'Inter')),
          const Spacer(),
          Text(value, style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: isTotal
                  ? (value.startsWith('-') ? MakaryaColors.lossRed : MakaryaColors.profitGreen)
                  : isDeduct
                      ? MakaryaColors.lossRed
                      : MakaryaColors.textPrimary,
              fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

// ── Bundle Analytics (unchanged, kept) ───────────────────────────────────────

class _BundleAnalyticsCard extends StatelessWidget {
  final BundleAnalyticsResult? bundle;
  const _BundleAnalyticsCard({this.bundle});

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Bundle Analytics', subtitle: 'Book + Coffee performance'),
          const SizedBox(height: 16),
          if (bundle == null)
            const Text('Tidak ada data', style: TextStyle(color: MakaryaColors.textMuted))
          else ...[
            Wrap(
              spacing: 10, runSpacing: 10,
              children: [
                _MetricChip(label: 'Bundle Rate',    value: bundle!.bundleRateFormatted, color: MakaryaColors.infoBlue),
                _MetricChip(label: 'Avg Bundle',     value: _rp(bundle!.avgBundleValue),    color: MakaryaColors.goldAccent),
                _MetricChip(label: 'Avg Non-Bundle', value: _rp(bundle!.avgNonBundleValue), color: MakaryaColors.concreteGrey),
                _MetricChip(
                  label: 'Revenue Uplift',
                  value: '${(bundle!.revenueUplift * 100).toStringAsFixed(1)}%',
                  color: bundle!.revenueUplift >= 0 ? MakaryaColors.profitGreen : MakaryaColors.lossRed,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: BarChart(BarChartData(
                maxY: [bundle!.avgBundleValue, bundle!.avgNonBundleValue].reduce((a, b) => a > b ? a : b) * 1.3,
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: bundle!.avgBundleValue, color: MakaryaColors.goldAccent, width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: bundle!.avgNonBundleValue, color: MakaryaColors.woodBrown.withValues(alpha: 0.6), width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                  ]),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        v == 0 ? 'Bundle' : 'Non-Bundle',
                        // ── Poin 3: font lebih besar + warna lebih terang ──
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MakaryaColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  )),
                  leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
              )),
            ),
            const SizedBox(height: 16),
            const Text('Top Bundle Pairs:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            ...bundle!.topBundlePairs.entries.take(3).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: MakaryaColors.goldAccent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, color: MakaryaColors.textPrimary, fontFamily: 'Inter'))),
                  Text('${e.value}×', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MakaryaColors.goldAccent, fontFamily: 'Inter')),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
      ],
    ),
  );
}

// ── ④ Best Seller Card ─────────────────────────────────────────────────────────

class _BestSellerCard extends StatelessWidget {
  final List<SkuProfitability> skus;
  final bool loading;
  final String sortKey;
  final int limit;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onLimitChange;

  const _BestSellerCard({
    required this.skus,
    required this.loading,
    required this.sortKey,
    required this.limit,
    required this.onSort,
    required this.onLimitChange,
  });

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _sortLabel(String key) => switch (key) {
    'revenue' => 'Revenue',
    'margin'  => 'Margin',
    _         => 'Terjual',
  };

  @override
  Widget build(BuildContext context) {
    // Nilai max untuk progress bar — ambil dari item pertama (sudah sorted)
    final maxVal = skus.isEmpty ? 1.0 : switch (sortKey) {
      'revenue' => skus.first.revenue,
      'margin'  => skus.first.grossMarginPct,
      _         => skus.first.unitsSold.toDouble(),
    };

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Best Seller',
                  subtitle: 'Produk terlaris periode ini',
                ),
              ),
              // Sort chips
              _SortChip(label: 'Terjual', active: sortKey == 'units',   onTap: () => onSort('units')),
              const SizedBox(width: 6),
              _SortChip(label: 'Revenue', active: sortKey == 'revenue', onTap: () => onSort('revenue')),
              const SizedBox(width: 6),
              _SortChip(label: 'Margin',  active: sortKey == 'margin',  onTap: () => onSort('margin')),
            ],
          ),
          const SizedBox(height: 16),

          // ── Content ──────────────────────────────────────────────────────────
          if (loading)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(
                  color: MakaryaColors.woodBrown, strokeWidth: 2)),
            )
          else if (skus.isEmpty)
            const Text(
              'Tidak ada data untuk periode ini.',
              style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter', fontSize: 12),
            )
          else ...[
            ...skus.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final sku  = entry.value;

              // Nilai & warna progress bar sesuai sort key
              final barValue = switch (sortKey) {
                'revenue' => sku.revenue,
                'margin'  => sku.grossMarginPct,
                _         => sku.unitsSold.toDouble(),
              };
              final barPct = maxVal > 0 ? (barValue / maxVal).clamp(0.0, 1.0) : 0.0;

              // Label nilai utama
              final mainLabel = switch (sortKey) {
                'revenue' => _rp(sku.revenue),
                'margin'  => '${(sku.grossMarginPct * 100).toStringAsFixed(1)}%',
                _         => '${sku.unitsSold} unit',
              };

              // Warna badge rank
              final rankColor = switch (rank) {
                1 => const Color(0xFFFFD700), // gold
                2 => const Color(0xFFC0C0C0), // silver
                3 => const Color(0xFFCD7F32), // bronze
                _ => MakaryaColors.concreteGrey,
              };

              // Warna dot kategori
              final catColor = switch (sku.categoryCode) {
                'COFFEE' => MakaryaColors.woodBrown,
                'BOOK'   => MakaryaColors.infoBlue,
                'FOOD'   => MakaryaColors.woodLight,
                _        => MakaryaColors.concreteGrey,
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? rankColor.withValues(alpha: 0.06)
                      : MakaryaColors.surface02,
                  borderRadius: BorderRadius.circular(10),
                  border: rank <= 3
                      ? Border.all(color: rankColor.withValues(alpha: 0.25), width: 0.5)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: rank <= 3 ? 0.2 : 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              rank <= 3 ? ['🥇','🥈','🥉'][rank - 1] : '$rank',
                              style: TextStyle(
                                fontSize: rank <= 3 ? 13 : 10,
                                fontWeight: FontWeight.w700,
                                color: rankColor,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Nama produk + meta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 5, height: 5,
                                    decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      sku.name,
                                      style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: MakaryaColors.textPrimary, fontFamily: 'Inter',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${sku.unitsSold} unit  ·  ${_rp(sku.revenue)}  ·  '
                                '${(sku.grossMarginPct * 100).toStringAsFixed(0)}% margin',
                                style: const TextStyle(
                                  fontSize: 9, color: MakaryaColors.textMuted, fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nilai utama (sesuai sort key)
                        Text(
                          mainLabel,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: rank <= 3 ? rankColor : MakaryaColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),

                    // Progress bar
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barPct,
                        minHeight: 4,
                        backgroundColor: MakaryaColors.woodBrown.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rank <= 3 ? rankColor : MakaryaColors.woodBrown.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Limit toggle (Top 5 / Top 10) ─────────────────────────────────
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LimitChip(label: 'Top 5',  active: limit == 5,  onTap: () => onLimitChange(5)),
                const SizedBox(width: 8),
                _LimitChip(label: 'Top 10', active: limit == 10, onTap: () => onLimitChange(10)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LimitChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: active ? MakaryaColors.woodBrown.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MakaryaColors.woodBrown.withValues(alpha: active ? 0.5 : 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? MakaryaColors.woodLight : MakaryaColors.textMuted,
          fontFamily: 'Inter',
        ),
      ),
    ),
  );
}