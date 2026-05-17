// =============================================================================
// MAKARYA HYBRID ERP — Business Logic Engine (FIXED)
// File: lib/logic/business_logic.dart
//
// FIXES APPLIED:
//   Fix ②a — SalesMixEntry: added missing `units` field to class body
//   Fix ②b — SalesMixEntry: constructor now lists all required named params
//   Fix ③  — InventoryAging: added `recommendation` getter (was missing field)
//             inventory_screen.dart called aging.recommendation → undefined
// =============================================================================

import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class TransactionLineItem {
  final int itemId;
  final String categoryCode;
  final double qty;
  final double unitSellPrice;
  final double costAtTime;
  final double unitDiscount;
  final double modifierCost;

  const TransactionLineItem({
    required this.itemId,
    required this.categoryCode,
    required this.qty,
    required this.unitSellPrice,
    required this.costAtTime,
    this.unitDiscount = 0.0,
    this.modifierCost = 0.0,
  });

  double get effectiveSellPrice => unitSellPrice - unitDiscount + modifierCost;
  double get lineSubtotal       => qty * effectiveSellPrice;
  double get lineCogs           => qty * costAtTime;
  double get lineGrossProfit    => lineSubtotal - lineCogs;
  double get lineMarginPct      =>
      effectiveSellPrice > 0 ? lineGrossProfit / lineSubtotal : 0.0;
}

class ExpenseEntry {
  final int id;
  final String categoryCode;
  final double amount;
  final DateTime date;
  final bool affectsProfit;

  const ExpenseEntry({
    required this.id,
    required this.categoryCode,
    required this.amount,
    required this.date,
    this.affectsProfit = true,
  });
}

class WastageEntry {
  final int itemId;
  final double qtyWasted;
  final double costAtTime;
  final DateTime wastedAt;
  final WasteType wasteType;
  final double insuranceClaim;

  const WastageEntry({
    required this.itemId,
    required this.qtyWasted,
    required this.costAtTime,
    required this.wastedAt,
    required this.wasteType,
    this.insuranceClaim = 0.0,
  });

  double get grossWasteCost => qtyWasted * costAtTime;
  double get netWasteCost   => grossWasteCost - insuranceClaim;
}

enum WasteType { spilled, expired, damaged, overPrepared, qualityReject, theft, other }

class TaxConfig {
  final double ppnRate;
  final double serviceRate;
  final double pb1Rate;
  final bool taxIncluded;

  const TaxConfig({
    this.ppnRate     = 0.11,
    this.serviceRate = 0.0,
    this.pb1Rate     = 0.0,
    this.taxIncluded = false,
  });

  double get totalTaxRate => ppnRate + serviceRate + pb1Rate;
}

class InventoryItem {
  final int id;
  final String sku;
  final String name;
  final String categoryCode;
  final int stock;
  final int minStockAlert;
  final double costPrice;
  final double sellingPrice;
  final DateTime? lastSold;
  final DateTime? lastRestocked;
  final int? shelfLifeDays;
  final double turnoverRate;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.categoryCode,
    required this.stock,
    required this.minStockAlert,
    required this.costPrice,
    required this.sellingPrice,
    this.lastSold,
    this.lastRestocked,
    this.shelfLifeDays,
    this.turnoverRate = 0.0,
  });

  int get daysSinceLastSale =>
      lastSold != null ? DateTime.now().difference(lastSold!).inDays : 9999;

  int get daysSinceRestock =>
      lastRestocked != null ? DateTime.now().difference(lastRestocked!).inDays : 0;

  double get stockValue  => stock * costPrice;
  double get daysOfStock =>
      turnoverRate > 0 ? stock / turnoverRate : double.infinity;
}

// ─────────────────────────────────────────────────────────────────────────────
// NET PROFIT ENGINE
// ─────────────────────────────────────────────────────────────────────────────

