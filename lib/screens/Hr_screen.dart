// =============================================================================
// MAKARYA ERP — HR Screen
// Tab container: Karyawan | Jadwal | Absensi Live
// Hanya bisa diakses role Manager
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../providers/hr_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';
import '../supabase_config.dart';

final _kResendApiKey = resendApiKey;
const _kFromEmail    = 'onboarding@resend.dev'; 

class HRScreen extends StatefulWidget {
  const HRScreen({super.key});
  @override
  State<HRScreen> createState() => _HRScreenState();
}

class _HRScreenState extends State<HRScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HRProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Tab bar ───────────────────────────────────────────────────────────
      Container(
        color: MakaryaColors.surface01,
        child: TabBar(
          controller: _tab,
          labelColor:       MakaryaColors.woodLight,
          unselectedLabelColor: MakaryaColors.textMuted,
          indicatorColor:   MakaryaColors.woodBrown,
          indicatorWeight:  2,
          labelStyle:   const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded,         size: 18), text: 'Karyawan'),
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Jadwal'),
            Tab(icon: Icon(Icons.fact_check_rounded,     size: 18), text: 'Absensi'),
            Tab(icon: Icon(Icons.history_rounded,        size: 18), text: 'History'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: const [
            _StaffTab(),
            _ScheduleTab(),
            _AttendanceTab(),
            _HistoryTab(),
          ],
        ),
      ),
    ]);
  }
}

// =============================================================================
// TAB KARYAWAN
// =============================================================================

class _StaffTab extends StatefulWidget {
  const _StaffTab();
  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  String _search = '';
  bool   _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final hr   = context.watch<HRProvider>();
    final auth = context.read<AuthProvider>();

    if (hr.loading) {
      return const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown));
    }
    if (hr.error != null) {
  return Center(child: Text('ERROR: ${hr.error!}', 
      style: const TextStyle(color: Colors.red, fontSize: 12)));
}
if (hr.staffList.isEmpty) {
  return Center(child: Text('Staff kosong — error: ${hr.error ?? "null"}', 
      style: const TextStyle(color: Colors.white)));
}

    final filtered = hr.staffList.where((s) {
      final matchSearch = _search.isEmpty ||
          s.fullName.toLowerCase().contains(_search.toLowerCase()) ||
          s.employeeId.toLowerCase().contains(_search.toLowerCase());
      final matchActive = _showInactive ? true : s.isActive;
      return matchSearch && matchActive;
    }).toList();

    return Column(children: [
      // ── Search + filter bar ───────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        color: MakaryaColors.surface01,
        child: Row(children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari nama atau ID karyawan…',
                hintStyle: const TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: MakaryaColors.textMuted),
                filled: true,
                fillColor: MakaryaColors.surface02,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle nonaktif
          GestureDetector(
            onTap: () => setState(() => _showInactive = !_showInactive),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _showInactive
                    ? MakaryaColors.woodBrown.withValues(alpha: 0.2)
                    : MakaryaColors.surface02,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showInactive
                      ? MakaryaColors.woodBrown.withValues(alpha: 0.5)
                      : MakaryaColors.surface02,
                ),
              ),
              child: Row(children: [
                Icon(Icons.filter_list_rounded, size: 16,
                    color: _showInactive ? MakaryaColors.woodLight : MakaryaColors.textMuted),
                const SizedBox(width: 4),
                Text('Nonaktif',
                    style: TextStyle(
                      fontSize: 11, fontFamily: 'Inter',
                      color: _showInactive ? MakaryaColors.woodLight : MakaryaColors.textMuted,
                    )),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // Tombol tambah
          GestureDetector(
            onTap: () => _showAddStaffSheet(context, hr, auth),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MakaryaColors.woodBrown,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
            ),
          ),
        ]),
      ),

      // ── Summary chips ─────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        color: MakaryaColors.surface01,
        child: Row(children: [
          _SummaryChip(
            label: '${hr.staffList.where((s) => s.isActive).length} Aktif',
            color: MakaryaColors.profitGreen,
            icon:  Icons.check_circle_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: '${hr.staffList.where((s) => !s.isActive).length} Nonaktif',
            color: MakaryaColors.textMuted,
            icon:  Icons.cancel_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: '${hr.totalPresentToday} Hadir Hari Ini',
            color: MakaryaColors.infoBlue,
            icon:  Icons.how_to_reg_rounded,
          ),
        ]),
      ),

      // ── Staff list ────────────────────────────────────────────────────────
      Expanded(
        child: filtered.isEmpty
            ? const Center(
                child: Text('Tidak ada karyawan ditemukan',
                    style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _StaffCard(
                  staff:    filtered[i],
                  hr:       hr,
                  auth:     auth,
                  onEdit:   () => _showEditStaffSheet(context, filtered[i], hr, auth),
                  onQR:     () => _showQRSheet(context, filtered[i], hr, auth),
                ),
              ),
      ),
    ]);
  }

  // ── Add Staff Bottom Sheet ────────────────────────────────────────────────
  void _showAddStaffSheet(BuildContext ctx, HRProvider hr, AuthProvider auth) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MakaryaColors.surface02,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _StaffFormSheet(
        hr:       hr,
        auth:     auth,
        staff:    null,
        onSaved:  () => Navigator.pop(sheetCtx),
      ),
    );
  }

  // ── Edit Staff Bottom Sheet ───────────────────────────────────────────────
  void _showEditStaffSheet(BuildContext ctx, StaffModel staff, HRProvider hr, AuthProvider auth) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MakaryaColors.surface02,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _StaffFormSheet(
        hr:      hr,
        auth:    auth,
        staff:   staff,
        onSaved: () => Navigator.pop(sheetCtx),
      ),
    );
  }

  // ── QR Code Sheet ─────────────────────────────────────────────────────────
  void _showQRSheet(BuildContext ctx, StaffModel staff, HRProvider hr, AuthProvider auth) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MakaryaColors.surface02,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _QRSheet(
        staff: staff,
        hr:    hr,
        auth:  auth,
      ),
    );
  }
}

