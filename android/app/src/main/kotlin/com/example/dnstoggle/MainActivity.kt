package com.example.dnstoggle

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream

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

    private fun getInstalledAppsList(): List<Map<String, Any?>> {
        Log.i("MainActivity", "getInstalledAppsList called")
        val apps = mutableListOf<Map<String, Any?>>()
        val pm = packageManager
        val packages = pm.getInstalledPackages(PackageManager.GET_META_DATA)
        Log.i("MainActivity", "Found ${packages.size} packages")
        
        for (pkg in packages) {
            val appName = pkg.applicationInfo?.loadLabel(pm)?.toString() ?: pkg.packageName
            var iconBase64: String? = null
            
            try {
                val drawable = pkg.applicationInfo?.loadIcon(pm)
                if (drawable != null) {
                    val bitmap = drawableToBitmap(drawable)
                    val scaledBitmap = Bitmap.createScaledBitmap(bitmap, 48, 48, true)
                    val byteArrayOutputStream = ByteArrayOutputStream()
                    scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 60, byteArrayOutputStream)
                    val byteArray = byteArrayOutputStream.toByteArray()
                    iconBase64 = Base64.encodeToString(byteArray, Base64.NO_WRAP)
                    scaledBitmap.recycle()
                    bitmap.recycle()
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "Failed to load icon for ${pkg.packageName}: $e")
            }
            
            apps.add(mapOf(
                "packageName" to pkg.packageName,
                "appName" to appName,
                "iconBase64" to iconBase64
            ))
        }
        
        Log.i("MainActivity", "Returning ${apps.size} apps")
        return apps.sortedBy { it["appName"] as String }
    }

    private fun drawableToBitmap(drawable: android.graphics.drawable.Drawable): Bitmap {
        if (drawable is android.graphics.drawable.BitmapDrawable) {
            return drawable.bitmap
        }
        
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
        
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        
        return bitmap
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = appOps.checkOpNoThrow(
            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
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
                            if (settings.optBoolean("persistentNotification", false) && DnsManager.isDnsActive()) {
                                DnsNotificationService.startService(this)
                            } else {
                                DnsNotificationService.stopService(this)
                            }
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "getInstalledApps" -> {
                    Log.i("MainActivity", "getInstalledApps method called")
                    Thread {
                        val apps = getInstalledAppsList()
                        Log.i("MainActivity", "Returning ${apps.size} apps to Flutter")
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }
                "hasUsageAccessPermission" -> {
                    val hasAccess = hasUsageAccess()
                    result.success(hasAccess)
                }
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }
                "startExcludedAppMonitor" -> {
                    ExcludedAppMonitorService.startService(this)
                    result.success(true)
                }
                "stopExcludedAppMonitor" -> {
                    ExcludedAppMonitorService.stopService(this)
                    result.success(true)
                }
                "syncExcludedApps" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    ExcludedAppMonitorService.syncExcludedApps(this, packages)
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