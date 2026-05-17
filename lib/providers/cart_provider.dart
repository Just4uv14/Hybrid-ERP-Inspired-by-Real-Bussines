
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/business_logic.dart';
import '../providers/auth_provider.dart';

// ── Cart Item ──────────────────────────────────────────────────────────────────

class CartItem {
  final int itemId;
  final String sku;
  final String name;
  final String categoryCode;
  final double unitSellPrice;
  final double costAtTime;
  int qty;
  double unitDiscount;

  CartItem({
    required this.itemId,
    required this.sku,
    required this.name,
    required this.categoryCode,
    required this.unitSellPrice,
    required this.costAtTime,
    this.qty = 1,
    this.unitDiscount = 0.0,
  });

  double get effectivePrice => unitSellPrice - unitDiscount;
  double get lineTotal      => effectivePrice * qty;
  double get lineCogs       => costAtTime * qty;

  TransactionLineItem toLineItem() => TransactionLineItem(
    itemId:        itemId,
    categoryCode:  categoryCode,
    qty:           qty.toDouble(),
    unitSellPrice: unitSellPrice,
    costAtTime:    costAtTime,
    unitDiscount:  unitDiscount,
  );

  CartItem copyWith({int? qty, double? unitDiscount}) => CartItem(
    itemId:        itemId,
    sku:           sku,
    name:          name,
    categoryCode:  categoryCode,
    unitSellPrice: unitSellPrice,
    costAtTime:    costAtTime,
    qty:           qty ?? this.qty,
    unitDiscount:  unitDiscount ?? this.unitDiscount,
  );
}

// ── Payment Method ─────────────────────────────────────────────────────────────

enum PaymentMethod { cash, qris, debit, credit }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash   => 'TUNAI',
    PaymentMethod.qris   => 'QRIS',
    PaymentMethod.debit  => 'DEBIT',
    PaymentMethod.credit => 'KREDIT',
  };

  String get dbValue => switch (this) {
    PaymentMethod.cash   => 'CASH',
    PaymentMethod.qris   => 'QRIS',
    PaymentMethod.debit  => 'DEBIT',
    PaymentMethod.credit => 'CREDIT',
  };
}