// ── Staff Card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffModel  staff;
  final HRProvider  hr;
  final AuthProvider auth;
  final VoidCallback onEdit;
  final VoidCallback onQR;

  const _StaffCard({
    required this.staff,
    required this.hr,
    required this.auth,
    required this.onEdit,
    required this.onQR,
  });

  Color _roleColor() => switch (staff.role.toUpperCase()) {
    'MANAGER'      => MakaryaColors.goldAccent,
    'CASHIER'      => MakaryaColors.infoBlue,
    'BARISTA'      => MakaryaColors.woodBrown,
    'STOCK_KEEPER' => MakaryaColors.profitGreen,
    'RESEARCHER'   => const Color(0xFF8B5CF6),
    _              => MakaryaColors.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _roleColor();
    return Container(
      decoration: BoxDecoration(
        color: MakaryaColors.surface02,
        borderRadius: BorderRadius.circular(12),
        // [FIX] Border non-uniform tidak bisa pakai borderRadius
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // ── Avatar ───────────────────────────────────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
            ),
            child: Center(
              child: Text(staff.initials,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: accent, fontFamily: 'Inter')),
            ),
          ),
          const SizedBox(width: 12),

          // ── Info ─────────────────────────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(staff.fullName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                const SizedBox(width: 6),
                if (!staff.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MakaryaColors.lossRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Nonaktif',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                            color: MakaryaColors.lossRed, fontFamily: 'Inter')),
                  ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Text(staff.employeeId,
                    style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(staff.roleLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: accent, fontFamily: 'Inter')),
                ),
              ]),
              if (staff.email != null) ...[
                const SizedBox(height: 3),
                Text(staff.email!,
                    style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted,
                        fontFamily: 'Inter')),
              ],
            ]),
          ),

          // ── Actions ──────────────────────────────────────────────────────
          Column(children: [
            // QR button
            GestureDetector(
              onTap: onQR,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: MakaryaColors.woodBrown.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_rounded, size: 17, color: MakaryaColors.woodBrown),
              ),
            ),
            const SizedBox(height: 6),
            // Edit button
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: MakaryaColors.infoBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, size: 17, color: MakaryaColors.infoBlue),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Staff Form Sheet (Add / Edit) ─────────────────────────────────────────────

class _StaffFormSheet extends StatefulWidget {
  final HRProvider   hr;
  final AuthProvider auth;
  final StaffModel?  staff;
  final VoidCallback onSaved;
  const _StaffFormSheet({required this.hr, required this.auth, this.staff, required this.onSaved});
  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey      = GlobalKey<FormState>();
  late TextEditingController _idCtrl, _nameCtrl, _pinCtrl, _emailCtrl, _phoneCtrl;
  String _role  = 'CASHIER';
  String _shift = 'MORNING';
  bool   _saving = false;
  String? _err;

  final _roles  = ['MANAGER', 'CASHIER', 'BARISTA', 'STOCK_KEEPER', 'RESEARCHER'];
  final _shifts = ['MORNING', 'EVENING', 'FULL'];

  String _roleLabel(String r) => switch (r) {
    'MANAGER'      => 'Manager',
    'CASHIER'      => 'Kasir',
    'BARISTA'      => 'Barista',
    'STOCK_KEEPER' => 'Stock Keeper',
    'RESEARCHER'   => 'Researcher',
    _              => r,
  };