class ProfitabilityResult {
  final double grossRevenue;
  final double totalDiscounts;
  final double netRevenue;
  final double totalCogs;
  final double grossProfit;
  final double grossMarginPct;
  final double totalOpex;
  final double totalWastage;
  final double totalTax;
  final double netProfit;
  final double netMarginPct;
  final Map<String, double> revenueByCategory;
  final Map<String, double> cogsByCategory;
  final Map<String, double> grossProfitByCategory;

  const ProfitabilityResult({
    required this.grossRevenue,
    required this.totalDiscounts,
    required this.netRevenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.totalOpex,
    required this.totalWastage,
    required this.totalTax,
    required this.netProfit,
    required this.netMarginPct,
    required this.revenueByCategory,
    required this.cogsByCategory,
    required this.grossProfitByCategory,
  });

  bool get isProfitable => netProfit > 0;

  Map<String, String> toDisplayMap() => {
    'Gross Revenue':    'Rp ${_fmt(grossRevenue)}',
    'Total Discounts':  '- Rp ${_fmt(totalDiscounts)}',
    'Net Revenue':      'Rp ${_fmt(netRevenue)}',
    '─ COGS':          '- Rp ${_fmt(totalCogs)}',
    'Gross Profit':     'Rp ${_fmt(grossProfit)}',
    'Gross Margin':     '${(grossMarginPct * 100).toStringAsFixed(1)}%',
    '─ OPEX':          '- Rp ${_fmt(totalOpex)}',
    '─ Wastage':       '- Rp ${_fmt(totalWastage)}',
    'NET PROFIT':       'Rp ${_fmt(netProfit)}',
    'Net Margin':       '${(netMarginPct * 100).toStringAsFixed(1)}%',
  };

