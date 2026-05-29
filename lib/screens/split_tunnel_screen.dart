import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/widgets.dart';

class SplitTunnelScreen extends StatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  State<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends State<SplitTunnelScreen> {
  final TextEditingController _dnsController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final List<String> _domains = [];

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _dnsController.text = settings.corporateDnsIp;
    _domains.addAll(settings.splitTunnelDomains);
  }

  @override
  void dispose() {
    _dnsController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final appState = context.read<AppState>();
    appState.updateSettings(
      appState.settings.copyWith(
        corporateDnsIp: _dnsController.text.trim(),
        splitTunnelDomains: _domains,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Routing rules saved')),
    );
  }

  void _addDomain() {
    final domain = _domainController.text.trim();
    if (domain.isNotEmpty) {
      if (!_domains.contains(domain)) {
        setState(() {
          _domains.add(domain);
        });
        _domainController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Domain already added')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Split-Tunnel Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save Rules',
            onPressed: _saveSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          ExpressiveCard(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpressiveIconContainer(
                  icon: Icons.info_outline_rounded,
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
                        'What is Split-Tunneling?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Traffic destined for the domains listed below will resolve via your private corporate DNS server instead of your secure primary DNS provider. Useful for internal corporate/work intranets.',
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
          ),
          const SizedBox(height: 24),
          ExpressiveSectionHeader(
            title: 'Corporate Resolver',
            icon: Icons.dns_rounded,
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corporate DNS Server IP',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requests for split-tunnel domains will be forwarded here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dnsController,
                  keyboardType: TextInputType.values[3], // IP Address/numbers
                  decoration: InputDecoration(
                    hintText: 'e.g. 192.168.1.1',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ExpressiveSectionHeader(
            title: 'Bypass Domains',
            icon: Icons.alt_route_rounded,
          ),
          const SizedBox(height: 8),
          ExpressiveCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _domainController,
                        decoration: InputDecoration(
                          hintText: 'e.g. corp.company.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _addDomain(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _addDomain,
                    ),
                  ],
                ),
                if (_domains.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _domains.length,
                    itemBuilder: (context, index) {
                      final item = _domains[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ExpressiveIconContainer(
                          icon: Icons.link_rounded,
                          size: 36,
                          iconSize: 18,
                          color: colorScheme.secondary,
                        ),
                        title: Text(
                          item,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _domains.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Icon(
                    Icons.lan_outlined,
                    size: 40,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No split-tunnel domains added yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
