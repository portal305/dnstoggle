package com.example.dnstoggle

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            
            Log.i("BootReceiver", "Device booted, checking for auto-start...")
            
            val pendingResult = goAsync()
            
            Thread {
                try {
                    // Give Shizuku some time to start if it hasn't already
                    Thread.sleep(5000)
                    
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val settingsJson = prefs.getString("flutter.app_settings", null)
                    
                    if (settingsJson != null) {
                        val settings = JSONObject(settingsJson)
                        val autoStart = settings.optBoolean("autoStartOnBoot", false)
                        val isRunning = prefs.getBoolean("flutter.is_running", false)
                        
                        Log.i("BootReceiver", "Auto-start setting: $autoStart, Last running state: $isRunning")
                        
                        if (autoStart && isRunning) {
                            Log.i("BootReceiver", "Triggering DNS start...")
                            DnsManager.startDns(context)
                            
                            // Also start notification if enabled
                            if (settings.optBoolean("persistentNotification", false)) {
                                DnsNotificationService.startService(context)
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("BootReceiver", "Error in boot receiver", e)
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }
}
