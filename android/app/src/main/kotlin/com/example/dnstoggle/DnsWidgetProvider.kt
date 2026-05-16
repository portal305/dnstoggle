package com.example.dnstoggle

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class DnsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Thread {
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }.start()
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        Thread {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }.start()
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, DnsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val updateIntent = Intent(context, DnsWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            context.sendBroadcast(updateIntent)
        }
    }
}

internal fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: IntArray) {
    // This is handled by onUpdate above for each ID
}

internal fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    val isActive = DnsManager.isDnsActive()
    val serverInfo = DnsManager.getSelectedServerInfo(context)
    
    // We need to determine if it's 2x2 or 4x2. 
    // For simplicity, we can try to find views from both and see which one stick, 
    // but better is to check options.
    val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
    val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
    Log.i("DnsWidget", "Widget $appWidgetId: minWidth=$minWidth, maxWidth=$maxWidth")
    
    val isLarge = minWidth >= 180 // Lower threshold for better compatibility

    val views = if (isLarge) {
        RemoteViews(context.packageName, R.layout.widget_4x2).apply {
            setTextViewText(R.id.widget_status_4x2, if (isActive) "ACTIVE" else "INACTIVE")
            setTextViewText(R.id.widget_server_name_4x2, serverInfo.name)
            setTextViewText(R.id.widget_server_hostname_4x2, serverInfo.hostname)
            setImageViewResource(R.id.widget_icon_4x2, R.drawable.ic_shield)
            setInt(R.id.widget_icon_4x2, "setColorFilter", if (isActive) context.getColor(R.color.active) else context.getColor(R.color.primary))
            
            // Setup list view
            val serviceIntent = Intent(context, DnsRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            setRemoteAdapter(R.id.widget_server_list, serviceIntent)
            
            // Template for list clicks
            val clickIntent = Intent(context, DnsActionReceiver::class.java).apply {
                action = "com.example.dnstoggle.ACTION_SELECT_SERVER"
            }
            val clickPendingIntent = PendingIntent.getBroadcast(
                context, 0, clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            setPendingIntentTemplate(R.id.widget_server_list, clickPendingIntent)
            
            // Left section click (toggle)
            val toggleIntent = Intent(context, DnsActionReceiver::class.java).apply {
                action = "com.example.dnstoggle.ACTION_TOGGLE"
            }
            val togglePendingIntent = PendingIntent.getBroadcast(
                context, 1, toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            setOnClickPendingIntent(R.id.widget_left_section, togglePendingIntent)
        }
    } else {
        RemoteViews(context.packageName, R.layout.widget_2x2).apply {
            setTextViewText(R.id.widget_status, if (isActive) "ACTIVE" else "INACTIVE")
            setTextViewText(R.id.widget_server_name, serverInfo.name)
            setTextViewText(R.id.widget_server_hostname, serverInfo.hostname)
            setImageViewResource(R.id.widget_icon, R.drawable.ic_shield)
            setInt(R.id.widget_icon, "setColorFilter", if (isActive) context.getColor(R.color.active) else context.getColor(R.color.primary))
            
            val toggleIntent = Intent(context, DnsActionReceiver::class.java).apply {
                action = "com.example.dnstoggle.ACTION_TOGGLE"
            }
            val togglePendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId, toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            setOnClickPendingIntent(R.id.widget_container, togglePendingIntent)
        }
    }

    appWidgetManager.updateAppWidget(appWidgetId, views)
    if (isLarge) {
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_server_list)
    }
}
