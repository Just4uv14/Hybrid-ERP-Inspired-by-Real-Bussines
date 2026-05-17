// =============================================================================
// MAKARYA HYBRID ERP — Sidebar Navigation (DARK GLASS WITH BLOBS)
// File: lib/widgets/makarya_sidebar.dart
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/makarya_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────

class SidebarItem {
  final String    label;
  final IconData  icon;
  final String    route;
  final int?      badge;
  final bool      requiresManager;

  const SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
    this.badge,
    this.requiresManager = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV SECTIONS
// ─────────────────────────────────────────────────────────────────────────────

const _kMainItems = <SidebarItem>[
  SidebarItem(label: 'Dashboard',   icon: Icons.grid_view_rounded,      route: '/dashboard'),
  SidebarItem(label: 'POS / Kasir', icon: Icons.point_of_sale_rounded,  route: '/pos'),
  SidebarItem(label: 'Inventori',   icon: Icons.inventory_2_outlined,   route: '/inventory'),
  SidebarItem(label: 'Antrian',     icon: Icons.coffee_maker_rounded,   route: '/queue'),
];

const _kOtherItems = <SidebarItem>[
  SidebarItem(label: 'Analitik',    icon: Icons.bar_chart_rounded,      route: '/analytics',  requiresManager: true),
  SidebarItem(label: 'Pengeluaran', icon: Icons.receipt_long_outlined,  route: '/expenses',   requiresManager: true),
  SidebarItem(label: 'Karyawan',    icon: Icons.badge_outlined,         route: '/hr',         requiresManager: true),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SIDEBAR WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class MakaryaSidebar extends StatefulWidget {
  final String   currentRoute;
  final Function(String route) onNavigate;
  final VoidCallback? onLogout;

  const MakaryaSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    this.onLogout,
  });

  @override
  State<MakaryaSidebar> createState() => _MakaryaSidebarState();
}

