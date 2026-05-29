package com.example.dnstoggle

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URL
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class DnsVpnService : VpnService(), Runnable {
    private var vpnThread: Thread? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    private val executor = Executors.newFixedThreadPool(4)
    private var isRunning = false

    private var dohUrl: String = "https://cloudflare-dns.com/dns-query"
    private var corporateDnsIp: String = ""
    private var splitDomains: List<String> = emptyList()
    private var fallbackTriggered = false

    companion object {
        private const val TAG = "DnsVpnService"
        const val ACTION_START = "com.example.dnstoggle.START_VPN"
        const val ACTION_STOP = "com.example.dnstoggle.STOP_VPN"
        const val DNS_IP = "10.0.0.1"
        private const val NOTIFICATION_ID = 2002
        private const val CHANNEL_ID = "dns_vpn_service_channel"
        private const val WARNING_CHANNEL_ID = "dns_vpn_warning_channel"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            when (intent.action) {
                ACTION_START -> {
                    dohUrl = intent.getStringExtra("doh_url") ?: "https://cloudflare-dns.com/dns-query"
                    corporateDnsIp = intent.getStringExtra("corporate_dns") ?: ""
                    splitDomains = intent.getStringArrayListExtra("split_domains") ?: emptyList()
                    startVpn()
                }
                ACTION_STOP -> stopVpn()
            }
        }
        return START_STICKY
    }

    private fun startVpn() {
        if (vpnThread != null) return
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification("DNS Protection Active (VPN Mode)"))
        
        vpnThread = Thread(this, "DnsVpnThread").apply { start() }
        Log.i(TAG, "VPN service started with DoH: $dohUrl, Corporate DNS: $corporateDnsIp, Split Domains: ${splitDomains.size}")
    }

    private fun stopVpn() {
        isRunning = false
        vpnInterface?.close()
        vpnInterface = null
        vpnThread = null
        stopForeground(true)
        stopSelf()
        Log.i(TAG, "VPN service stopped")
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun run() {
        try {
            val builder = Builder()
                .setSession("DNS Toggle VPN")
                .addAddress(DNS_IP, 32)
                .addRoute(DNS_IP, 32)
                .addDnsServer(DNS_IP)
                .setConfigureIntent(
                    PendingIntent.getActivity(
                        this, 0, Intent(this, MainActivity::class.java),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface")
                return
            }

            val fd = vpnInterface!!.fileDescriptor
            val input = FileInputStream(fd)
            val output = FileOutputStream(fd)
            val packet = ByteBuffer.allocate(32767)

            while (isRunning) {
                packet.clear()
                val length = input.read(packet.array())
                if (length > 0) {
                    packet.limit(length)
                    handlePacket(packet, output)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in VPN thread", e)
        } finally {
            stopVpn()
        }
    }

    private fun handlePacket(packet: ByteBuffer, output: FileOutputStream) {
        val array = packet.array()
        if (array[0].toInt() and 0xF0 != 0x40) return

        val ipHeaderLength = (array[0].toInt() and 0x0F) * 4
        val protocol = array[9].toInt()
        if (protocol != 17) return

        val srcPort = ((array[ipHeaderLength].toInt() and 0xFF) shl 8) or (array[ipHeaderLength + 1].toInt() and 0xFF)
        val dstPort = ((array[ipHeaderLength + 2].toInt() and 0xFF) shl 8) or (array[ipHeaderLength + 3].toInt() and 0xFF)
        if (dstPort != 53) return

        val udpLength = ((array[ipHeaderLength + 4].toInt() and 0xFF) shl 8) or (array[ipHeaderLength + 5].toInt() and 0xFF)
        val dnsLength = udpLength - 8

        val dnsData = ByteArray(dnsLength)
        System.arraycopy(array, ipHeaderLength + 8, dnsData, 0, dnsLength)

        executor.submit {
            try {
                val domain = extractDomainName(dnsData)
                val dnsResponse: ByteArray?
                
                if (shouldBypass(domain) && corporateDnsIp.isNotEmpty()) {
                    Log.i(TAG, "Routing domain $domain via Corporate DNS: $corporateDnsIp")
                    dnsResponse = resolveUdpDns(dnsData, corporateDnsIp)
                } else {
                    dnsResponse = resolveDns(dnsData)
                }

                if (dnsResponse != null) {
                    sendDnsResponse(packet, dnsResponse, srcPort, dstPort, ipHeaderLength, output)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to handle packet", e)
            }
        }
    }

    private fun extractDomainName(dnsData: ByteArray): String {
        val sb = java.lang.StringBuilder()
        var pos = 12
        if (dnsData.size <= pos) return ""
        while (pos < dnsData.size) {
            val len = dnsData[pos].toInt() and 0xFF
            if (len == 0) break
            if (pos + 1 + len > dnsData.size) return ""
            if (sb.isNotEmpty()) sb.append(".")
            for (i in 0 until len) {
                sb.append((dnsData[pos + 1 + i].toInt() and 0xFF).toChar())
            }
            pos += 1 + len
        }
        return sb.toString()
    }

    private fun shouldBypass(domain: String): Boolean {
        if (domain.isEmpty()) return false
        for (suffix in splitDomains) {
            if (domain.endsWith(suffix) || domain == suffix) return true
        }
        return false
    }

    private fun resolveDns(dnsData: ByteArray): ByteArray? {
        val dohUrlStr = dohUrl
        val url = URL(dohUrlStr)
        var conn: HttpURLConnection? = null
        try {
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/dns-message")
            conn.setRequestProperty("Accept", "application/dns-message")
            
            conn.outputStream.use { os -> os.write(dnsData) }
            
            if (conn.responseCode == 200) {
                conn.inputStream.use { ins -> return ins.readBytes() }
            } else {
                Log.w(TAG, "DoH server returned status ${conn.responseCode}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "DoH request failed: ${e.message}. Triggering fallback.")
        } finally {
            conn?.disconnect()
        }
        return handleFallback(dnsData)
    }

    private fun handleFallback(dnsData: ByteArray): ByteArray? {
        if (!fallbackTriggered) {
            fallbackTriggered = true
            showWarningNotification("Primary DNS Unreachable", "Switched to public fallback DNS resolver.")
        }
        val fallbackDoh = "https://cloudflare-dns.com/dns-query"
        val url = URL(fallbackDoh)
        var conn: HttpURLConnection? = null
        try {
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 2000
            conn.readTimeout = 2000
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/dns-message")
            conn.setRequestProperty("Accept", "application/dns-message")
            conn.outputStream.use { os -> os.write(dnsData) }
            if (conn.responseCode == 200) {
                conn.inputStream.use { ins -> return ins.readBytes() }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Fallback DoH failed: ${e.message}")
        } finally {
            conn?.disconnect()
        }
        return null
    }

    private fun resolveUdpDns(dnsData: ByteArray, dnsServerIp: String): ByteArray? {
        val socket = DatagramSocket()
        try {
            socket.soTimeout = 3000
            val address = InetAddress.getByName(dnsServerIp)
            val packet = DatagramPacket(dnsData, dnsData.size, address, 53)
            socket.send(packet)
            val receiveBuf = ByteArray(4096)
            val receivePacket = DatagramPacket(receiveBuf, receiveBuf.size)
            socket.receive(receivePacket)
            val response = ByteArray(receivePacket.length)
            System.arraycopy(receiveBuf, 0, response, 0, receivePacket.length)
            return response
        } catch (e: Exception) {
            Log.e(TAG, "UDP DNS resolution failed: ${e.message}")
        } finally {
            socket.close()
        }
        return null
    }

    private fun sendDnsResponse(
        requestPacket: ByteBuffer,
        dnsResponse: ByteArray,
        srcPort: Int,
        dstPort: Int,
        ipHeaderLength: Int,
        output: FileOutputStream
    ) {
        val responseBuffer = ByteBuffer.allocate(20 + 8 + dnsResponse.size)
        responseBuffer.put(0, 0x45.toByte())
        responseBuffer.put(1, 0.toByte())
        val totalLength = 20 + 8 + dnsResponse.size
        responseBuffer.putShort(2, totalLength.toShort())
        responseBuffer.putShort(4, 0.toByte().toShort())
        responseBuffer.putShort(6, 0x4000.toByte().toShort())
        responseBuffer.put(8, 64.toByte())
        responseBuffer.put(9, 17.toByte())
        
        val srcIp = ByteArray(4)
        val dstIp = ByteArray(4)
        val requestArray = requestPacket.array()
        System.arraycopy(requestArray, 12, dstIp, 0, 4)
        System.arraycopy(requestArray, 16, srcIp, 0, 4)
        
        for (i in 0..3) {
            responseBuffer.put(12 + i, srcIp[i])
            responseBuffer.put(16 + i, dstIp[i])
        }
        
        responseBuffer.putShort(10, 0.toShort())
        responseBuffer.putShort(20, dstPort.toShort())
        responseBuffer.putShort(22, srcPort.toShort())
        val udpLength = 8 + dnsResponse.size
        responseBuffer.putShort(24, udpLength.toShort())
        responseBuffer.putShort(26, 0.toShort())
        responseBuffer.position(28)
        responseBuffer.put(dnsResponse)
        
        val ipChecksum = computeChecksum(responseBuffer.array(), 0, 20)
        responseBuffer.putShort(10, ipChecksum)
        
        synchronized(output) {
            output.write(responseBuffer.array())
        }
    }

    private fun computeChecksum(buf: ByteArray, offset: Int, length: Int): Short {
        var sum = 0
        var i = offset
        while (i < offset + length) {
            val word = ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        while (sum shr 16 != 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return (sum.inv() and 0xFFFF).toShort()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "DNS VPN Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val warningChannel = NotificationChannel(
                WARNING_CHANNEL_ID,
                "DNS VPN Warnings",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
            manager.createNotificationChannel(warningChannel)
        }
    }

    private fun createNotification(text: String): android.app.Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DNS Toggle VPN")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_shield)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun showWarningNotification(title: String, text: String) {
        val notification = NotificationCompat.Builder(this, WARNING_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_shield)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(2003, notification)
    }
}
