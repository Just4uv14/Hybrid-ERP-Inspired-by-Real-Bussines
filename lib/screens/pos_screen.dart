// =============================================================================
// MAKARYA HYBRID ERP — POS Screen
// File: lib/screens/pos_screen.dart
// =============================================================================

import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../providers/cart_provider.dart';
import '../providers/inventory_provider.dart';
import '../logic/business_logic.dart';
import '../logic/pdf_service.dart';
import '../theme/makarya_theme.dart';
import '../providers/auth_provider.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override State<PosScreen> createState() => _PosScreenState();
}

// GlobalKey untuk icon keranjang di bottom bar — target animasi fly-to-cart
final GlobalKey cartBarIconKey = GlobalKey();

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<String> _categories = ['ALL', 'COFFEE', 'BOOK', 'FOOD'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Fly-to-cart animation ──────────────────────────────────────────────────
  void _flyToCart(BuildContext context, Offset startOffset) {
    // Fallback target: tengah-bawah layar
    Offset targetOffset = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height - 30,
    );
    final targetCtx = cartBarIconKey.currentContext;
    if (targetCtx != null) {
      final box = targetCtx.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero);
      targetOffset = Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);
    }

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final ctrl = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 480),
    );

    final curvedAnim  = CurvedAnimation(parent: ctrl, curve: Curves.easeInCubic);
    final scaleAnim   = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );
    final opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: ctrl, curve: const Interval(0.75, 1.0)),
    );

    entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final t = curvedAnim.value;
          final x = lerpDouble(startOffset.dx, targetOffset.dx, t)!;
          final arcHeight = (startOffset.dy - targetOffset.dy).abs() * 0.5 + 60;
          final y = lerpDouble(startOffset.dy, targetOffset.dy, t)!
              - arcHeight * 4 * t * (1 - t);

          return Positioned(
            left: x - 16,
            top:  y - 16,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: opacityAnim,
                child: ScaleTransition(
                  scale: scaleAnim,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: MakaryaColors.woodBrown,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )],
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    overlay.insert(entry);
    ctrl.forward().whenComplete(() {
      entry.remove();
      ctrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return isWide ? _buildWideLayout() : _buildNarrowLayout();
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(flex: 6, child: _buildMenuPanel()),
        Container(width: 1, color: MakaryaColors.woodBrown.withValues(alpha: 0.2)),
        SizedBox(width: 340, child: _buildCartPanel()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(child: _buildMenuPanel()),
        _buildCartBottomSheet(),
      ],
    );
  }

  Widget _buildMenuPanel() {
    return Column(
      children: [
        // Category tabs
        Container(
          color: MakaryaColors.surface01,
          child: TabBar(
            controller: _tabCtrl,
            tabs: _categories.map((c) => Tab(text: c)).toList(),
            indicatorColor: MakaryaColors.woodBrown,
            labelColor: MakaryaColors.woodLight,
            unselectedLabelColor: MakaryaColors.textMuted,
            labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        // Menu grid
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _categories.map((cat) => _MenuGrid(
              category: cat,
              flyToCart: _flyToCart,
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) => Container(
        color: MakaryaColors.surface01,
        child: Column(
          children: [
            // Cart header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_rounded, key: cartBarIconKey, color: MakaryaColors.woodLight, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Keranjang (${cart.itemCount})',
                    style: const TextStyle(color: MakaryaColors.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 14),
                  ),
                  const Spacer(),
                  if (!cart.isEmpty)
                    TextButton(
                      onPressed: () => _confirmClear(context, cart),
                      child: const Text('Kosongkan', style: TextStyle(fontSize: 11, color: MakaryaColors.lossRed)),
                    ),
                ],
              ),
            ),

            // Bundle badge
            if (cart.bundlePromoLabel != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MakaryaColors.goldAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MakaryaColors.goldAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_rounded, size: 14, color: MakaryaColors.goldAccent),
                    const SizedBox(width: 6),
                    Text(
                      '${cart.bundlePromoLabel} — Diskon 10%',
                      style: const TextStyle(fontSize: 11, color: MakaryaColors.goldAccent, fontFamily: 'Inter', fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            // Cart items list
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 48, color: MakaryaColors.textMuted),
                          SizedBox(height: 8),
                          Text('Pilih item dari menu', style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: cart.items.length,
                      itemBuilder: (_, i) => _CartItemRow(item: cart.items[i]),
                    ),
            ),

            // Totals & payment
            _CartFooter(cart: cart),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBottomSheet() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) => GestureDetector(
        onTap: () => _showCartSheet(context),
        // ── Poin 9: SafeArea supaya bottom bar tidak tertimpa gesture nav bar
        // (Android gesture mode) atau home indicator (iPhone). Height 60 adalah
        // konten — SafeArea tambah padding di bawahnya otomatis sesuai device.
        child: SafeArea(
          top: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: MakaryaColors.woodBrown,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_rounded, key: cartBarIconKey, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('${cart.itemCount} item', style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  'Rp ${cart.grandTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MakaryaColors.surface01,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: SizedBox(height: 400, child: _buildCartPanel()),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MakaryaColors.surface02,
        title: const Text('Kosongkan keranjang?', style: TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MakaryaColors.lossRed),
            onPressed: () { cart.clearCart(); Navigator.pop(context); },
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }
}

// ── Menu Grid ─────────────────────────────────────────────────────────────────

class _MenuGrid extends StatelessWidget {
  final String category;
  final void Function(BuildContext, Offset) flyToCart;
  const _MenuGrid({required this.category, required this.flyToCart});

  @override
  Widget build(BuildContext context) {
    final inv  = context.watch<InventoryProvider>();
    final cart = context.read<CartProvider>();
    final items = inv.agingResults
        .where((a) => category == 'ALL' || a.item.categoryCode == category)
        .where((a) => a.item.stock > 0)
        .toList();

    // ── Poin 6/9: LayoutBuilder supaya grid adaptive terhadap lebar layar.
    // Di HP sempit (~360dp), maxCrossAxisExtent 160 → 2 kolom ~170dp per card.
    // childAspectRatio dihitung dari lebar aktual supaya card tidak overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width      = constraints.maxWidth;
        final crossExtent = width < 400 ? 155.0 : 180.0;
        // Hitung berapa kolom yang terbentuk, lalu ratio dari lebar kolom aktual
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: crossExtent,
            mainAxisSpacing:    10,
            crossAxisSpacing:   10,
            mainAxisExtent:     155,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i].item;
            return _MenuCard(
              item: item,
              flyToCart: flyToCart,
              onTap: () => cart.addItem(CartItem(
                itemId:        item.id,
                sku:           item.sku,
                name:          item.name,
                categoryCode:  item.categoryCode,
                unitSellPrice: item.sellingPrice,
                costAtTime:    item.costPrice,
              )),
            );
          },
        );
      },
    );
  }
}

