// =============================================================================
// MAKARYA HYBRID ERP — Ingredients Provider
// File: lib/providers/ingredients_provider.dart
// Handles: load bahan baku, restock, filter, alert status
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

enum IngredientStatus { habis, rendah, aman }

class Ingredient {
  final int       id;
  final String    name;
  final String    unit;
  final double    stock;
  final double    minStock;
  final String    category;
  final DateTime? lastRestocked;
  final int       usedInMenuCount;

  const Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
    required this.category,
    this.lastRestocked,
    this.usedInMenuCount = 0,
  });

  IngredientStatus get status {
    if (stock <= 0)          return IngredientStatus.habis;
    if (stock <= minStock)   return IngredientStatus.rendah;
    return IngredientStatus.aman;
  }

  bool get needsRestock => stock <= minStock;

  factory Ingredient.fromMap(Map<String, dynamic> m) => Ingredient(
    id:              m['id']              as int,
    name:            m['name']            as String,
    unit:            m['unit']            as String? ?? 'pcs',
    stock:           (m['stock']          as num).toDouble(),
    minStock:        (m['min_stock']      as num).toDouble(),
    category:        m['category']        as String? ?? 'UMUM',
    lastRestocked:   m['last_restocked'] != null
        ? DateTime.tryParse(m['last_restocked'] as String)
        : null,
    usedInMenuCount: (m['used_in_menu_count'] as num?)?.toInt() ?? 0,
  );

  // Optimistic update saat restock
  Ingredient withAddedStock(double qty) => Ingredient(
    id:              id,
    name:            name,
    unit:            unit,
    stock:           stock + qty,
    minStock:        minStock,
    category:        category,
    lastRestocked:   DateTime.now(),
    usedInMenuCount: usedInMenuCount,
  );
}

// ── Provider ───────────────────────────────────────────────────────────────────

class IngredientsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ── State ──────────────────────────────────────────────────────────────────
  bool    _loading = false;
  bool    get loading => _loading;

  String? _error;
  String? get error => _error;

  List<Ingredient> _all = [];

  String _search   = '';
  String get search => _search;

  String _category = 'SEMUA';
  String get selectedCategory => _category;

  // ── Computed ───────────────────────────────────────────────────────────────

  List<Ingredient> get all {
    // Sort: habis dulu → rendah → aman
    final sorted = [..._all];
    sorted.sort((a, b) => _statusPriority(a.status) - _statusPriority(b.status));
    return sorted;
  }

  List<Ingredient> get filtered {
    return all.where((ing) {
      final matchCat = _category == 'SEMUA' || ing.category == _category;
      final matchSearch = _search.isEmpty ||
          ing.name.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  List<Ingredient> get lowStockItems =>
      all.where((i) => i.needsRestock).toList();

  int get alertCount => lowStockItems.length;

  int _statusPriority(IngredientStatus s) => switch (s) {
    IngredientStatus.habis  => 0,
    IngredientStatus.rendah => 1,
    IngredientStatus.aman   => 2,
  };

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('vw_ingredients_status')
          .select()
          .order('category')
          .order('name');

      _all = (data as List)
          .map((m) => Ingredient.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Gagal memuat bahan: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  // ── Restock ────────────────────────────────────────────────────────────────

  Future<String> restock({
    required int    ingredientId,
    required double qtyAdd,
    required int    staffId,
  }) async {
    // Optimistic update dulu biar UI responsif
    final idx = _all.indexWhere((i) => i.id == ingredientId);
    if (idx >= 0) {
      _all[idx] = _all[idx].withAddedStock(qtyAdd);
      notifyListeners();
    }

    try {
      final result = await _supabase.rpc('restock_ingredient', params: {
        'p_ingredient_id': ingredientId,
        'p_qty_add':       qtyAdd,
        'p_staff_id':      staffId,
      });

      final res = result as Map<String, dynamic>;
      if (res['success'] == true) {
        await load(); // refresh dari server
        return 'ok';
      } else {
        // Rollback optimistic
        await load();
        return res['message'] as String? ?? 'Gagal restock';
      }
    } catch (e) {
      await load();
      return 'Error: $e';
    }
  }

  // ── Filter ─────────────────────────────────────────────────────────────────

  void setSearch(String q) {
    _search = q;
    notifyListeners();
  }

  void setCategory(String cat) {
    _category = cat;
    notifyListeners();
  }
}
