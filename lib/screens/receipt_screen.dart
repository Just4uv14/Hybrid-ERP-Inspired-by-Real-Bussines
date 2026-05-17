// =============================================================================
// MAKARYA HYBRID ERP — Receipt Screen (Struk Transaksi)
// File: lib/screens/receipt_screen.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../logic/pdf_service.dart';
import '../theme/makarya_theme.dart';


class ReceiptScreen extends StatefulWidget {
  final String trxCode;
  const ReceiptScreen({super.key, required this.trxCode});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Map<String, dynamic>? _transaction;
  bool _loading = true;
  bool _pdfGenerating = false;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadTransaction() async {
    final dash = context.read<DashboardProvider>();
    final data = await dash.fetchTransactionForReceipt(widget.trxCode);
    if (mounted) {
      setState(() {
        _transaction = data;
        _loading     = false;
      });
    }
  }

  Future<void> _generateAndSharePdf() async {
    if (_transaction == null) return;
    setState(() => _pdfGenerating = true);
    try {
      final bytes = await generateReceiptPdf(transaction: _transaction!);
      await sharePdf(bytes, fileName: 'Struk_${widget.trxCode}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal generate PDF: $e'), backgroundColor: MakaryaColors.lossRed),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  Future<void> _showEmailDialog() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MakaryaColors.surface01,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Kirim via Email', style: TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan email tujuan untuk mengirimkan struk ini.',
              style: TextStyle(color: MakaryaColors.textSecondary, fontFamily: 'Inter', fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'email@contoh.com',
                hintStyle: const TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                filled: true,
                fillColor: MakaryaColors.surface02,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email_outlined, size: 18, color: MakaryaColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MakaryaColors.woodBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(context);
              await openEmailWithReceipt(trxCode: widget.trxCode, recipientEmail: email);
            },
            child: const Text('Kirim', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MakaryaColors.darkEspresso,
      appBar: AppBar(
        backgroundColor: MakaryaColors.darkEspresso,
        elevation: 0,
        title: Text(
          'Struk — ${widget.trxCode}',
          style: const TextStyle(color: MakaryaColors.textPrimary, fontSize: 14, fontFamily: 'Inter', letterSpacing: 0.5),
        ),
        iconTheme: const IconThemeData(color: MakaryaColors.woodLight),
        actions: [
          if (!_loading && _transaction != null) ...[
            IconButton(
              icon: _pdfGenerating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: MakaryaColors.goldAccent))
                  : const Icon(Icons.share_rounded, size: 20, color: MakaryaColors.goldAccent),
              tooltip: 'Bagikan PDF',
              onPressed: _pdfGenerating ? null : _generateAndSharePdf,
            ),
            IconButton(
              icon: const Icon(Icons.email_rounded, size: 20, color: MakaryaColors.woodLight),
              tooltip: 'Kirim Email',
              onPressed: _showEmailDialog,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown))
          : _transaction == null
              ? _buildError()
              : _buildReceipt(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_rounded, size: 48, color: MakaryaColors.textMuted),
          const SizedBox(height: 16),
          Text('Transaksi ${widget.trxCode} tidak ditemukan.',
              style: const TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Widget _buildReceipt() {
    final t          = _transaction!;
    final grandTotal = (t['grand_total'] as num).toDouble();
    final discount   = (t['discount_amount'] as num? ?? 0).toDouble();
    final tax        = (t['tax_amount'] as num? ?? 0).toDouble();
    final service    = (t['service_amount'] as num? ?? 0).toDouble();
    final payMethod  = t['payment_method'] as String? ?? '-';
    final cashTender = t['cash_tendered'] != null ? (t['cash_tendered'] as num).toDouble() : null;
    final change     = t['change_given'] != null ? (t['change_given'] as num).toDouble() : null;
    final staffName  = t['staff_name'] as String? ?? 'Staff';
    final trxAt      = DateTime.parse(t['trx_at'] as String);
    final details    = (t['transaction_details'] as List);
    final subtotal   = details.fold<double>(
        0, (s, d) => s + (d['qty'] as num).toDouble() * (d['unit_price'] as num).toDouble());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              color: MakaryaColors.surface01,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Column(
              children: [
                // ── Store header ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: MakaryaColors.surface02,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [MakaryaColors.woodBrown, MakaryaColors.woodLight],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Text('M', style: TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w700, fontFamily: 'Inter',
                          )),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('MAKARYA',
                          style: TextStyle(color: MakaryaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: 2)),
                      const Text('Kafe Buku & Kopi',
                          style: TextStyle(color: MakaryaColors.textSecondary, fontSize: 11, fontFamily: 'Inter')),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ── Trx info ──────────────────────────────────────────
                      _DashedDivider(),
                      const SizedBox(height: 10),
                      _ReceiptRow(label: 'No Trx',   value: t['trx_code'] as String, isSmall: true),
                      _ReceiptRow(label: 'Kasir',    value: staffName,                isSmall: true),
                      _ReceiptRow(
                        label: 'Waktu',
                        value: '${trxAt.day}/${trxAt.month}/${trxAt.year}  '
                            '${trxAt.hour.toString().padLeft(2, '0')}:${trxAt.minute.toString().padLeft(2, '0')}',
                        isSmall: true,
                      ),
                      const SizedBox(height: 10),
                      _DashedDivider(),
                      const SizedBox(height: 10),

                      // ── Items ─────────────────────────────────────────────
                      ...details.map((d) {
                        final name  = d['items']?['name'] as String? ?? 'Item';
                        final qty   = (d['qty'] as num).toDouble();
                        final price = (d['unit_price'] as num).toDouble();
                        final disc  = (d['discount'] as num? ?? 0).toDouble();
                        final line  = qty * (price - disc);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(
                                  color: MakaryaColors.textPrimary, fontSize: 12,
                                  fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('  ${qty.toInt()}× ${_rp(price - disc)}',
                                      style: const TextStyle(color: MakaryaColors.textMuted, fontSize: 11, fontFamily: 'Inter')),
                                  Text(_rp(line),
                                      style: const TextStyle(color: MakaryaColors.textPrimary, fontSize: 11, fontFamily: 'Inter')),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 4),
                      _DashedDivider(),
                      const SizedBox(height: 10),

                      // ── Totals ────────────────────────────────────────────
                      _ReceiptRow(label: 'Subtotal',  value: _rp(subtotal)),
                      if (discount > 0)
                        _ReceiptRow(label: 'Diskon', value: '- ${_rp(discount)}', valueColor: MakaryaColors.lossRed),
                      if (tax > 0)
                        _ReceiptRow(label: 'PPN 11%', value: _rp(tax)),
                      if (service > 0)
                        _ReceiptRow(label: 'Service 5%', value: _rp(service)),

                      const SizedBox(height: 6),
                      Divider(color: MakaryaColors.woodBrown.withValues(alpha: 0.5), thickness: 0.8),
                      const SizedBox(height: 6),

                      _ReceiptRow(label: 'TOTAL', value: _rp(grandTotal), isBold: true, valueColor: MakaryaColors.goldAccent),
                      const SizedBox(height: 6),

                      _ReceiptRow(label: 'Bayar ($payMethod)', value: cashTender != null ? _rp(cashTender) : '-'),
                      if (change != null && change > 0)
                        _ReceiptRow(label: 'Kembali', value: _rp(change)),

                      const SizedBox(height: 16),
                      _DashedDivider(),
                      const SizedBox(height: 16),

                      // ── Footer ────────────────────────────────────────────
                      const Text('Terima kasih!',
                          style: TextStyle(color: MakaryaColors.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                      const SizedBox(height: 4),
                      const Text('Selamat membaca & menikmati kopi ☕',
                          style: TextStyle(color: MakaryaColors.textMuted, fontSize: 10, fontFamily: 'Inter')),
                      const SizedBox(height: 12),
                      Text(t['trx_code'] as String,
                          style: const TextStyle(color: MakaryaColors.textMuted, fontSize: 9,
                              fontFamily: 'Inter', letterSpacing: 1.5)),
                    ],
                  ),
                ),

                // ── Action buttons ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.5)),
                            foregroundColor: MakaryaColors.woodLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('PDF', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                          onPressed: _pdfGenerating ? null : _generateAndSharePdf,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MakaryaColors.woodBrown,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.email_rounded, size: 16),
                          label: const Text('Email', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                          onPressed: _showEmailDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  final String label, value;
  final bool isBold, isSmall;
  final Color? valueColor;

  const _ReceiptRow({
    required this.label, required this.value,
    this.isBold = false, this.isSmall = false, this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
            color: MakaryaColors.textSecondary, fontSize: isSmall ? 10 : 11, fontFamily: 'Inter')),
        Text(value, style: TextStyle(
            color: valueColor ?? MakaryaColors.textPrimary,
            fontSize: isSmall ? 10 : 11,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            fontFamily: 'Inter')),
      ],
    ),
  );
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      28,
      (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 0.6,
          color: i % 2 == 0 ? MakaryaColors.woodBrown.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
    ),
  );
}

String _rp(double v) => 'Rp ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
