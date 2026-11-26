import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme_controller.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/floating_navigation_bar.dart';
import '../../auth/data/auth_service.dart';
import '../../activity/presentation/recent_activity_screen.dart';
import '../../amenities/presentation/amenity_requests_screen.dart';
import '../../community/data/society_repository.dart';
import '../../complaints/presentation/complaints_screen.dart';
import '../../events/presentation/events_screen.dart';
import '../../flats/presentation/flats_screen.dart';
import '../../maintenance/presentation/maintenance_screen.dart';
import '../../maintenance/presentation/admin_maintenance_screen.dart';
import '../../notices/presentation/notices_screen.dart';
import '../../residents/presentation/residents_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.role,
    required this.fullName,
    required this.societyId,
    this.flatNumber = '',
    super.key,
  });

  final String role;
  final String fullName;
  final String societyId;
  final String flatNumber;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPress;

  bool get _isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      societyNotificationService.bindUser(userId).catchError((Object error) {
        debugPrint('SocietyConnect notifications could not be enabled: $error');
      });
    }
  }

  void _handleBackPress() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    final now = DateTime.now();
    final lastPress = _lastBackPress;
    if (lastPress != null &&
        now.difference(lastPress) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  List<NavigationDestination> get _destinations => _isAdmin
      ? const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment_rounded),
              label: 'Flats'),
          NavigationDestination(
              icon: Icon(Icons.report_problem_outlined),
              selectedIcon: Icon(Icons.report_problem_rounded),
              label: 'Complaints'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign_rounded),
              label: 'Notices'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ]
      : const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Maintenance'),
          NavigationDestination(
              icon: Icon(Icons.report_problem_outlined),
              selectedIcon: Icon(Icons.report_problem_rounded),
              label: 'Complaints'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign_rounded),
              label: 'Notices'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ];

  Widget _selectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardOverview(
          name: widget.fullName,
          societyId: widget.societyId,
          flatNumber: widget.flatNumber,
          isAdmin: _isAdmin,
          onNavigate: (index) => setState(() => _selectedIndex = index),
          onOpenMaintenance: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AdminMaintenanceScreen(societyId: widget.societyId),
            ),
          ),
          onOpenDues: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AdminMaintenanceScreen(societyId: widget.societyId),
            ),
          ),
          onOpenResidents: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ResidentsScreen(societyId: widget.societyId),
            ),
          ),
          onOpenEvents: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventsScreen(
                societyId: widget.societyId,
                isAdmin: _isAdmin,
              ),
            ),
          ),
          onOpenAmenities: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AmenityRequestsScreen(
                societyId: widget.societyId,
                isAdmin: _isAdmin,
                flatNumber: widget.flatNumber,
                residentName: widget.fullName,
              ),
            ),
          ),
        );
      case 1:
        return _isAdmin
            ? FlatsScreen(societyId: widget.societyId)
            : MaintenanceScreen(
                societyId: widget.societyId,
                userId: authService.currentUser!.uid,
              );
      case 2:
        return ComplaintsScreen(
          societyId: widget.societyId,
          userId: authService.currentUser!.uid,
          isAdmin: _isAdmin,
          flatNumber: _isAdmin ? '' : widget.flatNumber,
        );
      case 3:
        return NoticesScreen(societyId: widget.societyId, isAdmin: _isAdmin);
      default:
        return _ProfileScreen(
          fullName: widget.fullName,
          role: widget.role,
          societyId: widget.societyId,
          flatNumber: widget.flatNumber,
          onOpenRecentActivity: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecentActivityScreen(societyId: widget.societyId),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? AppBar(
                toolbarHeight: 72,
                titleSpacing: 18,
                title: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Image.asset(
                        'assets/brand/society_connect_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isAdmin ? 'Admin Console' : 'SocietyConnect',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          Text(
                            'SOCIETY ID  ${widget.societyId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : null,
        body: SafeArea(
          top: _selectedIndex != 0,
          child: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map((destination) => NavigationRailDestination(
                            icon: destination.icon,
                            selectedIcon: destination.selectedIcon,
                            label: Text(destination.label),
                          ))
                      .toList(),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(_selectedIndex),
                    child: _selectedPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : FloatingNavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                destinations: _destinations,
              ),
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.name,
    required this.societyId,
    required this.flatNumber,
    required this.isAdmin,
    required this.onNavigate,
    required this.onOpenMaintenance,
    required this.onOpenDues,
    required this.onOpenResidents,
    required this.onOpenEvents,
    required this.onOpenAmenities,
  });

  final String name;
  final String societyId;
  final String flatNumber;
  final bool isAdmin;
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenMaintenance;
  final VoidCallback onOpenDues;
  final VoidCallback onOpenResidents;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenAmenities;

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final greeting = DateTime.now().hour < 12
        ? 'Good morning'
        : DateTime.now().hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 900 ? 44.0 : 20.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WelcomeBanner(
                    greeting: greeting,
                    firstName: firstName,
                    societyId: societyId,
                    subtitle: isAdmin
                        ? 'Your community, all in one place.'
                        : (flatNumber.isEmpty
                            ? 'Your community, all in one place.'
                            : 'Flat $flatNumber  ·  Your community, all in one place.'),
                    isAdmin: isAdmin,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 22),
                    _AdminMetricGrid(
                      societyId: societyId,
                      onOpenDues: onOpenDues,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(isAdmin ? 'Administrative modules' : 'Quick services',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, inner) {
                      final columns = isAdmin
                          ? (inner.maxWidth >= 900 ? 2 : 1)
                          : (inner.maxWidth >= 400 ? 4 : 3);
                      const spacing = 10.0;
                      final itemWidth =
                          (inner.maxWidth - spacing * (columns - 1)) / columns;
                      final actions = isAdmin
                          ? const [
                              _QuickAction(
                                  icon: Icons.apartment_outlined,
                                  title: 'Manage flats',
                                  text: 'Add flats and check occupancy.',
                                  tab: 1),
                              _QuickAction(
                                  icon: Icons.report_problem_outlined,
                                  title: 'Review complaints',
                                  text: 'Respond and update status.',
                                  tab: 2),
                              _QuickAction(
                                  icon: Icons.campaign_outlined,
                                  title: 'Publish a notice',
                                  text: 'Share an update with residents.',
                                  tab: 3),
                              _QuickAction(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Manage maintenance',
                                  text: 'Generate dues and record payments.',
                                  tab: -1),
                              _QuickAction(
                                  icon: Icons.people_alt_outlined,
                                  title: 'Manage residents',
                                  text:
                                      'Search residents and manage flat assignments.',
                                  tab: -2),
                              _QuickAction(
                                  icon: Icons.event_outlined,
                                  title: 'Events and meetings',
                                  text: 'Share upcoming community plans.',
                                  tab: -3),
                              _QuickAction(
                                  icon: Icons.meeting_room_outlined,
                                  title: 'Amenity bookings',
                                  text: 'Review resident booking requests.',
                                  tab: -4),
                            ]
                          : const [
                              _QuickAction(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Bills',
                                  text: 'Review your dues and history.',
                                  tab: 1),
                              _QuickAction(
                                  icon: Icons.report_problem_outlined,
                                  title: 'Complaints',
                                  text: 'Submit and track a complaint.',
                                  tab: 2),
                              _QuickAction(
                                  icon: Icons.campaign_outlined,
                                  title: 'Notices',
                                  text: 'Read the latest announcements.',
                                  tab: 3),
                              _QuickAction(
                                  icon: Icons.event_outlined,
                                  title: 'Events',
                                  text:
                                      'See what is coming up in your society.',
                                  tab: -3),
                              _QuickAction(
                                  icon: Icons.meeting_room_outlined,
                                  title: 'Bookings',
                                  text:
                                      'Request a community space or facility.',
                                  tab: -4),
                            ];
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: actions
                            .map((action) => SizedBox(
                                  width: itemWidth,
                                  child: _ActionCard(
                                      action: action,
                                      compact: !isAdmin,
                                      onTap: action.tab == -1
                                          ? onOpenMaintenance
                                          : action.tab == -2
                                              ? onOpenResidents
                                              : action.tab == -3
                                                  ? onOpenEvents
                                                  : action.tab == -4
                                                      ? onOpenAmenities
                                                      : () => onNavigate(
                                                          action.tab)),
                                ))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Society information is protected by your account role and Society ID.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction {
  const _QuickAction(
      {required this.icon,
      required this.title,
      required this.text,
      required this.tab});
  final IconData icon;
  final String title;
  final String text;
  final int tab;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.onTap,
    this.compact = false,
  });
  final _QuickAction action;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 16),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionIcon(action: action, compact: true),
                      const SizedBox(height: 8),
                      Text(
                        action.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _ActionIcon(action: action),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(action.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(action.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chevron_right_rounded,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
          ),
        ),
      );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action, this.compact = false});
  final _QuickAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      (scheme.primary, scheme.primaryContainer),
      (scheme.secondary, scheme.secondaryContainer),
      (scheme.tertiary, scheme.tertiaryContainer),
      (const Color(0xFFE05C67), const Color(0xFFFFE8E9)),
    ];
    final index = action.tab < 0 ? -action.tab - 1 : action.tab;
    final colors = palette[index % palette.length];
    final size = compact ? 52.0 : 54.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.$2.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(compact ? 17 : 18),
      ),
      child: Icon(action.icon, color: colors.$1, size: compact ? 24 : 25),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.greeting,
    required this.firstName,
    required this.societyId,
    required this.subtitle,
    required this.isAdmin,
  });

  final String greeting;
  final String firstName;
  final String societyId;
  final String subtitle;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isAdmin ? scheme.onSurface : Colors.white;
    final mutedForeground =
        isAdmin ? scheme.onSurfaceVariant : const Color(0xFFE6E9FF);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isAdmin ? scheme.surface : null,
        gradient: isAdmin
            ? null
            : const LinearGradient(
                colors: [Color(0xFF087A5B), Color(0xFF12A77C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(28),
        border: isAdmin
            ? Border.all(color: scheme.outlineVariant.withValues(alpha: .55))
            : null,
        boxShadow: [
          BoxShadow(
            color: (isAdmin ? Colors.black : const Color(0xFF087A5B))
                .withValues(alpha: isAdmin ? .035 : .2),
            blurRadius: isAdmin ? 16 : 24,
            offset: Offset(0, isAdmin ? 5 : 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(greeting.toUpperCase(),
                    style: TextStyle(
                      color: mutedForeground,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.15,
                    )),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? scheme.primaryContainer.withValues(alpha: .7)
                      : Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isAdmin ? 'ADMIN' : 'RESIDENT',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Text(firstName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: foreground,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        )),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.waving_hand_rounded,
                  color: Color(0xFFFFD27D), size: 25),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: mutedForeground, height: 1.35, fontSize: 13)),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.domain_rounded, size: 16, color: mutedForeground),
              const SizedBox(width: 7),
              Expanded(
                child: Text('Society ID  $societyId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminMetricGrid extends StatefulWidget {
  const _AdminMetricGrid({required this.societyId, required this.onOpenDues});
  final String societyId;
  final VoidCallback onOpenDues;

  @override
  State<_AdminMetricGrid> createState() => _AdminMetricGridState();
}

class _AdminMetricGridState extends State<_AdminMetricGrid> {
  late Future<AdminDashboardMetrics> _metrics;

  @override
  void initState() {
    super.initState();
    _metrics = societyRepository.loadAdminDashboardMetrics(widget.societyId);
  }

  void _retry() {
    setState(() {
      _metrics = societyRepository.loadAdminDashboardMetrics(widget.societyId);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminDashboardMetrics>(
        future: _metrics,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Dashboard data unavailable'),
                subtitle: const Text('Check Firestore access and try again.'),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final metrics = snapshot.data!;
          final values = [
            _MetricValue(
                'Residents', '${metrics.residents}', Icons.people_alt_outlined),
            _MetricValue('Flats', '${metrics.flats}', Icons.apartment_outlined,
                caption:
                    '${metrics.occupiedFlats} occupied • ${metrics.vacantFlats} vacant'),
            _MetricValue('Open complaints', '${metrics.openComplaints}',
                Icons.report_problem_outlined),
            _MetricValue('Resolved complaints', '${metrics.resolvedComplaints}',
                Icons.task_alt_rounded),
            _MetricValue('Upcoming events', '${metrics.upcomingEvents}',
                Icons.event_outlined),
            _MetricValue(
                'Amenity requests',
                '${metrics.pendingAmenityRequests}',
                Icons.meeting_room_outlined,
                caption: 'awaiting review'),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminBalanceCard(
                metrics: metrics,
                onTap: widget.onOpenDues,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 360
                          ? 2
                          : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: values
                        .map((metric) => SizedBox(
                              width: width,
                              child: _MetricCard(metric: metric),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      );
}

class _AdminBalanceCard extends StatelessWidget {
  const _AdminBalanceCard({required this.metrics, required this.onTap});

  final AdminDashboardMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const pendingColor = Color(0xFFFFC35A);
    const paidColor = Color(0xFF47D1AB);
    return Card(
      color: const Color(0xFF111827),
      elevation: 5,
      shadowColor: const Color(0x30111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOTAL PENDING MAINTENANCE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFB8C1D4),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.05,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF173F43),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text('VIEW DUES  ›',
                        style: TextStyle(
                          color: Color(0xFF8CE3D2),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '₹ ${metrics.pendingMaintenanceAmount.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 19),
              Row(
                children: [
                  Expanded(
                    child: _BalanceStat(
                      label: 'Paid records',
                      value: '${metrics.paidMaintenanceRecords}',
                      color: paidColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BalanceStat(
                      label: 'Pending records',
                      value: '${metrics.pendingMaintenanceRecords}',
                      color: pendingColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFAAB4C7), fontSize: 12)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      );
}

class _MetricValue {
  const _MetricValue(this.title, this.value, this.icon, {this.caption = ''});
  final String title;
  final String value;
  final IconData icon;
  final String caption;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _MetricValue metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (metric.title) {
      'Open complaints' => const Color(0xFFE05C67),
      'Resolved complaints' => const Color(0xFF15966E),
      'Upcoming events' => scheme.tertiary,
      'Amenity requests' => const Color(0xFF8158D7),
      'Flats' => scheme.secondary,
      _ => scheme.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(metric.icon, color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.title,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(metric.value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (metric.caption.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(metric.caption,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen(
      {required this.fullName,
      required this.role,
      required this.societyId,
      required this.flatNumber,
      required this.onOpenRecentActivity});
  final String fullName;
  final String role;
  final String societyId;
  final String flatNumber;
  final VoidCallback onOpenRecentActivity;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again at any time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                      radius: 28,
                      child: Text(
                          fullName.isEmpty ? '?' : fullName[0].toUpperCase())),
                  const SizedBox(height: 16),
                  Text(fullName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(email),
                  const Divider(height: 28),
                  Text(
                      'Role  •  ${role == 'admin' ? 'Administrator' : 'Resident'}'),
                  const SizedBox(height: 8),
                  Text('Society ID  •  $societyId'),
                  if (role == 'resident' && flatNumber.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Flat number  •  ${flatNumber.trim()}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (role == 'admin') ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Recent activity'),
                subtitle: const Text('View the latest society updates'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onOpenRecentActivity,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: appThemeController.themeMode,
                decoration: const InputDecoration(
                  labelText: 'Appearance',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                      value: ThemeMode.system, child: Text('System default')),
                  DropdownMenuItem(
                      value: ThemeMode.light, child: Text('Light mode')),
                  DropdownMenuItem(
                      value: ThemeMode.dark, child: Text('Dark mode')),
                ],
                onChanged: (mode) async {
                  if (mode == null) return;
                  try {
                    await appThemeController.setMode(mode);
                  } on FirebaseException {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Could not save appearance preference. Check your connection and deployed Firestore rules.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
