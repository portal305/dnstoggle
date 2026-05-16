package com.example.dnstoggle

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

class DnsActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val action = intent.action
        Log.i("DnsActionReceiver", "Received action: $action")
        
        Thread {
            try {
                when (action) {
                    "com.example.dnstoggle.ACTION_TOGGLE" -> {
                        DnsManager.toggleDns(context)
                    }
                    "com.example.dnstoggle.ACTION_SELECT_SERVER" -> {
                        val serverId = intent.getStringExtra("server_id")
                        if (serverId != null) {
                            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            prefs.edit().putString("flutter.selected_server_id", serverId).apply()
                            DnsManager.startDns(context)
                        }
                    }
                }
                
                // Refresh all UI components
                DnsNotificationService.startService(context)
                DnsWidgetProvider.updateAllWidgets(context)
                DnsTileService.requestTileUpdate(context)
                
            } catch (e: Exception) {
                Log.e("DnsActionReceiver", "Error processing action", e)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}
