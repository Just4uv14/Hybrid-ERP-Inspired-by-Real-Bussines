// =============================================================================
// MAKARYA HYBRID ERP — Inventory Screen (Updated)
// File: lib/screens/inventory_screen.dart
//
// CHANGES:
//   - Tambah TabBar: "Menu" (existing) + "Bahan Baku" (new)
//   - Tab Bahan: list ingredients dengan alert stok rendah + tombol restock
//   - Restock hanya bisa dilakukan barista, kasir, & manager
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/ingredients_provider.dart';
import '../providers/auth_provider.dart';
import '../logic/business_logic.dart';
import '../theme/makarya_theme.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // ── Tab bar header ──────────────────────────────────────────────────
          Consumer<IngredientsProvider>(
            builder: (_, ing, __) => Container(
              color: MakaryaColors.surface01,
              child: TabBar(
                labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize:   13,
                    fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize:   13,
                    fontWeight: FontWeight.w400),
                labelColor:         MakaryaColors.woodLight,
                unselectedLabelColor: MakaryaColors.textMuted,
                indicatorColor:     MakaryaColors.woodBrown,
                indicatorWeight:    2.5,
                tabs: [
                  const Tab(text: 'Menu'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Bahan Baku'),
                        if (ing.alertCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: MakaryaColors.lossRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${ing.alertCount}',
                                style: const TextStyle(
                                    fontSize:   10,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.white,
                                    fontFamily: 'Inter')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────────────
          const Expanded(
            child: TabBarView(
              children: [
                _MenuTab(),
                _IngredientsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 1: MENU (existing inventory — tidak banyak berubah)
// =============================================================================

class _MenuTab extends StatelessWidget {
  const _MenuTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, inv, _) {
        if (inv.loading) {
          return const Center(
              child: CircularProgressIndicator(color: MakaryaColors.woodBrown));
        }
        return Column(children: [
          _MenuTopBar(inv: inv),
          Expanded(
            child: RefreshIndicator(
              color:     MakaryaColors.woodBrown,
              onRefresh: inv.refresh,
              child: inv.filteredItems.isEmpty
                  ? const Center(
                      child: Text('Tidak ada item ditemukan',
                          style: TextStyle(
                              color: MakaryaColors.textMuted, fontFamily: 'Inter')))
                  : ListView.builder(
                      padding:   const EdgeInsets.all(12),
                      itemCount: inv.filteredItems.length,
                      itemBuilder: (_, i) =>
                          _InventoryRow(aging: inv.filteredItems[i]),
                    ),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Menu tab top bar ──────────────────────────────────────────────────────────

class _MenuTopBar extends StatelessWidget {
  final InventoryProvider inv;
  const _MenuTopBar({required this.inv});

  @override
  Widget build(BuildContext context) {
    final cats = ['ALL', 'COFFEE', 'BOOK', 'FOOD'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: MakaryaColors.surface01,
      child: Column(children: [
        Row(children: [
          _StatChip(label: 'Total Item', value: '${inv.agingResults.length}'),
          const SizedBox(width: 8),
          _StatChip(
              label: 'Alert',
              value: '${inv.alertCount}',
              color: MakaryaColors.warningAmber),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Nilai Stok',
            value:
                'Rp ${(inv.totalStockValue / 1000000).toStringAsFixed(1)}jt',
            color: MakaryaColors.goldAccent,
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          onChanged: inv.setSearch,
          style: const TextStyle(
              color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 13),
          decoration: const InputDecoration(
            hintText:    'Cari nama / SKU...',
            prefixIcon:  Icon(Icons.search, size: 18, color: MakaryaColors.textMuted),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cats.map((c) {
              final sel = inv.selectedCategory == c;
              return GestureDetector(
                onTap: () => inv.setCategory(c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? MakaryaColors.woodBrown
                        : MakaryaColors.surface02,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : MakaryaColors.textMuted,
                          fontFamily: 'Inter')),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// TAB 2: BAHAN BAKU (NEW)
// =============================================================================

class _IngredientsTab extends StatefulWidget {
  const _IngredientsTab();

  @override
  State<_IngredientsTab> createState() => _IngredientsTabState();
}

class _IngredientsTabState extends State<_IngredientsTab> {
  @override
  void initState() {
    super.initState();
    // Load saat pertama kali tab dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IngredientsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IngredientsProvider>(
      builder: (context, ing, _) {
        if (ing.loading) {
          return const Center(
              child: CircularProgressIndicator(color: MakaryaColors.woodBrown));
        }

        if (ing.error != null) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: MakaryaColors.lossRed),
              const SizedBox(height: 8),
              Text(ing.error!,
                  style: const TextStyle(
                      color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: ing.refresh,
                child: const Text('Coba lagi',
                    style: TextStyle(
                        color: MakaryaColors.woodLight, fontFamily: 'Inter')),
              ),
            ]),
          );
        }

        return Column(children: [
          _IngredientsTopBar(ing: ing),
          Expanded(
            child: RefreshIndicator(
              color:     MakaryaColors.woodBrown,
              onRefresh: ing.refresh,
              child: ing.filtered.isEmpty
                  ? Center(
                      child: Text(
                        ing.search.isEmpty
                            ? 'Belum ada bahan baku'
                            : 'Tidak ditemukan: "${ing.search}"',
                        style: const TextStyle(
                            color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                      ),
                    )
                  : ListView.builder(
                      padding:   const EdgeInsets.all(12),
                      itemCount: ing.filtered.length,
                      itemBuilder: (_, i) =>
                          _IngredientRow(ingredient: ing.filtered[i]),
                    ),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Ingredients top bar ───────────────────────────────────────────────────────

class _IngredientsTopBar extends StatelessWidget {
  final IngredientsProvider ing;
  const _IngredientsTopBar({required this.ing});

  @override
  Widget build(BuildContext context) {
    const cats = ['SEMUA', 'COFFEE', 'FOOD', 'UMUM'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: MakaryaColors.surface01,
      child: Column(children: [
        // Stats row
        Row(children: [
          _StatChip(
              label: 'Total Bahan', value: '${ing.all.length}'),
          const SizedBox(width: 8),
          _StatChip(
              label: 'Stok Rendah',
              value: '${ing.alertCount}',
              color: ing.alertCount > 0
                  ? MakaryaColors.lossRed
                  : MakaryaColors.profitGreen),
        ]),
        const SizedBox(height: 8),

        // Search
        TextField(
          onChanged: ing.setSearch,
          style: const TextStyle(
              color: MakaryaColors.textPrimary,
              fontFamily: 'Inter',
              fontSize: 13),
          decoration: const InputDecoration(
            hintText:   'Cari bahan...',
            prefixIcon: Icon(Icons.search, size: 18, color: MakaryaColors.textMuted),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),

        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cats.map((c) {
              final sel = ing.selectedCategory == c;
              return GestureDetector(
                onTap: () => ing.setCategory(c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? MakaryaColors.woodBrown
                        : MakaryaColors.surface02,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : MakaryaColors.textMuted,
                          fontFamily: 'Inter')),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Single ingredient row ─────────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final Ingredient ingredient;
  const _IngredientRow({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final ing  = ingredient;
    final role = context.read<AuthProvider>().currentRole;

    final (statusColor, statusLabel) = switch (ing.status) {
      IngredientStatus.habis  => (MakaryaColors.lossRed,      'HABIS'),
      IngredientStatus.rendah => (MakaryaColors.warningAmber, 'RENDAH'),
      IngredientStatus.aman   => (MakaryaColors.profitGreen,  'AMAN'),
    };

    final catIcon = switch (ing.category) {
      'COFFEE' => Icons.coffee_rounded,
      'FOOD'   => Icons.restaurant_rounded,
      _        => Icons.inventory_2_rounded,
    };
    final catColor = switch (ing.category) {
      'COFFEE' => MakaryaColors.woodBrown,
      'FOOD'   => MakaryaColors.warningAmber,
      _        => MakaryaColors.concreteGrey,
    };

    // Progress bar: stock vs min_stock (cap at 3x min_stock sebagai "full")
    final maxDisplay = ing.minStock * 3;
    final progress   = (ing.stock / maxDisplay).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MakaryaColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ing.needsRestock
              ? statusColor.withValues(alpha: 0.35)
              : MakaryaColors.woodBrown.withValues(alpha: 0.12),
          width: ing.needsRestock ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Category icon
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(catIcon, size: 18, color: catColor),
            ),
            const SizedBox(width: 12),

            // Name + status
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: Text(ing.name,
                        style: const TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color:      MakaryaColors.textPrimary,
                            fontFamily: 'Inter'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:        statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize:      9,
                            fontWeight:    FontWeight.w700,
                            color:         statusColor,
                            fontFamily:    'Inter',
                            letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  'Stok: ${ing.stock.toStringAsFixed(0)} ${ing.unit}  •  Min: ${ing.minStock.toStringAsFixed(0)} ${ing.unit}',
                  style: const TextStyle(
                      fontSize:   10,
                      color:      MakaryaColors.textSecondary,
                      fontFamily: 'Inter'),
                ),
              ]),
            ),

            // Restock button (barista, kasir, manager)
            if (ing.needsRestock &&
                (role.canAccessQueue ||
                    role.canAccessPos ||
                    role == StaffRole.manager)) ...[
              const SizedBox(width: 8),
              _RestockButton(ingredient: ing),
            ],
          ]),

          const SizedBox(height: 10),

          // ── Stock progress bar ────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:            progress,
                  backgroundColor:  MakaryaColors.surface02,
                  valueColor: AlwaysStoppedAnimation(
                    ing.stock <= 0
                        ? MakaryaColors.lossRed
                        : ing.stock <= ing.minStock
                            ? MakaryaColors.warningAmber
                            : MakaryaColors.profitGreen,
                  ),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize:   9,
                  fontWeight: FontWeight.w600,
                  color:      statusColor,
                  fontFamily: 'Inter'),
            ),
          ]),

          // ── Last restocked ────────────────────────────────────────────────
          if (ing.lastRestocked != null) ...[
            const SizedBox(height: 6),
            Text(
              'Terakhir restock: ${_formatDate(ing.lastRestocked!)}',
              style: const TextStyle(
                  fontSize:   9,
                  color:      MakaryaColors.textMuted,
                  fontFamily: 'Inter'),
            ),
          ],

          // ── Used in menu info ─────────────────────────────────────────────
          if (ing.usedInMenuCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Digunakan di ${ing.usedInMenuCount} menu',
              style: const TextStyle(
                  fontSize: 9, color: MakaryaColors.textMuted, fontFamily: 'Inter'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes} menit lalu';
    if (diff.inHours   < 24)  return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

// ── Restock button + dialog ───────────────────────────────────────────────────

class _RestockButton extends StatefulWidget {
  final Ingredient ingredient;
  const _RestockButton({required this.ingredient});

  @override
  State<_RestockButton> createState() => _RestockButtonState();
}

class _RestockButtonState extends State<_RestockButton> {
  bool _loading = false;

  Future<void> _showRestockDialog() async {
    final ctrl = TextEditingController();
    final ing  = widget.ingredient;

    final confirmed = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MakaryaColors.surface02,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tambah Stok',
          style: const TextStyle(
              color: MakaryaColors.textPrimary,
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info bahan
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        MakaryaColors.surface01,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ing.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color:      MakaryaColors.textPrimary,
                            fontFamily: 'Inter',
                            fontSize:   13)),
                    const SizedBox(height: 2),
                    Text(
                      'Stok saat ini: ${ing.stock.toStringAsFixed(0)} ${ing.unit}',
                      style: const TextStyle(
                          fontSize:   11,
                          color:      MakaryaColors.textSecondary,
                          fontFamily: 'Inter'),
                    ),
                    Text(
                      'Minimal stok: ${ing.minStock.toStringAsFixed(0)} ${ing.unit}',
                      style: TextStyle(
                          fontSize:   11,
                          color:      MakaryaColors.warningAmber.withValues(alpha: 0.9),
                          fontFamily: 'Inter'),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Input jumlah
            Text('Jumlah yang ditambah (${ing.unit})',
                style: const TextStyle(
                    fontSize:   12,
                    color:      MakaryaColors.textSecondary,
                    fontFamily: 'Inter')),
            const SizedBox(height: 6),
            TextField(
              controller:  ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus:   true,
              style: const TextStyle(
                  color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
              decoration: InputDecoration(
                hintText:    'Contoh: 100',
                suffixText:  ing.unit,
                suffixStyle: const TextStyle(
                    color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(
                    color: MakaryaColors.textMuted, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MakaryaColors.woodBrown,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final qty = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (qty != null && qty > 0) {
                Navigator.pop(context, qty);
              }
            },
            child: const Text('Tambah Stok',
                style: TextStyle(
                    color: Colors.white, fontFamily: 'Inter',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == null || !mounted) return;

    setState(() => _loading = true);

    final staffId = context.read<AuthProvider>().session?.staffId ?? 0;
    final result  = await context.read<IngredientsProvider>().restock(
      ingredientId: widget.ingredient.id,
      qtyAdd:       confirmed,
      staffId:      staffId,
    );

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result == 'ok'
              ? '✅ Stok ${widget.ingredient.name} berhasil ditambah!'
              : '❌ $result',
          style: const TextStyle(fontFamily: 'Inter', color: Colors.white),
        ),
        backgroundColor: result == 'ok'
            ? MakaryaColors.profitGreen
            : MakaryaColors.lossRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: MakaryaColors.woodBrown))
        : IconButton(
            onPressed: _showRestockDialog,
            icon: const Icon(Icons.add_box_rounded,
                color: MakaryaColors.woodLight, size: 22),
            tooltip: 'Restock bahan',
            style: IconButton.styleFrom(
              backgroundColor:
                  MakaryaColors.woodBrown.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatChip({
    required this.label,
    required this.value,
    this.color = MakaryaColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
                fontFamily: 'Inter')),
        Text(value,
            style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w700,
                color:      color,
                fontFamily: 'Inter')),
      ]),
    );
  }
}

// ── Existing menu inventory row (tidak berubah) ───────────────────────────────

class _InventoryRow extends StatelessWidget {
  final InventoryAging aging;
  const _InventoryRow({required this.aging});

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final item = aging.item;
    final statusColor = switch (aging.health) {
      StockHealth.outOfStock  => MakaryaColors.lossRed,
      StockHealth.expiredRisk => MakaryaColors.warningAmber,
      StockHealth.lowStock    => MakaryaColors.warningAmber,
      StockHealth.slowMover   => MakaryaColors.infoBlue,
      StockHealth.healthy     => MakaryaColors.profitGreen,
    };
    final statusLabel = switch (aging.health) {
      StockHealth.outOfStock  => 'HABIS',
      StockHealth.expiredRisk => 'EXPIRED RISK',
      StockHealth.lowStock    => 'STOK RENDAH',
      StockHealth.slowMover   => 'SLOW MOVER',
      StockHealth.healthy     => 'SEHAT',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MakaryaColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: aging.health != StockHealth.healthy
              ? statusColor.withValues(alpha: 0.3)
              : MakaryaColors.woodBrown.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:        _catColor(item.categoryCode).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_catIcon(item.categoryCode),
              size: 20, color: _catColor(item.categoryCode)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      MakaryaColors.textPrimary,
                        fontFamily: 'Inter'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:        statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize:      9,
                        fontWeight:    FontWeight.w700,
                        color:         statusColor,
                        fontFamily:    'Inter',
                        letterSpacing: 0.5)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text(item.sku,
                  style: const TextStyle(
                      fontSize: 10, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
              const SizedBox(width: 12),
              Text('Stok: ${item.stock}  •  ${_rp(item.sellingPrice)}',
                  style: const TextStyle(
                      fontSize:   10,
                      color:      MakaryaColors.textSecondary,
                      fontFamily: 'Inter')),
            ]),
            if (aging.health != StockHealth.healthy) ...[
              const SizedBox(height: 4),
              Text(aging.recommendation,
                  style: TextStyle(
                      fontSize: 10,
                      color:    statusColor.withValues(alpha: 0.9),
                      fontFamily: 'Inter'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        if (aging.health == StockHealth.lowStock ||
            aging.health == StockHealth.outOfStock)
          IconButton(
            onPressed: () => _showRestockDialog(context, item),
            icon: const Icon(Icons.add_box_rounded,
                color: MakaryaColors.woodLight, size: 22),
            tooltip: 'Restock',
          ),
      ]),
    );
  }

  void _showRestockDialog(BuildContext context, InventoryItem item) {
    final ctrl = TextEditingController(text: '50');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MakaryaColors.surface02,
        title: Text('Restock: ${item.name}',
            style: const TextStyle(
                color: MakaryaColors.textPrimary,
                fontFamily: 'Inter',
                fontSize: 14)),
        content: TextField(
          controller:   ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
          decoration: const InputDecoration(labelText: 'Jumlah tambah'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(ctrl.text) ?? 0;
              if (qty > 0)
                context.read<InventoryProvider>().restock(item.id, qty);
              Navigator.pop(context);
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  Color    _catColor(String code) => switch (code) {
    'COFFEE' => MakaryaColors.woodBrown,
    'BOOK'   => MakaryaColors.concreteGrey,
    'FOOD'   => MakaryaColors.woodLight,
    _        => MakaryaColors.categoryMerch,
  };

  IconData _catIcon(String code) => switch (code) {
    'COFFEE' => Icons.coffee_rounded,
    'BOOK'   => Icons.menu_book_rounded,
    'FOOD'   => Icons.restaurant_rounded,
    _        => Icons.shopping_bag_rounded,
  };
}