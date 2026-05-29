import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/dns_service.dart';

class ExcludedAppsScreen extends StatefulWidget {
  final bool showOnlyExcluded;

  const ExcludedAppsScreen({super.key, this.showOnlyExcluded = false});

  @override
  State<ExcludedAppsScreen> createState() => _ExcludedAppsScreenState();
}

class _ExcludedAppsScreenState extends State<ExcludedAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (!appState.hasLoadedApps) {
        appState.loadInstalledApps();
      }
    });
  }

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
        title: Text(
          widget.showOnlyExcluded ? 'Excluded Apps' : 'Manage Excluded Apps',
        ),
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (appState.isRefreshingApps) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final excludedApps = appState.excludedApps;
          final installedApps = appState.installedApps;
          final isLoading = appState.isLoadingApps;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.showOnlyExcluded
                        ? 'Search excluded apps...'
                        : 'Search apps...',
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              if (installedApps.isNotEmpty)
                Expanded(
                  child: _buildAppList(context, installedApps, excludedApps),
                )
              else if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.apps_outage_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No apps available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to load installed apps.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
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
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          app.appName.isNotEmpty
              ? app.appName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildAppList(
    BuildContext context,
    List<InstalledApp> installedApps,
    List<ExcludedApp> excludedApps,
  ) {
    List<InstalledApp> displayApps;

    if (widget.showOnlyExcluded) {
      final excludedPackageNames = excludedApps
          .map((e) => e.packageName)
          .toSet();
      displayApps = installedApps.where((app) {
        final matches = excludedPackageNames.contains(app.packageName);
        if (_searchQuery.isEmpty) return matches;
        return matches &&
            (app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                app.packageName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ));
      }).toList();

      if (displayApps.isEmpty && excludedApps.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No excluded apps',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'All apps are using DNS filtering.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const ExcludedAppsScreen(showOnlyExcluded: false),
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
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Excluded Apps'),
              ),
            ],
          ),
        );
      }
    } else {
      displayApps = installedApps.where((app) {
        if (_searchQuery.isEmpty) return true;
        return app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (displayApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No apps match your search',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: displayApps.length,
      itemBuilder: (context, index) {
        final app = displayApps[index];
        final isExcluded = excludedApps.any(
          (e) => e.packageName == app.packageName,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            leading: _buildAppIcon(app),
            title: Text(
              app.appName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              app.packageName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: widget.showOnlyExcluded
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () {
                      context.read<AppState>().removeExcludedApp(
                        app.packageName,
                      );
                    },
                  )
                : Switch(
                    value: isExcluded,
                    onChanged: (value) {
                      final appState = context.read<AppState>();
                      if (value) {
                        appState.addExcludedApp(
                          ExcludedApp(
                            packageName: app.packageName,
                            appName: app.appName,
                            excludedAt: DateTime.now(),
                          ),
                        );
                      } else {
                        appState.removeExcludedApp(app.packageName);
                      }
                    },
                  ),
          ),
        );
      },
    );
  }
}