class _MenuCard extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final void Function(BuildContext, Offset) flyToCart;
  const _MenuCard({required this.item, required this.onTap, required this.flyToCart});
  @override State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Ambil posisi tengah card sebagai titik awal animasi
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null
        ? box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2))
        : Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);

    // Jalankan animasi press (scale down lalu up)
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());

    // Jalankan fly-to-cart overlay
    widget.flyToCart(context, center);

    // Tambah item ke cart
    widget.onTap();
  }

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final item     = widget.item;
    final catColor = switch (item.categoryCode) {
      'COFFEE' => MakaryaColors.woodBrown,
      'BOOK'   => MakaryaColors.concreteGrey,
      'FOOD'   => MakaryaColors.woodLight,
      _        => MakaryaColors.categoryMerch,
    };
    return GestureDetector(
      key: _key,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            // ── Poin 12: surface02 (#2E2E2F) vs surface01 (#242425) —
            // kontras lebih jelas di atas darkEspresso (#1A1A1B).
            // Shadow tipis warna catColor bantu mata memisahkan antar card.
            color: MakaryaColors.surface02,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MakaryaColors.woodBrown.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: catColor.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category color bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_categoryIcon(item.categoryCode), size: 22, color: catColor.withValues(alpha: 0.8)),
                    const SizedBox(height: 4),
                    Text(item.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_rp(item.sellingPrice),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MakaryaColors.woodLight, fontFamily: 'Inter')),
                              Text('Stok: ${item.stock}',
                                  style: const TextStyle(fontSize: 10, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                            ],
                          ),
                        ),
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add_shopping_cart_rounded, size: 14, color: catColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String code) => switch (code) {
    'COFFEE' => Icons.coffee_rounded,
    'BOOK'   => Icons.menu_book_rounded,
    'FOOD'   => Icons.restaurant_rounded,
    _        => Icons.shopping_bag_rounded,
  };
}

