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
            DnsManager.toggleDns(this)
            // After toggle, update tile on main thread
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
