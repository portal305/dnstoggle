import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

class DnsService {
  static const MethodChannel _shizukuChannel = MethodChannel(
    'dnstoggle/shizuku_native',
  );

  bool _isRunning = false;
  DnsServer? _currentServer;

  static const String _modeKey = 'private_dns_mode';
  static const String _specifierKey = 'private_dns_specifier';
  static const String _modeHostname = 'hostname';
  static const String _modeOff = 'off';

  bool get isRunning => _isRunning;
  DnsServer? get currentServer => _currentServer;

  Future<bool> checkShizukuPermission() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'checkPermission',
      );
      debugPrint('DnsService: Shizuku permission check: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('Shizuku permission check failed: $e');
      return false;
    }
  }

  Future<bool> requestShizukuPermission() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'requestPermission',
      );
      debugPrint('DnsService: Shizuku permission request: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('Shizuku permission request failed: $e');
      return false;
    }
  }

  Future<bool> checkDnsSupport() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'checkDnsSupport',
      );
      return result ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> isBinderAlive() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>('pingBinder');
      debugPrint('DnsService: Shizuku binder alive: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('DnsService: Shizuku binder check failed: $e');
      return false;
    }
  }

  Future<String?> runCommand(String command) async {
    try {
      final result = await _shizukuChannel.invokeMethod<String>('runCommand', {
        'command': command,
      });
      debugPrint(
        'DnsService: Command result: ${result?.substring(0, result.length > 100 ? 100 : result.length)}',
      );
      return result;
    } catch (e) {
      debugPrint('DnsService: Command failed: $command -> $e');
      return null;
    }
  }

  Future<bool> startDnsService(DnsServer server) async {
    try {
      final hasPermission = await checkShizukuPermission();
      if (!hasPermission) {
        debugPrint('No Shizuku permission');
        return false;
      }

      _currentServer = server;
      debugPrint('Starting DNS: ${server.primaryDns}');

      await runCommand(
        'settings put global $_specifierKey ${server.primaryDns}',
      );
      await Future.delayed(const Duration(milliseconds: 100));
      await runCommand('settings put global $_modeKey $_modeHostname');

      await Future.delayed(const Duration(milliseconds: 200));
      final actualState = await checkActualDnsState();
      _isRunning = actualState;

      await notifyStateChanged();

      return actualState;
    } catch (e) {
      debugPrint('DNS start failed: $e');
      return false;
    }
  }

  Future<bool> stopDnsService() async {
    try {
      final hasPermission = await checkShizukuPermission();
      if (!hasPermission) {
        debugPrint('No Shizuku permission');
        return false;
      }

      debugPrint('Stopping DNS');

      await runCommand('settings put global $_modeKey $_modeOff');

      await Future.delayed(const Duration(milliseconds: 200));
      final actualState = await checkActualDnsState();
      _isRunning = actualState;
      _currentServer = null;

      await notifyStateChanged();

      return !actualState;
    } catch (e) {
      debugPrint('DNS stop failed: $e');
      _isRunning = false;
      _currentServer = null;
      return false;
    }
  }

  Future<bool> checkActualDnsState() async {
    try {
      final modeResult = await runCommand('settings get global $_modeKey');
      final specResult = await runCommand('settings get global $_specifierKey');

      final mode = modeResult?.trim() ?? '';
      final spec = specResult?.trim() ?? '';

      debugPrint('DnsService: Actual DNS state - Mode=$mode, Specifier=$spec');

      return mode == _modeHostname && spec.isNotEmpty;
    } catch (e) {
      debugPrint('DnsService: State check failed: $e');
      return false;
    }
  }

  Future<bool> applyDns(DnsServer server) async {
    if (_isRunning) {
      await stopDnsService();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return startDnsService(server);
  }

  Future<int> measureLatency(String hostname) async {
    try {
      final stopwatch = Stopwatch()..start();
      final addresses = await InternetAddress.lookup(hostname)
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (addresses.isNotEmpty) {
        return stopwatch.elapsedMilliseconds;
      }
      return -1;
    } catch (e) {
      debugPrint('Latency measurement failed for $hostname: $e');
      return -1;
    }
  }

  Future<Map<String, int>> measureAllServersLatencies(List<DnsServer> servers) async {
    final Map<String, int> latencies = {};
    for (final server in servers) {
      final latency = await measureLatency(server.primaryDns);
      if (latency > 0) {
        latencies[server.id] = latency;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return latencies;
  }

  Future<DnsTestResult> testDnsConnection() async {
    try {
      final hasPermission = await checkShizukuPermission();
      if (!hasPermission) {
        return DnsTestResult(
          isSuccess: false,
          currentDns: 'No Shizuku',
          resolvedIp: 'No Shizuku',
          message: 'Shizuku permission required',
          latencyMs: 0,
        );
      }

      final modeResult = await runCommand('settings get global $_modeKey');
      final specResult = await runCommand('settings get global $_specifierKey');

      final mode = modeResult?.trim() ?? '';
      final spec = specResult?.trim() ?? '';

      bool isConfigured = mode == _modeHostname && spec.isNotEmpty;

      if (!isConfigured) {
        return DnsTestResult(
          isSuccess: false,
          currentDns: spec.isEmpty ? 'None' : spec,
          resolvedIp: 'N/A',
          message: 'DNS not configured in system',
          latencyMs: 0,
        );
      }

      try {
        final stopwatch = Stopwatch()..start();
        final result = await InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 3));
        stopwatch.stop();

        if (result.isNotEmpty) {
          return DnsTestResult(
            isSuccess: true,
            currentDns: spec,
            resolvedIp: result.first.address,
            message: 'DNS is working correctly',
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }
      } catch (e) {
        return DnsTestResult(
          isSuccess: false,
          currentDns: spec,
          resolvedIp: 'Failed',
          message: 'Resolution failed: $e',
          latencyMs: 0,
        );
      }

      return DnsTestResult(
        isSuccess: false,
        currentDns: spec,
        resolvedIp: 'N/A',
        message: 'Unknown error during resolution',
        latencyMs: 0,
      );
    } catch (e) {
      return DnsTestResult(
        isSuccess: false,
        currentDns: 'Error',
        resolvedIp: 'Error',
        message: 'Test failed: $e',
        latencyMs: 0,
      );
    }
  }

  Future<bool> notifyStateChanged() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'notifyStateChanged',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to notify state change: $e');
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  Future<bool> startNotificationService() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'startNotificationService',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to start notification service: $e');
      return false;
    }
  }

  Future<bool> stopNotificationService() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'stopNotificationService',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to stop notification service: $e');
      return false;
    }
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      debugPrint('DnsService: Requesting installed apps...');
      final result = await _shizukuChannel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      debugPrint('DnsService: Got result: ${result?.length ?? 0} apps');
      if (result == null) {
        debugPrint('DnsService: Result is null');
        return [];
      }
      final apps = result.map((app) {
        final map = Map<String, dynamic>.from(app as Map);
        return InstalledApp(
          packageName: map['packageName'] as String,
          appName: map['appName'] as String,
          iconBase64: map['iconBase64'] as String?,
        );
      }).toList();
      debugPrint('DnsService: Parsed ${apps.length} apps');
      return apps;
    } catch (e, stack) {
      debugPrint('Failed to get installed apps: $e');
      debugPrint('Stack: $stack');
      return [];
    }
  }

  Future<bool> hasUsageAccessPermission() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>(
        'hasUsageAccessPermission',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check usage access: $e');
      return false;
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _shizukuChannel.invokeMethod('openUsageAccessSettings');
    } catch (e) {
      debugPrint('Failed to open usage access settings: $e');
    }
  }

  Future<void> startExcludedAppMonitor() async {
    try {
      await _shizukuChannel.invokeMethod('startExcludedAppMonitor');
    } catch (e) {
      debugPrint('Failed to start excluded app monitor: $e');
    }
  }

  Future<void> stopExcludedAppMonitor() async {
    try {
      await _shizukuChannel.invokeMethod('stopExcludedAppMonitor');
    } catch (e) {
      debugPrint('Failed to stop excluded app monitor: $e');
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check accessibility service: $e');
      return false;
    }
  }

  Future<void> syncExcludedApps(List<ExcludedApp> apps) async {
    try {
      final packageNames = apps.map((a) => a.packageName).toList();
      await _shizukuChannel.invokeMethod('syncExcludedApps', {
        'packages': packageNames,
      });
    } catch (e) {
      debugPrint('Failed to sync excluded apps: $e');
    }
  }

  Future<DnsLeakResult> performDnsLeakTest(bool isProtectionRunning) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    
    Map<String, dynamic> clientJson = {};
    Map<String, dynamic> dnsJson = {};

    try {
      final clientRequest = await client.getUrl(Uri.parse('https://ip-api.com/json'));
      final clientResponse = await clientRequest.close();
      if (clientResponse.statusCode == 200) {
        final body = await clientResponse.transform(utf8.decoder).join();
        clientJson = jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('DnsService: Failed to fetch client IP: $e');
    }

    try {
      final dnsRequest = await client.getUrl(Uri.parse('https://edns.ip-api.com/json'));
      final dnsResponse = await dnsRequest.close();
      if (dnsResponse.statusCode == 200) {
        final body = await dnsResponse.transform(utf8.decoder).join();
        dnsJson = jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('DnsService: Failed to fetch DNS resolver IP: $e');
    } finally {
      client.close();
    }

    return DnsLeakResult.fromJson(
      clientJson: clientJson,
      dnsJson: dnsJson,
      isProtectionRunning: isProtectionRunning,
    );
  }

  Future<bool> checkVpnPermission() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>('prepareVpn');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check VPN permission: $e');
      return false;
    }
  }

  Future<bool> startVpn(String dohUrl, String corporateDns, List<String> splitDomains) async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>('startVpnService', {
        'dohUrl': dohUrl,
        'corporateDns': corporateDns,
        'splitDomains': splitDomains,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to start VPN service: $e');
      return false;
    }
  }

  Future<bool> stopVpn() async {
    try {
      final result = await _shizukuChannel.invokeMethod<bool>('stopVpnService');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to stop VPN service: $e');
      return false;
    }
  }

  void dispose() {}
}


class DnsTestResult {
  final bool isSuccess;
  final String? currentDns;
  final String? resolvedIp;
  final String message;
  final int latencyMs;

  DnsTestResult({
    required this.isSuccess,
    required this.currentDns,
    required this.resolvedIp,
    required this.message,
    required this.latencyMs,
  });
}

class InstalledApp {
  final String packageName;
  final String appName;
  final String? iconBase64;

  InstalledApp({
    required this.packageName,
    required this.appName,
    this.iconBase64,
  });
}