// ── Cart Item Row ─────────────────────────────────────────────────────────────

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  const _CartItemRow({required this.item});

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MakaryaColors.surface02,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_rp(item.unitSellPrice),
                    style: const TextStyle(fontSize: 11, color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
              ],
            ),
          ),
          // Qty controls
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: () => cart.decrementQty(item.itemId)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${item.qty}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
              ),
              _QtyButton(icon: Icons.add, onTap: () => cart.incrementQty(item.itemId)),
            ],
          ),
          const SizedBox(width: 8),
          Text(_rp(item.lineTotal),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MakaryaColors.woodLight, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: MakaryaColors.woodBrown.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: MakaryaColors.woodLight),
    ),
  );
}

// ── Cart Footer ───────────────────────────────────────────────────────────────

class _CartFooter extends StatelessWidget {
  final CartProvider cart;
  const _CartFooter({required this.cart});

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MakaryaColors.surface02,
        border: Border(top: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary rows
          _SummaryRow(label: 'Subtotal', value: _rp(cart.subtotal)),
          if (cart.globalDiscount > 0)
            _SummaryRow(label: 'Diskon', value: '- ${_rp(cart.globalDiscount)}', color: MakaryaColors.profitGreen),
          _SummaryRow(label: 'PPN 11%',  value: _rp(cart.taxAmount)),
          _SummaryRow(label: 'Service 5%', value: _rp(cart.serviceAmount)),
          const Divider(height: 12),
          _SummaryRow(
            label: 'TOTAL',
            value: _rp(cart.grandTotal),
            isBold: true,
            color: MakaryaColors.goldAccent,
          ),
          const SizedBox(height: 10),

          // Payment method
          Row(
            children: PaymentMethod.values.map((m) {
              final sel = cart.paymentMethod == m;
              return Expanded(
                child: GestureDetector(
                  onTap: () => cart.setPaymentMethod(m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? MakaryaColors.woodBrown : MakaryaColors.surface03,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? MakaryaColors.woodBrown : Colors.transparent),
                    ),
                    child: Text(m.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? Colors.white : MakaryaColors.textMuted, fontFamily: 'Inter')),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Charge button
          ElevatedButton(
            onPressed: cart.isEmpty ? null : () => _processPayment(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: MakaryaColors.profitGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              cart.isEmpty ? 'Pilih Item' : 'Proses Pembayaran · ${_rp(cart.grandTotal)}',
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _processPayment(BuildContext context) {
    final cart = context.read<CartProvider>();
    showDialog(
      context: context,
      builder: (_) => _PaymentDialog(cart: cart),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? color;
  const _SummaryRow({required this.label, required this.value, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isBold ? MakaryaColors.textPrimary : MakaryaColors.textSecondary, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, fontFamily: 'Inter')),
        const Spacer(),
        Text(value,  style: TextStyle(fontSize: 12, color: color ?? (isBold ? MakaryaColors.goldAccent : MakaryaColors.textPrimary), fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, fontFamily: 'Inter')),
      ],
    ),
  );
}

// ── Payment Dialog ────────────────────────────────────────────────────────────

class _PaymentDialog extends StatefulWidget {
  final CartProvider cart;
  const _PaymentDialog({required this.cart});
  @override State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _cashCtrl = TextEditingController();
  bool _paid     = false;
  bool _loading  = false;
  bool _printing = false;
  String?      _error;
  ReceiptData? _receiptData; // snapshot setelah bayar, sebelum cart dibersihkan

  @override
  void dispose() { _cashCtrl.dispose(); super.dispose(); }

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  // ── Cetak / preview struk ────────────────────────────────────────────────
  Future<void> _printReceipt() async {
    if (_receiptData == null) return;
    setState(() => _printing = true);
    try {
      final bytes = await generateReceiptPdfFromData(_receiptData!);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Struk_${_receiptData!.trxCode}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal cetak: $e'),
            backgroundColor: MakaryaColors.lossRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_receiptData == null) return;
    setState(() => _printing = true);
    try {
      final bytes = await generateReceiptPdfFromData(_receiptData!);
      await sharePdf(bytes, fileName: 'Struk_${_receiptData!.trxCode}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal bagikan: $e'), backgroundColor: MakaryaColors.lossRed),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  // ── Struk preview widget ──────────────────────────────────────────────────
  Widget _buildReceiptPreview(ReceiptData r) {
    final subtotal    = r.items.fold(0.0, (s, i) => s + i.lineSubtotal);
    final taxable     = subtotal - r.discountAmount;
    final ppnAmt      = taxable * r.taxConfig.ppnRate;
    final serviceAmt  = taxable * r.taxConfig.serviceRate;
    final grandTotal  = taxable + ppnAmt + serviceAmt;

    const mono = TextStyle(fontFamily: 'monospace', fontSize: 11, color: MakaryaColors.textPrimary);
    const monoSm = TextStyle(fontFamily: 'monospace', fontSize: 10, color: MakaryaColors.textSecondary);
    const monoMuted = TextStyle(fontFamily: 'monospace', fontSize: 10, color: MakaryaColors.textMuted);

    Widget row(String left, String right, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: monoSm),
            Text(right, style: bold
                ? TextStyle(fontFamily: 'monospace', fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color ?? MakaryaColors.woodLight)
                : TextStyle(fontFamily: 'monospace', fontSize: 10,
                    color: color ?? MakaryaColors.textPrimary)),
          ],
        ),
      );

    Widget dash() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('- - - - - - - - - - - - - - - - - -',
          style: monoMuted, textAlign: TextAlign.center),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5), // kertas putih agak krem
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: DefaultTextStyle(
        style: mono,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            const Text('MAKARYA',
                style: TextStyle(fontFamily: 'monospace', fontSize: 16,
                    fontWeight: FontWeight.bold, color: Color(0xFF2C1A00))),
            const Text('Kafe Buku & Kopi',
                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF7A6040))),
            const Text('Jl. Matraman Raya No.46, Jakarta',
                style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFF7A6040))),
            dash(),

