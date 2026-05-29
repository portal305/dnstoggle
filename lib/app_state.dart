import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/models.dart';
import '../services/services.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final StorageService _storageService;
  final DnsService _dnsService;
  final ShizukuService _shizukuService;

  List<DnsServer> _servers = [];
  DnsServer? _selectedServer;
  bool _isRunning = false;
  AppSettings _settings = AppSettings();
  bool _shizukuHasPermission = false;
  bool _shizukuBinderAlive = false;
  bool _deviceSupportsDns = true;
  bool _isLoading = true;
  DnsTestResult? _testResult;
  bool _isTesting = false;
  DnsLeakResult? _leakTestResult;
  bool _isTestingLeak = false;
  String _appVersion = '1.0.0';
  List<ExcludedApp> _excludedApps = [];
  Map<String, int> _serverLatencies = {};
  bool _isMeasuringLatency = false;
  List<InstalledApp> _installedApps = [];
  bool _isLoadingApps = false;
  bool _hasLoadedApps = false;
  bool _isRefreshingApps = false;
  DateTime? _protectionStartedAt;

  List<DnsServer> get servers => _servers;
  DnsServer? get selectedServer => _selectedServer;
  bool get isRunning => _isRunning;
  AppSettings get settings => _settings;
  bool get shizukuHasPermission => _shizukuHasPermission;
  bool get shizukuBinderAlive => _shizukuBinderAlive;
  bool get deviceSupportsDns => _deviceSupportsDns;
  bool get isLoading => _isLoading;
  DnsTestResult? get testResult => _testResult;
  bool get isTesting => _isTesting;
  DnsLeakResult? get leakTestResult => _leakTestResult;
  bool get isTestingLeak => _isTestingLeak;
  String get appVersion => _appVersion;
  List<ExcludedApp> get excludedApps => _excludedApps;
  Map<String, int> get serverLatencies => _serverLatencies;
  bool get isMeasuringLatency => _isMeasuringLatency;
  DateTime? get protectionStartedAt => _protectionStartedAt;
  List<InstalledApp> get installedApps => _installedApps;
  bool get isLoadingApps => _isLoadingApps;
  bool get hasLoadedApps => _hasLoadedApps;
  bool get isRefreshingApps => _isRefreshingApps;

  AppState({
    required StorageService storageService,
    required DnsService dnsService,
    required ShizukuService shizukuService,
  }) : _storageService = storageService,
       _dnsService = dnsService,
       _shizukuService = shizukuService {
    WidgetsBinding.instance.addObserver(this);
    _shizukuChannel.setMethodCallHandler((call) async {
      debugPrint(
        'AppState: Received method call ${call.method} with args ${call.arguments}',
      );
      if (call.method == 'onStateChanged') {
        final bool isRunning = call.arguments as bool;
        debugPrint('AppState: Updating isRunning to $isRunning');
        _isRunning = isRunning;
        notifyListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('AppState: App resumed, refreshing state');
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    _shizukuBinderAlive = await _shizukuService.checkBinderAlive();
    _shizukuHasPermission = await _shizukuService.checkSelfPermission();
    if (_settings.useVpnMode) {
      notifyListeners();
      return;
    }
    final newState = await _dnsService.checkActualDnsState();
    if (newState != _isRunning) {
      _isRunning = newState;
    }
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _storageService.init();
    await _shizukuService.checkPermissionStatus();
    _shizukuBinderAlive = await _shizukuService.checkBinderAlive();

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (e) {
      debugPrint('Failed to get app version: $e');
    }

    _deviceSupportsDns = await _dnsService.checkDnsSupport();
    _shizukuHasPermission = _shizukuService.hasPermission;
    _servers = _storageService.getServers();
    _settings = _storageService.getSettings();
    _excludedApps = _storageService.getExcludedApps();
    _serverLatencies = _storageService.getServerLatencies();
    _installedApps = _storageService.getInstalledApps();
    if (_installedApps.isNotEmpty) {
      _hasLoadedApps = true;
    }
    _protectionStartedAt = _storageService.getProtectionStartedAt();

    final selectedId = _storageService.getSelectedServerId();
    _selectedServer = _servers.firstWhere(
      (s) => s.id == selectedId,
      orElse: () => _servers.first,
    );
    _isRunning = _storageService.getIsRunning();

    await Future.delayed(const Duration(milliseconds: 300));

    if (_settings.useVpnMode) {
      _isRunning = _storageService.getIsRunning();
    } else {
      _isRunning = await _dnsService.checkActualDnsState();
      await _storageService.setIsRunning(_isRunning);
      if (!_isRunning) {
        _protectionStartedAt = null;
        await _storageService.setProtectionStartedAt(null);
      }
    }

    if (_settings.persistentNotification && _isRunning) {
      await _dnsService.startNotificationService();
    }

    if (_settings.excludedAppsMonitor &&
        _excludedApps.isNotEmpty &&
        _isRunning) {
      await _dnsService.syncExcludedApps(_excludedApps);
      await _dnsService.startExcludedAppMonitor();
    }

    _isLoading = false;
    notifyListeners();

    if (_serverLatencies.isEmpty) {
      measureAllLatencies();
    }

    loadInstalledApps();
  }

  Future<bool> checkBinderAlive() async {
    _shizukuBinderAlive = await _shizukuService.checkBinderAlive();
    notifyListeners();
    return _shizukuBinderAlive;
  }

  Future<bool> requestShizukuPermission() async {
    await _shizukuService.requestPermission();
    _shizukuHasPermission = await _shizukuService.checkSelfPermission();
    _shizukuBinderAlive = await _shizukuService.checkBinderAlive();
    notifyListeners();
    return _shizukuHasPermission;
  }

  Future<void> selectServer(DnsServer server) async {
    final wasRunning = _isRunning;
    _selectedServer = server;
    await _storageService.setSelectedServerId(server.id);

    if (wasRunning) {
      await stopDnsService();
      await startDnsService();
    } else {
      await _dnsService.notifyStateChanged();
    }

    notifyListeners();
  }

  Future<void> addCustomServer(DnsServer server) async {
    await _storageService.addCustomServer(server);
    _servers = _storageService.getServers();
    notifyListeners();
  }

  Future<void> updateCustomServer(DnsServer server) async {
    await _storageService.updateServer(server);
    _servers = _storageService.getServers();
    if (_selectedServer?.id == server.id) {
      _selectedServer = server;
    }
    notifyListeners();
  }

  Future<void> removeServer(String serverId) async {
    final currentRunningServerId = _selectedServer?.id;

    await _storageService.removeServer(serverId);
    _servers = _storageService.getServers();

    if (currentRunningServerId == serverId && _servers.isNotEmpty) {
      _selectedServer = _servers.first;
      await _storageService.setSelectedServerId(_selectedServer!.id);
    }

    notifyListeners();
  }

  Future<void> toggleDnsService() async {
    final actualState = await _dnsService.checkActualDnsState();
    debugPrint('AppState: Actual DNS state: $actualState');

    if (actualState) {
      await stopDnsService();
    } else {
      await startDnsService();
    }

    _isRunning = await _dnsService.checkActualDnsState();
    notifyListeners();
  }

  Future<bool> startDnsService() async {
    if (_selectedServer == null) return false;

    if (_settings.useVpnMode) {
      final hasPermission = await _dnsService.checkVpnPermission();
      if (!hasPermission) {
        return false;
      }

      String dohUrl = _settings.customDohUrl;
      if (dohUrl.isEmpty) {
        dohUrl = 'https://${_selectedServer!.primaryDns}/dns-query';
      }

      final success = await _dnsService.startVpn(
        dohUrl,
        _settings.corporateDnsIp,
        _settings.splitTunnelDomains,
      );
      if (success) {
        _isRunning = true;
        await _storageService.setIsRunning(true);
        _protectionStartedAt = DateTime.now();
        await _storageService.setProtectionStartedAt(_protectionStartedAt);
      }
      notifyListeners();
      return success;
    }

    if (!_shizukuHasPermission) {
      _shizukuHasPermission = await _shizukuService.requestPermission();
      if (!_shizukuHasPermission) {
        return false;
      }
    }

    final success = await _dnsService.startDnsService(_selectedServer!);
    if (success) {
      _isRunning = await _dnsService.checkActualDnsState();
      await _storageService.setIsRunning(_isRunning);
      _protectionStartedAt = DateTime.now();
      await _storageService.setProtectionStartedAt(_protectionStartedAt);

      if (_settings.persistentNotification) {
        await _dnsService.startNotificationService();
      }
      if (_settings.excludedAppsMonitor && _excludedApps.isNotEmpty) {
        await _dnsService.syncExcludedApps(_excludedApps);
        await _dnsService.startExcludedAppMonitor();
      }
    }
    notifyListeners();
    return success;
  }

  Future<bool> stopDnsService() async {
    if (_settings.useVpnMode) {
      final success = await _dnsService.stopVpn();
      if (success) {
        _isRunning = false;
        await _storageService.setIsRunning(false);
        _protectionStartedAt = null;
        await _storageService.setProtectionStartedAt(null);
      }
      notifyListeners();
      return success;
    }

    if (!_shizukuHasPermission) {
      _shizukuHasPermission = await _shizukuService.requestPermission();
      if (!_shizukuHasPermission) {
        return false;
      }
    }

    await _dnsService.stopExcludedAppMonitor();
    final success = await _dnsService.stopDnsService();
    if (success) {
      _isRunning = await _dnsService.checkActualDnsState();
      await _storageService.setIsRunning(_isRunning);
      _protectionStartedAt = null;
      await _storageService.setProtectionStartedAt(null);

      if (_settings.persistentNotification) {
        await _dnsService.stopNotificationService();
      }
    }
    notifyListeners();
    return success;
  }

  Future<void> testConnection() async {
    _isTesting = true;
    _testResult = null;
    notifyListeners();

    _testResult = await _dnsService.testDnsConnection();

    _isTesting = false;
    notifyListeners();
  }

  void clearTestResult() {
    _testResult = null;
    notifyListeners();
  }

  Future<void> runDnsLeakTest() async {
    _isTestingLeak = true;
    _leakTestResult = null;
    notifyListeners();

    try {
      _leakTestResult = await _dnsService.performDnsLeakTest(_isRunning);
    } catch (e) {
      debugPrint('AppState: Leak test failed: $e');
    } finally {
      _isTestingLeak = false;
      notifyListeners();
    }
  }

  void clearLeakTestResult() {
    _leakTestResult = null;
    notifyListeners();
  }

  Future<void> measureAllLatencies() async {
    if (_isMeasuringLatency) return;

    _isMeasuringLatency = true;
    notifyListeners();

    for (final server in _servers) {
      final latency = await _dnsService.measureLatency(server.primaryDns);
      if (latency > 0) {
        _serverLatencies[server.id] = latency;
        await _storageService.updateServerLatency(server.id, latency);
      } else {
        _serverLatencies[server.id] = -1;
      }
    }

    _servers = _storageService.getServers();
    _isMeasuringLatency = false;
    notifyListeners();
  }

  Future<void> refreshLatency(String serverId) async {
    final server = _servers.firstWhere((s) => s.id == serverId);
    final latency = await _dnsService.measureLatency(server.primaryDns);
    if (latency > 0) {
      _serverLatencies[serverId] = latency;
      await _storageService.updateServerLatency(serverId, latency);
    } else {
      _serverLatencies[serverId] = -1;
    }
    _servers = _storageService.getServers();
    notifyListeners();
  }

  Future<void> addExcludedApp(ExcludedApp app) async {
    if (!_excludedApps.any((a) => a.packageName == app.packageName)) {
      _excludedApps.add(app);
      await _storageService.saveExcludedApps(_excludedApps);
      await _dnsService.syncExcludedApps(_excludedApps);

      if (_isRunning &&
          _settings.excludedAppsMonitor &&
          _excludedApps.length == 1) {
        await _dnsService.startExcludedAppMonitor();
      }
      notifyListeners();
    }
  }

  Future<void> removeExcludedApp(String packageName) async {
    _excludedApps.removeWhere((a) => a.packageName == packageName);
    await _storageService.saveExcludedApps(_excludedApps);
    await _dnsService.syncExcludedApps(_excludedApps);
    if (_excludedApps.isEmpty) {
      await _dnsService.stopExcludedAppMonitor();
    }
    notifyListeners();
  }

  Future<void> loadInstalledApps() async {
    if (_isLoadingApps || _isRefreshingApps) return;

    if (_hasLoadedApps) {
      _isRefreshingApps = true;
      notifyListeners();

      _dnsService
          .getInstalledApps()
          .then((apps) {
            _installedApps = apps;
            _storageService.saveInstalledApps(apps);
            _isLoadingApps = false;
            _isRefreshingApps = false;
            _hasLoadedApps = true;
            notifyListeners();
          })
          .catchError((e) {
            debugPrint('Failed to refresh apps: $e');
            _isRefreshingApps = false;
            notifyListeners();
          });
      return;
    }

    _isLoadingApps = true;
    notifyListeners();

    _dnsService
        .getInstalledApps()
        .then((apps) {
          _installedApps = apps;
          _storageService.saveInstalledApps(apps);
          _isLoadingApps = false;
          _hasLoadedApps = true;
          notifyListeners();
        })
        .catchError((e) {
          debugPrint('Failed to load apps: $e');
          _isLoadingApps = false;
          notifyListeners();
        });
  }

  Future<bool> checkUsageAccessPermission() async {
    return await _dnsService.hasUsageAccessPermission();
  }

  Future<void> openUsageAccessSettings() async {
    await _dnsService.openUsageAccessSettings();
  }

  Future<bool> requestNotificationPermission() async {
    return await _dnsService.requestNotificationPermission();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    if (newSettings.useVpnMode != _settings.useVpnMode && _isRunning) {
      await stopDnsService();
    }

    final oldPersistent = _settings.persistentNotification;
    final oldMonitor = _settings.excludedAppsMonitor;

    if ((newSettings.persistentNotification && !oldPersistent) ||
        (newSettings.excludedAppsMonitor && !oldMonitor)) {
      final granted = await _shizukuChannel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      if (granted == false) {
        notifyListeners();
        return;
      }
    }

    _settings = newSettings;
    await _storageService.saveSettings(newSettings);

    if (newSettings.persistentNotification != oldPersistent) {
      if (newSettings.persistentNotification) {
        if (_isRunning) {
          await _dnsService.startNotificationService();
        }
      } else {
        await _dnsService.stopNotificationService();
      }
    }

    if (newSettings.excludedAppsMonitor != oldMonitor) {
      if (newSettings.excludedAppsMonitor) {
        if (_isRunning && _excludedApps.isNotEmpty) {
          await _dnsService.syncExcludedApps(_excludedApps);
          await _dnsService.startExcludedAppMonitor();
        }
      } else {
        await _dnsService.stopExcludedAppMonitor();
      }
    }

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _settings = _settings.copyWith(onboardingCompleted: true);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  String exportCustomServers() {
    return _storageService.exportServers();
  }

  Future<void> importCustomServers(String json) async {
    await _storageService.importServers(json);
    _servers = _storageService.getServers();
    notifyListeners();
  }

  static const _shizukuChannel = MethodChannel('dnstoggle/shizuku_native');

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dnsService.dispose();
    _shizukuService.dispose();
    super.dispose();
  }
}
