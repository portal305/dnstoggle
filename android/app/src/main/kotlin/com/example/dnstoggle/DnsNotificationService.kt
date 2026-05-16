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
            val intent = Intent(context, DnsNotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, DnsNotificationService::class.java).apply {
                action = ACTION_STOP_SERVICE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // To ensure it processes the action even if it's already running
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
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
        if (intent?.action == ACTION_STOP_SERVICE) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        showNotification()
        return START_STICKY
    }

    private fun showNotification() {
        val isActive = DnsManager.isDnsActive()
        val hostname = if (isActive) DnsManager.getActualDnsHostname() else DnsManager.getSelectedServerHostname(this)
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
            .setContentText("Status: ${if (isActive) "Active ($displayHostname)" else "Inactive"}")
            .setSmallIcon(R.drawable.ic_shield)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(mainPendingIntent)
            .addAction(
                if (isActive) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isActive) "Turn OFF" else "Turn ON",
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
