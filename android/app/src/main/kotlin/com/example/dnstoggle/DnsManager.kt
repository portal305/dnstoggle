package com.example.dnstoggle

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

object DnsManager {
    private const val TAG = "DnsManager"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_SELECTED_SERVER_ID = "flutter.selected_server_id"
    private const val KEY_ALL_SERVERS = "flutter.all_servers"
    private const val KEY_IS_RUNNING = "flutter.is_running"

    private const val MODE_KEY = "private_dns_mode"
    private const val SPECIFIER_KEY = "private_dns_specifier"
    private const val MODE_HOSTNAME = "hostname"
    private const val MODE_OFF = "off"

    fun getActualDnsHostname(): String? {
        return ShizukuHelper.runCommand("settings get global $SPECIFIER_KEY")?.trim()
    }

    data class ServerInfo(val name: String, val hostname: String)

    fun getSelectedServerInfo(context: Context): ServerInfo {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val selectedId = prefs.getString(KEY_SELECTED_SERVER_ID, "adguard") ?: "adguard"
        val allServersJson = prefs.getString(KEY_ALL_SERVERS, null)
        
        var name = "AdGuard DNS"
        var hostname = "dns.adguard-dns.com"

        if (allServersJson != null) {
            try {
                val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
                val cleanJson = if (allServersJson.startsWith(prefix)) {
                    allServersJson.substring(prefix.length)
                } else {
                    allServersJson
                }

                val serversArray = JSONArray(cleanJson)
                for (i in 0 until serversArray.length()) {
                    val serverJson = JSONObject(serversArray.getString(i))
                    if (serverJson.getString("id") == selectedId) {
                        name = serverJson.getString("name")
                        hostname = serverJson.getString("primaryDns")
                        break
                    }
                }
            } catch (e: Exception) {}
        }
        
        return ServerInfo(name, hostname)
    }

    fun getSelectedServerHostname(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val selectedId = prefs.getString(KEY_SELECTED_SERVER_ID, "adguard") ?: "adguard"
        val allServersJson = prefs.getString(KEY_ALL_SERVERS, null)
        
        Log.i(TAG, "Looking for hostname for server ID: $selectedId")

        if (allServersJson != null) {
            try {
                // Flutter's shared_preferences may prefix list strings with this base64 encoded string
                val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
                val cleanJson = if (allServersJson.startsWith(prefix)) {
                    allServersJson.substring(prefix.length)
                } else {
                    allServersJson
                }

                Log.i(TAG, "Parsing clean servers JSON: $cleanJson")
                // Try reading as a JSON array string first
                val serversArray = try {
                    JSONArray(cleanJson)
                } catch (e: Exception) {
                    null
                }

                if (serversArray != null) {
                    for (i in 0 until serversArray.length()) {
                        val serverJsonStr = serversArray.getString(i)
                        val serverJson = JSONObject(serverJsonStr)
                        if (serverJson.getString("id") == selectedId) {
                            val hostname = serverJson.getString("primaryDns")
                            Log.i(TAG, "Found hostname in JSON array: $hostname")
                            return hostname
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing servers from JSON string", e)
            }
        }

        // Try reading as a StringSet (classic shared_preferences StringList) fallback
        try {
            val allEntries = prefs.all
            val serversSet = allEntries[KEY_ALL_SERVERS] as? Set<String>
            if (serversSet != null) {
                Log.i(TAG, "Found servers as StringSet: $serversSet")
                for (serverJsonStr in serversSet) {
                    val serverJson = JSONObject(serverJsonStr)
                    if (serverJson.getString("id") == selectedId) {
                        val hostname = serverJson.getString("primaryDns")
                        Log.i(TAG, "Found hostname in StringSet: $hostname")
                        return hostname
                    }
                }
            }
        } catch (e: Exception) {
            // Not a StringSet or other error, ignore
        }
        
        Log.i(TAG, "Server not found in list, defaulting to AdGuard")
        return "dns.adguard-dns.com"
    }

    fun getActualServerName(context: Context): String {
        if (!isDnsActive()) return "Inactive"
        
        val actualHostname = getActualDnsHostname() ?: return "Active"
        
        // Try to find the name in our list
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val allServersJson = prefs.getString(KEY_ALL_SERVERS, null)
        
        if (allServersJson != null) {
            try {
                val prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"
                val cleanJson = if (allServersJson.startsWith(prefix)) {
                    allServersJson.substring(prefix.length)
                } else {
                    allServersJson
                }

                val serversArray = JSONArray(cleanJson)
                for (i in 0 until serversArray.length()) {
                    val serverJson = JSONObject(serversArray.getString(i))
                    if (serverJson.getString("primaryDns") == actualHostname) {
                        return serverJson.getString("name")
                    }
                }
            } catch (e: Exception) {}
        }
        
        return actualHostname
    }

    fun isDnsActive(): Boolean {
        val mode = ShizukuHelper.runCommand("settings get global $MODE_KEY")?.trim() ?: ""
        val spec = ShizukuHelper.runCommand("settings get global $SPECIFIER_KEY")?.trim() ?: ""
        return mode == MODE_HOSTNAME && spec.isNotEmpty()
    }

    fun toggleDns(context: Context): Boolean {
        if (isDnsActive()) {
            return stopDns(context)
        } else {
            return startDns(context)
        }
    }

    fun startDns(context: Context): Boolean {
        val hostname = getSelectedServerHostname(context) ?: return false
        Log.i(TAG, "Starting DNS with hostname: $hostname")
        ShizukuHelper.runCommand("settings put global $SPECIFIER_KEY $hostname")
        Thread.sleep(200)
        ShizukuHelper.runCommand("settings put global $MODE_KEY $MODE_HOSTNAME")
        
        Thread.sleep(200)
        val active = isDnsActive()
        Log.i(TAG, "DNS start result: $active")
        updateFlutterState(context, active)
        return active
    }

    fun stopDns(context: Context): Boolean {
        Log.i(TAG, "Stopping DNS")
        ShizukuHelper.runCommand("settings put global $MODE_KEY $MODE_OFF")
        
        Thread.sleep(200)
        val active = isDnsActive()
        Log.i(TAG, "DNS stop result: ${!active}")
        updateFlutterState(context, active)
        return !active
    }

    private fun updateFlutterState(context: Context, isRunning: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_IS_RUNNING, isRunning).apply()
        
        DnsTileService.requestTileUpdate(context)
        DnsWidgetProvider.updateAllWidgets(context)
        MainActivity.notifyFlutterState(isRunning)
        
        // If notification service is running, it will be updated by startService
        // We only want to trigger it if it's already active (user opted in)
        // For simplicity, we can just call it and it will handle channel/show logic
        // But we should check if the setting is enabled.
        val settingsJson = prefs.getString("flutter.app_settings", null)
        if (settingsJson != null) {
            try {
                val settings = JSONObject(settingsJson)
                if (settings.optBoolean("persistentNotification", false)) {
                    DnsNotificationService.startService(context)
                }
            } catch (e: Exception) {}
        }
    }
}
