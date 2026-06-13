// =============================================================================
// MAKARYA HYBRID ERP — Dashboard Screen (Glassmorphism Refactored)
// File: lib/screens/dashboard_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../logic/business_logic.dart';
import '../theme/makarya_theme.dart';
import '../widgets/glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().initialize();
    });
  }

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await context.read<DashboardProvider>().refresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dash, _) {
        if (dash.loading) {
          return const Center(
            child: CircularProgressIndicator(color: MakaryaColors.woodBrown),
          );
        }
        return RefreshIndicator(
          color: MakaryaColors.woodBrown,
          backgroundColor: MakaryaColors.surface01,
          onRefresh: dash.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DashboardHeader(
                    dash: dash,
                    onRefresh: _handleRefresh,
                    refreshing: _refreshing,
                  ),
                  const SizedBox(height: 24),
                  _KpiRow(pnl: dash.todayPnl, dash: dash),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (_, c) {
                    final isWide = c.maxWidth > 580;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _RevenueChartCard(trendData: dash.trendData),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: _SalesByCategoryCard(mix: dash.salesMix),
                          ),
                        ],
                      );
                    }
                    return Column(children: [
                      _RevenueChartCard(trendData: dash.trendData),
                      const SizedBox(height: 16),
                      _SalesByCategoryCard(mix: dash.salesMix),
                    ]);
                  }),
                  const SizedBox(height: 20),
                  _OrdersCustomersRow(dash: dash),
                  const SizedBox(height: 8),
                ],
              ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final DashboardProvider dash;
  final VoidCallback       onRefresh;
  final bool               refreshing;
  const _DashboardHeader({
    required this.dash,
    required this.onRefresh,
    required this.refreshing,
  });

  String _greetingEmoji() {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️';
    if (h < 17) return '👋';
    return '🌙';
  }

  String _formattedDate() {
    const days   = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final now    = DateTime.now();
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final session  = context.watch<AuthProvider>().session;
    final firstName = session?.fullName.split(' ').first ?? 'User';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $firstName! ${_greetingEmoji()}',
                style: TextStyle(
                  fontSize:     26,
                  fontWeight:   FontWeight.w800,
                  color:        MakaryaColors.textPrimary,
                  fontFamily:   'Inter',
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ini yang terjadi di toko kamu hari ini.',
                style: TextStyle(
                  fontSize:   13,
                  color:      MakaryaColors.textSecondary.withValues(alpha: 0.9),
                  fontFamily: 'Inter',
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Refresh data',
          child: GestureDetector(
            onTap: refreshing ? null : onRefresh,
            child: AnimatedRotation(
              turns:    refreshing ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: GlassContainer(
                borderRadius: 10,
                blurSigma: 8,
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.refresh_rounded,
                  size:  17,
                  color: refreshing
                      ? MakaryaColors.woodBrown
                      : MakaryaColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formattedDate(),
              style: const TextStyle(
                fontSize:     12,
                fontWeight:   FontWeight.w500,
                color:        MakaryaColors.textSecondary,
                fontFamily:   'Inter',
              ),
            ),
            const SizedBox(height: 6),
            _PeriodChip(dash: dash),
          ],
        ),
      ],
    );
  }
}

