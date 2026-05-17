# MAKARYA HYBRID ERP SYSTEM
## Research-Grade Hybrid Business Intelligence Platform
### Bookstore + Coffee Shop · Inspired by Gramedia Matraman

---

## PROJECT STRUCTURE

```
makarya_erp/
│
├── 01_schema_ddl.sql          ← Full MySQL schema (16 tables + 5 views + 2 stored procs)
├── 02_mock_data.sql           ← Seed data: 5 coffees + 5 books + 10 transactions
├── pubspec.yaml               ← Flutter dependencies (fl_chart, mobile_scanner, etc.)
│
└── lib/
    ├── main.dart              ← App entry point + navigation shell
    │
    ├── theme/
    │   └── makarya_theme.dart ← Industrial dark theme + GlassPanel + MetricCard widgets
    │
    ├── logic/
    │   └── business_logic.dart ← All financial calculations (pure Dart, testable)
    │
    ├── providers/
    │   ├── dashboard_provider.dart  ← Real-time KPI state
    │   ├── cart_provider.dart       ← (implement: POS cart state)
    │   └── inventory_provider.dart  ← (implement: stock management state)
    │
    └── screens/
        ├── dashboard_screen.dart    ← (implement: KPI + charts)
        ├── pos_screen.dart          ← (implement: hybrid POS + scanner)
        ├── inventory_screen.dart    ← (implement: stock + aging)
        ├── analytics_screen.dart    ← (implement: deep analytics)
        └── expenses_screen.dart     ← (implement: OPEX management)
```

---

## DATABASE ARCHITECTURE

### 16 Core Tables:

| # | Table | Purpose |
|---|-------|---------|
| 1 | `categories` | BOOK/COFFEE/FOOD/MERCHANDISE lookup |
| 2 | `suppliers` | Publisher & coffee supplier master |
| 3 | `tax_profiles` | PPN 11%, PB1 10%, Service Charge configs |
| 4 | `staff` | Employee master + role/shift |
| 5 | `items` | Product catalog with HPP + margin calculation |
| 6 | `item_price_history` | Full price change audit trail |
| 7 | `customers` | Member + loyalty tracking |
| 8 | `transactions` | Transaction header (denormalized for speed) |
| 9 | `transaction_details` | Line items with **cost_at_time** (KEY FIELD) |
| 10 | `expense_categories` | OPEX type lookup |
| 11 | `expenses` | Operational cost entries |
| 12 | `wastage_logs` | F&B waste tracking (P&L deduction) |
| 13 | `stock_movements` | Complete inventory ledger |
| 14 | `stock_batches` | FIFO batch tracking for perishables |
| 15 | `bundle_rules` | Book+Coffee combo promotion rules |
| 16 | `bundle_analytics` | Cross-purchase behavior recording |

### 5 Analytical Views:
- `vw_daily_pnl` — Net Profit per day (includes wastage deduction)
- `vw_sales_mix` — Category revenue share %
- `vw_peak_hours` — Hourly transaction density (30-day rolling)
- `vw_inventory_aging` — Slow movers + freshness alerts
- `vw_product_profitability` — Per-product margin matrix

---

## NET PROFIT FORMULA

```
Net Profit = Gross Revenue
           − Total COGS         (Σ cost_at_time × qty per line item)
           − Operational Expenses (affects_profit = TRUE only)
           − Net Wastage Cost   (qty_wasted × cost_at_time − insurance_claim)
```

### Why `cost_at_time` matters:
If a coffee bean supplier raises prices mid-month, all **previous** transactions
still report the correct COGS (the cost at the time of sale), not the new price.
This ensures historical P&L accuracy — critical for research-grade reporting.

---

## SALES MIX CALCULATION

```dart
Sales Mix % (category) = Revenue(category) / Total Revenue × 100

// Example from mock data:
// COFFEE: Rp 847,000 / Rp 1,448,831 = 58.5%
// BOOK:   Rp 601,831 / Rp 1,448,831 = 41.5%
```

---

## INVENTORY AGING RULES

| Status | Trigger | Action |
|--------|---------|--------|
| `OUT_OF_STOCK` | stock == 0 | Immediate restock alert |
| `EXPIRED_RISK` | Coffee: days_since_restock ≥ shelf_life_days | Discard + wastage log |
| `SLOW_MOVER` | Book: last_sold > 30 days ago | Display reposition / discount |
| `LOW_STOCK` | stock ≤ min_stock_alert | Purchase order trigger |
| `HEALTHY` | All conditions pass | Normal |

---

## FLUTTER SCREENS TO IMPLEMENT

### Dashboard Screen
```dart
// Use DashboardProvider for all data
// Components:
// - 4x MetricCard (Net Revenue, Net Profit, Margin %, Bundle Rate)
// - SalesMixPieChart (fl_chart PieChart)
// - RevenueVsExpensesBarChart (fl_chart BarChart)
// - PeakHourLineChart (fl_chart LineChart)
// - InventoryAlertList (top urgent items)
// - RecentTransactionsFeed
```

### POS Screen
```dart
// Components:
// - CategoryTabBar (COFFEE | BOOK | FOOD)
// - MenuGridView (tap to add to cart)
// - QRScannerButton → MobileScanner → lookup by qr_payload
// - CartPanel (live totals, discount input)
// - PaymentMethodSelector (CASH | QRIS | DEBIT | CREDIT)
// - PrintReceiptButton → esc_pos_printer
```

### Analytics Screen
```dart
// Deep analytics:
// - Date range picker
// - Profitability Matrix table (vw_product_profitability)
// - Bundle Analytics card (rate, uplift, top pairs)
// - Export to PDF (pdf package)
```

---

## HARDWARE PLUGINS

### QR Scanner (mobile_scanner)
```dart
MobileScanner(
  onDetect: (capture) {
    final barcode = capture.barcodes.first;
    final payload = jsonDecode(barcode.rawValue ?? '{}');
    cartProvider.addItemBySku(payload['sku']);
  },
)
```

### Thermal Printer (esc_pos_printer_plus)
```dart
final printer = NetworkPrinter(PaperSize.mm80, profile);
await printer.connect(printerIp, port: 9100);
final receipt = formatReceiptText(receiptData); // from business_logic.dart
printer.text(receipt, styles: PosStyles(align: PosAlign.left));
printer.cut();
printer.disconnect();
```

---

## RESEARCH METRICS (For Academic Paper)

| Metric | Data Source | Formula |
|--------|------------|---------|
| Bundle Rate | bundle_analytics | bundles / total_trx |
| Revenue Uplift | bundle_analytics | (avg_bundle_val - avg_solo_val) / avg_solo_val |
| Gross Margin | transaction_details | (sell - cost_at_time) / sell |
| Net Margin | vw_daily_pnl | net_profit / gross_revenue |
| Inventory Turnover | stock_movements | COGS / avg_inventory_value |
| Wastage Rate | wastage_logs | total_waste_cost / gross_revenue |

---

## AUTHOR NOTES

- All Dart calculations are **pure functions** (no side effects) — fully unit-testable
- Mock data in `02_mock_data.sql` simulates realistic Jakarta cafe patterns
- `cost_at_time` in `transaction_details` is the academic "granular constraint" field
- The `is_bundle` generated column in `transactions` enables zero-cost analytics
- `vw_daily_pnl` view encapsulates the full P&L formula for dashboard queries

**Version**: 2.0.0 Research Grade  
**Target**: Academic Research on Hybrid Business Operational Efficiency  
**Inspiration**: Makarya Gramedia Matraman, Jakarta
