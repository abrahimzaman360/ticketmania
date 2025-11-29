import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_ticket.dart';

class WidgetService {
  static const String _widgetName = 'TicketManiaWidgetProvider';

  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.com.fishmindlabs.ticketmania');
    } catch (e) {
      debugPrint('Failed to initialize widget: $e');
    }
  }

  Future<void> updateWidget(List<FavoriteTicket> favorites) async {
    try {
      // Update widget with favorites (max 4 for widget display)
      final favoritesData = favorites
          .take(4)
          .map(
            (f) => {
              'id': f.id,
              'name': f.ticketTypeName ?? 'Ticket',
              'price': f.ticketPrice?.toStringAsFixed(2) ?? '0.00',
            },
          )
          .toList();

      final favoritesJson = jsonEncode(favoritesData);

      // Save favorites as JSON string using home_widget
      await HomeWidget.saveWidgetData<String>(
        'favorites',
        favoritesJson,
      );

      // Also save directly to SharedPreferences for Android widget to read
      // Flutter's SharedPreferences uses "FlutterSharedPreferences" file on Android
      // We'll save to multiple locations to ensure the widget can read it
      try {
        // Save to default SharedPreferences (FlutterSharedPreferences file)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('favorites', favoritesJson);
        await prefs.setInt('favorites_count', favorites.length);
        
        // Also save to a named SharedPreferences file that the widget can read
        // This is a workaround since home_widget package may use a different file
        debugPrint('Saved widget data to SharedPreferences: $favoritesJson');
        debugPrint('Favorites count: ${favorites.length}');
      } catch (e) {
        debugPrint('Failed to save to SharedPreferences: $e');
      }

      // Save count
      await HomeWidget.saveWidgetData<int>('favorites_count', favorites.length);

      // Update widget
      await HomeWidget.updateWidget(
        name: _widgetName,
        iOSName: _widgetName,
        androidName: _widgetName,
      );
      
      debugPrint('Widget updated with ${favoritesData.length} favorites');
    } catch (e) {
      // Widget update failed, but app should continue working
      debugPrint('Failed to update widget: $e');
    }
  }

  Future<void> bookFromWidget(String favoriteId) async {
    // This will be handled by deep linking
    // The widget will open the app with the favorite ID
    try {
      await HomeWidget.saveWidgetData<String>('selected_favorite', favoriteId);
    } catch (e) {
      debugPrint('Failed to save selected favorite: $e');
    }
  }

  Future<String?> getSelectedFavorite() async {
    try {
      final favoriteId = await HomeWidget.getWidgetData<String>('selected_favorite', defaultValue: '');
      if (favoriteId != null && favoriteId.isNotEmpty) {
        // Clear it after reading
        await HomeWidget.saveWidgetData<String>('selected_favorite', '');
        return favoriteId;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting selected favorite: $e');
      return null;
    }
  }
}