  String _shiftLabel(String s) => switch (s) {
    'MORNING' => 'Shift Pagi (07:00–15:00)',
    'EVENING' => 'Shift Sore (15:00–23:00)',
    'FULL'    => 'Full Day',
    _         => s,
  };

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _idCtrl    = TextEditingController(text: s?.employeeId ?? '');
    _nameCtrl  = TextEditingController(text: s?.fullName   ?? '');
    _pinCtrl   = TextEditingController();
    _emailCtrl = TextEditingController(text: s?.email      ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone      ?? '');
    _role      = s?.role.toUpperCase()  ?? 'CASHIER';
    _shift     = s?.shift.toUpperCase() ?? 'MORNING';
  }

  @override
  void dispose() {
    for (final c in [_idCtrl, _nameCtrl, _pinCtrl, _emailCtrl, _phoneCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _err = null; });

    final isEdit = widget.staff != null;
    String? error;

    if (isEdit) {
      error = await widget.hr.updateStaff(
        staffId:  widget.staff!.id,
        fullName: _nameCtrl.text.trim(),
        role:     _role,
        shift:    _shift,
        email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
    } else {
      error = await widget.hr.addStaff(
        employeeId: _idCtrl.text.trim(),
        fullName:   _nameCtrl.text.trim(),
        role:       _role,
        shift:      _shift,
        pin:        _pinCtrl.text.trim(),
        email:      _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone:      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
    }

    setState(() => _saving = false);
    if (error == null) {
      widget.onSaved();
    } else {
      setState(() => _err = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit    = widget.staff != null;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardH + 24),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(child: Container(
              width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: MakaryaColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2)),
            )),
            // Title
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                    size: 17, color: MakaryaColors.woodBrown),
              ),
              const SizedBox(width: 10),
              Text(isEdit ? 'Edit Karyawan' : 'Tambah Karyawan',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
            ]),
            const SizedBox(height: 20),

            // Error
            if (_err != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MakaryaColors.lossRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_err!, style: const TextStyle(color: MakaryaColors.lossRed,
                    fontSize: 12, fontFamily: 'Inter')),
              ),
              const SizedBox(height: 12),
            ],

            // Employee ID (hanya saat tambah)
            if (!isEdit) ...[
              TextFormField(
                controller: _idCtrl,
                style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                decoration: const InputDecoration(labelText: 'Employee ID (misal: EMP-006)'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
            ],

            // Nama
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            // PIN (hanya saat tambah)
            if (!isEdit) ...[
              TextFormField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                decoration: const InputDecoration(labelText: 'PIN (6 digit)'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'PIN wajib diisi';
                  if (v.length < 4) return 'Minimal 4 digit';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Role
            DropdownButtonFormField<String>(
              value: _role,
              dropdownColor: MakaryaColors.surface02,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 14),
              decoration: const InputDecoration(labelText: 'Role'),
              items: _roles.map((r) => DropdownMenuItem(
                value: r,
                child: Text(_roleLabel(r)),
              )).toList(),
              onChanged: (v) => setState(() => _role = v ?? 'CASHIER'),
            ),
            const SizedBox(height: 12),

            // Shift default
            DropdownButtonFormField<String>(
              value: _shift,
              dropdownColor: MakaryaColors.surface02,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 14),
              decoration: const InputDecoration(labelText: 'Shift Default'),
              items: _shifts.map((s) => DropdownMenuItem(
                value: s,
                child: Text(_shiftLabel(s)),
              )).toList(),
              onChanged: (v) => setState(() => _shift = v ?? 'MORNING'),
            ),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
              decoration: const InputDecoration(
                labelText: 'Email (untuk kirim QR)',
                prefixIcon: Icon(Icons.email_rounded, size: 18, color: MakaryaColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),

            // Phone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
              decoration: const InputDecoration(
                labelText: 'No. HP (opsional)',
                prefixIcon: Icon(Icons.phone_rounded, size: 18, color: MakaryaColors.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MakaryaColors.woodBrown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Karyawan',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600,
                            fontFamily: 'Inter')),
              ),
            ),

            // Toggle nonaktif (hanya edit)
            if (isEdit) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: MakaryaColors.surface02,
                        title: Text(
                          widget.staff!.isActive ? 'Nonaktifkan Karyawan?' : 'Aktifkan Karyawan?',
                          style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                        ),
                        content: Text(
                          widget.staff!.isActive
                              ? '${widget.staff!.fullName} tidak akan bisa login.'
                              : '${widget.staff!.fullName} akan bisa login kembali.',
                          style: const TextStyle(color: MakaryaColors.textSecondary, fontFamily: 'Inter'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal')),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                              child: Text(widget.staff!.isActive ? 'Nonaktifkan' : 'Aktifkan',
                                  style: TextStyle(
                                    color: widget.staff!.isActive
                                        ? MakaryaColors.lossRed : MakaryaColors.profitGreen,
                                  ))),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await widget.hr.toggleStaffActive(
                          widget.staff!.id, !widget.staff!.isActive);
                      if (mounted) widget.onSaved();
                    }
                  },
                  child: Text(
                    widget.staff!.isActive ? 'Nonaktifkan Karyawan' : 'Aktifkan Karyawan',
                    style: TextStyle(
                      color: widget.staff!.isActive ? MakaryaColors.lossRed : MakaryaColors.profitGreen,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── QR Sheet ──────────────────────────────────────────────────────────────────

class _QRSheet extends StatefulWidget {
  final StaffModel   staff;
  final HRProvider   hr;
  final AuthProvider auth;
  const _QRSheet({required this.staff, required this.hr, required this.auth});
  @override
  State<_QRSheet> createState() => _QRSheetState();
}

class _QRSheetState extends State<_QRSheet> {
  bool _regenerating = false;
  bool _sending      = false;

  String get _qrData => 'makarya://attend?token=${widget.staff.qrToken ?? ""}';

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    await widget.hr.regenerateQRToken(
      widget.staff.id,
      widget.auth.session!.staffId,
    );
    setState(() => _regenerating = false);
  }

  // [FIX] Kirim QR langsung via Resend API
  // [FIX] Via Supabase Edge Function - avoid CORS
  Future<void> _sendEmail() async {
    final email = widget.staff.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email karyawan belum diisi')),
      );
      return;
    }
    final token = widget.staff.qrToken ?? '';
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Token belum ada, generate dulu')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await http.post(
        Uri.parse('https://bitsqlyrcnjhwaxmtxbt.supabase.co/functions/v1/swift-service'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ""}',
        },
        body: jsonEncode({
          'to':        email,
          'staffName': widget.staff.fullName,
          'token':     token,
        }),
      );
      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Email berhasil dikirim ke $email'),
            backgroundColor: Colors.green.shade700,
          ));
        } else {
          final b = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal: ${b["error"] ?? b["message"] ?? response.statusCode}'),
            backgroundColor: Colors.red.shade700,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final token   = widget.staff.qrToken;
    final hasToken = token != null && token.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).padding.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: MakaryaColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2)),
        )),

        // Header
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: MakaryaColors.woodBrown.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(widget.staff.initials,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: MakaryaColors.woodBrown, fontFamily: 'Inter')),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.staff.fullName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
            Text('${widget.staff.employeeId}  ·  ${widget.staff.roleLabel}',
                style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
          ]),
        ]),
        const SizedBox(height: 24),

        // QR Code
        if (hasToken) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: SizedBox(
              width: 200, height: 200,
              child: PrettyQrView.data(
                data: _qrData,
                decoration: const PrettyQrDecoration(
                  image: null,
                  shape: PrettyQrSmoothSymbol(color: Color(0xFF1A1A1B)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Token: ${token.substring(0, 8)}••••',
              style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted,
                  fontFamily: 'Inter', fontFeatures: [FontFeature.tabularFigures()])),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: MakaryaColors.surface01,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(children: [
              Icon(Icons.qr_code_2_rounded, size: 48, color: MakaryaColors.textMuted),
              SizedBox(height: 8),
              Text('Belum ada QR token',
                  style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
            ]),
          ),
        ],
        const SizedBox(height: 20),

        // Actions
        Row(children: [
          // Regenerate
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _regenerating ? null : _regenerate,
              icon: _regenerating
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Regenerate QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MakaryaColors.warningAmber,
                side: BorderSide(color: MakaryaColors.warningAmber.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Kirim email
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (!hasToken || _sending) ? null : _sendEmail,
              icon: _sending
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.email_rounded, size: 16, color: Colors.white),
              label: const Text('Kirim ke Email',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MakaryaColors.woodBrown,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),

        if (widget.staff.email != null) ...[
          const SizedBox(height: 8),
          Text('Email: ${widget.staff.email}',
              style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
        ],
      ]),
    );
  }
}

