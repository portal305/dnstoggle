import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShizukuService {
  static const MethodChannel _channel = MethodChannel('dnstoggle/shizuku_native');
  bool _hasPermission = false;
  bool _isBinderAlive = false;

  bool get hasPermission => _hasPermission;
  bool get isBinderAlive => _isBinderAlive;

  Future<bool> checkBinderAlive() async {
    try {
      debugPrint('ShizukuService: Checking binder...');
      final result = await _channel.invokeMethod<bool>('pingBinder');
      _isBinderAlive = result ?? false;
      debugPrint('ShizukuService: Binder alive: $_isBinderAlive');
      return _isBinderAlive;
    } catch (e) {
      debugPrint('ShizukuService: Binder check failed: $e');
      _isBinderAlive = false;
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      debugPrint('ShizukuService: Requesting permission...');
      final result = await _channel.invokeMethod<bool>('requestPermission');
      _hasPermission = result ?? false;
      debugPrint('ShizukuService: Permission result: $_hasPermission');
      return _hasPermission;
    } catch (e) {
      debugPrint('ShizukuService: Permission request failed: $e');
      _hasPermission = false;
      return false;
    }
  }

  Future<bool> checkSelfPermission() async {
    try {
      debugPrint('ShizukuService: Checking permission...');
      final result = await _channel.invokeMethod<bool>('checkPermission');
      _hasPermission = result ?? false;
      debugPrint('ShizukuService: Permission granted: $_hasPermission');
      return _hasPermission;
    } catch (e) {
      debugPrint('ShizukuService: Permission check failed: $e');
      _hasPermission = false;
      return false;
    }
  }

  Future<void> checkPermissionStatus() async {
    debugPrint('ShizukuService: Checking permission status...');
    final alive = await checkBinderAlive();
    if (alive) {
      await checkSelfPermission();
    }
  }

  void dispose() {}
}