

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/dashboard_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/ingredients_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/hr_provider.dart';
import 'logic/business_logic.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/barista_queue_screen.dart';
import 'screens/hr_screen.dart';
import 'screens/receipt_screen.dart';
import 'theme/makarya_theme.dart';
import 'widgets/makarya_sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                  Colors.transparent,
    statusBarIconBrightness:         Brightness.light,
    systemNavigationBarColor:        MakaryaColors.darkEspresso,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Supabase.initialize(
    url:     'https://bitsqlyrcnjhwaxmtxbt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpdHNxbHlyY25qaHdheG10eGJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3OTQwNDUsImV4cCI6MjA5MjM3MDA0NX0.VfZL2N9vw1ICFO9igNhLo7TW3akXz3mCghiVDijRuCA',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => IngredientsProvider()),
        ChangeNotifierProvider(create: (_) => HRProvider()),
      ],
      child: const MakaryaApp(),
    ),
  );
}

class MakaryaApp extends StatelessWidget {
  const MakaryaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'Makarya ERP',
      debugShowCheckedModeBanner: false,
      theme:                    MakaryaTheme.dark(),
      // Auth gate: Login → Splash → MainShell
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          if (!auth.isLoggedIn)    return const LoginScreen();
          if (auth.showSplash)     return const SplashScreen();
          return const MainShell();
        },
      ),
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
        '/pos':       (_) => const PosScreen(),
        '/inventory': (_) => const InventoryScreen(),
        '/analytics': (_) => const AnalyticsScreen(),
        '/expenses':  (_) => const ExpensesScreen(),
        '/queue':     (_) => const BaristaQueueScreen(),
        '/hr':        (_) => const HRScreen(),
        '/receipt': (ctx) {
          final code = ModalRoute.of(ctx)!.settings.arguments as String;
          return ReceiptScreen(trxCode: code);
        },
      },
    );
  }
}

