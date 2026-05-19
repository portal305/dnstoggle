import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../app_state.dart';
import '../widgets/widgets.dart';
import 'settings_screen.dart';
import 'server_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('DNS Toggle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const SettingsScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0.0, 1.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: child,
                        );
                      },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (!appState.deviceSupportsDns) {
            return _buildUnsupportedView(context);
          }

          final isLoading = appState.isLoading;

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isLoading
                      ? const SizedBox.shrink()
                      : _buildHealthCheck(context, appState),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildAnimatedStatus(
                    context,
                    appState,
                    hideCircles: isLoading,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isLoading
                      ? Shimmer.fromColors(
                          baseColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey[300]!,
                          highlightColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.grey[100]!,
                          child: Column(
                            children: [
                              _buildShimmerBlock(height: 88, radius: 28),
                              const SizedBox(height: 16),
                              _buildShimmerBlock(height: 72, radius: 28),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _buildExpressiveServerSelector(context, appState),
                            const SizedBox(height: 16),
                            _buildExpressiveToggleButton(context, appState),
                          ],
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerBlock({required double height, required double radius}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildAnimatedStatus(
    BuildContext context,
    AppState appState, {
    bool hideCircles = false,
  }) {
    final isRunning = appState.isRunning;
    final isLoading = appState.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = isRunning && !isLoading
        ? Colors.green
        : colorScheme.outline;
    final selectedServer = appState.selectedServer;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: isRunning && !isLoading
              ? _pulseAnimation
              : const AlwaysStoppedAnimation(1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isRunning && !isLoading
                  ? RadialGradient(
                      colors: [
                        Colors.green.withValues(alpha: 0.2),
                        Colors.green.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.6, 1.0],
                    )
                  : null,
              boxShadow: isRunning && !isLoading
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(
                          alpha: _glowAnimation.value,
                        ),
                        blurRadius: 50,
                        spreadRadius: 15,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: hideCircles ? 0.0 : 1.0,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning && !isLoading
                        ? Colors.green.withValues(alpha: 0.12)
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isRunning && !isLoading
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    size: 64,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: hideCircles ? 0.0 : 1.0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey<bool>(isRunning && !isLoading),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isRunning && !isLoading
                      ? 'PROTECTION ACTIVE'
                      : 'PROTECTION DISABLED',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRunning && !isLoading
                      ? 'Your connection is secure'
                      : 'Tap below to enable filtering',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpressiveServerSelector(
    BuildContext context,
    AppState appState,
  ) {
    final server = appState.selectedServer;
    final colorScheme = Theme.of(context).colorScheme;
    final latency = appState.serverLatencies[server?.id];

    return ExpressiveCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ServerScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0.0, 1.0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
          ),
        );
      },
      child: Row(
        children: [
          ExpressiveIconContainer(
            icon: Icons.dns_rounded,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DNS PROVIDER',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  server?.name ?? 'Select Server',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (latency != null && latency > 0) ...[
                  const SizedBox(height: 2),
                  LatencyIndicator(
                    latencyMs: latency,
                    showLabel: true,
                    size: 13,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.unfold_more_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 26,
          ),
        ],
      ),
    );
  }

  Widget _buildExpressiveToggleButton(BuildContext context, AppState appState) {
    final isRunning = appState.isRunning;

    return ExpressiveToggleButton(
      isActive: isRunning,
      onPressed: () async {
        if (isRunning) {
          await appState.stopDnsService();
        } else {
          await appState.startDnsService();
        }
      },
      activeLabel: 'STOP PROTECTION',
      inactiveLabel: 'ENABLE PROTECTION',
      activeIcon: Icons.stop_rounded,
      inactiveIcon: Icons.power_settings_new_rounded,
    );
  }

  Widget _buildUnsupportedView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Unsupported Device',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Private DNS settings are only available on Android 9 (API 28) and higher.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCheck(BuildContext context, AppState appState) {
    final bool shizukuAlive = appState.shizukuBinderAlive;
    final bool hasPermission = appState.shizukuHasPermission;

    if (shizukuAlive && hasPermission) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !shizukuAlive ? 'Shizuku not running' : 'Permission required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                Text(
                  !shizukuAlive
                      ? 'Please start the Shizuku app first'
                      : 'Grant permission to toggle DNS settings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              if (!shizukuAlive) {
              } else {
                appState.requestShizukuPermission();
              }
            },
            child: Text(!shizukuAlive ? 'Fix' : 'Grant'),
          ),
        ],
      ),
    );
  }
}
