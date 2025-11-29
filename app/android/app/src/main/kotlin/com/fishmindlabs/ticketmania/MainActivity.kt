package com.fishmindlabs.ticketmania

import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fishmindlabs.ticketmania/ble_advertising"
    private var bleMethodChannel: BLEMethodChannel? = null
    
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            bleMethodChannel = BLEMethodChannel(this)
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(bleMethodChannel)
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val favoriteId = intent?.getStringExtra("favorite_id")
        if (favoriteId != null) {
            // Save favorite ID to shared preferences for Flutter to read
            val prefs: SharedPreferences = getSharedPreferences("home_widget", MODE_PRIVATE)
            prefs.edit().putString("selected_favorite", favoriteId).apply()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            bleMethodChannel?.unbindService()
        }
    }
}
