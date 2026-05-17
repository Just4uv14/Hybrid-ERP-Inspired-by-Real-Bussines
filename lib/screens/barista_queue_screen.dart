import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';

class BaristaQueueScreen extends StatefulWidget {
  const BaristaQueueScreen({super.key});
  @override
  State<BaristaQueueScreen> createState() => _BaristaQueueScreenState();
}

class _BaristaQueueScreenState extends State<BaristaQueueScreen> {
  List<Map<String, dynamic>> _queue = [];
  bool _loading = true;
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadQueue();
    _subscribeRealtime();
  }

    void _subscribeRealtime() {
    _channel = _supabase
        .channel('barista_queue_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            if (mounted) _loadQueue();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    try {
      final data = await _supabase.from('vw_barista_queue').select();
      if (mounted) {
        setState(() {
          _queue   = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Update status pesanan ──────────────────────────────────────────────────
  Future<void> _updateOrderStatus(String trxCode, String newStatus) async {
    final staffId = context.read<AuthProvider>().session?.staffId;
    if (staffId == null) return;

    try {
      final result = await _supabase.rpc('barista_update_order_status', params: {
        'p_trx_code':   trxCode,
        'p_new_status': newStatus,
        'p_staff_id':   staffId,
      });

      final res = result as Map<String, dynamic>;

      if (res['success'] == true) {
        // Jika DONE, deduct ingredients otomatis
        if (newStatus == 'DONE') {
          await _supabase.rpc('deduct_ingredients_for_order', params: {
            'p_trx_code': trxCode,
          });
        }
        await _loadQueue();
        if (mounted) {
          _showSnack(
            newStatus == 'READY' ? '✅ Pesanan siap!' : '🎉 Pesanan selesai!',
            MakaryaColors.profitGreen,
          );
        }
      } else {
        if (mounted) {
          _showSnack(res['message'] as String? ?? 'Gagal update', MakaryaColors.lossRed);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', MakaryaColors.lossRed);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Inter', color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown))
        : RefreshIndicator(
            onRefresh: _loadQueue,
            color: MakaryaColors.woodBrown,
            child: Column(
              children: [
                // ── Refresh bar ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(children: [
                    Text(
                      '${_queue.length} pesanan aktif',
                      style: const TextStyle(
                        fontSize:   12,
                        color:      MakaryaColors.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadQueue,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:        MakaryaColors.surface02.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: MakaryaColors.woodBrown.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.refresh_rounded,
                              size: 13, color: MakaryaColors.textMuted),
                          const SizedBox(width: 5),
                          const Text('Refresh',
                              style: TextStyle(
                                fontSize:   11,
                                color:      MakaryaColors.textMuted,
                                fontFamily: 'Inter',
                              )),
                        ]),
                      ),
                    ),
                  ]),
                ),
                // ── Queue list ────────────────────────────────────────────
                Expanded(
                  child: _queue.isEmpty
                      ? const Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.coffee_rounded, size: 48, color: MakaryaColors.textMuted),
                            SizedBox(height: 12),
                            Text('Tidak ada pesanan saat ini',
                                style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                          ]))
                      : ListView.builder(
                          padding:   const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _queue.length,
                          itemBuilder: (_, i) => _QueueCard(
                            order:          _queue[i],
                            onUpdateStatus: _updateOrderStatus,
                          ),
                        ),
                ),
              ],
            ),
          );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE CARD — dengan tombol status update
// ─────────────────────────────────────────────────────────────────────────────

class _QueueCard extends StatefulWidget {
  final Map<String, dynamic>                    order;
  final Future<void> Function(String, String)   onUpdateStatus;

  const _QueueCard({required this.order, required this.onUpdateStatus});

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  bool _updating = false;

  String get _trxCode => widget.order['trx_code'] as String? ?? '';
  int    get _minutes => (widget.order['minutes_waiting'] as num?)?.toInt() ?? 0;
  List   get _items   => widget.order['order_items'] as List? ?? [];
  String get _status {
    final raw = widget.order['status'] as String?;
    if (raw == null || raw.trim().isEmpty) return 'PENDING'; // fallback aman
    return raw.trim().toUpperCase();
  }

  bool get _isUrgent   => _minutes >= 10;
  bool get _isPending  => _status == 'PENDING' || _status == 'IN_PROGRESS';
  bool get _isReady    => _status == 'READY';
  bool get _isDone     => _status == 'DONE';