  static String _fmt(double v) =>
      v.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

/// Net Profit = Gross Revenue − COGS − OPEX − Net Wastage
ProfitabilityResult calculateNetProfit({
  required List<TransactionLineItem> lineItems,
  required List<ExpenseEntry> expenses,
  required List<WastageEntry> wastageEntries,
  required TaxConfig taxConfig,
}) {
  final grossRevenue   = lineItems.fold(0.0, (s, li) => s + li.lineSubtotal);
  final totalDiscounts = lineItems.fold(0.0, (s, li) => s + (li.unitDiscount * li.qty));
  final netRevenue     = grossRevenue - totalDiscounts;
  final totalCogs      = lineItems.fold(0.0, (s, li) => s + li.lineCogs);
  final grossProfit    = netRevenue - totalCogs;
  final grossMarginPct = netRevenue > 0 ? grossProfit / netRevenue : 0.0;
  final totalOpex      = expenses
      .where((e) => e.affectsProfit)
      .fold(0.0, (s, e) => s + e.amount);
  final totalWastage   = wastageEntries.fold(0.0, (s, w) => s + w.netWasteCost);
  final totalTax       = netRevenue * taxConfig.ppnRate / (1 + taxConfig.ppnRate);
  final netProfit      = grossProfit - totalOpex - totalWastage;
  final netMarginPct   = grossRevenue > 0 ? netProfit / grossRevenue : 0.0;

  final revenueByCategory  = <String, double>{};
  final cogsByCategory     = <String, double>{};
  final profitByCategory   = <String, double>{};

  for (final li in lineItems) {
    revenueByCategory[li.categoryCode] =
        (revenueByCategory[li.categoryCode] ?? 0) + li.lineSubtotal;
    cogsByCategory[li.categoryCode] =
        (cogsByCategory[li.categoryCode] ?? 0) + li.lineCogs;
    profitByCategory[li.categoryCode] =
        (profitByCategory[li.categoryCode] ?? 0) + li.lineGrossProfit;
  }

  return ProfitabilityResult(
    grossRevenue:          grossRevenue,
    totalDiscounts:        totalDiscounts,
    netRevenue:            netRevenue,
    totalCogs:             totalCogs,
    grossProfit:           grossProfit,
    grossMarginPct:        grossMarginPct,
    totalOpex:             totalOpex,
    totalWastage:          totalWastage,
    totalTax:              totalTax,
    netProfit:             netProfit,
    netMarginPct:          netMarginPct,
    revenueByCategory:     revenueByCategory,
    cogsByCategory:        cogsByCategory,
    grossProfitByCategory: profitByCategory,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SALES MIX CALCULATOR
// ─────────────────────────────────────────────────────────────────────────────

// ── FIX ②a & ②b ──────────────────────────────────────────────────────────────
// Before: class SalesMixEntry had no `units` field declared, and constructor
//         was missing `this.units` in its parameter list → 2 compile errors.
// After: `units` field added to class body; constructor requires it.
class SalesMixEntry {
  final String categoryCode;
  final String label;
  final String colorHex;
  final double revenue;
  final double units;        // ← FIX ②a: field was missing from class body
  final double cogs;
  final double grossProfit;

  const SalesMixEntry({
    required this.categoryCode,
    required this.label,
    required this.colorHex,
    required this.revenue,
    required this.units,     
    required this.cogs,
    required this.grossProfit,
  });

  double revenuePct(double total) => total > 0 ? revenue / total : 0.0;
  double get marginPct            => revenue > 0 ? grossProfit / revenue : 0.0;
}

class SalesMixResult {
  final List<SalesMixEntry> entries;
  final double totalRevenue;
  final double totalUnits;

  const SalesMixResult({
    required this.entries,
    required this.totalRevenue,
    required this.totalUnits,
  });

  Map<String, double> get revenueShareMap => {
    for (final e in entries)
      e.categoryCode: e.revenuePct(totalRevenue),
  };

  List<Map<String, dynamic>> toPieChartData() => entries
      .where((e) => e.revenue > 0)
      .map((e) => {
            'category': e.categoryCode,
            'label':    e.label,
            'value':    e.revenue,
            'pct':      e.revenuePct(totalRevenue) * 100,
            'color':    e.colorHex,
            'margin':   e.marginPct * 100,
          })
      .toList();
}

SalesMixResult calculateSalesMix(
  List<TransactionLineItem> items, {
  Map<String, String>? categoryLabels,
  Map<String, String>? categoryColors,
}) {
  final grouped = <String, List<TransactionLineItem>>{};
  for (final item in items) {
    grouped.putIfAbsent(item.categoryCode, () => []).add(item);
  }

  final entries = grouped.entries.map((entry) {
    final cat    = entry.key;
    final lines  = entry.value;
    final rev    = lines.fold(0.0, (s, l) => s + l.lineSubtotal);
    final units  = lines.fold(0.0, (s, l) => s + l.qty);
    final cogs   = lines.fold(0.0, (s, l) => s + l.lineCogs);
    final profit = lines.fold(0.0, (s, l) => s + l.lineGrossProfit);

    return SalesMixEntry(
      categoryCode: cat,
      label:        categoryLabels?[cat] ?? cat,
      colorHex:     categoryColors?[cat] ?? '#A9A9A9',
      revenue:      rev,
      units:        units,   // ← now correctly passed
      cogs:         cogs,
      grossProfit:  profit,
    );
  }).toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  final totalRevenue = entries.fold(0.0, (s, e) => s + e.revenue);
  final totalUnits   = entries.fold(0.0, (s, e) => s + e.units);

  return SalesMixResult(
    entries:      entries,
    totalRevenue: totalRevenue,
    totalUnits:   totalUnits,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INVENTORY AGING CLASSIFIER
// ─────────────────────────────────────────────────────────────────────────────

enum StockHealth { outOfStock, lowStock, slowMover, expiredRisk, healthy }

class InventoryAging {
  final InventoryItem item;
  final StockHealth health;
  final String healthLabel;
  final String? alertMessage;
  final double urgencyScore;

  const InventoryAging({
    required this.item,
    required this.health,
    required this.healthLabel,
    this.alertMessage,
    required this.urgencyScore,
  });

  // ── FIX ③ ─────────────────────────────────────────────────────────────────
  // inventory_screen.dart called `aging.recommendation` but the field didn't
  // exist. Added as a computed getter that returns the human-readable action
  // recommendation for each health status.
  String get recommendation {
    switch (health) {
      case StockHealth.outOfStock:
        return 'Stok habis — buat purchase order segera ke supplier.';
      case StockHealth.expiredRisk:
        return 'Catat ke wastage log, jangan gunakan untuk produksi.';
      case StockHealth.slowMover:
        return 'Reposisi display, beri diskon 10–15%, atau bundle dengan kopi.';
      case StockHealth.lowStock:
        return 'Segera restok ke min. ${item.minStockAlert * 3} unit.';
      case StockHealth.healthy:
        return 'Stok normal. Pantau turnover rate.';
    }
  }
}

List<InventoryAging> classifyInventoryAging(List<InventoryItem> items) {
  return items.map((item) {
    final daysSinceSale    = item.daysSinceLastSale;
    final daysSinceRestock = item.daysSinceRestock;
    final shelfLife        = item.shelfLifeDays;

    if (item.stock == 0) {
      return InventoryAging(
        item:         item,
        health:       StockHealth.outOfStock,
        healthLabel:  'Habis',
        alertMessage: 'Stok ${item.name} HABIS — segera restok!',
        urgencyScore: 1.0,
      );
    }

    if (item.categoryCode != 'BOOK' &&
        shelfLife != null &&
        daysSinceRestock >= shelfLife) {
      final overdueDays = daysSinceRestock - shelfLife;
      return InventoryAging(
        item:         item,
        health:       StockHealth.expiredRisk,
        healthLabel:  'Risiko Kadaluarsa',
        alertMessage: '${item.name} melewati shelf life ${shelfLife}h '
            '(${overdueDays}h terlambat!)',
        urgencyScore: math.min(1.0, 0.7 + (overdueDays / shelfLife) * 0.3),
      );
    }

    if (item.categoryCode == 'BOOK' && daysSinceSale > 30) {
      return InventoryAging(
        item:         item,
        health:       StockHealth.slowMover,
        healthLabel:  'Slow Mover',
        alertMessage: '${item.name} belum terjual $daysSinceSale hari. '
            'Pertimbangkan diskon/display ulang.',
        urgencyScore: math.min(0.9, 0.4 + ((daysSinceSale - 30) / 90) * 0.5),
      );
    }

    if (item.stock <= item.minStockAlert) {
      return InventoryAging(
        item:         item,
        health:       StockHealth.lowStock,
        healthLabel:  'Stok Rendah',
        alertMessage: '${item.name}: ${item.stock} unit tersisa '
            '(min: ${item.minStockAlert})',
        urgencyScore: 0.3 + (1.0 - (item.stock / item.minStockAlert)) * 0.3,
      );
    }

    return InventoryAging(
      item:         item,
      health:       StockHealth.healthy,
      healthLabel:  'Normal',
      urgencyScore: 0.0,
    );
  }).toList()
    ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));
}

// ─────────────────────────────────────────────────────────────────────────────
// PEAK HOUR ANALYTICS
// ─────────────────────────────────────────────────────────────────────────────

class HourlyDensity {
  final int hour;
  final String label;
  final int transactionCount;
  final double revenue;
  final double avgTransactionValue;
  final int bundleCount;
  final double bundlePct;

  const HourlyDensity({
    required this.hour,
    required this.label,
    required this.transactionCount,
    required this.revenue,
    required this.avgTransactionValue,
    required this.bundleCount,
    required this.bundlePct,
  });
}

class PeakHourResult {
  final List<HourlyDensity> hourly;
  final int peakHour;
  final int peakTransactionCount;
  final String recommendation;

  const PeakHourResult({
    required this.hourly,
    required this.peakHour,
    required this.peakTransactionCount,
    required this.recommendation,
  });
}

PeakHourResult calculatePeakHours(
  List<({DateTime timestamp, double revenue, bool isBundle})> transactions,
) {
  final buckets = List.generate(
      24, (_) => <({double revenue, bool isBundle})>[]);

  for (final trx in transactions) {
    buckets[trx.timestamp.hour].add(
        (revenue: trx.revenue, isBundle: trx.isBundle));
  }

  final hourly = List.generate(24, (h) {
    final bucket      = buckets[h];
    final bundleCount = bucket.where((t) => t.isBundle).length;
    final revenue     = bucket.fold(0.0, (s, t) => s + t.revenue);
    return HourlyDensity(
      hour:                h,
      label:               '${h.toString().padLeft(2, '0')}:00',
      transactionCount:    bucket.length,
      revenue:             revenue,
      avgTransactionValue: bucket.isEmpty ? 0 : revenue / bucket.length,
      bundleCount:         bundleCount,
      bundlePct: bucket.isEmpty ? 0 : bundleCount / bucket.length,
    );
  });

  final peakEntry = hourly.reduce(
      (a, b) => a.transactionCount >= b.transactionCount ? a : b);
  final peak1 = peakEntry.hour;
  final peak2 = hourly
      .where((h) => h.hour != peak1)
      .reduce((a, b) => a.transactionCount >= b.transactionCount ? a : b)
      .hour;

  return PeakHourResult(
    hourly:               hourly,
    peakHour:             peak1,
    peakTransactionCount: peakEntry.transactionCount,
    recommendation:
        'Tambah barista +1 jam ${peak1.toString().padLeft(2, '0')}:00–'
        '${(peak1 + 2).toString().padLeft(2, '0')}:00 dan '
        '${peak2.toString().padLeft(2, '0')}:00–'
        '${(peak2 + 2).toString().padLeft(2, '0')}:00.',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BUNDLE ANALYTICS
// ─────────────────────────────────────────────────────────────────────────────

class BundleAnalyticsResult {
  final int totalTransactions;
  final int bundleTransactions;
  final double bundleRate;
  final double bundleRevenue;
  final double nonBundleRevenue;
  final double avgBundleValue;
  final double avgNonBundleValue;
  final double revenueUplift;
  final Map<String, int> topBundlePairs;

  const BundleAnalyticsResult({
    required this.totalTransactions,
    required this.bundleTransactions,
    required this.bundleRate,
    required this.bundleRevenue,
    required this.nonBundleRevenue,
    required this.avgBundleValue,
    required this.avgNonBundleValue,
    required this.revenueUplift,
    required this.topBundlePairs,
  });

  String get bundleRateFormatted =>
      '${(bundleRate * 100).toStringAsFixed(1)}%';
}

BundleAnalyticsResult calculateBundleAnalytics({
  required int totalTransactions,
  required int bundleTransactions,
  required double bundleRevenue,
  required double totalRevenue,
  required Map<String, int> bundlePairCounts,
}) {
  final bundleRate       = totalTransactions > 0
      ? bundleTransactions / totalTransactions : 0.0;
  final nonBundleRevenue = totalRevenue - bundleRevenue;
  final avgBundleValue   = bundleTransactions > 0
      ? bundleRevenue / bundleTransactions : 0.0;
  final nonBundleCount   = totalTransactions - bundleTransactions;
  final avgNonBundle     = nonBundleCount > 0
      ? nonBundleRevenue / nonBundleCount : 0.0;
  final revenueUplift    = avgNonBundle > 0
      ? (avgBundleValue - avgNonBundle) / avgNonBundle : 0.0;

  final sortedPairs = Map.fromEntries(
    bundlePairCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)),
  );

  return BundleAnalyticsResult(
    totalTransactions:  totalTransactions,
    bundleTransactions: bundleTransactions,
    bundleRate:         bundleRate,
    bundleRevenue:      bundleRevenue,
    nonBundleRevenue:   nonBundleRevenue,
    avgBundleValue:     avgBundleValue,
    avgNonBundleValue:  avgNonBundle,
    revenueUplift:      revenueUplift,
    topBundlePairs:     sortedPairs,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RECEIPT FORMATTER (ESC/POS)
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptData {
  final String trxCode;
  final String storeName;
  final String storeAddress;
  final String staffName;
  final DateTime trxAt;
  final List<TransactionLineItem> items;
  final Map<int, String> itemNames;
  final double discountAmount;
  final TaxConfig taxConfig;
  final String paymentMethod;
  final double? cashTendered;
  final double? changeGiven;
  final String? bundlePromoLabel;

  const ReceiptData({
    required this.trxCode,
    required this.storeName,
    required this.storeAddress,
    required this.staffName,
    required this.trxAt,
    required this.items,
    required this.itemNames,
    required this.taxConfig,
    required this.paymentMethod,
    this.discountAmount   = 0,
    this.cashTendered,
    this.changeGiven,
    this.bundlePromoLabel,
  });
}

String formatReceiptText(ReceiptData data) {
  final buf = StringBuffer();
  const w   = 32;

  void line([String s = '']) => buf.writeln(s);
  void center(String s) =>
      buf.writeln(s.padLeft((w + s.length) ~/ 2).padRight(w));
  void divider([String c = '-']) => buf.writeln(c * w);
  void row(String left, String right) {
    final space = w - left.length - right.length;
    buf.writeln('$left${' ' * math.max(1, space)}$right');
  }

  line();
  center(data.storeName.toUpperCase());
  center(data.storeAddress);
  divider('═');
  row('No:', data.trxCode);
  row('Kasir:', data.staffName);
  row('Waktu:',
      '${data.trxAt.day}/${data.trxAt.month}/${data.trxAt.year} '
      '${data.trxAt.hour.toString().padLeft(2, '0')}:'
      '${data.trxAt.minute.toString().padLeft(2, '0')}');
  divider();

  double subtotal = 0;
  for (final item in data.items) {
    final name  = data.itemNames[item.itemId] ?? 'Item';
    final price = item.lineSubtotal;
    subtotal   += price;
    buf.writeln(name.substring(0, math.min(name.length, 22)));
    row('  ${item.qty.toInt()}x Rp ${_fmt(item.effectiveSellPrice)}',
        'Rp ${_fmt(price)}');
  }

  divider();
  row('Subtotal', 'Rp ${_fmt(subtotal)}');

  if (data.discountAmount > 0) {
    row(
      'Diskon${data.bundlePromoLabel != null ? " (${data.bundlePromoLabel})" : ""}',
      '- Rp ${_fmt(data.discountAmount)}',
    );
  }

  final taxable     = subtotal - data.discountAmount;
  final ppnAmt      = taxable * data.taxConfig.ppnRate;
  final serviceAmt  = taxable * data.taxConfig.serviceRate;
  final pb1Amt      = taxable * data.taxConfig.pb1Rate;

  if (ppnAmt > 0) {
    row('PPN ${(data.taxConfig.ppnRate * 100).toStringAsFixed(0)}%',
        'Rp ${_fmt(ppnAmt)}');
  }
  if (serviceAmt > 0) {
    row('Service ${(data.taxConfig.serviceRate * 100).toStringAsFixed(0)}%',
        'Rp ${_fmt(serviceAmt)}');
  }
  if (pb1Amt > 0) {
    row('PB1 ${(data.taxConfig.pb1Rate * 100).toStringAsFixed(0)}%',
        'Rp ${_fmt(pb1Amt)}');
  }

  final grandTotal = taxable + ppnAmt + serviceAmt + pb1Amt;
  divider('═');
  row('TOTAL', 'Rp ${_fmt(grandTotal)}');
  row('Bayar (${data.paymentMethod})',
      data.cashTendered != null ? 'Rp ${_fmt(data.cashTendered!)}' : '-');
  if ((data.changeGiven ?? 0) > 0) {
    row('Kembali', 'Rp ${_fmt(data.changeGiven!)}');
  }

  divider();
  center('PPN Reg: 02.123.456.7-890.000');
  center('Terima kasih — Makarya Gramedia');
  line();

  return buf.toString();
}

String _fmt(double v) => v.abs().toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );