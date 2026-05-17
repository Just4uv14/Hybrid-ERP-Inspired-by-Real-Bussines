// =============================================================================
// MAKARYA ERP — HR Provider
// Mengelola data karyawan, jadwal shift, QR token, dan absensi live
// =============================================================================

import 'dart:math'; // [FIX #2] Import dart:math untuk Random.secure()
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ShiftModel {
  final int    id;
  final String name;
  final String code;
  final String startTime;
  final String endTime;
  final String colorHex;
  final int    lateGraceMinutes;

  const ShiftModel({
    required this.id,
    required this.name,
    required this.code,
    required this.startTime,
    required this.endTime,
    required this.colorHex,
    required this.lateGraceMinutes,
  });

  factory ShiftModel.fromMap(Map<String, dynamic> m) => ShiftModel(
    id:               (m['id'] as num).toInt(),
    name:             m['name']       as String,
    code:             m['code']       as String,
    startTime:        m['start_time'] as String,
    endTime:          m['end_time']   as String,
    colorHex:         m['color_hex']  as String? ?? '#8B6914',
    lateGraceMinutes: (m['late_grace_minutes'] as num?)?.toInt() ?? 15,
  );
}

class StaffModel {
  final int     id;
  final String  employeeId;
  final String  fullName;
  final String  role;
  final String  shift;
  final bool    isActive;
  final String? email;
  final String? phone;
  final String? address;
  final String? joinedDate;
  final String? photoUrl;
  final String? qrToken;

  const StaffModel({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.role,
    required this.shift,
    required this.isActive,
    this.email,
    this.phone,
    this.address,
    this.joinedDate,
    this.photoUrl,
    this.qrToken,
  });

  factory StaffModel.fromMap(Map<String, dynamic> m) => StaffModel(
    id:         (m['id'] as num).toInt(),
    employeeId: m['employee_id'] as String,
    fullName:   m['full_name']   as String,
    role:       m['role']        as String,
    shift:      m['shift']       as String? ?? 'FULL',
    isActive:   m['is_active']   as bool? ?? true,
    email:      m['email']       as String?,
    phone:      m['phone']       as String?,
    address:    m['address']     as String?,
    joinedDate: m['joined_date'] as String?,
    photoUrl:   m['photo_url']   as String?,
    qrToken:    m['qr_token']    as String?,
  );

  String get initials {
    final parts = fullName.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : fullName.substring(0, fullName.length.clamp(0, 2)).toUpperCase();
  }

  String get roleLabel => switch (role.toUpperCase()) {
    'MANAGER'      => 'Manager',
    'CASHIER'      => 'Kasir',
    'BARISTA'      => 'Barista',
    'STOCK_KEEPER' => 'Stock Keeper',
    'RESEARCHER'   => 'Researcher',
    _              => role,
  };
}

class ScheduleModel {
  final int?    scheduleId;
  final int     staffId;
  final String  staffName;
  final String  employeeId;
  final String  role;
  final DateTime workDate;
  final bool    isDayOff;
  final String? notes;
  final int?    shiftId;
  final String? shiftName;
  final String? shiftCode;
  final String? startTime;
  final String? endTime;
  final String? shiftColor;

  const ScheduleModel({
    this.scheduleId,
    required this.staffId,
    required this.staffName,
    required this.employeeId,
    required this.role,
    required this.workDate,
    required this.isDayOff,
    this.notes,
    this.shiftId,
    this.shiftName,
    this.shiftCode,
    this.startTime,
    this.endTime,
    this.shiftColor,
  });

  factory ScheduleModel.fromMap(Map<String, dynamic> m) => ScheduleModel(
    scheduleId:  m['schedule_id'] != null ? (m['schedule_id'] as num).toInt() : null,
    staffId:     m['staff_id'] != null ? (m['staff_id'] as num).toInt() : 0,
    staffName:   m['full_name']   as String? ?? '',
    employeeId:  m['employee_id'] as String? ?? '',
    role:        m['role']        as String? ?? '',
    workDate:    m['work_date'] != null ? DateTime.parse(m['work_date'] as String) : DateTime.now(),
    isDayOff:    m['is_day_off']  as bool? ?? false,
    notes:       m['notes']       as String?,
    shiftId:     m['shift_id'] != null ? (m['shift_id'] as num).toInt() : null,
    shiftName:   m['shift_name']  as String?,
    shiftCode:   m['shift_code']  as String?,
    startTime:   m['start_time']  as String?,
    endTime:     m['end_time']    as String?,
    shiftColor:  m['shift_color'] as String?,
  );
}