class _MakaryaSidebarState extends State<MakaryaSidebar>
    with SingleTickerProviderStateMixin {
  bool _collapsed = false;
  late AnimationController _collapseCtrl;
  late Animation<double>   _widthAnim;

  static const double _kExpandedWidth  = 240.0;
  static const double _kCollapsedWidth = 64.0;

  @override
  void initState() {
    super.initState();
    _collapseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 220),
    );
    _widthAnim = Tween<double>(
      begin: _kExpandedWidth,
      end:   _kCollapsedWidth,
    ).animate(CurvedAnimation(parent: _collapseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _collapseCtrl.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() => _collapsed = !_collapsed);
    if (_collapsed) {
      _collapseCtrl.forward();
    } else {
      _collapseCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final session = auth.session;
    final role    = auth.currentRole;

    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (_, __) {
        final effectiveCollapsed = _widthAnim.value < 140;

        return Stack(
          children: [
            // ── BACKGROUND BLOBS (sama kaya dashboard) ─────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MakaryaColors.darkEspresso,
                      MakaryaColors.darkEspresso.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Blob 1: Cyan top-left (sama kaya dashboard)
                    Positioned(
                      top: -80,
                      left: -60,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              MakaryaColors.blobCyan.withValues(alpha: 0.15),
                              MakaryaColors.blobCyan.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Blob 2: Purple mid-right
                    Positioned(
                      top: 100,
                      right: -80,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              MakaryaColors.blobPurple.withValues(alpha: 0.12),
                              MakaryaColors.blobPurple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Blob 3: Blue bottom-left
                    Positioned(
                      bottom: 80,
                      left: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              MakaryaColors.blobBlue.withValues(alpha: 0.10),
                              MakaryaColors.blobBlue.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── SIDEBAR CONTENT ─────────────────────────────────────────
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: _widthAnim.value,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    // Glass gelap — lebih gelap dari card biar sidebar keliatan
                    color: MakaryaColors.darkEspresso.withValues(alpha: 0.10),
                    border: Border(
                      right: BorderSide(
                        color: MakaryaColors.glassBorder,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // ── Logo + Collapse button ─────────────────────
                      _SidebarHeader(
                        collapsed: effectiveCollapsed,
                        onToggle:  _toggleCollapse,
                        session:   session,
                      ),

                      // ── Search bar ─────────────────────────────────
                      if (!effectiveCollapsed) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _DarkSearchBar(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Main nav items ─────────────────────────────
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._kMainItems.where((item) {
                                if (item.route == '/queue') return role.canAccessQueue;
                                if (item.route == '/pos')   return role.canAccessPos;
                                return true;
                              }).map((item) => _SidebarNavItem(
                                item:      item,
                                isActive:  widget.currentRoute == item.route,
                                collapsed: effectiveCollapsed,
                                onTap:     () => widget.onNavigate(item.route),
                              )),

                              const SizedBox(height: 16),

                              if (!effectiveCollapsed)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Text(
                                    'LAINNYA',
                                    style: TextStyle(
                                      fontSize:      10,
                                      fontWeight:    FontWeight.w600,
                                      color:         MakaryaColors.textMuted,
                                      fontFamily:    'Inter',
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),

                              ..._kOtherItems.where((item) {
                                if (!item.requiresManager) return true;
                                if (item.route == '/hr')        return role.canManageStaff;
                                if (item.route == '/expenses')   return role.canAccessExpenses;
                                if (item.route == '/analytics')  return role.canAccessAnalytics;
                                return role.canAccessAnalytics;
                              }).map((item) => _SidebarNavItem(
                                item:      item,
                                isActive:  widget.currentRoute == item.route,
                                collapsed: effectiveCollapsed,
                                onTap:     () => widget.onNavigate(item.route),
                              )),
                            ],
                          ),
                        ),
                      ),

                      // ── User profile footer ────────────────────────
                      _UserFooter(
                        session:   session,
                        collapsed: effectiveCollapsed,
                        onLogout:  widget.onLogout,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final bool         collapsed;
  final VoidCallback onToggle;
  final StaffSession? session;

  const _SidebarHeader({
    required this.collapsed,
    required this.onToggle,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MakaryaColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: collapsed
          ? Center(
              child: GestureDetector(
                onTap: onToggle,
                child: Container(
                  width:  28, height: 28,
                  decoration: BoxDecoration(
                    color: MakaryaColors.glassBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: MakaryaColors.glassBorder,
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_right_rounded,
                    size:  16,
                    color: MakaryaColors.textMuted,
                  ),
                ),
              ),
            )
          : Row(children: [
              // Logo — cyan glossy (brand)
              _GlossyIconBadge(
                size:   36,
                radius: 11,
                accent: MakaryaColors.woodBrown,
                child:  const Text(
                  'M',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAKARYA',
                      style: TextStyle(
                        fontSize:      13,
                        fontWeight:    FontWeight.w800,
                        color:         MakaryaColors.textPrimary,
                        fontFamily:    'Inter',
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      session?.role.label ?? 'ERP',
                      style: const TextStyle(
                        fontSize:   10,
                        color:      MakaryaColors.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width:  28, height: 28,
                  decoration: BoxDecoration(
                    color: MakaryaColors.glassBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: MakaryaColors.glassBorder,
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_left_rounded,
                    size:  16,
                    color: MakaryaColors.textMuted,
                  ),
                ),
              ),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DARK SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DarkSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: MakaryaColors.glassBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MakaryaColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        Icon(Icons.search_rounded,
            size: 15, color: MakaryaColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Cari...',
            style: TextStyle(
              fontSize:   12,
              color:      MakaryaColors.textMuted.withValues(alpha: 0.5),
              fontFamily: 'Inter',
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: MakaryaColors.glassBg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: MakaryaColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Text(
            '⌘ F',
            style: TextStyle(
              fontSize:   9,
              color:      MakaryaColors.textMuted.withValues(alpha: 0.5),
              fontFamily: 'Inter',
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR NAV ITEM — dark + active cyan subtle
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarNavItem extends StatefulWidget {
  final SidebarItem  item;
  final bool         isActive;
  final bool         collapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final collapsed = widget.collapsed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin:   const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding:  EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 10,
            vertical:   10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isActive
                ? MakaryaColors.woodBrown.withValues(alpha: 0.12)
                : _hovered
                    ? MakaryaColors.glassBg
                    : Colors.transparent,
            border: isActive
                ? Border.all(
                    color: MakaryaColors.woodBrown.withValues(alpha: 0.25),
                    width: 0.5,
                  )
                : null,
          ),
          child: _buildItemContent(isActive: isActive, collapsed: collapsed),
        ),
      ),
    );
  }

  Widget _buildItemContent({required bool isActive, required bool collapsed}) {
    final iconColor  = isActive ? MakaryaColors.woodLight : MakaryaColors.textMuted;
    final labelColor = isActive ? MakaryaColors.textPrimary : MakaryaColors.textSecondary;

    if (collapsed) {
      return Center(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive
                ? MakaryaColors.woodBrown.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.item.icon, size: 15, color: iconColor),
        ),
      );
    }

    return Row(children: [
      Icon(widget.item.icon, size: 18, color: iconColor),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          widget.item.label,
          style: TextStyle(
            fontSize:   13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color:      labelColor,
            fontFamily: 'Inter',
          ),
        ),
      ),
      if (widget.item.badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: MakaryaColors.lossRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: MakaryaColors.lossRed.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            '${widget.item.badge}',
            style: const TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w700,
              color:      MakaryaColors.lossRed,
              fontFamily: 'Inter',
            ),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _UserFooter extends StatelessWidget {
  final StaffSession? session;
  final bool          collapsed;
  final VoidCallback? onLogout;

  const _UserFooter({
    required this.session,
    required this.collapsed,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name     = session?.fullName    ?? 'User';
    final initials = session?.initials    ?? 'US';
    final role     = session?.role.label  ?? '';

    return Container(
      padding: collapsed
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: MakaryaColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: collapsed
          ? Center(
              child: _AvatarBadge(initials: initials, size: 36),
            )
          : Row(children: [
              _AvatarBadge(initials: initials, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      MakaryaColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis,
                    ),
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize:   10,
                        color:      MakaryaColors.textMuted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showUserMenu(context),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size:  16,
                  color: MakaryaColors.textMuted,
                ),
              ),
            ]),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MakaryaColors.surface01,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              _AvatarBadge(initials: session?.initials ?? 'US', size: 44),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  session?.fullName ?? 'User',
                  style: const TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      MakaryaColors.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  session?.role.label ?? '',
                  style: const TextStyle(
                    fontSize:   12,
                    color:      MakaryaColors.textMuted,
                    fontFamily: 'Inter',
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded,
                  color: MakaryaColors.lossRed, size: 18),
              title: const Text('Keluar',
                  style: TextStyle(
                      color: MakaryaColors.lossRed,
                      fontFamily: 'Inter',
                      fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                onLogout?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR BADGE — cyan gradient
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarBadge extends StatelessWidget {
  final String initials;
  final double size;

  const _AvatarBadge({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MakaryaColors.woodBrown,
            MakaryaColors.infoBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize:   size * 0.32,
            fontWeight: FontWeight.w700,
            color:      Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOSSY ICON BADGE — untuk logo
// ─────────────────────────────────────────────────────────────────────────────

class _GlossyIconBadge extends StatelessWidget {
  final Widget child;
  final double size;
  final double radius;
  final Color  accent;

  const _GlossyIconBadge({
    required this.child,
    required this.size,
    required this.radius,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.5),
                accent.withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: 0, left: 0,
              child: Container(
                width:  size * 0.6,
                height: size * 0.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft:     Radius.circular(radius),
                    bottomRight: const Radius.circular(4),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(child: child),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPORTED HELPER: GlossyIconBadge
// ─────────────────────────────────────────────────────────────────────────────

class GlossyIconBadge extends StatelessWidget {
  final Widget child;
  final double size;
  final double radius;
  final Color  accent;

  const GlossyIconBadge({
    super.key,
    required this.child,
    this.size   = 40,
    this.radius = 11,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return _GlossyIconBadge(
      child:  child,
      size:   size,
      radius: radius,
      accent: accent,
    );
  }
}