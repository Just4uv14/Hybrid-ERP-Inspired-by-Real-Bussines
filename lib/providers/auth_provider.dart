// =============================================================================
// MAKARYA HYBRID ERP — Auth Provider (PIN-based RBAC)
// File: lib/providers/auth_provider.dart
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StaffRole { manager, cashier, barista, stockKeeper, researcher, none }

extension StaffRoleX on StaffRole {
  String get label => switch (this) {
    StaffRole.manager     => 'Manager',
    StaffRole.cashier     => 'Kasir',
    StaffRole.barista     => 'Barista',
    StaffRole.stockKeeper => 'Stock Keeper',
    StaffRole.researcher  => 'Researcher',
    StaffRole.none        => '-',
  };

  bool get canAccessDashboard => this != StaffRole.none;
  bool get canAccessPos       => this == StaffRole.manager || this == StaffRole.cashier;
  bool get canAccessInventory => [StaffRole.manager, StaffRole.cashier, StaffRole.stockKeeper].contains(this);
  bool get canAccessAnalytics => this == StaffRole.manager || this == StaffRole.researcher;
  bool get canAccessExpenses  => this == StaffRole.manager;
  bool get canAccessQueue     => this == StaffRole.barista || this == StaffRole.manager;
  bool get canVoidTransaction => this == StaffRole.manager;
  bool get canDeleteItems     => this == StaffRole.manager || this == StaffRole.stockKeeper;
  bool get canExportPdf       => this == StaffRole.manager || this == StaffRole.researcher;
  bool get canManageStaff     => this == StaffRole.manager;
}

StaffRole _parseRole(String raw) => switch (raw.toUpperCase()) {
  'MANAGER'      => StaffRole.manager,
  'CASHIER'      => StaffRole.cashier,
  'BARISTA'      => StaffRole.barista,
  'STOCK_KEEPER' => StaffRole.stockKeeper,
  'RESEARCHER'   => StaffRole.researcher,
  _              => StaffRole.none,
};

class StaffSession {
  final int       staffId;
  final String    employeeId;
  final String    fullName;
  final StaffRole role;
  final String    shift;
  final DateTime  loginAt;

  const StaffSession({
    required this.staffId, required this.employeeId, required this.fullName,
    required this.role,    required this.shift,      required this.loginAt,
  });

  String get initials {
    final parts = fullName.split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : fullName.substring(0, 2).toUpperCase();
  }
}

class AuthProvider extends ChangeNotifier {
  StaffSession? _session;
  StaffSession? get session => _session;
  bool          get isLoggedIn => _session != null;
  StaffRole     get currentRole => _session?.role ?? StaffRole.none;

  bool    _loading = false;
  bool    get loading => _loading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Splash screen flag ───────────────────────────────────────────────────
  bool _showSplash = false;
  bool get showSplash => _showSplash;

  final _supabase = Supabase.instance.client;

  Future<bool> login(String employeeId, String pin) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _supabase.rpc('verify_staff_pin', params: {
        'p_employee_id': employeeId.trim().toUpperCase(),
        'p_pin':         pin.trim(),
      });

      final resultList = result as List?;
      if (resultList == null || resultList.isEmpty) {
        _errorMessage = 'Terjadi kesalahan. Coba lagi.';
        _loading = false;
        notifyListeners();
        return false;
      }

      final row = resultList.first as Map<String, dynamic>;

      if (row['success'] != true) {
        _errorMessage = row['message'] as String? ?? 'Login gagal';
        _loading = false;
        notifyListeners();
        return false;
      }

      _session = StaffSession(
        staffId:    row['staff_id']    as int,
        employeeId: row['employee_id'] as String,
        fullName:   row['full_name']   as String,
        role:       _parseRole(row['role'] as String),
        shift:      row['shift']       as String? ?? 'FULL',
        loginAt:    DateTime.now(),
      );

      await _supabase.rpc('set_current_role', params: {
        'p_role':     row['role'],
        'p_staff_id': row['staff_id'],
      });

      _showSplash = true;  // ← trigger splash screen after login
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Koneksi gagal: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void dismissSplash() {
    _showSplash = false;
    notifyListeners();
  }

  void logout() {
    _session = null;
    _showSplash = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<String> changePIN(String oldPin, String newPin) async {
    if (_session == null) return 'Belum login';
    try {
      final result = await _supabase.rpc('change_staff_pin', params: {
        'p_staff_id': _session!.staffId,
        'p_old_pin':  oldPin,
        'p_new_pin':  newPin,
      });
      return (result as Map<String, dynamic>)['message'] as String? ?? 'Selesai';
    } catch (e) {
      return 'Error: $e';
    }
  }

  void clearError() { _errorMessage = null; notifyListeners(); }
}
