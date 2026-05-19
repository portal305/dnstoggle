import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('DNS Servers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Latencies',
            onPressed: () {
              context.read<AppState>().measureAllLatencies();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddServerSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final servers = appState.servers;
          final selectedId = appState.selectedServer?.id;

          final filteredServers = servers.where((server) {
            if (_searchQuery.isEmpty) return true;
            return server.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                server.primaryDns.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (_searchQuery.isEmpty && servers.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search servers...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              if (appState.isMeasuringLatency)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Measuring server latencies...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredServers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No servers match your search',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        itemCount: filteredServers.length,
                        itemBuilder: (context, index) {
                          final server = filteredServers[index];
                          final isSelected = server.id == selectedId;
                          final latency = appState.serverLatencies[server.id];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildExpressiveServerCard(
                              context,
                              appState,
                              server,
                              isSelected,
                              latency,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dns_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Servers Configured',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first custom DNS server to start securing your connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _showAddServerSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Custom Server'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpressiveServerCard(
    BuildContext context,
    AppState appState,
    DnsServer server,
    bool isSelected,
    int? latency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => appState.selectServer(server),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.6)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? Icons.shield_rounded : Icons.dns_rounded,
                size: 20,
                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    server.primaryDns,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (latency != null) ...[
              const SizedBox(width: 8),
              LatencyIndicator(
                latencyMs: latency,
                showLabel: true,
                size: 14,
              ),
              const SizedBox(width: 8),
            ],
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
            if (server.isCustom) ...[
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                onPressed: () => _showAddServerSheet(context, server: server),
              ),
              if (!isSelected)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  onPressed: () => _showDeleteDialog(context, appState, server),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    AppState appState,
    DnsServer server,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, size: 32),
        iconColor: Theme.of(context).colorScheme.error,
        title: const Text('Delete Server?'),
        content: Text(
          'This will permanently remove "${server.name}" from your list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      appState.removeServer(server.id);
    }
  }

  void _showAddServerSheet(BuildContext context, {DnsServer? server}) {
    final nameController = TextEditingController(text: server?.name);
    final primaryDnsController = TextEditingController(
      text: server?.primaryDns,
    );
    final secondaryDnsController = TextEditingController(
      text: server?.secondaryDns,
    );
    final bool isEditing = server != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    isEditing ? 'Edit DNS Server' : 'Add Custom DNS',
                    style: Theme.of(sheetContext).textTheme.headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Server Name',
                      hintText: 'e.g. My Private DNS',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: primaryDnsController,
                    decoration: const InputDecoration(
                      labelText: 'DNS Hostname',
                      hintText: 'e.g. dns.example.com',
                      prefixIcon: Icon(Icons.lan_rounded),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: secondaryDnsController,
                    decoration: const InputDecoration(
                      labelText: 'Secondary (Optional)',
                      hintText: 'e.g. 1.1.1.1',
                      prefixIcon: Icon(Icons.alt_route_rounded),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final primaryDns = primaryDnsController.text.trim();
                        final secondaryDns = secondaryDnsController.text.trim();

                        if (name.isEmpty || primaryDns.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in required fields'),
                            ),
                          );
                          return;
                        }

                        final newServer = DnsServer(
                          id: isEditing
                              ? server.id
                              : 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          primaryDns: primaryDns,
                          secondaryDns: secondaryDns.isNotEmpty
                              ? secondaryDns
                              : null,
                          isCustom: true,
                        );

                        final appState = sheetContext.read<AppState>();
                        if (isEditing) {
                          appState.updateCustomServer(newServer);
                        } else {
                          appState.addCustomServer(newServer);
                          appState.selectServer(newServer);
                        }

                        Navigator.pop(sheetContext);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Save Changes' : 'Create Server',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}