class AttendanceModel {
  final int       id;
  final int       staffId;
  final String    employeeId;
  final String    fullName;
  final String    role;
  final String?   shiftName;
  final String?   shiftCode;
  final String?   shiftColor;
  final String    attendType;
  final String    attendStatus;
  final DateTime  scannedAt;
  final String?   notes;

  const AttendanceModel({
    required this.id,
    required this.staffId,
    required this.employeeId,
    required this.fullName,
    required this.role,
    this.shiftName,
    this.shiftCode,
    this.shiftColor,
    required this.attendType,
    required this.attendStatus,
    required this.scannedAt,
    this.notes,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> m) => AttendanceModel(
    id:           (m['id']          as num).toInt(),
    staffId:      (m['staff_id']    as num).toInt(),
    employeeId:   m['employee_id']  as String,
    fullName:     m['full_name']    as String,
    role:         m['role']         as String,
    shiftName:    m['shift_name']   as String?,
    shiftCode:    m['shift_code']   as String?,
    shiftColor:   m['shift_color']  as String?,
    attendType:   m['attend_type']  as String,
    attendStatus: m['attend_status'] as String,
    scannedAt:    DateTime.parse(m['scanned_at'] as String),
    notes:        m['notes']        as String?,
  );

  bool get isCheckIn     => attendType   == 'CHECK_IN';
  bool get isOnTime      => attendStatus == 'ON_TIME';
  bool get isLate        => attendStatus == 'LATE';
  bool get isEarlyLeave  => attendStatus == 'EARLY_LEAVE';

  String get timeLabel {
    final h = scannedAt.toLocal().hour.toString().padLeft(2, '0');
    final m = scannedAt.toLocal().minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

class HRProvider extends ChangeNotifier {
  final _db = Supabase.instance.client;

  // State
  List<StaffModel>      _staffList       = [];
  List<ShiftModel>      _shifts          = [];
  List<ScheduleModel>   _weekSchedules   = [];
  List<AttendanceModel> _attendanceToday   = [];
  List<AttendanceModel> _attendanceHistory = [];
  bool                  _loadingHistory    = false;

  bool    _loading           = false;
  bool    _scheduleLoading   = false;
  bool    _loadingAttendance = false;
  String? _error;

  // Realtime subscription
  RealtimeChannel? _attendanceChannel;

  // Getters
  List<StaffModel>      get staffList          => _staffList;
  List<ShiftModel>      get shifts             => _shifts;
  List<ScheduleModel>   get weekSchedules      => _weekSchedules;
  List<AttendanceModel> get attendanceToday    => _attendanceToday;
  List<AttendanceModel> get attendanceHistory  => _attendanceHistory;
  bool                  get loading            => _loading;
  bool                  get scheduleLoading    => _scheduleLoading;
  bool                  get loadingAttendance  => _loadingAttendance;
  bool                  get loadingHistory     => _loadingHistory;
  String?               get error              => _error;

  int get totalPresentToday => _attendanceToday.map((a) => a.staffId).toSet().length;
  int get totalLateToday    => _attendanceToday.where((a) => a.isLate && a.isCheckIn).length;

  // ── Initialize ────────────────────────────────────────────────────────────
  // [FIX #4] Wrapped dengan try/finally agar _loading pasti di-reset
  // dan gunakan eagerError: false agar semua Future tetap jalan walau ada yang gagal
  Future<void> initialize() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadShifts(),
        _loadStaff(),
        _loadAttendanceToday(),
        _loadWeekSchedules(),
      ], eagerError: false);

      _subscribeAttendanceRealtime();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _attendanceChannel?.unsubscribe();
    super.dispose();
  }

  // ── Load Shifts ───────────────────────────────────────────────────────────
  Future<void> _loadShifts() async {
    try {
      final data = await _db.from('shifts').select().eq('is_active', true).order('start_time');
      _shifts = data.map<ShiftModel>((m) => ShiftModel.fromMap(m)).toList();
    } catch (e) {
      _error = e.toString();
    }
  }

  // ── Load Staff ────────────────────────────────────────────────────────────
  Future<void> loadStaff() async {
    await _loadStaff();
    notifyListeners();
  }

