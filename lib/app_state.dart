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
  String _appVersion = '1.0.0';

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
  String get appVersion => _appVersion;

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
    final newState = await _dnsService.checkActualDnsState();
    if (newState != _isRunning) {
      _isRunning = newState;
      notifyListeners();
    }
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

    final selectedId = _storageService.getSelectedServerId();
    _selectedServer = _servers.firstWhere(
      (s) => s.id == selectedId,
      orElse: () => _servers.first,
    );
    _isRunning = _storageService.getIsRunning();

    await Future.delayed(const Duration(milliseconds: 300));

    _isRunning = await _dnsService.checkActualDnsState();
    await _storageService.setIsRunning(_isRunning);

    if (_settings.persistentNotification) {
      await _dnsService.startNotificationService();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> checkBinderAlive() async {
    return await _shizukuService.checkBinderAlive();
  }

  Future<bool> requestShizukuPermission() async {
    final granted = await _shizukuService.requestPermission();
    _shizukuHasPermission = granted;
    notifyListeners();
    return granted;
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
      if (_settings.persistentNotification) {
        await _dnsService.startNotificationService();
      }
    }
    notifyListeners();
    return success;
  }

  Future<bool> stopDnsService() async {
    if (!_shizukuHasPermission) {
      _shizukuHasPermission = await _shizukuService.requestPermission();
      if (!_shizukuHasPermission) {
        return false;
      }
    }

    final success = await _dnsService.stopDnsService();
    if (success) {
      _isRunning = await _dnsService.checkActualDnsState();
      await _storageService.setIsRunning(_isRunning);
      if (_settings.persistentNotification) {
        await _dnsService.startNotificationService();
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

  Future<void> updateSettings(AppSettings newSettings) async {
    final oldPersistent = _settings.persistentNotification;

    if (newSettings.persistentNotification && !oldPersistent) {
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
        await _dnsService.startNotificationService();
      } else {
        await _dnsService.stopNotificationService();
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