// ── Period filter chip ────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final DashboardProvider dash;
  const _PeriodChip({required this.dash});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPeriodSheet(context, dash),
      child: GlassContainer(
        borderRadius: 20,
        blurSigma: 8,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dash.selectedPeriod.label,
              style: const TextStyle(
                fontSize:     12,
                fontWeight:   FontWeight.w600,
                color:        MakaryaColors.textSecondary,
                fontFamily:   'Inter',
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: MakaryaColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showPeriodSheet(BuildContext ctx, DashboardProvider dash) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: MakaryaColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Periode',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
            const SizedBox(height: 12),
            ...PeriodFilter.values.where((p) => p != PeriodFilter.custom).map((p) {
              final selected = dash.selectedPeriod == p;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Inter',
                      color: selected ? MakaryaColors.textPrimary : MakaryaColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    )),
                trailing: selected
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: MakaryaColors.textPrimary)
                    : null,
                onTap: () {
                  dash.setPeriod(p);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI ROW  (GlassCard-based metric cards)
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final ProfitabilityResult? pnl;
  final DashboardProvider    dash;
  const _KpiRow({this.pnl, required this.dash});

  String _rp(double v) => 'Rp ' + v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.') ;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    final net    = pnl?.netRevenue ?? 0;
    final profit = pnl?.netProfit  ?? 0;
    final totalOrders    = dash.totalOrders;
    final totalVisitors  = dash.totalVisitors;

    final cards = [
      _GlassMetricCard(
        label:    'Total Revenue',
        value:    _rp(net),
        icon:     Icons.attach_money_rounded,
        trend:    '+2.6%',
        trendUp:  true,
        subtitle: 'Bulan ini vs lalu',
        isHero:   true,
        ambientColor: Colors.teal,
      ),
      _GlassMetricCard(
        label:    'Total Orders',
        value:    '$totalOrders',
        icon:     Icons.receipt_long_rounded,
        trend:    '+1.8%',
        trendUp:  true,
        subtitle: 'Bulan ini vs lalu',
      ),
      _GlassMetricCard(
        label:    'Total Visitors',
        value:    '$totalVisitors',
        icon:     Icons.people_alt_rounded,
        trend:    '+2.8%',
        trendUp:  true,
        subtitle: 'Bulan ini vs lalu',
      ),
      _GlassMetricCard(
        label:    'Net Profit',
        value:    _rp(profit),
        icon:     Icons.trending_up_rounded,
        trend:    profit >= 0 ? '+5.0%' : '-1.2%',
        trendUp:  profit >= 0,
        subtitle: 'Setelah OPEX & waste',
        ambientColor: Colors.orange,
      ),
    ];

    // ── RESPONSIVE LAYOUT ─────────────────────────────────────────
    if (isMobile || isTablet) {
      final gap = isMobile ? 12.0 : 16.0;
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              SizedBox(width: gap),
              Expanded(child: cards[1]),
            ],
          ),
          SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[2]),
              SizedBox(width: gap),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    // Desktop: 4 column row
    return Row(
      children: cards.asMap().entries.map((e) {
        final isLast = e.key == cards.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 24),
            child: e.value,
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS METRIC CARD  (replaces legacy MetricCard on this screen)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassMetricCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final String   trend;
  final bool     trendUp;
  final String   subtitle;
  final bool     isHero;
  final Color?   ambientColor;

  const _GlassMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.trend,
    required this.trendUp,
    required this.subtitle,
    this.isHero = false,
    this.ambientColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurSigma: 10,
      tintColor: isHero ? ambientColor : null,
      padding: const EdgeInsets.all(24),
      borderSide: ambientColor != null 
          ? BorderSide(color: ambientColor!.withValues(alpha: isHero ? 0.30 : 0.15), width: 1.2)
          : null,
      boxShadow: ambientColor != null 
          ? [
              BoxShadow(
                color: ambientColor!.withValues(alpha: isHero ? 0.12 : 0.04),
                blurRadius: isHero ? 32 : 24,
                offset: Offset(0, isHero ? 12 : 8),
                spreadRadius: -4,
              )
            ] 
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      MakaryaColors.textMuted,
                  fontFamily: 'Inter',
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MakaryaColors.iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MakaryaColors.iconBorder,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size:  18,
                  color: MakaryaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize:   isHero ? 34 : 28,
              fontWeight: isHero ? FontWeight.w800 : (ambientColor != null ? FontWeight.w700 : FontWeight.w600),
              color:      Colors.white,
              fontFamily: 'Inter',
              height:     1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size:  14,
                color: trendUp ? MakaryaColors.profitGreen : MakaryaColors.lossRed,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  color:      trendUp ? MakaryaColors.profitGreen : MakaryaColors.lossRed,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize:   11,
                    color:      MakaryaColors.textMuted,
                    fontFamily: 'Inter',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVENUE BAR CHART
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueChartCard extends StatelessWidget {
  final List<DailyTrendPoint> trendData;
  const _RevenueChartCard({required this.trendData});

  @override
  Widget build(BuildContext context) {
    final points = trendData.length > 8
        ? trendData.sublist(trendData.length - 8)
        : trendData;

    final maxY = points.isEmpty
        ? 100000.0
        : points.map((p) => p.revenue).reduce((a, b) => a > b ? a : b) * 1.2;

    return GlassCard(
      blurSigma: 10,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text(
              'Revenue',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      MakaryaColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MakaryaColors.glassBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MakaryaColors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: const Text(
                'Bulan ini vs lalu',
                style: TextStyle(
                  fontSize:   10,
                  color:      MakaryaColors.textSecondary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.open_in_new_rounded,
                size: 16, color: MakaryaColors.textMuted.withValues(alpha: 0.5)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: points.isEmpty
                ? const Center(
                    child: Text('Belum ada data trend',
                        style: TextStyle(
                            color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) =>
                              MakaryaColors.surface02.withValues(alpha: 0.95),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final p = points[group.x];
                            final label = p.date.day.toString() + '/' + p.date.month.toString();
                            final val = rod.toY >= 1000000
                                ? (rod.toY / 1000000).toStringAsFixed(1) + 'jt'
                                : (rod.toY / 1000).toStringAsFixed(0) + 'rb';
                            return BarTooltipItem(
                              label + '\nRp ' + val,
                              const TextStyle(
                                  color: MakaryaColors.textPrimary,
                                  fontSize: 10,
                                  fontFamily: 'Inter'),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles:   true,
                            reservedSize: 24,
                            getTitlesWidget: (v, meta) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  points[idx].date.day.toString() + ' ' + _monthShort(points[idx].date.month),
                                  style: const TextStyle(
                                      fontSize:   9,
                                      color:      MakaryaColors.textMuted,
                                      fontFamily: 'Inter'),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles:   true,
                            reservedSize: 44,
                            getTitlesWidget: (v, meta) {
                              if (v == 0) return const SizedBox.shrink();
                              final label = v >= 1000000
                                  ? (v / 1000000).toStringAsFixed(0) + 'jt'
                                  : v >= 1000
                                      ? (v / 1000).toStringAsFixed(0) + 'rb'
                                      : v.toInt().toString();
                              return Text(
                                label,
                                style: const TextStyle(
                                    fontSize:   9,
                                    color:      MakaryaColors.textMuted,
                                    fontFamily: 'Inter'),
                              );
                            },
                          ),
                        ),
                        topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show:             true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color:       Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1.0,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: points.asMap().entries.map((e) {
                        final isLast = e.key == points.length - 1;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.revenue,
                              gradient: LinearGradient(
                                colors: isLast
                                    ? [
                                        MakaryaColors.woodBrown,
                                        MakaryaColors.woodBrown.withValues(alpha: 0.3),
                                      ]
                                    : [
                                        MakaryaColors.woodBrown.withValues(alpha: 0.6),
                                        MakaryaColors.woodBrown.withValues(alpha: 0.15),
                                      ],
                                begin: Alignment.topCenter,
                                end:   Alignment.bottomCenter,
                              ),
                              width:        16,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _monthShort(int m) {
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALES BY CATEGORY
// ─────────────────────────────────────────────────────────────────────────────

class _SalesByCategoryCard extends StatefulWidget {
  final SalesMixResult? mix;
  const _SalesByCategoryCard({this.mix});
  @override
  State<_SalesByCategoryCard> createState() => _SalesByCategoryCardState();
}

class _SalesByCategoryCardState extends State<_SalesByCategoryCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final mix = widget.mix;

    return GlassCard(
      blurSigma: 10,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text(
              'Sales by Category',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      MakaryaColors.textPrimary,
                fontFamily: 'Inter',
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MakaryaColors.glassBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MakaryaColors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: const Text(
                'Bulan ini vs lalu',
                style: TextStyle(
                  fontSize:   10,
                  color:      MakaryaColors.textSecondary,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          if (mix == null || mix.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Tidak ada data',
                    style: TextStyle(
                        color: MakaryaColors.textMuted, fontFamily: 'Inter')),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: Row(children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace:    3,
                      centerSpaceRadius: 42,
                      pieTouchData: PieTouchData(
                        touchCallback: (ev, res) {
                          setState(() {
                            _touched =
                                (ev.isInterestedForInteractions &&
                                        res?.touchedSection != null)
                                    ? res!.touchedSection!.touchedSectionIndex
                                    : -1;
                          });
                        },
                      ),
                      sections: mix.entries.asMap().entries.map((e) {
                        final i         = e.key;
                        final cat       = e.value;
                        final color     = _categoryColor(cat.categoryCode);
                        final isTouched = i == _touched;
                        final pct = cat.revenuePct(mix.totalRevenue) * 100;
                        return PieChartSectionData(
                          value:     pct,
                          color:     color,
                          radius:    isTouched ? 62 : 50,
                          showTitle: isTouched,
                          title:     pct.toStringAsFixed(0) + '%',
                          titleStyle: const TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white,
                            fontFamily: 'Inter',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: mix.entries.map((cat) {
                    final pct   = cat.revenuePct(mix.totalRevenue) * 100;
                    final color = _categoryColor(cat.categoryCode);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color:  color,
                            shape:  BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.label,
                              style: const TextStyle(
                                fontSize:   11,
                                color:      MakaryaColors.textSecondary,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              pct.toStringAsFixed(0) + '%',
                              style: TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w700,
                                color:      color,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Color _categoryColor(String code) => switch (code) {
    'COFFEE' => MakaryaColors.woodBrown,
    'BOOK'   => MakaryaColors.concreteGrey,
    'FOOD'   => MakaryaColors.woodLight,
    'MERCH'  => MakaryaColors.categoryMerch,
    _        => MakaryaColors.infoBlue,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDERS & CUSTOMERS ROW  (Responsive: stacks on mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersCustomersRow extends StatelessWidget {
  final DashboardProvider dash;
  const _OrdersCustomersRow({required this.dash});

  @override
  Widget build(BuildContext context) {
    final orders    = dash.totalOrders;
    final customers = dash.totalVisitors;
    final isMobile  = Responsive.isMobile(context);

    final ordersCard = GlassCard(
      blurSigma: 10,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: MakaryaColors.iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MakaryaColors.iconBorder,
                width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 18,
              color: MakaryaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                orders.toString(),
                style: const TextStyle(
                  fontSize:   32,
                  fontWeight: FontWeight.w800,
                  color:      MakaryaColors.textPrimary,
                  fontFamily: 'Inter',
                  height:     1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'orders',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    color:      MakaryaColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HighlightedText(
            text:      dash.alertCount.toString() + ' pesanan menunggu konfirmasi.',
            highlight: dash.alertCount.toString() + ' pesanan',
            color:     MakaryaColors.lossRed,
          ),
        ],
      ),
    );

    final customersCard = GlassCard(
      blurSigma: 10,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: MakaryaColors.iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MakaryaColors.iconBorder,
                width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 18,
              color: MakaryaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                customers.toString(),
                style: const TextStyle(
                  fontSize:   32,
                  fontWeight: FontWeight.w800,
                  color:      MakaryaColors.textPrimary,
                  fontFamily: 'Inter',
                  height:     1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'customers',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    color:      MakaryaColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HighlightedText(
            text:      customers.toString() + ' customers menunggu respons.',
            highlight: customers.toString() + ' customers',
            color:     MakaryaColors.lossRed,
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ordersCard,
          const SizedBox(height: 16),
          customersCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: ordersCard),
        const SizedBox(width: 16),
        Expanded(child: customersCard),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HIGHLIGHTED TEXT helper
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String highlight;
  final Color  color;

  const _HighlightedText({
    required this.text,
    required this.highlight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final idx = text.indexOf(highlight);
    if (idx < 0) {
      return Text(text,
          style: const TextStyle(
              fontSize: 12, color: MakaryaColors.textSecondary, fontFamily: 'Inter'));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 12, color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text:  highlight,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text.substring(idx + highlight.length)),
        ],
      ),
    );
  }
}
