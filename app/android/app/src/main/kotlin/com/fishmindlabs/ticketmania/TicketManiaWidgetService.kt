package com.fishmindlabs.ticketmania

import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TicketManiaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TicketManiaWidgetFactory(applicationContext, intent)
    }
}

class TicketManiaWidgetFactory(
    private val context: android.content.Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {
    // Triple: (name, price, id)
    private val favorites = mutableListOf<Triple<String, String, String>>()
    
    override fun onCreate() {
        loadFavorites()
    }
    
    override fun onDataSetChanged() {
        loadFavorites()
    }
    
    private fun loadFavorites() {
        favorites.clear()
        
        // Try multiple SharedPreferences files to find the data
        // home_widget package may use different file names
        val prefsNames = listOf(
            "home_widget",
            "FlutterSharedPreferences",
            "group.com.fishmindlabs.ticketmania"
        )
        
        var favoritesJson: String? = null
        for (prefsName in prefsNames) {
            try {
                val prefs = context.getSharedPreferences(prefsName, android.content.Context.MODE_PRIVATE)
                favoritesJson = prefs.getString("favorites", null)
                if (favoritesJson != null && favoritesJson.isNotEmpty() && favoritesJson != "[]") {
                    android.util.Log.d("WidgetService", "Found favorites in $prefsName: $favoritesJson")
                    break
                }
            } catch (e: Exception) {
                android.util.Log.w("WidgetService", "Failed to read from $prefsName: ${e.message}")
            }
        }
        
        // Fallback to default SharedPreferences
        if (favoritesJson == null || favoritesJson.isEmpty() || favoritesJson == "[]") {
            try {
                val defaultPrefs = android.preference.PreferenceManager.getDefaultSharedPreferences(context)
                favoritesJson = defaultPrefs.getString("favorites", "[]") ?: "[]"
            } catch (e: Exception) {
                android.util.Log.w("WidgetService", "Failed to read from default prefs: ${e.message}")
                favoritesJson = "[]"
            }
        }
        
        try {
            if (favoritesJson != null && favoritesJson.isNotEmpty() && favoritesJson != "[]") {
                val jsonArray = org.json.JSONArray(favoritesJson)
                for (i in 0 until jsonArray.length()) {
                    val jsonObject = jsonArray.getJSONObject(i)
                    val id = jsonObject.optString("id", "")
                    val name = jsonObject.optString("name", "Ticket")
                    val priceStr = jsonObject.optString("price", "0.00")
                    val price = "€$priceStr"
                    if (id.isNotEmpty()) {
                        favorites.add(Triple(name, price, id))
                    }
                }
                android.util.Log.d("WidgetService", "Loaded ${favorites.size} favorites")
            } else {
                android.util.Log.d("WidgetService", "No favorites found or empty JSON")
            }
        } catch (e: Exception) {
            // Handle JSON parsing error
            android.util.Log.e("WidgetService", "Error loading favorites: ${e.message}", e)
            e.printStackTrace()
        }
    }
    
    override fun onDestroy() {
        favorites.clear()
    }
    
    override fun getCount(): Int = favorites.size
    
    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_item)
        if (position < favorites.size) {
            val favorite = favorites[position]
            views.setTextViewText(R.id.ticket_name, favorite.first)
            views.setTextViewText(R.id.ticket_price, favorite.second)
            views.setTextViewText(R.id.ticket_subtitle, "Tap to book")
            
            // Set fill-in intent with favorite ID for deep linking
            val fillInIntent = Intent().apply {
                putExtra("favorite_id", favorite.third) // favorite.third is the ID
                putExtra("from_widget", true)
            }
            // Use the root LinearLayout as the clickable container
            views.setOnClickFillInIntent(android.R.id.content, fillInIntent)
        } else {
            // Fallback for out of bounds
            views.setTextViewText(R.id.ticket_name, "Loading...")
            views.setTextViewText(R.id.ticket_price, "€0.00")
            views.setTextViewText(R.id.ticket_subtitle, "")
        }
        return views
    }
    
    override fun getLoadingView(): RemoteViews? = null
    
    override fun getViewTypeCount(): Int = 1
    
    override fun getItemId(position: Int): Long = position.toLong()
    
    override fun hasStableIds(): Boolean = true
}