// ── Summary Chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String  label;
  final Color   color;
  final IconData icon;
  const _SummaryChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: color, fontFamily: 'Inter')),
    ]),
  );
}

// ── Placeholder Tabs (akan diisi di Tahap 3 & 4) ─────────────────────────────

// ── Schedule Tab ──────────────────────────────────────────────────────────────

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();
  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  DateTime _weekStart = _getMonday(DateTime.now());

  static DateTime _getMonday(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  bool get _isCurrentWeek {
    final now = DateTime.now();
    final mon = _getMonday(now);
    return _weekStart.year == mon.year &&
           _weekStart.month == mon.month &&
           _weekStart.day == mon.day;
  }

  String _monthRange() {
    final end = _weekDays.last;
    if (_weekStart.month == end.month) {
      return '${_monthName(_weekStart.month)} ${_weekStart.year}';
    }
    return '${_monthName(_weekStart.month)} – ${_monthName(end.month)} ${end.year}';
  }

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ][m];

  String _dayName(int wd) => const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][wd - 1];

  @override
  Widget build(BuildContext context) {
    final hr      = context.watch<HRProvider>();
    final staff   = hr.staffList.where((s) => s.isActive).toList();
    final shifts  = hr.shifts;
    final today   = DateTime.now();

    return Column(children: [
      // ── Week navigator ─────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: MakaryaColors.surface02,
        child: Row(children: [
          IconButton(
            onPressed: _prevWeek,
            icon: const Icon(Icons.chevron_left_rounded, color: MakaryaColors.textSecondary),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(children: [
              Text(_monthRange(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
              Text('${_weekDays.first.day} – ${_weekDays.last.day}',
                  style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
            ]),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right_rounded, color: MakaryaColors.textSecondary),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
          if (!_isCurrentWeek) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _weekStart = _getMonday(DateTime.now())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.3), width: 0.5),
                ),
                child: const Text('Hari ini',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: MakaryaColors.woodBrown, fontFamily: 'Inter')),
              ),
            ),
          ],
        ]),
      ),

      // ── Shift legend ───────────────────────────────────────────────────────
      if (shifts.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: MakaryaColors.darkEspresso,
          child: Row(children: [
            const Text('Shift: ', style: TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
            ...shifts.map((s) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _hexColor(s.colorHex),
                      borderRadius: BorderRadius.circular(3),
                    )),
                const SizedBox(width: 4),
                Text('${s.name} (${s.startTime.substring(0, 5)}–${s.endTime.substring(0, 5)})',
                    style: const TextStyle(fontSize: 10, color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
              ]),
            )),
          ]),
        ),

      // ── Grid header (hari) ─────────────────────────────────────────────────
      Container(
        color: MakaryaColors.surface01,
        child: Row(children: [
          // Kolom nama karyawan
          const SizedBox(width: 90),
          ..._weekDays.map((d) {
            final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
            return Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? MakaryaColors.woodBrown.withValues(alpha: 0.15) : null,
                border: Border(left: BorderSide(color: MakaryaColors.surface02, width: 1)),
              ),
              child: Column(children: [
                Text(_dayName(d.weekday),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: isToday ? MakaryaColors.woodBrown : MakaryaColors.textMuted,
                        fontFamily: 'Inter')),
                Text('${d.day}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isToday ? MakaryaColors.woodBrown : MakaryaColors.textSecondary,
                        fontFamily: 'Inter')),
              ]),
            ));
          }),
        ]),
      ),

      // ── Grid body (karyawan × hari) ────────────────────────────────────────
      Expanded(
        child: hr.scheduleLoading
            ? const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown))
            : staff.isEmpty
                ? const Center(child: Text('Belum ada karyawan aktif',
                    style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')))
                : ListView.builder(
                    itemCount: staff.length,
                    itemBuilder: (ctx, i) {
                      final s = staff[i];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(
                              color: MakaryaColors.surface02, width: 1)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          // Nama karyawan
                          SizedBox(width: 90,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.fullName.split(' ').first,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                        color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                                    overflow: TextOverflow.ellipsis),
                                Text(s.roleLabel,
                                    style: const TextStyle(fontSize: 9, color: MakaryaColors.textMuted,
                                        fontFamily: 'Inter')),
                              ]),
                            ),
                          ),
                          // Sel per hari
                          ..._weekDays.map((d) {
                            final isToday = d.year == today.year &&
                                d.month == today.month && d.day == today.day;
                            final sched = hr.getSchedule(s.id, d);
                            return Expanded(child: GestureDetector(
                              onTap: () => _showAssignSheet(ctx, s, d, sched, shifts, hr),
                              child: Container(
                                height: 52,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? MakaryaColors.woodBrown.withValues(alpha: 0.08)
                                      : MakaryaColors.surface01,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isToday
                                        ? MakaryaColors.woodBrown.withValues(alpha: 0.3)
                                        : MakaryaColors.surface02,
                                    width: 1,
                                  ),
                                ),
                                child: sched == null
                                    ? const Icon(Icons.add_rounded, size: 14,
                                        color: MakaryaColors.textMuted)
                                    : sched.isDayOff
                                        ? const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.beach_access_rounded, size: 14,
                                                  color: MakaryaColors.textMuted),
                                              Text('OFF', style: TextStyle(fontSize: 8,
                                                  color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                                            ])
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _hexColor(sched.shiftColor ?? '#8B6914')
                                                      .withValues(alpha: 0.25),
                                                  borderRadius: BorderRadius.circular(4),
                                                 border: Border.all(
                                                  color: _hexColor(sched.shiftColor ?? '#8B6914').withValues(alpha: 0.5),
                                                  width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  sched.shiftCode == 'MORNING' ? 'Pagi' : 'Sore',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 9, fontWeight: FontWeight.w700,
                                                    color: _hexColor(sched.shiftColor ?? '#8B6914'),
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                sched.startTime != null
                                                    ? sched.startTime!.substring(0, 5)
                                                    : '',
                                                style: const TextStyle(fontSize: 8,
                                                    color: MakaryaColors.textMuted, fontFamily: 'Inter'),
                                              ),
                                            ],
                                          ),
                              ),
                            ));
                          }),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _showAssignSheet(
    BuildContext ctx,
    dynamic staff,
    DateTime date,
    dynamic currentSched,
    List<dynamic> shifts,
    HRProvider hr,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: MakaryaColors.surface02,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => _AssignShiftSheet(
        staff: staff,
        date: date,
        currentSched: currentSched,
        shifts: shifts,
        hr: hr,
      ),
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ── Assign Shift Bottom Sheet ─────────────────────────────────────────────────

class _AssignShiftSheet extends StatefulWidget {
  final dynamic staff;
  final DateTime date;
  final dynamic currentSched;
  final List<dynamic> shifts;
  final HRProvider hr;

  const _AssignShiftSheet({
    required this.staff,
    required this.date,
    required this.currentSched,
    required this.shifts,
    required this.hr,
  });

  @override
  State<_AssignShiftSheet> createState() => _AssignShiftSheetState();
}

class _AssignShiftSheetState extends State<_AssignShiftSheet> {
  int?    _selectedShiftId;
  bool    _isDayOff = false;
  bool    _saving   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.currentSched != null) {
      _isDayOff        = widget.currentSched.isDayOff;
      _selectedShiftId = widget.currentSched.shiftId;
    }
  }

  String _dayLabel(DateTime d) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const mons = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${days[d.weekday - 1]}, ${d.day} ${mons[d.month]} ${d.year}';
  }

  Future<void> _save() async {
    if (!_isDayOff && _selectedShiftId == null) {
      setState(() => _error = 'Pilih shift terlebih dahulu');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final err = await widget.hr.assignSchedule(
      staffId:   widget.staff.id,
      date:      widget.date,
      shiftId:   _selectedShiftId,
      isDayOff:  _isDayOff,
    );

    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _saving = false; });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (widget.currentSched == null) return;
    setState(() { _saving = true; _error = null; });
    await widget.hr.deleteSchedule(widget.currentSched.scheduleId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardH + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Handle
        Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: MakaryaColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2)))),

        // Header
        Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_calendar_rounded, size: 18, color: MakaryaColors.woodBrown)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.staff.fullName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
            Text(_dayLabel(widget.date),
                style: const TextStyle(fontSize: 11, color: MakaryaColors.textMuted, fontFamily: 'Inter')),
          ])),
          if (widget.currentSched != null)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: MakaryaColors.lossRed, size: 20),
              tooltip: 'Hapus jadwal',
            ),
        ]),
        const SizedBox(height: 20),

        // Toggle hari libur
        GestureDetector(
          onTap: () => setState(() { _isDayOff = !_isDayOff; _selectedShiftId = null; }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isDayOff
                  ? MakaryaColors.infoBlue.withValues(alpha: 0.1)
                  : MakaryaColors.surface01,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isDayOff
                    ? MakaryaColors.infoBlue.withValues(alpha: 0.4)
                    : MakaryaColors.surface02,
                width: 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.beach_access_rounded,
                  color: _isDayOff ? MakaryaColors.infoBlue : MakaryaColors.textMuted, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Hari Libur / OFF',
                  style: TextStyle(fontSize: 13, color: MakaryaColors.textPrimary,
                      fontFamily: 'Inter', fontWeight: FontWeight.w500))),
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _isDayOff ? MakaryaColors.infoBlue : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isDayOff ? MakaryaColors.infoBlue : MakaryaColors.textMuted,
                    width: 1.5,
                  ),
                ),
                child: _isDayOff
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ]),
          ),
        ),

        if (!_isDayOff) ...[
          const SizedBox(height: 12),
          const Text('Pilih Shift', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: MakaryaColors.textMuted, letterSpacing: 0.5, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          ...widget.shifts.map((sh) {
            final accent = Color(int.parse('FF${sh.colorHex.replaceFirst('#', '')}', radix: 16));
            final selected = _selectedShiftId == sh.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedShiftId = sh.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: 0.12) : MakaryaColors.surface01,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? accent.withValues(alpha: 0.5) : MakaryaColors.surface02,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 4, height: 36,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sh.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: selected ? accent : MakaryaColors.textPrimary, fontFamily: 'Inter')),
                    Text('${sh.startTime.substring(0, 5)} – ${sh.endTime.substring(0, 5)}',
                        style: TextStyle(fontSize: 11,
                            color: selected ? accent.withValues(alpha: 0.8) : MakaryaColors.textMuted,
                            fontFamily: 'Inter')),
                  ])),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: accent, size: 20),
                ]),
              ),
            );
          }),
        ],

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: MakaryaColors.lossRed,
              fontSize: 12, fontFamily: 'Inter')),
        ],

        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: MakaryaColors.woodBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Jadwal',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
          ),
        ),
      ]),
    );
  }
}

