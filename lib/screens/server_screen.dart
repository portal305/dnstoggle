import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';

class ServerScreen extends StatelessWidget {
  const ServerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'DNS Servers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
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

          if (servers.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: servers.length,
            itemBuilder: (context, index) {
              final server = servers[index];
              final isSelected = server.id == selectedId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildExpressiveServerCard(
                  context,
                  appState,
                  server,
                  isSelected,
                ),
              );
            },
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
                ).colorScheme.primaryContainer.withOpacity(0.5),
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
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: () => appState.selectServer(server),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.dns_rounded,
            size: 20,
            color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
          ),
        ),
        title: Text(
          server.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          server.primaryDns,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 22,
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
                          borderRadius: BorderRadius.circular(20),
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
