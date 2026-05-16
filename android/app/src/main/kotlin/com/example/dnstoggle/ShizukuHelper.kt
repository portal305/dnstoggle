package com.example.dnstoggle

import android.content.Context
import android.util.Log
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

object ShizukuHelper {
    private const val TAG = "ShizukuHelper"
    
    fun pingBinder(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (e: Exception) {
            Log.e(TAG, "pingBinder failed", e)
            false
        }
    }
    
    fun checkSelfPermission(): Boolean {
        return try {
            Shizuku.checkSelfPermission() == android.content.pm.PackageManager.PERMISSION_GRANTED
        } catch (e: Exception) {
            Log.e(TAG, "checkSelfPermission failed", e)
            false
        }
    }
    
    fun requestPermission(requestCode: Int) {
        try {
            Shizuku.requestPermission(requestCode)
        } catch (e: Exception) {
            Log.e(TAG, "requestPermission failed", e)
        }
    }
    
    fun runCommand(command: String): String? {
        if (!pingBinder()) {
            Log.e(TAG, "Binder not alive, cannot run command: $command")
            return null
        }
        
        return try {
            val clazz = Class.forName("rikka.shizuku.Shizuku")
            val method = clazz.getDeclaredMethod("newProcess", Array<String>::class.java, Array<String>::class.java, String::class.java)
            method.isAccessible = true
            
            val process = method.invoke(null, arrayOf("sh", "-c", command), null, null) as rikka.shizuku.ShizukuRemoteProcess
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.append(line).append("\n")
            }
            
            process.waitFor()
            val result = output.toString().trim()
            process.destroy()
            
            result.ifEmpty { null }
        } catch (e: Exception) {
            Log.e(TAG, "runCommand failed: $command", e)
            null
        }
    }
    
    fun grantWriteSecureSettings(context: Context): Boolean {
        return try {
            val packageName = context.packageName
            val command = "pm grant $packageName android.permission.WRITE_SECURE_SETTINGS"
            runCommand(command)
            true
        } catch (e: Exception) {
            Log.e(TAG, "grantWriteSecureSettings failed", e)
            false
        }
    }
}