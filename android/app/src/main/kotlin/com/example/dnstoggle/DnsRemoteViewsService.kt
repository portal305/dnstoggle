package com.example.dnstoggle

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class DnsRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return DnsRemoteViewsFactory(this.applicationContext)
    }
}

class DnsRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var servers = mutableListOf<ServerInfo>()

    data class ServerInfo(val id: String, val name: String, val hostname: String)

    override fun onCreate() {}

    override fun onDataSetChanged() {
        servers.clear()
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val allServersJson = prefs.getString("flutter.all_servers", null)
        
        if (allServersJson != null) {
            try {
                val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
                val cleanJson = if (allServersJson.startsWith(prefix)) {
                    allServersJson.substring(prefix.length)
                } else {
                    allServersJson
                }

                val serversArray = JSONArray(cleanJson)
                // Limit to 5 servers for the widget list
                val count = if (serversArray.length() > 5) 5 else serversArray.length()
                for (i in 0 until count) {
                    val serverJson = JSONObject(serversArray.getString(i))
                    servers.add(ServerInfo(
                        serverJson.getString("id"),
                        serverJson.getString("name"),
                        serverJson.getString("primaryDns")
                    ))
                }
            } catch (e: Exception) {
                Log.e("DnsWidget", "Error loading servers for widget", e)
            }
        }
    }

    override fun onDestroy() {
        servers.clear()
    }

    override fun getCount(): Int = servers.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= servers.size) return RemoteViews(context.packageName, R.layout.widget_list_item)

        val server = servers[position]
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)
        views.setTextViewText(R.id.widget_item_name, server.name)

        // Fill in the click intent
        val fillInIntent = Intent().apply {
            putExtra("server_id", server.id)
            putExtra("server_name", server.name)
        }
        views.setOnClickFillInIntent(R.id.widget_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
