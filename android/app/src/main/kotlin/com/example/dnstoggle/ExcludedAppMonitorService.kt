package com.example.dnstoggle

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class ExcludedAppMonitorService : Service() {
    private val monitorHandler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private var currentForegroundApp: String? = null
    private var wasDnsActive = false
    private var savedDnsHostname: String? = null
    private var excludedPackages: Set<String> = emptySet()

    companion object {
        private const val TAG = "ExcludedAppMonitor"
        private const val CHANNEL_ID = "dns_toggle_monitor"
        private const val NOTIFICATION_ID = 1003
        private const val PREFS_NAME = "dnstoggle_excluded_apps"
        private const val KEY_EXCLUDED_PACKAGES = "excluded_packages"
        private const val KEY_WAS_DNS_ACTIVE = "was_dns_active"
        private const val KEY_SAVED_HOSTNAME = "saved_hostname"
        private const val MONITOR_INTERVAL = 1000L

        fun startService(context: Context) {
            Log.d(TAG, "startService called")
            val intent = Intent(context, ExcludedAppMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            Log.d(TAG, "stopService called")
            val intent = Intent(context, ExcludedAppMonitorService::class.java)
            context.stopService(intent)
        }

        fun syncExcludedApps(context: Context, packages: List<String>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putStringSet(KEY_EXCLUDED_PACKAGES, packages.toSet()).apply()
            Log.d(TAG, "Synced ${packages.size} excluded apps: $packages")
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        createNotificationChannel()
        loadState()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        
        if (!DnsManager.isDnsActive()) {
            Log.d(TAG, "DNS not active, stopping monitor")
            stopSelf()
            return START_NOT_STICKY
        }
        
        Log.d(TAG, "Foregrounding with notification")
        startForeground(NOTIFICATION_ID, createNotification())
        startMonitoring()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        stopMonitoring()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Bypass Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors active apps to temporarily bypass DNS for excluded apps"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val count = excludedPackages.size
        val countText = if (count == 1) "1 app is configured to bypass DNS" else "$count apps are configured to bypass DNS"
        
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            setPackage(packageName)
        }
        val mainPendingIntent = PendingIntent.getActivity(
            this, 1, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Bypass Monitor")
            .setContentText(countText)
            .setSmallIcon(R.drawable.ic_shield)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(mainPendingIntent)
            .build()
    }

    private fun updateNotification() {
        try {
            val notification = createNotification()
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating notification: $e")
        }
    }

    private fun loadState() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            excludedPackages = prefs.getStringSet(KEY_EXCLUDED_PACKAGES, emptySet()) ?: emptySet()
            wasDnsActive = prefs.getBoolean(KEY_WAS_DNS_ACTIVE, false)
            savedDnsHostname = prefs.getString(KEY_SAVED_HOSTNAME, null)
            Log.d(TAG, "Loaded state: excluded=${excludedPackages.size}, wasDns=$wasDnsActive, hostname=$savedDnsHostname")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading state: $e")
        }
    }

    private fun saveDnsState() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_WAS_DNS_ACTIVE, wasDnsActive)
                .putString(KEY_SAVED_HOSTNAME, savedDnsHostname)
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving state: $e")
        }
    }

    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isMonitoring) {
                checkForegroundApp()
                monitorHandler.postDelayed(this, MONITOR_INTERVAL)
            }
        }
    }

    private fun startMonitoring() {
        isMonitoring = true
        checkForegroundApp()
        monitorHandler.post(monitorRunnable)
        Log.d(TAG, "Started monitoring")
    }

    private fun stopMonitoring() {
        isMonitoring = false
        monitorHandler.removeCallbacks(monitorRunnable)
        Log.d(TAG, "Stopped monitoring")
    }

    private fun checkForegroundApp() {
        try {
            val endTime = System.currentTimeMillis()
            val startTime = endTime - 10000

            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? android.app.usage.UsageStatsManager
            val events = usageStatsManager?.queryEvents(startTime, endTime)
            if (events == null) return

            var latestEventTime = 0L
            var latestPackage: String? = null

            while (events.hasNextEvent()) {
                val event = android.app.usage.UsageEvents.Event()
                events.getNextEvent(event)

                val eventType = event.eventType
                if (eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED) {
                    if (event.timeStamp > latestEventTime) {
                        latestEventTime = event.timeStamp
                        latestPackage = event.packageName
                    }
                }
            }

            if (latestPackage != null && latestPackage != currentForegroundApp && latestPackage != "com.example.dnstoggle") {
                Log.d(TAG, "Foreground app: $latestPackage")
                currentForegroundApp = latestPackage
                handleAppSwitch(latestPackage)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking foreground app: $e")
        }
    }

    private fun handleAppSwitch(packageName: String) {
        try {
            loadState()
            Log.d(TAG, "Handling switch to: $packageName")
            Log.d(TAG, "Excluded: $excludedPackages")

            val dnsActive = try { DnsManager.isDnsActive() } catch (e: Exception) { false }
            Log.d(TAG, "DNS active: $dnsActive")

            if (excludedPackages.contains(packageName)) {
                if (dnsActive) {
                    Log.d(TAG, "Excluded app! Stopping DNS...")
                    wasDnsActive = true
                    savedDnsHostname = try { DnsManager.getActualDnsHostname() } catch (e: Exception) { null }
                    DnsManager.stopDns()
                    saveDnsState()
                    DnsTileService.requestTileUpdate(this)
                    DnsWidgetProvider.updateAllWidgets(this)
                    MainActivity.notifyFlutterState(false)
                    updateNotification()
                }
            } else {
                if (wasDnsActive) {
                    val stillActive = try { DnsManager.isDnsActive() } catch (e: Exception) { false }
                    if (!stillActive) {
                        Log.d(TAG, "Returning to non-excluded, restarting DNS...")
                        val hostname = savedDnsHostname
                        if (hostname != null) {
                            DnsManager.startDns(hostname)
                            DnsTileService.requestTileUpdate(this)
                            DnsWidgetProvider.updateAllWidgets(this)
                            MainActivity.notifyFlutterState(true)
                            wasDnsActive = false
                            savedDnsHostname = null
                            saveDnsState()
                            Log.d(TAG, "DNS restarted")
                            updateNotification()
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleAppSwitch: $e")
        }
    }
}