// ── Attendance Tab ────────────────────────────────────────────────────────────

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();
  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HRProvider>().loadAttendanceToday();
    });
  }

  Color _statusColor(String status) => switch (status) {
    'ON_TIME'     => MakaryaColors.profitGreen,
    'LATE'        => MakaryaColors.lossRed,
    'EARLY_LEAVE' => MakaryaColors.warningAmber,
    _             => MakaryaColors.textMuted,
  };

  String _statusLabel(String status) => switch (status) {
    'ON_TIME'     => 'Tepat Waktu',
    'LATE'        => 'Terlambat',
    'EARLY_LEAVE' => 'Pulang Awal',
    _             => status,
  };

  String _typeLabel(String type) => type == 'CHECK_IN' ? 'Masuk' : 'Keluar';

  IconData _typeIcon(String type) =>
      type == 'CHECK_IN' ? Icons.login_rounded : Icons.logout_rounded;

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final hr       = context.watch<HRProvider>();
    final logs     = hr.attendanceToday;
    final total    = hr.staffList.where((s) => s.isActive).length;
    final hadir    = hr.totalPresentToday;
    final terlambat= hr.totalLateToday;

    return Column(children: [
      // ── Summary strip ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: MakaryaColors.surface02,
        child: Row(children: [
          _StatChip(label: 'Total Staf', value: '$total',
              color: MakaryaColors.infoBlue, icon: Icons.people_rounded),
          const SizedBox(width: 8),
          _StatChip(label: 'Hadir', value: '$hadir',
              color: MakaryaColors.profitGreen, icon: Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _StatChip(label: 'Terlambat', value: '$terlambat',
              color: MakaryaColors.lossRed, icon: Icons.warning_rounded),
          const Spacer(),
          // Live indicator
          Row(children: [
            Container(width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: MakaryaColors.profitGreen, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: MakaryaColors.profitGreen, fontFamily: 'Inter')),
          ]),
        ]),
      ),

      // ── Scan QR button ───────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openScanner(context, hr),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Scan QR Absensi',
                style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            style: ElevatedButton.styleFrom(
              backgroundColor: MakaryaColors.woodBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),

      // ── Tanggal hari ini ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 13, color: MakaryaColors.textMuted),
          const SizedBox(width: 6),
          Text(_todayLabel(),
              style: const TextStyle(fontSize: 12, color: MakaryaColors.textMuted,
                  fontFamily: 'Inter')),
        ]),
      ),
      const SizedBox(height: 8),

      // ── Log list ─────────────────────────────────────────────────────────
      Expanded(
        child: hr.loadingAttendance
            ? const Center(child: CircularProgressIndicator(color: MakaryaColors.woodBrown))
            : logs.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fact_check_outlined, size: 48,
                        color: MakaryaColors.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    const Text('Belum ada absensi hari ini',
                        style: TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter')),
                    const SizedBox(height: 4),
                    const Text('Scan QR karyawan untuk mencatat kehadiran',
                        style: TextStyle(fontSize: 11, color: MakaryaColors.textMuted,
                            fontFamily: 'Inter')),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final log   = logs[i];
                      final sColor= _statusColor(log.attendStatus);
                      final sLabel= _statusLabel(log.attendStatus);
                      final tLabel= _typeLabel(log.attendType);
                      final tIcon = _typeIcon(log.attendType);
                      final shColor = log.shiftColor != null
                          ? Color(int.parse('FF${log.shiftColor!.replaceFirst('#', '')}', radix: 16))
                          : MakaryaColors.woodBrown;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MakaryaColors.surface01,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sColor.withValues(alpha: 0.4), width: 0.5),
                        ),
                        child: Row(children: [
                          // Avatar initials
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: sColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(
                              log.fullName.split(' ').map((w) => w[0]).take(2).join(),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: sColor, fontFamily: 'Inter'),
                            )),
                          ),
                          const SizedBox(width: 10),
                          // Info
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(log.fullName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                            const SizedBox(height: 2),
                            Row(children: [
                              // Shift badge
                              if (log.shiftName != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: shColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(log.shiftName!,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                          color: shColor, fontFamily: 'Inter')),
                                ),
                                const SizedBox(width: 6),
                              ],
                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: sColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(sLabel,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                        color: sColor, fontFamily: 'Inter')),
                              ),
                            ]),
                          ])),
                          // Type + time
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(tIcon, size: 13, color: MakaryaColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(tLabel, style: const TextStyle(fontSize: 11,
                                  color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
                            ]),
                            const SizedBox(height: 2),
                            Text(_timeStr(log.scannedAt),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: MakaryaColors.textPrimary,
                                    fontFamily: 'Inter',
                                    fontFeatures: [FontFeature.tabularFigures()])),
                          ]),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _openScanner(BuildContext context, HRProvider hr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _QRScannerSheet(hr: hr),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const mons = ['','Januari','Februari','Maret','April','Mei','Juni',
                  'Juli','Agustus','September','Oktober','November','Desember'];
    return '${days[now.weekday - 1]}, ${now.day} ${mons[now.month]} ${now.year}';
  }
}

