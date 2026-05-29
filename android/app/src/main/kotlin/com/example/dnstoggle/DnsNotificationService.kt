package com.example.dnstoggle

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DnsNotificationService : Service() {
    companion object {
        private const val CHANNEL_ID = "dns_toggle_persistent"
        private const val NOTIFICATION_ID = 1002
        const val ACTION_TOGGLE = "com.example.dnstoggle.ACTION_TOGGLE"
        const val ACTION_STOP_SERVICE = "com.example.dnstoggle.ACTION_STOP_SERVICE"

        fun startService(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val settingsJson = prefs.getString("flutter.app_settings", null)
            var isPersistent = false
            if (settingsJson != null) {
                try {
                    val settings = org.json.JSONObject(settingsJson)
                    isPersistent = settings.optBoolean("persistentNotification", false)
                } catch (e: Exception) {
                    android.util.Log.e("DnsNotificationService", "Failed to parse app_settings for guard", e)
                }
            }
            if (!isPersistent || !DnsManager.isDnsActive()) {
                android.util.Log.i("DnsNotificationService", "Persistent notification is disabled or DNS is inactive, stopping service")
                stopService(context)
                return
            }

            val intent = Intent(context, DnsNotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, DnsNotificationService::class.java)
            context.stopService(intent)
        }
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!DnsManager.isDnsActive()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }
        createNotificationChannel()
        showNotification()
        return START_STICKY
    }

    private fun showNotification() {
        val hostname = DnsManager.getActualDnsHostname() ?: DnsManager.getSelectedServerHostname(this)
        val displayHostname = hostname ?: "DNS"
        
        val toggleIntent = Intent(this, DnsActionReceiver::class.java).apply {
            action = ACTION_TOGGLE
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            this, 0, toggleIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val mainIntent = Intent(this, MainActivity::class.java)
        val mainPendingIntent = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DNS Toggle")
            .setContentText("Status: Active ($displayHostname)")
            .setSmallIcon(R.drawable.ic_shield)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(mainPendingIntent)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Turn OFF",
                togglePendingIntent
            )
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Persistent DNS Toggle",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows a persistent notification to toggle DNS"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
