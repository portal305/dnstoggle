import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

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
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              _buildSectionHeader(context, 'General', Icons.tune_rounded),
              const SizedBox(height: 12),
              _buildSettingCard(
                context,
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

              const SizedBox(height: 32),
              _buildSectionHeader(context, 'Tools', Icons.construction_rounded),
              const SizedBox(height: 12),
              if (appState.testResult == null)
                _buildTestConnectionCard(context, appState)
              else
                _buildTestResultCard(context, appState),

              const SizedBox(height: 32),
              _buildSectionHeader(context, 'Status', Icons.analytics_rounded),
              const SizedBox(height: 12),
              _buildSettingCard(
                context,
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
                            onPressed: () =>
                                appState.requestShizukuPermission(),
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
                ],
              ),

              const SizedBox(height: 32),
              _buildSectionHeader(
                context,
                'Backup & Restore',
                Icons.cloud_sync_rounded,
              ),
              const SizedBox(height: 12),
              _buildSettingCard(
                context,
                children: [
                  ListTile(
                    leading: _buildIconContainer(
                      context,
                      Icons.upload_rounded,
                      Colors.teal,
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
                    leading: _buildIconContainer(
                      context,
                      Icons.download_rounded,
                      Colors.orange,
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

              const SizedBox(height: 32),
              _buildSectionHeader(context, 'About', Icons.info_rounded),
              const SizedBox(height: 12),
              _buildSettingCard(
                context,
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Card(child: Column(children: children));
  }

  Widget _buildTestConnectionCard(BuildContext context, AppState appState) {
    return Card(
      child: InkWell(
        onTap: appState.isTesting ? null : () => appState.testConnection(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _buildIconContainer(
                context,
                Icons.speed_rounded,
                Theme.of(context).colorScheme.primary,
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
        ),
      ),
    );
  }

  Widget _buildTestResultCard(BuildContext context, AppState appState) {
    final result = appState.testResult!;
    final isSuccess = result.isSuccess;
    final color = isSuccess
        ? Colors.green
        : Theme.of(context).colorScheme.error;

    return Card(
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
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
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: _buildIconContainer(context, icon, iconColor),
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
      leading: _buildIconContainer(context, icon, iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
