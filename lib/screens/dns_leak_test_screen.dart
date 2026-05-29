import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../app_state.dart';
import '../widgets/widgets.dart';

class DnsLeakTestScreen extends StatefulWidget {
  const DnsLeakTestScreen({super.key});

  @override
  State<DnsLeakTestScreen> createState() => _DnsLeakTestScreenState();
}

class _DnsLeakTestScreenState extends State<DnsLeakTestScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-run the leak test when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().runDnsLeakTest();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('DNS Leak Test'),
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (appState.isTestingLeak) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Retest Connection',
                onPressed: () => appState.runDnsLeakTest(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final isTesting = appState.isTestingLeak;
          final result = appState.leakTestResult;
          final isRunning = appState.isRunning;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _buildExplanationCard(context),
              const SizedBox(height: 24),
              if (isTesting)
                _buildLoadingState(context)
              else if (result != null) ...[
                _buildStatusBanner(context, result, isRunning),
                const SizedBox(height: 24),
                ExpressiveSectionHeader(
                  title: 'Connection details',
                  icon: Icons.public_rounded,
                ),
                const SizedBox(height: 8),
                _buildDetailsCard(context, result),
              ] else
                _buildEmptyState(context, appState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExplanationCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpressiveCard(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpressiveIconContainer(
            icon: Icons.help_outline_rounded,
            size: 40,
            iconSize: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What is a DNS Leak?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A DNS leak occurs when your system sends DNS queries directly to your ISP\'s servers, bypassing your configured secure DNS provider. This allows your ISP to track which websites you visit even when protection is enabled.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey[300]!;
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          // Banner Shimmer
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(height: 32),
          // Details Card Shimmer
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    dynamic result,
    bool isRunning,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    String statusTitle;
    String statusDescription;
    IconData statusIcon;

    if (!isRunning) {
      statusColor = colorScheme.outline;
      statusTitle = 'Protection Inactive';
      statusDescription = 'Secure DNS is turned off. Your requests are resolving through your default network settings.';
      statusIcon = Icons.shield_outlined;
    } else if (result.isLeak) {
      statusColor = colorScheme.error;
      statusTitle = 'DNS Leak Detected!';
      statusDescription = 'Your queries are resolving through your public ISP. Your secure DNS configuration is not active on this network.';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = Colors.green;
      statusTitle = 'Connection Secured';
      statusDescription = 'No DNS leaks detected. Your traffic is successfully resolving through your chosen secure DNS provider.';
      statusIcon = Icons.verified_user_rounded;
    }

    return ExpressiveCard(
      color: statusColor.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            statusTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusDescription,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, dynamic result) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpressiveCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildDetailItem(
            context: context,
            title: 'Your Public IP',
            value: result.clientIp,
            subtitle: 'What websites see as your entry point',
            icon: Icons.laptop_rounded,
            iconColor: colorScheme.primary,
          ),
          const Divider(height: 1, indent: 64),
          _buildDetailItem(
            context: context,
            title: 'Public Connection ISP',
            value: result.clientIsp,
            subtitle: result.clientCountry,
            icon: Icons.business_rounded,
            iconColor: colorScheme.secondary,
          ),
          const Divider(height: 1, indent: 64),
          _buildDetailItem(
            context: context,
            title: 'Detected DNS Resolver',
            value: result.dnsIp,
            subtitle: 'The server resolving your website queries',
            icon: Icons.dns_rounded,
            iconColor: result.isLeak ? colorScheme.error : Colors.green,
          ),
          const Divider(height: 1, indent: 64),
          _buildDetailItem(
            context: context,
            title: 'DNS Resolver Geo / ISP',
            value: result.dnsGeo,
            subtitle: 'Location and owner of the resolving server',
            icon: Icons.travel_explore_rounded,
            iconColor: result.isLeak ? colorScheme.error : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: ExpressiveIconContainer(
        icon: icon,
        size: 40,
        iconSize: 20,
        color: iconColor,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState appState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              'No test results available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => appState.runDnsLeakTest(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Leak Test'),
            ),
          ],
        ),
      ),
    );
  }
}
