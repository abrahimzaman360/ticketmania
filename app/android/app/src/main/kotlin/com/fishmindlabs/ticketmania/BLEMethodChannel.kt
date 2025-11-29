package com.fishmindlabs.ticketmania

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.os.IBinder
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Flutter method channel for BLE advertising
 */
@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class BLEMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private var advertisingService: BLEAdvertisingService? = null
    private var isBound = false
    
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as BLEAdvertisingService.LocalBinder
            advertisingService = binder.getService()
            isBound = true
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            advertisingService = null
            isBound = false
        }
    }
    
    init {
        bindService()
    }
    
    private fun bindService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val intent = Intent(context, BLEAdvertisingService::class.java)
            context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        }
    }
    
    fun unbindService() {
        if (isBound) {
            context.unbindService(serviceConnection)
            isBound = false
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.error("UNSUPPORTED", "BLE advertising requires Android 5.0+", null)
            return
        }
        
        when (call.method) {
            "startAdvertising" -> {
                val ticketIds = call.argument<List<String>>("ticketIds")
                if (ticketIds == null || ticketIds.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "ticketIds cannot be null or empty", null)
                    return
                }
                
                if (!isBound || advertisingService == null) {
                    result.error("SERVICE_NOT_BOUND", "BLE advertising service not bound", null)
                    return
                }
                
                val success = advertisingService!!.startAdvertising(ticketIds)
                if (success) {
                    result.success(true)
                } else {
                    result.error("ADVERTISING_FAILED", "Failed to start advertising", null)
                }
            }
            
            "stopAdvertising" -> {
                if (!isBound || advertisingService == null) {
                    result.error("SERVICE_NOT_BOUND", "BLE advertising service not bound", null)
                    return
                }
                
                advertisingService!!.stopAdvertising()
                result.success(true)
            }
            
            "updateTicketIds" -> {
                val ticketIds = call.argument<List<String>>("ticketIds")
                if (ticketIds == null) {
                    result.error("INVALID_ARGUMENT", "ticketIds cannot be null", null)
                    return
                }
                
                if (!isBound || advertisingService == null) {
                    result.error("SERVICE_NOT_BOUND", "BLE advertising service not bound", null)
                    return
                }
                
                advertisingService!!.updateTicketIds(ticketIds)
                result.success(true)
            }
            
            "isAdvertising" -> {
                if (!isBound || advertisingService == null) {
                    result.success(false)
                    return
                }
                
                result.success(advertisingService!!.isCurrentlyAdvertising())
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
}