// =============================================================================
// MainShell — nav items ditentukan berdasarkan role
// =============================================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int  _selectedIndex    = 0;
  bool _sidebarCollapsed = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static const _kRouteIndex = <String, int>{
    '/dashboard': 0,
    '/pos':       1,
    '/inventory': 2,
    '/analytics': 3,
    '/expenses':  4,
    '/queue': 5,
    '/hr':  6,
  };

  final Stream<DateTime> _clockStream =
      Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  List<_NavItem>? _cachedNavItems;
  StaffRole?      _cachedRole;

  final _allScreens = [
    const DashboardScreen(),
    const PosScreen(),
    const InventoryScreen(),
    const AnalyticsScreen(),
    const ExpensesScreen(),
    const BaristaQueueScreen(),
    const HRScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  List<_NavItem> _navItemsForRole(StaffRole role) {
    if (_cachedRole == role && _cachedNavItems != null) return _cachedNavItems!;
    _cachedRole = role;

    final all = [
      _NavItem(icon: Icons.dashboard_rounded,      label: 'Dashboard',   screen: _allScreens[0]),
      _NavItem(icon: Icons.point_of_sale_rounded,  label: 'POS',         screen: _allScreens[1]),
      _NavItem(icon: Icons.inventory_2_rounded,    label: 'Inventori',   screen: _allScreens[2]),
      _NavItem(icon: Icons.analytics_rounded,      label: 'Analitik',    screen: _allScreens[3]),
      _NavItem(icon: Icons.receipt_long_rounded,   label: 'Pengeluaran', screen: _allScreens[4]),
      _NavItem(icon: Icons.coffee_maker_rounded,   label: 'Antrian',     screen: _allScreens[5]),
      _NavItem(icon: Icons.badge_rounded,          label: 'HR',          screen: _allScreens[6]),
    ];

    _cachedNavItems = switch (role) {
      StaffRole.manager     => [all[0], all[1], all[2], all[3], all[4],all[5], all[6]],
      StaffRole.cashier     => [all[0], all[1], all[2]],
      StaffRole.barista     => [all[5]],
      StaffRole.stockKeeper => [all[0], all[2]],
      StaffRole.researcher  => [all[0], all[3]],
      _                     => [all[0]],
    };
    return _cachedNavItems!;
  }

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    _fadeCtrl.reset();
    _fadeCtrl.forward();
    setState(() => _selectedIndex = index);
  }

  void _showAlertSheet(BuildContext context, DashboardProvider dash) {
    final alerts = dash.inventoryAlerts.where((a) => a.health != StockHealth.healthy).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: MakaryaColors.surface02,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: MakaryaColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE05A4E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded, size: 18, color: Color(0xFFE05A4E)),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Inventory Alerts',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: MakaryaColors.textPrimary, fontFamily: 'Inter')),
                Text(alerts.isEmpty ? 'Semua stok sehat' : '${alerts.length} item perlu perhatian',
                    style: TextStyle(
                        fontSize: 11,
                        color: alerts.isEmpty ? MakaryaColors.profitGreen : const Color(0xFFE05A4E),
                        fontFamily: 'Inter')),
              ]),
            ]),
          ),
          const Divider(color: MakaryaColors.surface01, thickness: 1, height: 1),
          Expanded(
            child: alerts.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_outline_rounded, size: 40, color: MakaryaColors.profitGreen),
                      SizedBox(height: 8),
                      Text('Semua stok dalam kondisi sehat',
                          style: TextStyle(color: MakaryaColors.textSecondary, fontFamily: 'Inter')),
                    ]),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final a     = alerts[i];
                      final color = switch (a.health) {
                        StockHealth.outOfStock  => MakaryaColors.lossRed,
                        StockHealth.expiredRisk => MakaryaColors.warningAmber,
                        StockHealth.lowStock    => MakaryaColors.warningAmber,
                        StockHealth.slowMover   => MakaryaColors.infoBlue,
                        StockHealth.healthy     => MakaryaColors.profitGreen,
                      };
                      final label = switch (a.health) {
                        StockHealth.outOfStock  => 'Habis',
                        StockHealth.expiredRisk => 'Risiko Kadaluarsa',
                        StockHealth.lowStock    => 'Stok Menipis',
                        StockHealth.slowMover   => 'Slow Mover',
                        StockHealth.healthy     => 'Sehat',
                      };
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: color, width: 3)),
                        ),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.item.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: MakaryaColors.textPrimary, fontFamily: 'Inter'),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(a.recommendation,
                                style: TextStyle(fontSize: 11, color: color, fontFamily: 'Inter'),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ])),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: color, fontFamily: 'Inter')),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final navItems  = _navItemsForRole(auth.currentRole);
        final safeIndex = _selectedIndex.clamp(0, navItems.length - 1);

        return GlassBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Row(children: [
                if (isWide) _buildSidebar(auth, navItems, safeIndex),
                Expanded(child: Column(children: [
                  _buildTopBar(auth, navItems, safeIndex),
                  Expanded(child: FadeTransition(
                    opacity: _fadeAnim,
                    child: navItems[safeIndex].screen,
                  )),
                ])),
              ]),
            ),
            bottomNavigationBar: isWide ? null : _buildBottomNav(navItems, safeIndex),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(AuthProvider auth, List<_NavItem> items, int safeIndex) {
    final currentRoute = _kRouteIndex.entries.firstWhere(
      (e) {
        final itemLabel = items[safeIndex].label;
        final routeName = e.key.replaceAll('/', '');
        if (itemLabel == 'Analitik' && e.key == '/analytics') return true;
        if (itemLabel == 'Pengeluaran' && e.key == '/expenses') return true;
        if (itemLabel == 'Antrian' && e.key == '/queue') return true;
        if (itemLabel == 'Inventori' && e.key == '/inventory') return true;
        if (itemLabel == 'HR' && e.key == '/hr') return true;
        return itemLabel.toLowerCase().contains(routeName.toLowerCase());
      },
      orElse: () => const MapEntry('/dashboard', 0),
    ).key;
    return MakaryaSidebar(
      currentRoute: currentRoute,
      onNavigate: (route) {
        final targetIdx = items.indexWhere((item) {
          if (route == '/queue') return item.label == 'Antrian';
          if (route == '/hr') return item.label == 'HR';
          if (route == '/pos') return item.label == 'POS';
          if (route == '/inventory') return item.label == 'Inventori';
          if (route == '/analytics') return item.label == 'Analitik';
          if (route == '/expenses') return item.label == 'Pengeluaran';
          return item.label == 'Dashboard';
        });
        if (targetIdx != -1) _onNavTap(targetIdx);
      },
      onLogout: () => _confirmLogout(auth),
    );
  }

  Widget _buildRail(AuthProvider auth, List<_NavItem> items, int safeIndex) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: MakaryaColors.darkEspresso,
        border: Border(right: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.3))),
      ),
      child: Column(children: [
        const SizedBox(height: 16),
        _logoMark(),
        const SizedBox(height: 32),
        ...List.generate(items.length, (i) => _railItem(i, items[i], i == safeIndex)),
        const Spacer(),
        GestureDetector(
          onTap: () => _confirmLogout(auth),
          child: Container(
            width: 40, height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: MakaryaColors.lossRed.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.logout_rounded, size: 18, color: MakaryaColors.lossRed),
          ),
        ),
        _statusDot('DB', true),
        const SizedBox(height: 8),
        _statusDot('HW', false),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildTopBar(AuthProvider auth, List<_NavItem> items, int safeIndex) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MakaryaColors.darkEspresso,
        border: Border(bottom: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.2))),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: MakaryaColors.woodBrown.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.4), width: 0.5),
          ),
          child: const Center(
            child: Text('MK',
              style: TextStyle(color: MakaryaColors.woodLight, fontSize: 11,
                  fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: 0.5),
            ),
          ),
        ),
        const Spacer(),
        StreamBuilder<DateTime>(
          stream: _clockStream,
          builder: (_, snap) {
            final now = snap.data ?? DateTime.now();
            final hh  = now.hour.toString().padLeft(2, '0');
            final mm  = now.minute.toString().padLeft(2, '0');
            final ss  = now.second.toString().padLeft(2, '0');
            final dd  = now.day.toString().padLeft(2, '0');
            final mo  = now.month.toString().padLeft(2, '0');
            final yy  = now.year.toString();
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$hh:$mm:$ss',
                  style: TextStyle(
                    color: MakaryaColors.concreteGrey.withValues(alpha: 0.9),
                    fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text('$dd/$mo/$yy',
                  style: TextStyle(
                    color: MakaryaColors.concreteGrey.withValues(alpha: 0.5),
                    fontSize: 10, fontFamily: 'Inter',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(width: 16),
        Consumer<DashboardProvider>(
          builder: (ctx, dash, __) => GestureDetector(
            onTap: () => _showAlertSheet(ctx, dash),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: dash.alertCount > 0
                      ? const Color(0xFFE05A4E).withValues(alpha: 0.12)
                      : MakaryaColors.woodBrown.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: dash.alertCount > 0
                        ? const Color(0xFFE05A4E).withValues(alpha: 0.35)
                        : MakaryaColors.woodBrown.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  dash.alertCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: dash.alertCount > 0
                      ? const Color(0xFFE05A4E)
                      : MakaryaColors.concreteGrey.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              if (dash.alertCount > 0)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Color(0xFFE05A4E), shape: BoxShape.circle),
                    child: Center(child: Text('${dash.alertCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => _showProfileSheet(auth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MakaryaColors.woodBrown.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: MakaryaColors.woodBrown.withValues(alpha: 0.4),
                child: Text(auth.session?.initials ?? '??',
                    style: const TextStyle(color: MakaryaColors.woodLight, fontSize: 9,
                        fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
              const SizedBox(width: 6),
              Text(auth.session?.role.label ?? '',
                  style: const TextStyle(color: MakaryaColors.woodLight, fontSize: 10,
                      fontWeight: FontWeight.w500, fontFamily: 'Inter')),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBottomNav(List<_NavItem> items, int safeIndex) {
    return Container(
      decoration: BoxDecoration(
        color: MakaryaColors.darkEspresso,
        border: Border(top: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.3))),
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: MakaryaColors.woodLight,
        unselectedItemColor: MakaryaColors.concreteGrey.withValues(alpha: 0.5),
        selectedFontSize: 10, unselectedFontSize: 10,
        items: items.map((n) => BottomNavigationBarItem(icon: Icon(n.icon), label: n.label)).toList(),
      ),
    );
  }

  Widget _logoMark() => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [MakaryaColors.woodBrown, MakaryaColors.woodLight],
      ),
    ),
    child: const Center(child: Text('M', style: TextStyle(
        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: -1))),
  );

  Widget _railItem(int index, _NavItem item, bool selected) {
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56, height: 56,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? MakaryaColors.woodBrown.withValues(alpha: 0.25) : Colors.transparent,
          border: selected ? Border.all(color: MakaryaColors.woodBrown.withValues(alpha: 0.6)) : null,
        ),
        child: Tooltip(
          message: item.label,
          child: Icon(item.icon, size: 22,
              color: selected ? MakaryaColors.woodLight : MakaryaColors.concreteGrey.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _statusDot(String label, bool connected) => Column(children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: connected ? const Color(0xFF4CAF87) : const Color(0xFFE05A4E),
            boxShadow: connected
                ? [BoxShadow(color: const Color(0xFF4CAF87).withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 2)]
                : null)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 9,
        color: MakaryaColors.concreteGrey.withValues(alpha: 0.5), fontFamily: 'Inter')),
  ]);

  void _showProfileSheet(AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MakaryaColors.surface01,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProfileSheet(auth: auth),
    );
  }

  void _confirmLogout(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MakaryaColors.surface01,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Keluar?', style: TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 15)),
        content: const Text('Sesi kamu akan berakhir.',
            style: TextStyle(color: MakaryaColors.textSecondary, fontFamily: 'Inter', fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: MakaryaColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MakaryaColors.lossRed, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () { Navigator.pop(context); auth.logout(); },
            child: const Text('Keluar', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }
}

class _ProfileSheet extends StatefulWidget {
  final AuthProvider auth;
  const _ProfileSheet({required this.auth});
  @override State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final _oldPin = TextEditingController();
  final _newPin = TextEditingController();
  bool _showChangePIN = false;
  String? _pinMsg;

  @override
  void dispose() { _oldPin.dispose(); _newPin.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s             = widget.auth.session!;
    final keyboardH     = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, keyboardH + bottomPadding + 24),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: MakaryaColors.woodBrown.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: MakaryaColors.woodBrown.withValues(alpha: 0.3),
              child: Text(s.initials, style: const TextStyle(color: MakaryaColors.woodLight,
                  fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Inter'))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.fullName, style: const TextStyle(color: MakaryaColors.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            Text('${s.role.label}  ·  ${s.employeeId}', style: const TextStyle(
                color: MakaryaColors.textMuted, fontSize: 11, fontFamily: 'Inter')),
          ]),
        ]),
        const SizedBox(height: 20),
        Divider(color: MakaryaColors.woodBrown.withValues(alpha: 0.2)),
        const SizedBox(height: 12),

        if (!_showChangePIN) ...[
          ListTile(
            contentPadding: EdgeInsets.zero, dense: true,
            leading: const Icon(Icons.lock_reset_rounded, size: 18, color: MakaryaColors.woodLight),
            title: const Text('Ganti PIN', style: TextStyle(color: MakaryaColors.textPrimary,
                fontSize: 13, fontFamily: 'Inter')),
            onTap: () => setState(() => _showChangePIN = true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero, dense: true,
            leading: const Icon(Icons.logout_rounded, size: 18, color: MakaryaColors.lossRed),
            title: const Text('Keluar', style: TextStyle(color: MakaryaColors.lossRed,
                fontSize: 13, fontFamily: 'Inter')),
            onTap: () { Navigator.pop(context); widget.auth.logout(); },
          ),
        ] else ...[
          TextField(controller: _oldPin, obscureText: true, keyboardType: TextInputType.number,
            style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 13),
            decoration: _pinDeco('PIN lama'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _newPin, obscureText: true, keyboardType: TextInputType.number,
            style: const TextStyle(color: MakaryaColors.textPrimary, fontFamily: 'Inter', fontSize: 13),
            decoration: _pinDeco('PIN baru (min 4 digit)'),
          ),
          if (_pinMsg != null) ...[
            const SizedBox(height: 6),
            Text(_pinMsg!, style: TextStyle(fontSize: 11, fontFamily: 'Inter',
                color: _pinMsg!.contains('berhasil') ? MakaryaColors.profitGreen : MakaryaColors.lossRed)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: BorderSide(color: MakaryaColors.woodBrown.withValues(alpha: 0.3)),
                  foregroundColor: MakaryaColors.textMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => setState(() { _showChangePIN = false; _pinMsg = null; }),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Inter')),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MakaryaColors.woodBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final msg = await widget.auth.changePIN(_oldPin.text, _newPin.text);
                setState(() { _pinMsg = msg; });
                if (msg.contains('berhasil')) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  });
                }
              },
              child: const Text('Simpan', style: TextStyle(fontFamily: 'Inter')),
            )),
          ]),
        ],
      ]),
      ),
    );
  }

  InputDecoration _pinDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: MakaryaColors.textMuted, fontFamily: 'Inter', fontSize: 12),
    filled: true, fillColor: MakaryaColors.surface02,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  );
}

class _NavItem {
  final IconData icon;
  final String   label;
  final Widget   screen;
  const _NavItem({required this.icon, required this.label, required this.screen});
}
