// =============================================================================
// MAKARYA HYBRID ERP — Expenses Screen
// File: lib/screens/expenses_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../logic/business_logic.dart';
import '../theme/makarya_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // Local mock expenses state (replace with DB in production)
  final List<ExpenseEntry> _expenses = [
    ExpenseEntry(id: 1, categoryCode: 'SALARIES',    amount: 28500000, date: DateTime.now().subtract(const Duration(days: 6)), affectsProfit: true),
    ExpenseEntry(id: 2, categoryCode: 'UTILITIES',   amount: 3200000,  date: DateTime.now().subtract(const Duration(days: 5)), affectsProfit: true),
    ExpenseEntry(id: 3, categoryCode: 'RENT',        amount: 15000000, date: DateTime.now().subtract(const Duration(days: 5)), affectsProfit: true),
    ExpenseEntry(id: 4, categoryCode: 'UTILITIES',   amount: 450000,   date: DateTime.now().subtract(const Duration(days: 4)), affectsProfit: true),
    ExpenseEntry(id: 5, categoryCode: 'SUPPLIES',    amount: 350000,   date: DateTime.now().subtract(const Duration(days: 3)), affectsProfit: true),
    ExpenseEntry(id: 6, categoryCode: 'MARKETING',   amount: 500000,   date: DateTime.now().subtract(const Duration(days: 2)), affectsProfit: true),
    ExpenseEntry(id: 7, categoryCode: 'MAINTENANCE', amount: 750000,   date: DateTime.now().subtract(const Duration(days: 1)), affectsProfit: true),
    ExpenseEntry(id: 8, categoryCode: 'SUPPLIES',    amount: 280000,   date: DateTime.now(),                                    affectsProfit: true),
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  String _newCategory = 'SUPPLIES';

  static const _categories = ['SALARIES', 'UTILITIES', 'RENT', 'SUPPLIES', 'MARKETING', 'MAINTENANCE', 'OTHER'];

  double get _totalOpex => _expenses.where((e) => e.affectsProfit).fold(0.0, (s, e) => s + e.amount);

  String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    // Category breakdown
    final breakdown = <String, double>{};
    for (final e in _expenses) {
      breakdown[e.categoryCode] = (breakdown[e.categoryCode] ?? 0) + e.amount;
    }

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(16),
          color: MakaryaColors.surface01,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total OPEX',
                      value: _rp(_totalOpex),
                      color: MakaryaColors.lossRed,
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Entri Bulan Ini',
                      value: '${_expenses.length}',
                      color: MakaryaColors.infoBlue,
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category breakdown chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: breakdown.entries.map((e) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MakaryaColors.surface02,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${e.key}: ${_rp(e.value)}',
                      style: const TextStyle(fontSize: 10, color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),

        // Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Pengeluaran'),
              onPressed: () => _showAddDialog(context),
            ),
          ),
        ),

        // Expense list
        Expanded(
          child: _expenses.isEmpty
              ? const Center(child: Text('Belum ada pengeluaran', style: TextStyle(color: MakaryaColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _expenses.length,
                  itemBuilder: (_, i) {
                    final e = _expenses[_expenses.length - 1 - i]; // newest first
                    return _ExpenseRow(
                      expense: e,
                      rp: _rp,
                      onDelete: () => setState(() => _expenses.removeWhere((x) => x.id == e.id)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MakaryaColors.surface02,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      // ── FIX poin 10 & 11 ──────────────────────────────────────────────────
      // Pakai `sheetContext` (bukan `context` parent) supaya viewInsets.bottom
      // terbaca live saat keyboard naik — bukan nilai stale dari sebelum sheet terbuka.
      builder: (sheetContext) {
        final keyboardHeight = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: keyboardHeight + 24,
            top: 24, left: 20, right: 20,
          ),
          // ── FIX poin 11 ───────────────────────────────────────────────────
          // SingleChildScrollView supaya saat keyboard naik, user bisa scroll
          // ke atas dan tetap bisa akses dropdown Kategori yang ada di atas.
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: MakaryaColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const Text('Tambah Pengeluaran',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                          color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                  const SizedBox(height: 16),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _newCategory,
                    dropdownColor: MakaryaColors.surface02,
                    style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 14),
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _newCategory = v ?? 'SUPPLIES'),
                  ),
                  const SizedBox(height: 12),

                  // Amount field
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)', prefixText: 'Rp '),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Masukkan jumlah';
                      if (double.tryParse(v) == null) return 'Format tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Note
                  TextFormField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final amount = double.parse(_amountCtrl.text);
                          setState(() {
                            _expenses.add(ExpenseEntry(
                              id:            _expenses.length + 100,
                              categoryCode:  _newCategory,
                              amount:        amount,
                              date:          DateTime.now(),
                              affectsProfit: true,
                            ));
                            _amountCtrl.clear();
                            _noteCtrl.clear();
                          });
                          Navigator.pop(sheetContext);
                        }
                      },
                      child: const Text('Simpan Pengeluaran'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontFamily: 'Inter')),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color, fontFamily: 'Inter')),
          ],
        ),
      ],
    ),
  );
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseEntry expense;
  final String Function(double) rp;
  final VoidCallback onDelete;
  const _ExpenseRow({required this.expense, required this.rp, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final catColors = {
      'SALARIES':    MakaryaColors.infoBlue,
      'UTILITIES':   MakaryaColors.warningAmber,
      'RENT':        MakaryaColors.woodBrown,
      'SUPPLIES':    MakaryaColors.woodLight,
      'MARKETING':   MakaryaColors.categoryMerch,
      'MAINTENANCE': MakaryaColors.concreteGrey,
      'OTHER':       MakaryaColors.textSecondary,
    };
    final color = catColors[expense.categoryCode] ?? MakaryaColors.textSecondary;
    final d = expense.date;
    final dateStr = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MakaryaColors.surface01,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(expense.categoryCode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(dateStr, style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
          ),
          Text(rp(expense.amount),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MakaryaColors.lossRed, fontFamily: 'Inter')),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: MakaryaColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}