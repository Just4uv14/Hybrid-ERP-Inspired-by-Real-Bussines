// =============================================================================
// MAKARYA HYBRID ERP — Inventory Provider
// File: lib/providers/inventory_provider.dart
// Description  : Stock management state — load items, search, filter,
//                restock, and aging alerts.
// =============================================================================

import 'package:flutter/foundation.dart';
import '../logic/business_logic.dart';

class InventoryProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = false;
  bool get loading => _loading;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _selectedCategory = 'ALL';
  String get selectedCategory => _selectedCategory;

  List<InventoryItem> _allItems = [];
  List<InventoryAging> _agingResults = [];

  // Sorted entries: urgent first
  List<InventoryAging> get agingResults {
    final sorted = [..._agingResults];
    sorted.sort((a, b) => _healthPriority(a.health) - _healthPriority(b.health));
    return sorted;
  }

  int _healthPriority(StockHealth h) => switch (h) {
    StockHealth.outOfStock   => 0,
    StockHealth.expiredRisk  => 1,
    StockHealth.lowStock     => 2,
    StockHealth.slowMover    => 3,
    StockHealth.healthy      => 4,
  };

  // Filtered & searched
  List<InventoryAging> get filteredItems {
    return agingResults.where((a) {
      final matchCat = _selectedCategory == 'ALL' ||
          a.item.categoryCode == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          a.item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.item.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  List<InventoryAging> get alertItems =>
      agingResults.where((a) => a.health != StockHealth.healthy).toList();

  int get alertCount => alertItems.length;

  // Category stats
  Map<String, int> get categoryStock {
    final map = <String, int>{};
    for (final item in _allItems) {
      map[item.categoryCode] = (map[item.categoryCode] ?? 0) + item.stock;
    }
    return map;
  }

  double get totalStockValue =>
      _allItems.fold(0.0, (s, i) => s + i.stockValue);

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadItems() async {
    _loading = true;
    notifyListeners();

    // MOCK DATA — replace with sqflite/mysql_client query in production
    await Future.delayed(const Duration(milliseconds: 400));
    _allItems = _mockItems();
    _agingResults = classifyInventoryAging(_allItems);

    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadItems();

  // ── Mutations ──────────────────────────────────────────────────────────────

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String categoryCode) {
    _selectedCategory = categoryCode;
    notifyListeners();
  }

  /// Restock an item — adds qty to current stock
  void restock(int itemId, int addQty) {
    final idx = _allItems.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final old = _allItems[idx];
    _allItems[idx] = InventoryItem(
      id:             old.id,
      sku:            old.sku,
      name:           old.name,
      categoryCode:   old.categoryCode,
      stock:          old.stock + addQty,
      minStockAlert:  old.minStockAlert,
      costPrice:      old.costPrice,
      sellingPrice:   old.sellingPrice,
      lastSold:       old.lastSold,
      lastRestocked:  DateTime.now(),
      shelfLifeDays:  old.shelfLifeDays,
      turnoverRate:   old.turnoverRate,
    );
    _agingResults = classifyInventoryAging(_allItems);
    notifyListeners();
  }

  /// Reduce stock (sold via POS)
  void deductStock(int itemId, int qty) {
    final idx = _allItems.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final old = _allItems[idx];
    _allItems[idx] = InventoryItem(
      id:             old.id,
      sku:            old.sku,
      name:           old.name,
      categoryCode:   old.categoryCode,
      stock:          (old.stock - qty).clamp(0, 9999),
      minStockAlert:  old.minStockAlert,
      costPrice:      old.costPrice,
      sellingPrice:   old.sellingPrice,
      lastSold:       DateTime.now(),
      lastRestocked:  old.lastRestocked,
      shelfLifeDays:  old.shelfLifeDays,
      turnoverRate:   old.turnoverRate,
    );
    _agingResults = classifyInventoryAging(_allItems);
    notifyListeners();
  }

  // Lookup by SKU (for QR scanner)
  InventoryItem? findBySku(String sku) {
    try {
      return _allItems.firstWhere((i) => i.sku == sku);
    } catch (_) {
      return null;
    }
  }

  // ── Mock data (same as dashboard_provider for consistency) ─────────────────

  List<InventoryItem> _mockItems() => [
    InventoryItem(id: 1,  sku: 'C-MKSIG-001', name: 'Makarya Signature Espresso',  categoryCode: 'COFFEE', stock: 150, minStockAlert: 20,  costPrice: 9500,  sellingPrice: 32000,  lastSold: DateTime.now().subtract(const Duration(hours: 1)),    lastRestocked: DateTime.now().subtract(const Duration(days: 3)),  shelfLifeDays: 14, turnoverRate: 8.5),
    InventoryItem(id: 2,  sku: 'C-BSOAT-002', name: 'Brown Sugar Oat Latte',        categoryCode: 'COFFEE', stock: 80,  minStockAlert: 15,  costPrice: 15500, sellingPrice: 45000,  lastSold: DateTime.now().subtract(const Duration(minutes: 30)), lastRestocked: DateTime.now().subtract(const Duration(days: 5)),  shelfLifeDays: 14, turnoverRate: 6.2),
    InventoryItem(id: 3,  sku: 'C-V60GA-003', name: 'V60 Pour Over \u2014 Aceh Gayo', categoryCode: 'COFFEE', stock: 60,  minStockAlert: 10,  costPrice: 12000, sellingPrice: 38000,  lastSold: DateTime.now().subtract(const Duration(hours: 2)),    lastRestocked: DateTime.now().subtract(const Duration(days: 7)),  shelfLifeDays: 14, turnoverRate: 3.8),
    InventoryItem(id: 4,  sku: 'C-MATPR-004', name: 'Matcha Latte Premium',          categoryCode: 'COFFEE', stock: 70,  minStockAlert: 15,  costPrice: 14500, sellingPrice: 42000,  lastSold: DateTime.now().subtract(const Duration(minutes: 45)), lastRestocked: DateTime.now().subtract(const Duration(days: 4)),  shelfLifeDays: 10, turnoverRate: 5.1),
    InventoryItem(id: 5,  sku: 'C-TUBJA-005', name: 'Kopi Tubruk Jawa Klasik',       categoryCode: 'COFFEE', stock: 120, minStockAlert: 25,  costPrice: 6500,  sellingPrice: 22000,  lastSold: DateTime.now().subtract(const Duration(hours: 3)),    lastRestocked: DateTime.now().subtract(const Duration(days: 2)),  shelfLifeDays: 21, turnoverRate: 4.3),
    InventoryItem(id: 6,  sku: 'B-FILTE-001', name: 'Filosofi Teras',                categoryCode: 'BOOK',   stock: 45,  minStockAlert: 8,   costPrice: 59000, sellingPrice: 98000,  lastSold: DateTime.now().subtract(const Duration(hours: 2)),    lastRestocked: DateTime.now().subtract(const Duration(days: 10)), turnoverRate: 2.1),
    InventoryItem(id: 7,  sku: 'B-BUTRE-002', name: 'Bumi (Tere Liye)',              categoryCode: 'BOOK',   stock: 38,  minStockAlert: 10,  costPrice: 52000, sellingPrice: 89000,  lastSold: DateTime.now().subtract(const Duration(hours: 4)),    lastRestocked: DateTime.now().subtract(const Duration(days: 15)), turnoverRate: 1.8),
    InventoryItem(id: 8,  sku: 'B-SAPIE-003', name: 'Sapiens (ID)',                  categoryCode: 'BOOK',   stock: 22,  minStockAlert: 5,   costPrice: 88000, sellingPrice: 145000, lastSold: DateTime.now().subtract(const Duration(hours: 6)),    lastRestocked: DateTime.now().subtract(const Duration(days: 20)), turnoverRate: 1.2),
    InventoryItem(id: 9,  sku: 'B-ATHAT-004', name: 'Atomic Habits (ID)',            categoryCode: 'BOOK',   stock: 55,  minStockAlert: 10,  costPrice: 70000, sellingPrice: 115000, lastSold: DateTime.now().subtract(const Duration(hours: 1)),    lastRestocked: DateTime.now().subtract(const Duration(days: 8)),  turnoverRate: 2.8),
    InventoryItem(id: 10, sku: 'B-PULTR-005', name: 'Pulang (Tere Liye)',            categoryCode: 'BOOK',   stock: 18,  minStockAlert: 5,   costPrice: 48000, sellingPrice: 79000,  lastSold: DateTime.now().subtract(const Duration(days: 35)),   lastRestocked: DateTime.now().subtract(const Duration(days: 45)), turnoverRate: 0.2),
  ];
}