            // Info transaksi
            row('No Trx', r.trxCode),
            row('Kasir',  r.staffName),
            row('Waktu',
                '${r.trxAt.day.toString().padLeft(2,'0')}/${r.trxAt.month.toString().padLeft(2,'0')}/${r.trxAt.year}'
                ' ${r.trxAt.hour.toString().padLeft(2,'0')}:${r.trxAt.minute.toString().padLeft(2,'0')}'),
            dash(),

            // Items
            ...r.items.map((item) {
              final name = r.itemNames[item.itemId] ?? 'Item';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11,
                            fontWeight: FontWeight.bold, color: Color(0xFF2C1A00))),
                    row('  ${item.qty.toInt()}x ${_rp(item.effectiveSellPrice)}',
                        _rp(item.lineSubtotal)),
                  ],
                ),
              );
            }),

            dash(),

            // Totals
            row('Subtotal', _rp(subtotal)),
            if (r.discountAmount > 0)
              row('Diskon${r.bundlePromoLabel != null ? " (${r.bundlePromoLabel})" : ""}',
                  '- ${_rp(r.discountAmount)}', color: const Color(0xFFBB4040)),
            if (ppnAmt > 0)     row('PPN 11%',     _rp(ppnAmt)),
            if (serviceAmt > 0) row('Service 5%',  _rp(serviceAmt)),
            const Divider(color: Color(0xFF8B6914), thickness: 0.8, height: 10),
            row('TOTAL', _rp(grandTotal), bold: true, color: const Color(0xFF8B6914)),
            const SizedBox(height: 4),
            row('Bayar (${r.paymentMethod})',
                r.cashTendered != null ? _rp(r.cashTendered!) : '-'),
            if ((r.changeGiven ?? 0) > 0)
              row('Kembali', _rp(r.changeGiven!), color: const Color(0xFF2E7D55)),

            dash(),
            const SizedBox(height: 4),
            const Text('Terima kasih!',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12,
                    fontWeight: FontWeight.bold, color: Color(0xFF2C1A00))),
            const Text('Selamat membaca & menikmati kopi ☕',
                style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Color(0xFF7A6040))),
            const SizedBox(height: 6),
            Text(r.trxCode,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 8, color: Color(0xFFAA9977),
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;

    // ── SUKSES: tampil preview struk + tombol cetak ───────────────────────
    if (_paid && _receiptData != null) {
      return Dialog(
        backgroundColor: MakaryaColors.surface02,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                decoration: BoxDecoration(
                  color: MakaryaColors.profitGreen.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: MakaryaColors.profitGreen, size: 22),
                    const SizedBox(width: 8),
                    const Text('Pembayaran Berhasil!',
                        style: TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter',
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    // total & kembalian
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_rp(_receiptData!.items.fold(0.0, (s, i) => s + i.lineSubtotal)
                              - _receiptData!.discountAmount
                              + (_receiptData!.items.fold(0.0, (s, i) => s + i.lineSubtotal)
                                  - _receiptData!.discountAmount) * 0.16),
                          style: const TextStyle(color: MakaryaColors.goldAccent,
                              fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14)),
                      if ((_receiptData!.changeGiven ?? 0) > 0)
                        Text('Kembali ${_rp(_receiptData!.changeGiven!)}',
                            style: const TextStyle(color: MakaryaColors.profitGreen,
                                fontFamily: 'Inter', fontSize: 10)),
                    ]),
                  ],
                ),
              ),

              // Struk preview
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildReceiptPreview(_receiptData!),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const Divider(height: 12),
                    Row(
                      children: [
                        // Cetak Struk
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MakaryaColors.woodBrown,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _printing
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.print_rounded, size: 18),
                            label: Text(_printing ? 'Mencetak...' : 'Cetak Struk',
                                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                            onPressed: _printing ? null : _printReceipt,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bagikan PDF
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.5)),
                              foregroundColor: MakaryaColors.woodLight,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: const Text('Bagikan', style: TextStyle(fontFamily: 'Inter')),
                            onPressed: _printing ? null : _shareReceipt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Transaksi baru — full width
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: MakaryaColors.textMuted),
                        onPressed: () { cart.clearCart(); Navigator.pop(context); },
                        child: const Text('Tutup & Transaksi Baru',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── FORM PEMBAYARAN ───────────────────────────────────────────────────
    return AlertDialog(
      backgroundColor: MakaryaColors.surface02,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Proses Pembayaran',
          style: TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_rp(cart.grandTotal),
              style: const TextStyle(color: MakaryaColors.goldAccent,
                  fontWeight: FontWeight.w700, fontFamily: 'Inter', fontSize: 22)),
          if (cart.paymentMethod == PaymentMethod.cash) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cashCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
              decoration: const InputDecoration(
                labelText: 'Jumlah Tunai',
                prefixText: 'Rp ',
              ),
              onChanged: (v) {
                final amount = double.tryParse(v.replaceAll('.', '')) ?? 0;
                cart.setCashTendered(amount);
                setState(() {});
              },
            ),
            if (cart.cashTendered >= cart.grandTotal)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Kembalian: ${_rp(cart.change)}',
                    style: const TextStyle(color: MakaryaColors.profitGreen, fontFamily: 'Inter')),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: MakaryaColors.lossRed,
                fontSize: 11, fontFamily: 'Inter')),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: MakaryaColors.profitGreen),
          onPressed: (cart.paymentMethod != PaymentMethod.cash ||
                  cart.cashTendered >= cart.grandTotal) &&
              !_loading
              ? () async {
                  setState(() { _loading = true; _error = null; });
                  final auth = context.read<AuthProvider>();
                  // Snapshot data SEBELUM proses (untuk receipt)
                  final staffName = auth.session?.fullName ?? 'Kasir';
                  final snapshot  = cart.buildReceiptData(
                    trxCode:   'PENDING',
                    staffName: staffName,
                  );
                  final success = await cart.processPayment(auth: auth);
                  if (success) {
                    // Rebuild snapshot dengan trxCode yang sudah ter-generate
                    final finalReceipt = cart.buildReceiptData(
                      trxCode:   cart.lastTrxCode ?? snapshot.trxCode,
                      staffName: staffName,
                    );
                    setState(() {
                      _receiptData = finalReceipt;
                      _paid        = true;
                      _loading     = false;
                    });
                  } else {
                    setState(() {
                      _error   = cart.lastError ?? 'Gagal menyimpan transaksi';
                      _loading = false;
                    });
                  }
                }
              : null,
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Bayar'),
        ),
      ],
    );
  }
}