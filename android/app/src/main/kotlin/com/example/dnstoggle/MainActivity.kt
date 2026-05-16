package com.example.dnstoggle

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dnstoggle/shizuku"
    private val SHIZUKU_CHANNEL = "dnstoggle/shizuku_native"

    private val mainHandler = Handler(Looper.getMainLooper())
    
    companion object {
        private var methodChannel: MethodChannel? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        
        fun notifyFlutterState(isRunning: Boolean) {
            Log.i("MainActivity", "notifyFlutterState called with: $isRunning")
            mainHandler.post {
                if (methodChannel == null) {
                    Log.w("MainActivity", "Cannot notify Flutter: methodChannel is null")
                } else {
                    Log.i("MainActivity", "Invoking onStateChanged on Flutter")
                    methodChannel?.invokeMethod("onStateChanged", isRunning)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHIZUKU_CHANNEL)
        methodChannel = channel
        
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pingBinder" -> result.success(ShizukuHelper.pingBinder())
                "checkPermission" -> result.success(ShizukuHelper.checkSelfPermission())
                "checkDnsSupport" -> result.success(android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P)
                "runCommand" -> {
                    val command = call.argument<String>("command") ?: ""
                    result.success(ShizukuHelper.runCommand(command))
                }
                "grantWriteSecureSettings" -> result.success(ShizukuHelper.grantWriteSecureSettings(this))
                "requestPermission" -> {
                    ShizukuHelper.requestPermission(1001)
                    result.success(true)
                }
                "startNotificationService" -> {
                    DnsNotificationService.startService(this)
                    result.success(true)
                }
                "stopNotificationService" -> {
                    DnsNotificationService.stopService(this)
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1002)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "notifyStateChanged" -> {
                    DnsTileService.requestTileUpdate(this)
                    DnsWidgetProvider.updateAllWidgets(this)
                    // Also refresh notification if active
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val settingsJson = prefs.getString("flutter.app_settings", null)
                    if (settingsJson != null) {
                        try {
                            val settings = JSONObject(settingsJson)
                            if (settings.optBoolean("persistentNotification", false)) {
                                DnsNotificationService.startService(this)
                            }
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBinderAlive" -> result.success(ShizukuHelper.pingBinder())
                "checkPermission" -> result.success(ShizukuHelper.checkSelfPermission())
                "requestPermission" -> result.success(true)
                "getPackageName" -> result.success(packageName)
                "getPendingAction" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}