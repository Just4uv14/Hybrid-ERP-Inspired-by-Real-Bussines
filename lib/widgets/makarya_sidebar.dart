import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';
import 'glass_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR MODELS & DATA
// ─────────────────────────────────────────────────────────────────────────────

class SidebarItem {
  final String    label;
  final IconData  icon;
  final String    route;
  final bool      requiresManager;
  final String?   badge;

  SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
    this.requiresManager = false,
    this.badge,
  });
}

final _kMainItems = [
  SidebarItem(label: 'Dashboard',   icon: Icons.dashboard_rounded,      route: '/dashboard'),
  SidebarItem(label: 'Kasir (POS)', icon: Icons.point_of_sale_rounded,  route: '/pos'),
  SidebarItem(label: 'Inventory',   icon: Icons.inventory_2_rounded,    route: '/inventory'),
  SidebarItem(label: 'Antrean',     icon: Icons.list_alt_rounded,       route: '/queue'),
];

final _kOtherItems = [
  SidebarItem(label: 'Analitik',    icon: Icons.bar_chart_rounded,      route: '/analytics',  requiresManager: true),
  SidebarItem(label: 'Pengeluaran', icon: Icons.receipt_long_outlined,  route: '/expenses',   requiresManager: true),
  SidebarItem(label: 'Karyawan',    icon: Icons.badge_outlined,         route: '/hr',         requiresManager: true),
];

// ─────────────────────────────────────────────────────────────────────────────
// PILL DOCK SIDEBAR (Pierre Su Style)
// ─────────────────────────────────────────────────────────────────────────────

class MakaryaSidebar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  const MakaryaSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.currentRole;

    // Filter items based on role access
    final mainItems = _kMainItems.where((item) {
      if (item.route == '/queue') return role.canAccessQueue;
      if (item.route == '/pos')   return role.canAccessPos;
      return true;
    }).toList();

    final otherItems = _kOtherItems.where((item) {
      if (!item.requiresManager) return true;
      if (item.route == '/hr')        return role.canManageStaff;
      if (item.route == '/expenses')   return role.canAccessExpenses;
      if (item.route == '/analytics')  return role.canAccessAnalytics;
      return role.canAccessAnalytics;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // Gap on both sides
      child: Center(
        child: Container(
          width: 72, // Fixed narrow width for the pill
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100), // Perfect pill shape
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24.0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: GlassContainer(
            width: 72,
            borderRadius: 100, // Match container
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
            blurSigma: 30.0,
            tintColor: Colors.black.withValues(alpha: 0.4), // Darker glass for contrast
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, // Hug content vertically
                children: [
                  ...mainItems.map((item) => _SidebarNavItem(
                    item: item,
                    isActive: currentRoute == item.route,
                    onTap: () => onNavigate(item.route),
                  )),
                  
                  if (otherItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: 32,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 12),
                    ...otherItems.map((item) => _SidebarNavItem(
                      item: item,
                      isActive: currentRoute == item.route,
                      onTap: () => onNavigate(item.route),
                    )),
                  ],
            
                  const SizedBox(height: 12),
                  Container(
                    width: 32,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 12),
                  
                  // Logout button as a pill item
                  _SidebarNavItem(
                    item: SidebarItem(label: 'Keluar', icon: Icons.logout_rounded, route: ''),
                    isActive: false,
                    onTap: onLogout,
                    isLogout: true,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR NAV ITEM (Icon Only with Circle Active State)
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarNavItem extends StatelessWidget {
  final SidebarItem item;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLogout;

  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    // Styling matching the Pierre Su reference
    final iconColor = isActive 
        ? const Color(0xFF141620) // Very dark color when active (because background is bright white)
        : (isLogout ? MakaryaColors.lossRed.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.5));
    
    final activeBgColor = Colors.white.withValues(alpha: 0.95); // Bright circle for active state

    return Tooltip(
      message: item.label,
      preferBelow: false,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeBgColor : Colors.transparent,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: iconColor,
              ),
              if (item.badge != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: MakaryaColors.lossRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