// ── Stat chip kecil ───────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;
  const _StatChip({required this.label, required this.value,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Inter')),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8),
            fontFamily: 'Inter')),
      ]),
    ]),
  );
}

// ── QR Scanner Sheet ──────────────────────────────────────────────────────────

class _QRScannerSheet extends StatefulWidget {
  final HRProvider hr;
  const _QRScannerSheet({required this.hr});
  @override
  State<_QRScannerSheet> createState() => _QRScannerSheetState();
}

class _QRScannerSheetState extends State<_QRScannerSheet> {
  final MobileScannerController _ctrl = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  bool   _processing = false;
  bool   _scanned    = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Ambil token dari QR — format: "makarya://attend?token=XXX" atau raw token
    String token = raw;
    if (raw.contains('token=')) {
      token = raw.split('token=').last.split('&').first;
    }

    setState(() => _processing = true);
    await _ctrl.stop();

    final result = await widget.hr.processQrAttendance(token);
    if (!mounted) return;

    setState(() {
      _processing = false;
      _scanned    = true;
      _result     = result;
    });
  }

  void _reset() {
    setState(() { _scanned = false; _result = null; _processing = false; });
    _ctrl.start();
  }
  Future<void> _pickFromGallery() async {
  final file = await _picker.pickImage(source: ImageSource.gallery);
  if (file == null) return;
  setState(() => _processing = true);
  final result = await _ctrl.analyzeImage(file.path);
  if (!mounted) return;
  if (result == null || result.barcodes.isEmpty) {
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR Code tidak ditemukan di gambar')),
    );
    return;
  }
  final raw = result.barcodes.first.rawValue ?? '';
  String token = raw;
  if (raw.contains('token=')) {
    token = raw.split('token=').last.split('&').first;
  }
  final res = await widget.hr.processQrAttendance(token);
  if (!mounted) return;
  setState(() { _processing = false; _scanned = true; _result = res; });
}

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        // Handle bar
        Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2))),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('Scan QR Absensi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white, fontFamily: 'Inter'))),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
            ),
          ]),
        ),

        Expanded(child: _scanned ? _buildResult() : _buildScanner()),
      ]),
    );
  }

  Widget _buildScanner() => Stack(children: [
    // Kamera
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MobileScanner(
        controller: _ctrl,
        onDetect: _onDetect,
      ),
    ),

    // Overlay frame
    Center(child: Container(
      width: 220, height: 220,
      decoration: BoxDecoration(
        border: Border.all(color: MakaryaColors.woodLight, width: 2.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(children: [
        // Corner accents
        ...[ Alignment.topLeft, Alignment.topRight,
             Alignment.bottomLeft, Alignment.bottomRight,
        ].map((a) => Align(alignment: a,
            child: Container(width: 24, height: 24,
                decoration: BoxDecoration(
                  border: Border(
                    top:    a.y < 0 ? BorderSide(color: MakaryaColors.goldAccent, width: 3) : BorderSide.none,
                    bottom: a.y > 0 ? BorderSide(color: MakaryaColors.goldAccent, width: 3) : BorderSide.none,
                    left:   a.x < 0 ? BorderSide(color: MakaryaColors.goldAccent, width: 3) : BorderSide.none,
                    right:  a.x > 0 ? BorderSide(color: MakaryaColors.goldAccent, width: 3) : BorderSide.none,
                  ),
                )))),
      ]),
    )),

    if (_processing)
      Container(color: Colors.black54,
          child: const Center(child: CircularProgressIndicator(color: MakaryaColors.woodLight))),

    // Instruksi
    Positioned(bottom: 24, left: 0, right: 0,
      child: Text('Arahkan kamera ke QR Code karyawan',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13, fontFamily: 'Inter'))),
    Positioned(bottom: 64, right: 20,
      child: GestureDetector(
        onTap: _processing ? null : _pickFromGallery,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('Galeri', style: TextStyle(color: Colors.white,
                fontSize: 12, fontFamily: 'Inter')),
          ]),
        ),
      ),
    ),
  ]);

  Widget _buildResult() {
    final ok      = _result?['success'] == true;
    final name    = _result?['staff_name']    as String? ?? '';
    final empId   = _result?['employee_id']   as String? ?? '';
    final type    = _result?['attend_type']   as String? ?? '';
    final status  = _result?['attend_status'] as String? ?? '';
    final shift   = _result?['shift_name']    as String? ?? '';
    final msg     = _result?['message']       as String? ?? '';

    final statusColor = switch (status) {
      'ON_TIME'     => MakaryaColors.profitGreen,
      'LATE'        => MakaryaColors.lossRed,
      'EARLY_LEAVE' => MakaryaColors.warningAmber,
      _             => MakaryaColors.textMuted,
    };
    final statusLabel = switch (status) {
      'ON_TIME'     => 'Tepat Waktu',
      'LATE'        => 'Terlambat',
      'EARLY_LEAVE' => 'Pulang Awal',
      _             => '',
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Icon hasil
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: (ok ? MakaryaColors.profitGreen : MakaryaColors.lossRed)
                .withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 40,
            color: ok ? MakaryaColors.profitGreen : MakaryaColors.lossRed,
          ),
        ),
        const SizedBox(height: 20),

        if (ok) ...[
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
              color: Colors.white, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(empId, style: TextStyle(fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5), fontFamily: 'Inter')),
          const SizedBox(height: 16),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: MakaryaColors.woodBrown.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.4)),
            ),
            child: Text(type == 'CHECK_IN' ? '⬆ CHECK IN' : '⬇ CHECK OUT',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: MakaryaColors.woodLight, fontFamily: 'Inter')),
          ),
          const SizedBox(height: 12),

          // Status + shift
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel, style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: statusColor, fontFamily: 'Inter')),
            ),
            if (shift.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(shift, style: TextStyle(fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6), fontFamily: 'Inter')),
            ],
          ]),
        ] else ...[
          Text('Gagal Absen', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: Colors.white, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          Text(msg, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7), fontFamily: 'Inter')),
        ],

        const SizedBox(height: 32),

        // Buttons
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _reset,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Scan Lagi', style: TextStyle(fontFamily: 'Inter')),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: MakaryaColors.woodBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Selesai', style: TextStyle(fontFamily: 'Inter')),
          )),
        ]),
      ]),
    );
  }
}

