import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../app_state.dart';
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
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
        title: Text(
          'DNS Toggle',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Top Section
                  const SizedBox(height: 20),
                  if (isLoading)
                    Container()
                  else
                    _buildHealthCheck(context, appState),

                  const Spacer(),

                  // The Shield (Stays in place)
                  _buildAnimatedStatus(
                    context,
                    appState,
                    hideCircles: isLoading,
                  ),

                  const Spacer(),

                  // Bottom Section
                  if (isLoading) ...[
                    _buildShimmerBlock(height: 88, radius: 24),
                    const SizedBox(height: 32),
                    _buildShimmerBlock(height: 72, radius: 24),
                  ] else ...[
                    _buildExpressiveServerSelector(context, appState),
                    const SizedBox(height: 32),
                    _buildExpressiveToggleButton(context, appState),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerBlock({required double height, required double radius}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white10 : Colors.grey[300]!,
      highlightColor: isDark ? Colors.white24 : Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: isRunning && !isLoading
              ? _pulseAnimation
              : const AlwaysStoppedAnimation(1.0),
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isRunning && !isLoading
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning && !isLoading
                        ? Colors.green.withOpacity(0.1)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  child: Icon(
                    isRunning && !isLoading
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    size: 72,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: hideCircles ? 0.0 : 1.0,
          child: Column(
            children: [
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey<bool>(isRunning && !isLoading),
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
                    const SizedBox(height: 8),
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
            ],
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServerScreen()),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
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
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpressiveToggleButton(BuildContext context, AppState appState) {
    final isRunning = appState.isRunning;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 72,
      child: FilledButton(
        onPressed: () async {
          if (isRunning) {
            await appState.stopDnsService();
          } else {
            await appState.startDnsService();
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor: isRunning
              ? colorScheme.errorContainer
              : colorScheme.primary,
          foregroundColor: isRunning
              ? colorScheme.onErrorContainer
              : colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            key: ValueKey<bool>(isRunning),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRunning
                    ? Icons.stop_rounded
                    : Icons.power_settings_new_rounded,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isRunning ? 'STOP FILTERING' : 'ENABLE PROTECTION',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
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

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !shizukuAlive
                        ? 'Shizuku not running'
                        : 'Permission required',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    !shizukuAlive
                        ? 'Please start the Shizuku app first'
                        : 'Grant permission to toggle DNS settings',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
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
      ),
    );
  }
}
