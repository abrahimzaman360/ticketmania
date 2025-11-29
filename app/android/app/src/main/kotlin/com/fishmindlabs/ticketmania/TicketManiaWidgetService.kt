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
        val prefs = context.getSharedPreferences("home_widget", android.content.Context.MODE_PRIVATE)
        val favoritesJson = prefs.getString("favorites", "[]")
        
        try {
            val jsonArray = org.json.JSONArray(favoritesJson)
            for (i in 0 until jsonArray.length()) {
                val jsonObject = jsonArray.getJSONObject(i)
                val id = jsonObject.getString("id")
                val name = jsonObject.getString("name")
                val price = "€${jsonObject.getString("price")}"
                favorites.add(Triple(name, price, id))
            }
        } catch (e: Exception) {
            // Handle JSON parsing error
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
            }
            // Use the root LinearLayout as the clickable container
            views.setOnClickFillInIntent(android.R.id.content, fillInIntent)
        }
        return views
    }
    
    override fun getLoadingView(): RemoteViews? = null
    
    override fun getViewTypeCount(): Int = 1
    
    override fun getItemId(position: Int): Long = position.toLong()
    
    override fun hasStableIds(): Boolean = true
}