  Future<void> _handleTap() async {
    final nextStatus = _isPending ? 'READY' : 'DONE';
    final label      = _isPending ? 'Tandai Siap' : 'Selesaikan';
    final confirm    = await _showConfirmDialog(label, nextStatus);
    if (!confirm) return;

    setState(() => _updating = true);
    await widget.onUpdateStatus(_trxCode, nextStatus);
    if (mounted) setState(() => _updating = false);
  }

  Future<bool> _showConfirmDialog(String label, String nextStatus) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MakaryaColors.surface02,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          label,
          style: const TextStyle(
              color: MakaryaColors.textPrimary, fontFamily: 'Inter',
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          nextStatus == 'READY'
              ? 'Tandai pesanan $_trxCode sudah siap untuk diambil?'
              : 'Selesaikan pesanan $_trxCode? Stok bahan akan otomatis dikurangi.',
          style: const TextStyle(
              color: MakaryaColors.textSecondary, fontFamily: 'Inter', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus == 'READY'
                  ? MakaryaColors.warningAmber
                  : MakaryaColors.profitGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'Inter',
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isDone
        ? MakaryaColors.profitGreen.withValues(alpha: 0.4)
        : _isReady
            ? MakaryaColors.warningAmber.withValues(alpha: 0.5)
            : _isUrgent
                ? MakaryaColors.lossRed.withValues(alpha: 0.5)
                : MakaryaColors.woodBrown.withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        MakaryaColors.surface01,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor,
            width: (_isDone || _isReady || _isUrgent) ? 1 : 0.5),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              // TRX code badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        MakaryaColors.woodBrown.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_trxCode,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: MakaryaColors.woodLight, fontFamily: 'Inter')),
              ),
              const SizedBox(width: 8),
              // Status badge
              _StatusBadge(status: _status),
              const Spacer(),
              // Timer badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isUrgent
                      ? MakaryaColors.lossRed.withValues(alpha: 0.15)
                      : MakaryaColors.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_rounded, size: 12,
                      color: _isUrgent
                          ? MakaryaColors.lossRed
                          : MakaryaColors.warningAmber),
                  const SizedBox(width: 4),
                  Text('$_minutes mnt',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter',
                          color: _isUrgent
                              ? MakaryaColors.lossRed
                              : MakaryaColors.warningAmber)),
                ]),
              ),
            ]),
          ),

          // ── Items list ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: _items.map((item) {
                final name    = item['item']     as String? ?? '-';
                final qty     = item['qty'];
                final notes   = item['notes']    as String?;
                final prepSec = item['prep_sec'] as int?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color:        MakaryaColors.woodBrown.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text('$qty',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: MakaryaColors.goldAccent, fontFamily: 'Inter')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                        if (notes != null && notes.isNotEmpty)
                          Text(notes,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: MakaryaColors.warningAmber,
                                  fontFamily: 'Inter')),
                      ]),
                    ),
                    if (prepSec != null)
                      Text('${(prepSec / 60).ceil()} mnt',
                          style: const TextStyle(
                              fontSize: 9,
                              color: MakaryaColors.textMuted,
                              fontFamily: 'Inter')),
                  ]),
                );
              }).toList(),
            ),
          ),

          // ── Action button (hanya kalau belum DONE) ───────────────────────────
          if (!_isDone) ...[
            const Divider(height: 1, color: Color(0x22FFFFFF)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: _updating
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MakaryaColors.woodBrown),
                        ))
                    : ElevatedButton.icon(
                        onPressed: _handleTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPending
                              ? MakaryaColors.warningAmber
                              : MakaryaColors.profitGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: Icon(
                          _isPending
                              ? Icons.coffee_rounded
                              : Icons.check_circle_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _isPending ? 'Tandai Siap' : 'Selesaikan Pesanan',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              fontFamily: 'Inter'),
                        ),
                      ),
              ),
            ),
          ] else ...[
            // Done state indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: MakaryaColors.profitGreen),
                const SizedBox(width: 6),
                Text('Pesanan selesai',
                    style: TextStyle(
                        fontSize: 11,
                        color: MakaryaColors.profitGreen.withValues(alpha: 0.9),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'READY'       => (MakaryaColors.warningAmber, 'SIAP'),
      'DONE'        => (MakaryaColors.profitGreen,  'SELESAI'),
      'IN_PROGRESS' => (MakaryaColors.infoBlue,     'PROSES'),
      _             => (MakaryaColors.textMuted,     'PENDING'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize:   9,
              fontWeight: FontWeight.w700,
              color:      color,
              fontFamily: 'Inter',
              letterSpacing: 0.5)),
    );
  }
}