// ── Provider ──────────────────────────────────────────────────────────────────

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  PaymentMethod get paymentMethod => _paymentMethod;

  double _globalDiscount = 0.0;
  double get globalDiscount => _globalDiscount;

  String? _bundlePromoLabel;
  String? get bundlePromoLabel => _bundlePromoLabel;

  double _cashTendered = 0.0;
  double get cashTendered => _cashTendered;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String? _lastError;
  String? get lastError => _lastError;

  final _supabase = Supabase.instance.client;

  bool get isEmpty   => _items.isEmpty;
  int  get itemCount => _items.fold(0, (s, i) => s + i.qty);

  // ── Totals ─────────────────────────────────────────────────────────────────

  double get subtotal      => _items.fold(0.0, (s, i) => s + i.lineTotal);
  double get totalCogs     => _items.fold(0.0, (s, i) => s + i.lineCogs);
  double get afterDiscount => subtotal - _globalDiscount;
  double get taxAmount     => afterDiscount * 0.11;
  double get serviceAmount => afterDiscount * 0.05;
  double get grandTotal    => afterDiscount + taxAmount + serviceAmount;
  double get change        => (_cashTendered - grandTotal).clamp(0, double.infinity);

  bool get hasBundle =>
      _items.any((i) => i.categoryCode == 'BOOK') &&
      _items.any((i) => i.categoryCode == 'COFFEE');

  // ── Mutations ──────────────────────────────────────────────────────────────

  void addItem(CartItem item) {
    final idx = _items.indexWhere((i) => i.itemId == item.itemId);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(qty: _items[idx].qty + 1);
    } else {
      _items.add(item);
    }
    _applyBundlePromo();
    notifyListeners();
  }

  void removeItem(int itemId) {
    _items.removeWhere((i) => i.itemId == itemId);
    _applyBundlePromo();
    notifyListeners();
  }

  void incrementQty(int itemId) {
    final idx = _items.indexWhere((i) => i.itemId == itemId);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(qty: _items[idx].qty + 1);
      _applyBundlePromo();
      notifyListeners();
    }
  }

  void decrementQty(int itemId) {
    final idx = _items.indexWhere((i) => i.itemId == itemId);
    if (idx >= 0) {
      if (_items[idx].qty <= 1) {
        removeItem(itemId);
      } else {
        _items[idx] = _items[idx].copyWith(qty: _items[idx].qty - 1);
        _applyBundlePromo();
        notifyListeners();
      }
    }
  }

  void setGlobalDiscount(double amount) {
    _globalDiscount = amount.clamp(0, subtotal);
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCashTendered(double amount) {
    _cashTendered = amount;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _globalDiscount   = 0.0;
    _bundlePromoLabel = null;
    _cashTendered     = 0.0;
    _paymentMethod    = PaymentMethod.cash;
    _lastError        = null;
    notifyListeners();
  }

  // ── Bundle promo ────────────────────────────────────────────────────────────

  void _applyBundlePromo() {
    if (hasBundle) {
      final cheapest = _items.reduce(
          (a, b) => a.unitSellPrice < b.unitSellPrice ? a : b);
      _globalDiscount   = cheapest.unitSellPrice * 0.10;
      _bundlePromoLabel = 'Bundle Book+Coffee';
    } else {
      _globalDiscount   = 0.0;
      _bundlePromoLabel = null;
    }
  }

  // ── Save to Supabase ────────────────────────────────────────────────────────

  Future<bool> processPayment({AuthProvider? auth}) async {
    if (_items.isEmpty) return false;

    _isProcessing = true;
    _lastError    = null;
    notifyListeners();

    try {
      // ── Set RLS context dari session yang sedang login ─────────────────────
      final session  = auth?.session;
      final staffId  = session?.staffId;
      final roleStr  = switch (session?.role) {
        StaffRole.manager     => 'MANAGER',
        StaffRole.cashier     => 'CASHIER',
        StaffRole.barista     => 'BARISTA',
        StaffRole.stockKeeper => 'STOCK_KEEPER',
        StaffRole.researcher  => 'RESEARCHER',
        _                     => 'CASHIER',
      };

      // Panggil set_current_role sebelum setiap operasi insert
      if (staffId != null) {
        await _supabase.rpc('set_current_role', params: {
          'p_role':     roleStr,
          'p_staff_id': staffId,
        });
      }

      // Generate transaction code
      final now     = DateTime.now();
      final trxCode = 'TRX-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecondsSinceEpoch % 10000}';

      // Staff ID dari session, fallback ke EMP-001
      final resolvedStaffId = staffId ?? await _getFallbackStaffId();

      final hasBook = _items.any((i) => i.categoryCode == 'BOOK');
      final hasCafe = _items.any((i) => i.categoryCode == 'COFFEE');

      // Insert transaction header
      final trxRow = await _supabase.from('transactions').insert({
        'trx_code':        trxCode,
        'staff_id':        resolvedStaffId,
        'tax_profile_id':  4,
        'trx_at':          now.toIso8601String(),
        'subtotal':        subtotal,
        'discount_amount': _globalDiscount,
        'discount_pct':    subtotal > 0 ? _globalDiscount / subtotal : 0,
        'ppn_amount':      taxAmount,
        'service_charge':  serviceAmount,
        'grand_total':     grandTotal,
        'total_cogs':      totalCogs,
        'payment_method':  _paymentMethod.dbValue,
        'cash_tendered':   _paymentMethod == PaymentMethod.cash ? _cashTendered : null,
        'change_given':    _paymentMethod == PaymentMethod.cash ? change : null,
        'has_book':        hasBook,
        'has_cafe':        hasCafe,
        // PENDING kalau ada item cafe/food → masuk queue barista dulu
        // DONE langsung kalau pure buku (tidak perlu diracik)
        // NOTE: dashboard filter pakai 'DONE', jangan pakai 'COMPLETED'
        'status':          hasCafe ? 'PENDING' : 'DONE',
      }).select('id').single();

      final trxId = trxRow['id'] as int;

      // Insert transaction details
      final details = _items.map((item) => {
        'transaction_id':  trxId,
        'item_id':         item.itemId,
        'category_code':   item.categoryCode,
        'qty':             item.qty.toDouble(),
        'unit_sell_price': item.unitSellPrice,
        'cost_at_time':    item.costAtTime,
        'unit_cogs':       item.costAtTime,
        'unit_discount':   item.unitDiscount,
      }).toList();

      await _supabase.from('transaction_details').insert(details);

      // Insert bundle analytics jika bundle
      if (hasBundle) {
        final bookItem = _items.firstWhere((i) => i.categoryCode == 'BOOK');
        final cafeItem = _items.firstWhere((i) => i.categoryCode == 'COFFEE');
        final ruleRow  = await _supabase
            .from('bundle_rules')
            .select('id')
            .eq('is_active', true)
            .maybeSingle();

        await _supabase.from('bundle_analytics').insert({
          'transaction_id': trxId,
          'book_item_id':   bookItem.itemId,
          'cafe_item_id':   cafeItem.itemId,
          'bundle_rule_id': ruleRow?['id'],
          'book_revenue':   bookItem.lineTotal,
          'cafe_revenue':   cafeItem.lineTotal,
          'discount_given': _globalDiscount,
        });
      }

      // Update stock
      for (final item in _items) {
        await _supabase.rpc('decrement_stock', params: {
          'p_item_id': item.itemId,
          'p_qty':     item.qty,
        });
      }

      _isProcessing = false;
      notifyListeners();
      return true;

    } catch (e) {
      _lastError    = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<int> _getFallbackStaffId() async {
    final row = await _supabase
        .from('staff')
        .select('id')
        .eq('employee_id', 'EMP-001')
        .maybeSingle();
    return row?['id'] as int? ?? 1;
  }

  // ── Receipt builder ────────────────────────────────────────────────────────

  ReceiptData buildReceiptData({
    required String trxCode,
    required String staffName,
  }) {
    final itemNames = {for (final i in _items) i.itemId: i.name};
    return ReceiptData(
      trxCode:          trxCode,
      storeName:        'Makarya Gramedia Matraman',
      storeAddress:     'Jl. Matraman Raya No.46, Jakarta',
      staffName:        staffName,
      trxAt:            DateTime.now(),
      items:            _items.map((i) => i.toLineItem()).toList(),
      itemNames:        itemNames,
      taxConfig:        const TaxConfig(ppnRate: 0.11, serviceRate: 0.05),
      paymentMethod:    _paymentMethod.label,
      discountAmount:   _globalDiscount,
      cashTendered:     _paymentMethod == PaymentMethod.cash ? _cashTendered : null,
      changeGiven:      _paymentMethod == PaymentMethod.cash ? change : null,
      bundlePromoLabel: _bundlePromoLabel,
    );
  }
}