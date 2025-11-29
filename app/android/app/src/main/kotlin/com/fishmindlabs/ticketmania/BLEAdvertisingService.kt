package com.fishmindlabs.ticketmania

import android.annotation.SuppressLint
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import androidx.annotation.RequiresApi
import java.util.UUID

/**
 * Highly optimized BLE advertising service for battery efficiency
 * Uses low power advertising intervals and proper advertising parameters
 */
@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class BLEAdvertisingService : Service() {
    
    companion object {
        private const val TAG = "BLEAdvertisingService"
        
        // Custom Service UUID for Ticket Mania
        // Format: 0000FEED-0000-1000-8000-00805F9B34FB
        private val SERVICE_UUID = UUID.fromString("0000FEED-0000-1000-8000-00805F9B34FB")
        
        // Low power advertising interval (milliseconds)
        // ADVERTISE_MODE_LOW_POWER = 1000ms (1 second)
        // This is the most battery-efficient mode
        private const val ADVERTISE_MODE = AdvertiseSettings.ADVERTISE_MODE_LOW_POWER
        
        // Low power TX power level
        private const val TX_POWER_LEVEL = AdvertiseSettings.ADVERTISE_TX_POWER_LOW
        
        // Connectable advertising (allows bus systems to connect)
        private const val CONNECTABLE = true
        
        // Advertising timeout (0 = no timeout, advertise indefinitely)
        private const val TIMEOUT = 0
    }
    
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false
    private var currentTicketIds: List<String> = emptyList()
    
    private val binder = LocalBinder()
    
    inner class LocalBinder : Binder() {
        fun getService(): BLEAdvertisingService = this@BLEAdvertisingService
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    override fun onCreate() {
        super.onCreate()
        initializeBluetooth()
    }
    
    @SuppressLint("MissingPermission")
    private fun initializeBluetooth() {
        try {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            bluetoothAdapter = bluetoothManager.adapter
            
            if (bluetoothAdapter?.isEnabled == true) {
                bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
                Log.d(TAG, "Bluetooth LE Advertiser initialized")
            } else {
                Log.e(TAG, "Bluetooth adapter is not enabled")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Bluetooth", e)
        }
    }
    
    /**
     * Start advertising with ticket IDs
     * Optimized for battery consumption with low power settings
     */
    @SuppressLint("MissingPermission")
    fun startAdvertising(ticketIds: List<String>): Boolean {
        if (isAdvertising) {
            Log.d(TAG, "Already advertising, updating ticket IDs")
            stopAdvertising()
        }
        
        if (bluetoothLeAdvertiser == null) {
            Log.e(TAG, "Bluetooth LE Advertiser is null")
            return false
        }
        
        if (ticketIds.isEmpty()) {
            Log.d(TAG, "No ticket IDs to advertise")
            return false
        }
        
        currentTicketIds = ticketIds
        
        try {
            // Create advertising settings optimized for battery
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(ADVERTISE_MODE) // Low power mode (1000ms interval)
                .setTxPowerLevel(TX_POWER_LEVEL) // Low TX power for battery efficiency
                .setConnectable(CONNECTABLE) // Allow connections from bus systems
                .setTimeout(TIMEOUT) // No timeout, advertise indefinitely
                .build()
            
            // Create advertising data with service UUID and ticket IDs
            val advertiseData = AdvertiseData.Builder()
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .addServiceData(
                    ParcelUuid(SERVICE_UUID),
                    encodeTicketIds(ticketIds)
                )
                .setIncludeDeviceName(false) // Don't include device name to save power
                .setIncludeTxPowerLevel(false) // Don't include TX power to save power
                .build()
            
            // Start advertising
            bluetoothLeAdvertiser?.startAdvertising(settings, advertiseData, advertiseCallback)
            isAdvertising = true
            Log.d(TAG, "Started BLE advertising with ${ticketIds.size} ticket(s)")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start advertising", e)
            isAdvertising = false
            return false
        }
    }
    
    /**
     * Stop advertising
     */
    @SuppressLint("MissingPermission")
    fun stopAdvertising() {
        if (!isAdvertising) {
            return
        }
        
        try {
            bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            isAdvertising = false
            currentTicketIds = emptyList()
            Log.d(TAG, "Stopped BLE advertising")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop advertising", e)
        }
    }
    
    /**
     * Update ticket IDs while advertising
     */
    fun updateTicketIds(ticketIds: List<String>) {
        if (isAdvertising) {
            // Restart advertising with new ticket IDs
            stopAdvertising()
            startAdvertising(ticketIds)
        } else {
            currentTicketIds = ticketIds
        }
    }
    
    /**
     * Encode ticket IDs into byte array for advertising
     * Format: [count: 1 byte][id1_length: 1 byte][id1: N bytes][id2_length: 1 byte][id2: M bytes]...
     */
    private fun encodeTicketIds(ticketIds: List<String>): ByteArray {
        if (ticketIds.isEmpty()) {
            return byteArrayOf(0)
        }
        
        // Limit to 20 bytes total (BLE advertising data limit is 31 bytes, we use 20 for ticket data)
        val maxBytes = 20
        var totalBytes = 1 // Count byte
        val encodedIds = mutableListOf<ByteArray>()
        
        for (ticketId in ticketIds) {
            val idBytes = ticketId.toByteArray(Charsets.UTF_8)
            val entrySize = 1 + idBytes.size // 1 byte for length + id bytes
            
            if (totalBytes + entrySize > maxBytes) {
                break // Can't fit more tickets
            }
            
            encodedIds.add(byteArrayOf(idBytes.size.toByte()) + idBytes)
            totalBytes += entrySize
        }
        
        // Build final byte array: [count][id1_length][id1]...[idN_length][idN]
        val result = ByteArray(totalBytes)
        result[0] = encodedIds.size.toByte()
        var offset = 1
        
        for (encodedId in encodedIds) {
            System.arraycopy(encodedId, 0, result, offset, encodedId.size)
            offset += encodedId.size
        }
        
        return result
    }
    
    /**
     * Decode ticket IDs from byte array
     */
    fun decodeTicketIds(data: ByteArray): List<String> {
        if (data.isEmpty() || data[0].toInt() == 0) {
            return emptyList()
        }
        
        val count = data[0].toInt()
        val ticketIds = mutableListOf<String>()
        var offset = 1
        
        for (i in 0 until count) {
            if (offset >= data.size) break
            
            val idLength = data[offset].toInt()
            offset++
            
            if (offset + idLength > data.size) break
            
            val idBytes = ByteArray(idLength)
            System.arraycopy(data, offset, idBytes, 0, idLength)
            ticketIds.add(String(idBytes, Charsets.UTF_8))
            offset += idLength
        }
        
        return ticketIds
    }
    
    /**
     * Advertising callback
     */
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
            Log.d(TAG, "BLE advertising started successfully")
            isAdvertising = true
        }
        
        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            Log.e(TAG, "BLE advertising failed with error code: $errorCode")
            isAdvertising = false
            
            // Error codes:
            // ADVERTISE_FAILED_DATA_TOO_LARGE = 1
            // ADVERTISE_FAILED_TOO_MANY_ADVERTISERS = 2
            // ADVERTISE_FAILED_ALREADY_STARTED = 3
            // ADVERTISE_FAILED_INTERNAL_ERROR = 4
            // ADVERTISE_FAILED_FEATURE_UNSUPPORTED = 5
        }
    }
    
    fun isCurrentlyAdvertising(): Boolean = isAdvertising
    
    fun getCurrentTicketIds(): List<String> = currentTicketIds
    
    override fun onDestroy() {
        super.onDestroy()
        stopAdvertising()
    }
}