  Future<void> _loadStaff() async {
    try {
      // Join staff dengan qr_tokens untuk dapat token aktif
      final data = await _db
          .from('staff')
          .select('*, qr_tokens!qr_tokens_staff_id_fkey(token, is_active)')
          .order('full_name');

      _staffList = data.map<StaffModel>((m) {
        // Ambil token aktif dari nested qr_tokens
        final tokens = m['qr_tokens'] as List?;
        final activeToken = tokens?.firstWhere(
          (t) => t['is_active'] == true,
          orElse: () => null,
        );
        return StaffModel.fromMap({
          ...m,
          'qr_token': activeToken?['token'],
        });
      }).toList();
    } catch (e) {
      _error = e.toString();
    }
  }

  // ── Load Attendance Today ─────────────────────────────────────────────────
  Future<void> _loadAttendanceToday() async {
    try {
      final data = await _db.from('vw_attendance_today').select();
      _attendanceToday = data.map<AttendanceModel>((m) => AttendanceModel.fromMap(m)).toList();
    } catch (e) {
      _error = e.toString();
    }
  }

  // ── Load Week Schedules ───────────────────────────────────────────────────
  // [FIX #1] Wrapped dengan try/finally agar _scheduleLoading pasti di-reset
  Future<void> loadWeekSchedules() async {
    _scheduleLoading = true;
    notifyListeners();
    try {
      await _loadWeekSchedules();
    } finally {
      _scheduleLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadWeekSchedules() async {
    try {
      final data = await _db.from('vw_staff_schedule_week').select();
      _weekSchedules = data.map<ScheduleModel>((m) => ScheduleModel.fromMap(m)).toList();
    } catch (e) {
      _error = e.toString();
    }
  }

  // ── Realtime Attendance ───────────────────────────────────────────────────
  void _subscribeAttendanceRealtime() {
    _attendanceChannel?.unsubscribe();
    _attendanceChannel = _db
        .channel('attendance_realtime')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'attendance_logs',
          callback: (payload) async {
            // Reload attendance hari ini saat ada insert baru
            await _loadAttendanceToday();
            notifyListeners();
          },
        )
        .subscribe();
  }

  // ── Add Staff ─────────────────────────────────────────────────────────────
  Future<String?> addStaff({
    required String employeeId,
    required String fullName,
    required String role,
    required String shift,
    required String pin,
    String? email,
    String? phone,
  }) async {
    try {
      // Hash PIN sederhana — di production pakai bcrypt via Edge Function
      await _db.from('staff').insert({
        'employee_id': employeeId.toUpperCase().trim(),
        'full_name':   fullName.trim(),
        'role':        role,
        'shift':       shift,
        'pin_hash':    pin, // Supabase RLS + trigger akan hash ini
        'email':       email?.trim(),
        'phone':       phone?.trim(),
        'is_active':   true,
      });

      // Generate QR token untuk karyawan baru
      final newStaff = await _db
          .from('staff')
          .select('id')
          .eq('employee_id', employeeId.toUpperCase().trim())
          .single();

      await _db.from('qr_tokens').insert({
        'staff_id':  newStaff['id'],
        'token':     _generateToken(),
        'is_active': true,
      });

      await _loadStaff();
      notifyListeners();
      return null; // null = sukses
    } catch (e) {
      return e.toString();
    }
  }

  // ── Update Staff ──────────────────────────────────────────────────────────
  Future<String?> updateStaff({
    required int    staffId,
    required String fullName,
    required String role,
    required String shift,
    String? email,
    String? phone,
  }) async {
    try {
      await _db.from('staff').update({
        'full_name': fullName.trim(),
        'role':      role,
        'shift':     shift,
        'email':     email?.trim(),
        'phone':     phone?.trim(),
      }).eq('id', staffId);

      await _loadStaff();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Toggle Active Status ──────────────────────────────────────────────────
  Future<String?> toggleStaffActive(int staffId, bool isActive) async {
    try {
      await _db.from('staff').update({'is_active': isActive}).eq('id', staffId);
      await _loadStaff();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Regenerate QR Token ───────────────────────────────────────────────────
  Future<String?> regenerateQRToken(int staffId, int issuedBy) async {
    try {
      final result = await _db.rpc('regenerate_qr_token', params: {
        'p_staff_id':  staffId,
        'p_issued_by': issuedBy,
      });
      await _loadStaff();
      notifyListeners();
      return result as String?; // return new token
    } catch (e) {
      return null;
    }
  }

  // ── Assign Shift (Jadwal) ─────────────────────────────────────────────────
  Future<String?> assignShift({
    required int      staffId,
    required int      shiftId,
    required DateTime workDate,
    bool isDayOff = false,
    String? notes,
    required int createdBy,
  }) async {
    try {
      await _db.from('staff_schedules').upsert({
        'staff_id':   staffId,
        'shift_id':   shiftId,
        'work_date':  workDate.toIso8601String().split('T')[0],
        'is_day_off': isDayOff,
        'notes':      notes,
        'created_by': createdBy,
      }, onConflict: 'staff_id,work_date');

      await _loadWeekSchedules();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  // [FIX #2] Ganti token generator dengan Random.secure() — kriptografis & tidak bisa diprediksi
  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand  = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  ScheduleModel? getSchedule(int staffId, DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      return _weekSchedules.firstWhere(
        (s) => s.staffId == staffId &&
               s.workDate.toIso8601String().split('T')[0] == dateStr,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Assign / Upsert Schedule ──────────────────────────────────────────────
  // [FIX #3] Hapus spasi di onConflict 'staff_id, work_date' → 'staff_id,work_date'
  Future<String?> assignSchedule({
    required int      staffId,
    required DateTime date,
    int?              shiftId,
    bool              isDayOff = false,
  }) async {
    try {
      await _db.from('staff_schedules').upsert({
        'staff_id':   staffId,
        'shift_id':   isDayOff ? null : shiftId,
        'work_date':  date.toIso8601String().split('T')[0],
        'is_day_off': isDayOff,
      }, onConflict: 'staff_id,work_date'); // [FIX #3] spasi dihapus

      await _loadWeekSchedules();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Delete Schedule ───────────────────────────────────────────────────────
  Future<void> deleteSchedule(int? scheduleId) async {
    if (scheduleId == null) return;
    try {
      await _db.from('staff_schedules').delete().eq('id', scheduleId);
      await _loadWeekSchedules();
      notifyListeners();
    } catch (_) {}
  }

  // ── Process QR Attendance ─────────────────────────────────────────────────
  // Dipanggil saat QR berhasil di-scan. Memanggil stored function Supabase
  // yang validate token, detect CHECK_IN/OUT, hitung status, insert log.
  Future<Map<String, dynamic>> processQrAttendance(String token) async {
    try {
      final result = await _db.rpc('process_qr_attendance', params: {
        'p_token':  token,
        'p_device': 'Makarya ERP Scanner',
      });

      final data = Map<String, dynamic>.from(result as Map);

      // Kalau sukses, reload attendance hari ini
      if (data['success'] == true) {
        await _loadAttendanceToday();
        notifyListeners();
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // ── Load Attendance Today (public) ────────────────────────────────────────
  // [FIX #1] Wrapped dengan try/finally agar _loadingAttendance pasti di-reset
  Future<void> loadAttendanceToday() async {
    _loadingAttendance = true;
    notifyListeners();
    try {
      await _loadAttendanceToday();
    } finally {
      _loadingAttendance = false;
      notifyListeners();
    }
  }

  // ── Load Attendance History (by month) ────────────────────────────────────
  Future<void> loadAttendanceHistory({required int year, required int month}) async {
    _loadingHistory = true;
    notifyListeners();
    try {
      final startDate = DateTime(year, month, 1);
      final endDate   = DateTime(year, month + 1, 1);

      final data = await _db
          .from('attendance_logs')
          .select('''
            id, staff_id, scanned_at, attend_type, attend_status, notes,
            staff!inner(employee_id, full_name, role),
            shifts(name, code, color_hex)
          ''')
          .gte('scanned_at', startDate.toIso8601String())
          .lt('scanned_at', endDate.toIso8601String())
          .order('scanned_at', ascending: false);

      _attendanceHistory = data.map<AttendanceModel>((m) {
        final staff = m['staff'] as Map<String, dynamic>? ?? {};
        final shift = m['shifts'] as Map<String, dynamic>?;
        return AttendanceModel.fromMap({
          'id':           m['id'],
          'staff_id':     m['staff_id'],
          'employee_id':  staff['employee_id'] ?? '',
          'full_name':    staff['full_name']   ?? '',
          'role':         staff['role']        ?? '',
          'shift_name':   shift?['name'],
          'shift_code':   shift?['code'],
          'shift_color':  shift?['color_hex'],
          'attend_type':  m['attend_type'],
          'attend_status':m['attend_status'],
          'scanned_at':   m['scanned_at'],
          'notes':        m['notes'],
        });
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }
}