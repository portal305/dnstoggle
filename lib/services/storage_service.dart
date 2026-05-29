import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/dns_service.dart' show InstalledApp;

class StorageService {
  static const String _selectedServerKey = 'selected_server_id';
  static const String _isRunningKey = 'is_running';
  static const String _settingsKey = 'app_settings';
  static const String _allServersKey = 'all_servers';
  static const String _excludedAppsKey = 'excluded_apps';
  static const String _serverLatenciesKey = 'server_latencies';
  static const String _installedAppsKey = 'installed_apps';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<DnsServer> getServers() {
    final allServersJson = _prefs.getStringList(_allServersKey) ?? [];
    if (allServersJson.isEmpty) {
      return DnsServer.defaultServers;
    }

    final latencies = getServerLatencies();
    final servers = allServersJson
        .map((json) => DnsServer.fromJson(jsonDecode(json)))
        .map((server) {
          final latency = latencies[server.id];
          if (latency != null) {
            return server.copyWith(latencyMs: latency);
          }
          return server;
        })
        .toList();
    return servers;
  }

  Future<void> saveAllServers(List<DnsServer> servers) async {
    final jsonList = servers.map((s) {
      final serverJson = s.toJson();
      serverJson.remove('latencyMs');
      return jsonEncode(serverJson);
    }).toList();
    await _prefs.setStringList(_allServersKey, jsonList);
  }

  Future<void> addCustomServer(DnsServer server) async {
    final servers = getServers();
    servers.add(server.copyWith(isCustom: true));
    await saveAllServers(servers);
  }

  Future<void> removeServer(String serverId) async {
    final servers = getServers();
    servers.removeWhere((s) => s.id == serverId);
    if (servers.isEmpty) {
      servers.addAll(DnsServer.defaultServers);
    }
    await saveAllServers(servers);
  }

  Future<void> updateServer(DnsServer server) async {
    final servers = getServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      servers[index] = server;
      await saveAllServers(servers);
    }
  }

  String getSelectedServerId() {
    return _prefs.getString(_selectedServerKey) ?? 'adguard';
  }

  Future<void> setSelectedServerId(String serverId) async {
    await _prefs.setString(_selectedServerKey, serverId);
  }

  bool getIsRunning() {
    return _prefs.getBool(_isRunningKey) ?? false;
  }

  Future<void> setIsRunning(bool value) async {
    await _prefs.setBool(_isRunningKey, value);
  }

  DateTime? getProtectionStartedAt() {
    final str = _prefs.getString('protection_started_at');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<void> setProtectionStartedAt(DateTime? value) async {
    if (value == null) {
      await _prefs.remove('protection_started_at');
    } else {
      await _prefs.setString('protection_started_at', value.toIso8601String());
    }
  }

  DnsServer? getRunningServer() {
    final isRunning = getIsRunning();
    if (!isRunning) return null;

    final serverId = getSelectedServerId();
    final servers = getServers();
    try {
      return servers.firstWhere((s) => s.id == serverId);
    } catch (_) {
      return servers.isNotEmpty ? servers.first : null;
    }
  }

  AppSettings getSettings() {
    final json = _prefs.getString(_settingsKey);
    if (json == null) return AppSettings();
    return AppSettings.fromJson(jsonDecode(json));
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  List<ExcludedApp> getExcludedApps() {
    final jsonList = _prefs.getStringList(_excludedAppsKey);
    if (jsonList == null || jsonList.isEmpty) return [];
    return jsonList.map((json) => ExcludedApp.fromJson(jsonDecode(json))).toList();
  }

  Future<void> saveExcludedApps(List<ExcludedApp> apps) async {
    final jsonList = apps.map((a) => jsonEncode(a.toJson())).toList();
    await _prefs.setStringList(_excludedAppsKey, jsonList);
  }

  Future<void> addExcludedApp(ExcludedApp app) async {
    final apps = getExcludedApps();
    if (!apps.any((a) => a.packageName == app.packageName)) {
      apps.add(app);
      await saveExcludedApps(apps);
    }
  }

  Future<void> removeExcludedApp(String packageName) async {
    final apps = getExcludedApps();
    apps.removeWhere((a) => a.packageName == packageName);
    await saveExcludedApps(apps);
  }

  Map<String, int> getServerLatencies() {
    final json = _prefs.getString(_serverLatenciesKey);
    if (json == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(json);
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveServerLatencies(Map<String, int> latencies) async {
    await _prefs.setString(_serverLatenciesKey, jsonEncode(latencies));
  }

  Future<void> updateServerLatency(String serverId, int latencyMs) async {
    final latencies = getServerLatencies();
    latencies[serverId] = latencyMs;
    await saveServerLatencies(latencies);
  }

  String exportServers() {
    final servers = getServers().where((s) => s.isCustom).toList();
    return jsonEncode(servers.map((s) => s.toJson()).toList());
  }

  Future<void> importServers(String json) async {
    try {
      final List<dynamic> decoded = jsonDecode(json);
      final newServers = decoded.map((j) => DnsServer.fromJson(j)).toList();

      final currentServers = getServers();
      for (var server in newServers) {
        if (!currentServers.any((s) => s.id == server.id)) {
          currentServers.add(server);
        }
      }
      await saveAllServers(currentServers);
    } catch (e) {
      throw Exception('Failed to import servers: $e');
    }
  }

  List<InstalledApp> getInstalledApps() {
    final jsonList = _prefs.getStringList(_installedAppsKey);
    if (jsonList == null || jsonList.isEmpty) return [];
    return jsonList.map((json) {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return InstalledApp(
        packageName: map['packageName'] as String,
        appName: map['appName'] as String,
        iconBase64: map['iconBase64'] as String?,
      );
    }).toList();
  }

  Future<void> saveInstalledApps(List<InstalledApp> apps) async {
    final jsonList = apps.map((a) => jsonEncode({
      'packageName': a.packageName,
      'appName': a.appName,
      'iconBase64': a.iconBase64,
    })).toList();
    await _prefs.setStringList(_installedAppsKey, jsonList);
  }
}