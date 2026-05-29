import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/dns_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _totalPages = 6;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _enableNotification = false;
  bool _autoStartOnBoot = true;
  bool _excludeAppsMonitor = false;
  final Set<String> _selectedExcludedApps = {};
  String _appSearchQuery = '';
  final TextEditingController _appSearchController = TextEditingController();
  bool _appsLoadingTriggered = false;

  @override
  void dispose() {
    _pageController.dispose();
    _appSearchController.dispose();
    super.dispose();
  }

  bool _isShizukuReady(BuildContext context) {
    final appState = context.read<AppState>();
    return appState.shizukuHasPermission && appState.shizukuBinderAlive;
  }

  void _onNext() async {
    if (_currentPage == 1 && !_isShizukuReady(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant Shizuku permission to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentPage == 4) {
      final appState = context.read<AppState>();
      if (appState.isLoadingApps) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading apps... Please wait.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    if (_currentPage < _totalPages - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _completeOnboarding();
    }
  }

  void _onBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _toggleNotification(bool value) async {
    if (value) {
      final appState = context.read<AppState>();
      final granted = await appState.requestNotificationPermission();
      if (granted != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission is required.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    if (mounted) {
      setState(() => _enableNotification = value);
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_isShizukuReady(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant Shizuku permission to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final appState = context.read<AppState>();

    await appState.updateSettings(
      appState.settings.copyWith(
        autoStartOnBoot: _autoStartOnBoot,
        persistentNotification:
            _enableNotification || _selectedExcludedApps.isNotEmpty,
        excludedAppsMonitor: _excludeAppsMonitor,
      ),
    );

    for (final app in appState.installedApps) {
      if (_selectedExcludedApps.contains(app.packageName)) {
        await appState.addExcludedApp(
          ExcludedApp(
            packageName: app.packageName,
            appName: app.appName,
            excludedAt: DateTime.now(),
          ),
        );
      }
    }

    await appState.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  List<InstalledApp> _getFilteredApps(List<InstalledApp> apps) {
    if (_appSearchQuery.isEmpty) return apps;
    return apps.where((app) {
      return app.appName.toLowerCase().contains(
            _appSearchQuery.toLowerCase(),
          ) ||
          app.packageName.toLowerCase().contains(_appSearchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    if (index == 4 && !_appsLoadingTriggered) {
                      _appsLoadingTriggered = true;
                      context.read<AppState>().loadInstalledApps();
                    }
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildShizukuPage(),
                  _buildAutoStartPage(),
                  _buildNotificationPage(),
                  _buildExcludedAppsPage(),
                  _buildCompletePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentPage + 1}/$_totalPages',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _currentPage > 0 ? _onBack : null,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _onNext,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _totalPages - 1
                                ? 'Finish'
                                : 'Continue',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _totalPages - 1
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildOnboardingScrollPage(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.shield_rounded,
            size: 100,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Welcome to DNS Toggle',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Control your system DNS with one tap. Block ads, protect privacy, and manage your connection effortlessly.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildFeatureRow(
          Icons.lock_rounded,
          'System-level DNS control',
          'No root required, works via Shizuku',
        ),
        _buildFeatureRow(
          Icons.block_rounded,
          'Exclude specific apps',
          'Bypass DNS for apps that need it',
        ),
        _buildFeatureRow(
          Icons.settings_rounded,
          'Quick Settings & Widget',
          'Toggle DNS from anywhere',
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildShizukuPage() {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final shizukuReady =
            appState.shizukuHasPermission && appState.shizukuBinderAlive;

        return _buildOnboardingScrollPage(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Setup Shizuku',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Shizuku grants access to system APIs needed for DNS control. Follow the steps below to get started:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSetupCard(
              icon: Icons.devices_rounded,
              title: 'Wireless Debugging Setup',
              description:
                  'Enable Developer Options and use wireless debugging to start Shizuku.',
              color: colorScheme.primary,
              steps: [
                'Install Shizuku from Play Store or GitHub',
                'Enable Developer Options on your device',
                'Enable Wireless Debugging',
                'Open Shizuku and tap "Start via wireless debugging"',
                'Grant permission when prompted',
              ],
              actionLabel: 'Grant Shizuku Permission',
              onAction: () async {
                await appState.requestShizukuPermission();
                await appState.checkBinderAlive();
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 24),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: shizukuReady
                    ? Colors.green.withValues(alpha: 0.1)
                    : colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: shizukuReady
                      ? Colors.green.withValues(alpha: 0.3)
                      : colorScheme.errorContainer,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    shizukuReady
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: shizukuReady ? Colors.green : colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shizukuReady
                          ? 'Shizuku is ready! You can continue.'
                          : 'Shizuku not detected. You can still continue and set it up later.',
                      style: TextStyle(
                        color: shizukuReady
                            ? Colors.green.shade800
                            : colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildAutoStartPage() {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildOnboardingScrollPage(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Auto-start on Boot',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose whether DNS protection should start automatically after your device restarts.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _autoStartOnBoot
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _autoStartOnBoot
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _autoStartOnBoot
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: _autoStartOnBoot
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-start on Boot',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start protection automatically when device boots.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _autoStartOnBoot,
                onChanged: (v) {
                  setState(() => _autoStartOnBoot = v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildNotificationPage() {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildOnboardingScrollPage(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Notification',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'A persistent notification lets you control DNS from the notification shade.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _enableNotification
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _enableNotification
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _enableNotification
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: _enableNotification
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Persistent Notification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Show a notification with DNS status and quick toggle button.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enableNotification,
                onChanged: _toggleNotification,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.onSecondaryContainer,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This will be automatically enabled if you exclude apps from DNS filtering.',
                  style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildExcludedAppsPage() {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isLoading = appState.isLoadingApps;
        final apps = appState.installedApps;
        final filtered = _getFilteredApps(apps);

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;
            final veryCompact = constraints.maxHeight < 460;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: compact ? 8 : 16),
                      Text(
                        'Excluded Apps',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (!veryCompact) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Select apps that should bypass DNS filtering.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                      ],
                      SizedBox(height: compact ? 10 : 16),
                      Container(
                        padding: EdgeInsets.all(compact ? 12 : 20),
                        decoration: BoxDecoration(
                          color: _excludeAppsMonitor
                              ? colorScheme.tertiaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.3,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _excludeAppsMonitor
                                ? colorScheme.tertiary.withValues(alpha: 0.3)
                                : colorScheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(compact ? 8 : 12),
                              decoration: BoxDecoration(
                                color: _excludeAppsMonitor
                                    ? colorScheme.tertiary.withValues(
                                        alpha: 0.1,
                                      )
                                    : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.1,
                                      ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.visibility_off_rounded,
                                color: _excludeAppsMonitor
                                    ? colorScheme.tertiary
                                    : colorScheme.onSurfaceVariant,
                                size: compact ? 22 : 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exclude Apps Monitor',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (!veryCompact) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Auto-pause DNS when an excluded app is in the foreground.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Switch(
                              value: _excludeAppsMonitor,
                              onChanged: (v) {
                                setState(() => _excludeAppsMonitor = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 8),
                  child: TextField(
                    controller: _appSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _appSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _appSearchController.clear();
                                setState(() => _appSearchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: compact ? 8 : 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _appSearchQuery = value);
                    },
                  ),
                ),
                Expanded(
                  child: isLoading && apps.isEmpty
                      ? _buildAppSkeleton()
                      : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                apps.isEmpty
                                    ? Icons.apps_outage_rounded
                                    : Icons.search_off_rounded,
                                size: 48,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                apps.isEmpty
                                    ? 'Unable to load apps'
                                    : 'No apps match your search',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (apps.isEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    context
                                        .read<AppState>()
                                        .loadInstalledApps();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            final isSelected = _selectedExcludedApps.contains(
                              app.packageName,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Material(
                                color: isSelected
                                    ? colorScheme.primaryContainer.withValues(
                                        alpha: 0.3,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  leading: _buildAppIcon(app),
                                  title: Text(
                                    app.appName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    app.packageName,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedExcludedApps.add(
                                            app.packageName,
                                          );
                                        } else {
                                          _selectedExcludedApps.remove(
                                            app.packageName,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (_selectedExcludedApps.contains(
                                        app.packageName,
                                      )) {
                                        _selectedExcludedApps.remove(
                                          app.packageName,
                                        );
                                      } else {
                                        _selectedExcludedApps.add(
                                          app.packageName,
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, compact ? 8 : 16),
                  child: Text(
                    '${_selectedExcludedApps.length} app${_selectedExcludedApps.length != 1 ? 's' : ''} selected',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletePage() {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final shizukuReady =
            appState.shizukuHasPermission && appState.shizukuBinderAlive;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: compact ? 16 : 24),
                  Text(
                    "You're All Set!",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your DNS protection is ready. Here\'s a summary of your setup:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  _buildSummaryItem(
                    Icons.shield_rounded,
                    'Shizuku',
                    shizukuReady ? 'Connected' : 'Not connected',
                    shizukuReady ? Colors.green : colorScheme.error,
                    compact: compact,
                  ),
                  _buildSummaryItem(
                    Icons.notifications_active_rounded,
                    'Notification',
                    _enableNotification ? 'Enabled' : 'Disabled',
                    _enableNotification
                        ? colorScheme.primary
                        : colorScheme.outline,
                    compact: compact,
                  ),
                  _buildSummaryItem(
                    Icons.power_settings_new_rounded,
                    'Auto-start on Boot',
                    _autoStartOnBoot ? 'Enabled' : 'Disabled',
                    _autoStartOnBoot
                        ? colorScheme.primary
                        : colorScheme.outline,
                    compact: compact,
                  ),
                  _buildSummaryItem(
                    Icons.block_rounded,
                    'Excluded Apps',
                    _selectedExcludedApps.isEmpty
                        ? 'None'
                        : '${_selectedExcludedApps.length} app${_selectedExcludedApps.length > 1 ? 's' : ''}',
                    colorScheme.tertiary,
                    compact: compact,
                  ),
                  _buildSummaryItem(
                    Icons.visibility_off_rounded,
                    'Exclude Apps Monitor',
                    _excludeAppsMonitor ? 'Enabled' : 'Disabled',
                    _excludeAppsMonitor
                        ? colorScheme.tertiary
                        : colorScheme.outline,
                    compact: compact,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOnboardingScrollPage({
    required List<Widget> children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required List<String> steps,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppIcon(InstalledApp app) {
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            cacheWidth: 80,
            cacheHeight: 80,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackIcon(app);
            },
          ),
        );
      } catch (e) {
        return _buildFallbackIcon(app);
      }
    }
    return _buildFallbackIcon(app);
  }

  Widget _buildFallbackIcon(InstalledApp app) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          app.appName.isNotEmpty
              ? app.appName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String title,
    String value,
    Color color, {
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: compact ? 20 : 22),
            ),
            SizedBox(width: compact ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