// =============================================================================
// TAB HISTORY ABSENSI
// =============================================================================

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  late int _selectedYear;
  late int _selectedMonth;

  final _months = [
    'Januari','Februari','Maret','April','Mei','Juni',
    'Juli','Agustus','September','Oktober','November','Desember',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear  = now.year;
    _selectedMonth = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    context.read<HRProvider>().loadAttendanceHistory(
      year: _selectedYear, month: _selectedMonth,
    );
  }

  Color _statusColor(String s) => switch (s) {
    'ON_TIME'     => MakaryaColors.profitGreen,
    'LATE'        => MakaryaColors.lossRed,
    'EARLY_LEAVE' => MakaryaColors.warningAmber,
    _             => MakaryaColors.textMuted,
  };

  String _statusLabel(String s) => switch (s) {
    'ON_TIME'     => 'Tepat Waktu',
    'LATE'        => 'Terlambat',
    'EARLY_LEAVE' => 'Pulang Awal',
    _             => s,
  };

  String _typeLabel(String t) => t == 'CHECK_IN' ? 'Masuk' : 'Pulang';

  String _dateStr(DateTime dt) {
    final local = dt.toLocal();
    const days = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
    final day  = days[local.weekday - 1];
    return '$day ${local.day}/${local.month}';
  }

  String _timeStr(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hr   = context.watch<HRProvider>();
    final logs = hr.attendanceHistory;

    // Summary
    final totalHadir    = logs.where((l) => l.isCheckIn).map((l) => l.staffId).toSet().length;
    final totalTerlambat = logs.where((l) => l.isLate && l.isCheckIn).length;
    final totalPulangAwal = logs.where((l) => l.isEarlyLeave && !l.isCheckIn).length;

    return Column(children: [
      // ── Filter bulan ───────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        color: MakaryaColors.surface01,
        child: Row(children: [
          // Prev month
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              _load();
            },
            icon: const Icon(Icons.chevron_left_rounded,
                color: MakaryaColors.textMuted, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Text(
              '${_months[_selectedMonth - 1]} $_selectedYear',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: MakaryaColors.textPrimary, fontFamily: 'Inter',
              ),
            ),
          ),
          // Next month
          IconButton(
            onPressed: () {
              final now = DateTime.now();
              if (_selectedYear == now.year && _selectedMonth == now.month) return;
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              _load();
            },
            icon: Icon(
              Icons.chevron_right_rounded,
              color: (_selectedYear == DateTime.now().year &&
                      _selectedMonth == DateTime.now().month)
                  ? MakaryaColors.textMuted.withValues(alpha: 0.3)
                  : MakaryaColors.textMuted,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      ),

      // ── Summary chips ──────────────────────────────────────────────────────
      if (!hr.loadingHistory) Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: MakaryaColors.surface01,
        child: Row(children: [
          _SummaryChip(label: '$totalHadir Hadir',
              color: MakaryaColors.profitGreen, icon: Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _SummaryChip(label: '$totalTerlambat Terlambat',
              color: MakaryaColors.lossRed, icon: Icons.watch_later_rounded),
          const SizedBox(width: 8),
          _SummaryChip(label: '$totalPulangAwal Pulang Awal',
              color: MakaryaColors.warningAmber, icon: Icons.logout_rounded),
        ]),
      ),

      // ── Log list ───────────────────────────────────────────────────────────
      Expanded(
        child: hr.loadingHistory
            ? const Center(child: CircularProgressIndicator(
                color: MakaryaColors.woodBrown))
            : logs.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, size: 48,
                        color: MakaryaColors.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('Tidak ada absensi di ${_months[_selectedMonth - 1]} $_selectedYear',
                        style: const TextStyle(color: MakaryaColors.textMuted,
                            fontFamily: 'Inter')),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final log    = logs[i];
                      final sColor = _statusColor(log.attendStatus);
                      final sLabel = _statusLabel(log.attendStatus);
                      final tLabel = _typeLabel(log.attendType);
                      final shColor = log.shiftColor != null
                        ? Color(int.parse(
                            'FF${log.shiftColor!.replaceFirst("#", "")}',
                            radix: 16))
                        : MakaryaColors.woodBrown;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: MakaryaColors.surface01,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sColor.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: sColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(
                              log.fullName.split(' ').map((w) => w[0]).take(2).join(),
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: sColor, fontFamily: 'Inter'),
                            )),
                          ),
                          const SizedBox(width: 10),
                          // Info
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.fullName,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: MakaryaColors.textPrimary,
                                      fontFamily: 'Inter')),
                              const SizedBox(height: 2),
                              Row(children: [
                                if (log.shiftName != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: shColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(log.shiftName!,
                                        style: TextStyle(fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: shColor,
                                            fontFamily: 'Inter')),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: sColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(sLabel,
                                      style: TextStyle(fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: sColor, fontFamily: 'Inter')),
                                ),
                              ]),
                            ],
                          )),
                          // Date + time + type
                          Column(crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            Text(_dateStr(log.scannedAt),
                                style: const TextStyle(fontSize: 10,
                                    color: MakaryaColors.textMuted,
                                    fontFamily: 'Inter')),
                            const SizedBox(height: 2),
                            Text(_timeStr(log.scannedAt),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: MakaryaColors.textPrimary,
                                    fontFamily: 'Inter',
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ])),
                            const SizedBox(height: 2),
                            Text(tLabel,
                                style: TextStyle(fontSize: 9,
                                    color: log.isCheckIn
                                        ? MakaryaColors.profitGreen
                                        : MakaryaColors.warningAmber,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter')),
                          ]),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }
}