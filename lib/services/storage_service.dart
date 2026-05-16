import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _selectedServerKey = 'selected_server_id';
  static const String _isRunningKey = 'is_running';
  static const String _settingsKey = 'app_settings';
  static const String _allServersKey = 'all_servers';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<DnsServer> getServers() {
    final allServersJson = _prefs.getStringList(_allServersKey) ?? [];
    if (allServersJson.isEmpty) {
      return DnsServer.defaultServers;
    }
    
    final servers = allServersJson
        .map((json) => DnsServer.fromJson(jsonDecode(json)))
        .toList();
    return servers;
  }

  Future<void> saveAllServers(List<DnsServer> servers) async {
    final jsonList = servers.map((s) => jsonEncode(s.toJson())).toList();
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
}