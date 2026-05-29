import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/widgets.dart';
import 'excluded_apps_screen.dart';
import 'dns_leak_test_screen.dart';

import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              ExpressiveSectionHeader(
                title: 'General',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: 8),
              ExpressiveCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSwitchTile(
                      context: context,
                      title: 'Auto-start on boot',
                      subtitle: 'Start protection automatically',
                      icon: Icons.power_settings_new_rounded,
                      iconColor: colorScheme.tertiary,
                      value: appState.settings.autoStartOnBoot,
                      onChanged: (value) => appState.updateSettings(
                        appState.settings.copyWith(autoStartOnBoot: value),
                      ),
                    ),
                    const Divider(height: 1, indent: 64),
                    _buildSwitchTile(
                      context: context,
                      title: 'Persistent Notification',
                      subtitle: 'Control from your status bar',
                      icon: Icons.notifications_active_rounded,
                      iconColor: colorScheme.primary,
                      value: appState.settings.persistentNotification,
                      onChanged: (value) => appState.updateSettings(
                        appState.settings.copyWith(persistentNotification: value),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              ExpressiveSectionHeader(
                title: 'Excluded Apps',
                icon: Icons.apps_rounded,
                trailing: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ExcludedAppsScreen(showOnlyExcluded: false),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
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
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Manage'),
                ),
              ),
              const SizedBox(height: 8),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return ExpressiveCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          context: context,
                          title: 'Excluded Apps Monitor',
                          subtitle: 'Bypass DNS for excluded apps in background',
                          icon: Icons.track_changes_rounded,
                          iconColor: colorScheme.secondary,
                          value: appState.settings.excludedAppsMonitor,
                          onChanged: (value) => appState.updateSettings(
                            appState.settings.copyWith(excludedAppsMonitor: value),
                          ),
                        ),
                        const Divider(height: 1, indent: 64),
                        ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    const ExcludedAppsScreen(showOnlyExcluded: true),
                                transitionsBuilder:
                                    (context, animation, secondaryAnimation, child) {
                                  return SlideTransition(
                                    position: Tween<Offset>(
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
                          leading: ExpressiveIconContainer(
                            icon: Icons.block_rounded,
                            size: 40,
                            iconSize: 20,
                            color: colorScheme.secondary,
                          ),
                          title: Text(
                            'Excluded Apps List',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            appState.excludedApps.isEmpty
                                ? 'No apps excluded'
                                : '${appState.excludedApps.length} app${appState.excludedApps.length > 1 ? 's' : ''} bypassing DNS',
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),
              ExpressiveSectionHeader(
                title: 'Tools',
                icon: Icons.construction_rounded,
              ),
              const SizedBox(height: 8),
              if (appState.testResult == null)
                _buildTestConnectionCard(context, appState)
              else
                _buildTestResultCard(context, appState),
              const SizedBox(height: 12),
              _buildDnsLeakTestCard(context),

              const SizedBox(height: 28),
              ExpressiveSectionHeader(
                title: 'Status',
                icon: Icons.analytics_rounded,
              ),
              const SizedBox(height: 8),
              ExpressiveCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildInfoTile(
                      context: context,
                      title: 'Shizuku',
                      subtitle: appState.shizukuHasPermission
                          ? 'Permission active'
                          : 'Action required',
                      icon: appState.shizukuHasPermission
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      iconColor: appState.shizukuHasPermission
                          ? Colors.green
                          : colorScheme.error,
                      trailing: appState.shizukuHasPermission
                          ? null
                          : FilledButton.tonal(
                              onPressed: () => appState.requestShizukuPermission(),
                              child: const Text('Fix'),
                            ),
                    ),
                    const Divider(height: 1, indent: 64),
                    _buildInfoTile(
                      context: context,
                      title: 'Service State',
                      subtitle: appState.isRunning ? 'Running' : 'Inactive',
                      icon: appState.isRunning
                          ? Icons.verified_user_rounded
                          : Icons.shield_outlined,
                      iconColor: appState.isRunning
                          ? Colors.green
                          : colorScheme.outline,
                    ),
                    const Divider(height: 1, indent: 64),
                    _buildInfoTile(
                      context: context,
                      title: 'DNS Server',
                      subtitle: appState.selectedServer?.name ?? 'None selected',
                      icon: Icons.dns_rounded,
                      iconColor: colorScheme.primary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              ExpressiveSectionHeader(
                title: 'Backup & Restore',
                icon: Icons.cloud_sync_rounded,
              ),
              const SizedBox(height: 8),
              ExpressiveCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: ExpressiveIconContainer(
                        icon: Icons.upload_rounded,
                        size: 40,
                        iconSize: 20,
                        color: Colors.teal,
                      ),
                      title: const Text('Export Config'),
                      subtitle: const Text('Save your custom servers'),
                      onTap: () async {
                        final json = appState.exportCustomServers();
                        final tempDir = await getTemporaryDirectory();
                        final file = File('${tempDir.path}/dns_toggle_backup.json');
                        await file.writeAsString(json);

                        await Share.shareXFiles(
                          [XFile(file.path)],
                          subject: 'DNS Toggle Backup',
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 64),
                    ListTile(
                      leading: ExpressiveIconContainer(
                        icon: Icons.download_rounded,
                        size: 40,
                        iconSize: 20,
                        color: Colors.orange,
                      ),
                      title: const Text('Import Config'),
                      subtitle: const Text('Load servers from file'),
                      onTap: () async {
                        final result = await FilePicker.pickFiles();
                        if (result != null) {
                          final file = File(result.files.single.path!);
                          final content = await file.readAsString();
                          try {
                            await appState.importCustomServers(content);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Configuration imported'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Import failed: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              ExpressiveSectionHeader(
                title: 'About',
                icon: Icons.info_rounded,
              ),
              const SizedBox(height: 8),
              ExpressiveCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildInfoTile(
                      context: context,
                      title: 'App Version',
                      subtitle: appState.appVersion,
                      icon: Icons.alternate_email_rounded,
                      iconColor: colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTestConnectionCard(BuildContext context, AppState appState) {
    return ExpressiveCard(
      onTap: appState.isTesting ? null : () => appState.testConnection(),
      child: Row(
        children: [
          ExpressiveIconContainer(
            icon: Icons.speed_rounded,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Connectivity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Measure DNS latency and resolution',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (appState.isTesting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  Widget _buildTestResultCard(BuildContext context, AppState appState) {
    final result = appState.testResult!;
    final isSuccess = result.isSuccess;
    final color = isSuccess
        ? Colors.green
        : Theme.of(context).colorScheme.error;

    return ExpressiveCard(
      color: color.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.verified_rounded : Icons.warning_rounded,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSuccess
                      ? 'Verification Successful'
                      : 'Connection Problem',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => appState.clearTestResult(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result.latencyMs > 0)
            _buildMetricRow(
              context,
              'Resolution Time',
              '${result.latencyMs} ms',
              Icons.timer_outlined,
            ),
          if (result.currentDns != null)
            _buildMetricRow(
              context,
              'DNS Server',
              result.currentDns!,
              Icons.lan_outlined,
            ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      leading: ExpressiveIconContainer(
        icon: icon,
        size: 40,
        iconSize: 20,
        color: iconColor,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: ExpressiveIconContainer(
        icon: icon,
        size: 40,
        iconSize: 20,
        color: iconColor,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Widget _buildDnsLeakTestCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DnsLeakTestScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
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
            icon: Icons.security_rounded,
            size: 48,
            iconSize: 24,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DNS Leak Test',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Check if your DNS queries are leaking',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}