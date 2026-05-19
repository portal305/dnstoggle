package com.example.dnstoggle

import android.content.Context
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log

class DnsTileService : TileService() {
    companion object {
        private const val TAG = "DnsTileService"

        fun requestTileUpdate(context: Context) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                requestListeningState(context, android.content.ComponentName(context, DnsTileService::class.java))
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (!ShizukuHelper.checkSelfPermission()) {
            Log.e(TAG, "Shizuku permission not granted")
            return
        }

        Thread {
            val wasActive = DnsManager.isDnsActive()
            if (wasActive) {
                DnsManager.stopDns(this)
                ExcludedAppMonitorService.stopService(this)
                DnsNotificationService.stopService(this)
            } else {
                val excludedPrefs = getSharedPreferences("dnstoggle_excluded_apps", Context.MODE_PRIVATE)
                val excludedPackages = excludedPrefs.getStringSet("excluded_packages", emptySet()) ?: emptySet()

                DnsManager.startDns(this)

                if (excludedPackages.isNotEmpty()) {
                    ExcludedAppMonitorService.startService(this)
                } else {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val settingsJson = prefs.getString("flutter.app_settings", null)
                    var isPersistent = false
                    if (settingsJson != null) {
                        try {
                            val settings = org.json.JSONObject(settingsJson)
                            isPersistent = settings.optBoolean("persistentNotification", false)
                        } catch (e: Exception) {}
                    }
                    if (isPersistent) {
                        DnsNotificationService.startService(this)
                    }
                }
            }

            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            handler.post {
                updateTile()
            }
        }.start()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val isActive = DnsManager.isDnsActive()
        
        tile.state = if (isActive) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "DNS Toggle"
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            tile.subtitle = if (isActive) DnsManager.getActualServerName(this) else "Inactive"
        }
        tile.updateTile()
    }
}
