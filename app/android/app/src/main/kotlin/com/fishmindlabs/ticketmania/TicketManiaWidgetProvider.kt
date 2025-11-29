package com.fishmindlabs.ticketmania

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class TicketManiaWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, TicketManiaWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_layout)
        
        // Set title
        views.setTextViewText(R.id.widget_title, "Quick Book")
        views.setTextViewText(R.id.widget_subtitle, "Tap to book your favorites")
        
        // Check if we have favorites - try multiple SharedPreferences files
        var favoritesJson: String? = null
        var favoritesCount = 0
        val prefsNames = listOf(
            "home_widget",
            "FlutterSharedPreferences",
            "group.com.fishmindlabs.ticketmania"
        )
        
        for (prefsName in prefsNames) {
            try {
                val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                favoritesJson = prefs.getString("favorites", null)
                favoritesCount = prefs.getInt("favorites_count", 0)
                if (favoritesJson != null && favoritesJson.isNotEmpty() && favoritesJson != "[]") {
                    break
                }
            } catch (e: Exception) {
                // Continue to next file
            }
        }
        
        // Fallback to default SharedPreferences
        if (favoritesJson == null || favoritesJson.isEmpty() || favoritesJson == "[]") {
            try {
                val defaultPrefs = android.preference.PreferenceManager.getDefaultSharedPreferences(context)
                favoritesJson = defaultPrefs.getString("favorites", "[]") ?: "[]"
                favoritesCount = defaultPrefs.getInt("favorites_count", 0)
            } catch (e: Exception) {
                favoritesJson = "[]"
                favoritesCount = 0
            }
        }
        
        if (favoritesJson == null) {
            favoritesJson = "[]"
        }
        
        if (favoritesCount > 0 && favoritesJson != "[]") {
            // Hide empty view, show list
            views.setViewVisibility(R.id.empty_view, android.view.View.GONE)
            views.setViewVisibility(R.id.favorites_list, android.view.View.VISIBLE)
            
            // Set up list view
            val intent = Intent(context, TicketManiaWidgetService::class.java)
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            views.setRemoteAdapter(R.id.favorites_list, intent)
            
            // Set click template - will be filled with favorite_id by fill-in intent
            val clickIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("from_widget", true)
            }
            val pendingIntent = android.app.PendingIntent.getActivity(
                context, 0, clickIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.favorites_list, pendingIntent)
            
            // Tell the AppWidgetManager to notify the ListView to update
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.favorites_list)
        } else {
            // Show empty view, hide list
            views.setViewVisibility(R.id.empty_view, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.favorites_list, android.view.View.GONE)
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

