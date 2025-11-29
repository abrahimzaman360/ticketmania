# Home Screen Widget Setup Guide

## Overview
The app now supports home screen widgets for quick ticket booking from favorites without opening the app.

## What's Been Implemented

### 1. Categories on Booking Page ✅
- Added `category` column to `ticket_types` table
- Categories are displayed as filter chips at the top of the booking page
- Users can filter tickets by category (All, daily, weekly, monthly, single, etc.)

### 2. Favorites System ✅
- Created `favorite_tickets` table with RLS policies
- Users can add/remove favorites from the booking page
- Favorites are displayed in a horizontal scrollable list at the top of the booking page
- Clicking a favorite automatically fills in the booking form and books the ticket
- Heart icon on each ticket type shows favorite status

### 3. Home Widget Foundation ✅
- Added `home_widget` package (v0.8.1)
- Created `WidgetService` to manage widget updates
- Widget automatically updates when favorites change
- Android widget provider and service created

## Android Widget Setup

### Files Created:
1. `android/app/src/main/res/xml/widget_provider_info.xml` - Widget configuration
2. `android/app/src/main/res/layout/widget_layout.xml` - Widget layout
3. `android/app/src/main/res/layout/widget_item.xml` - Individual favorite item layout
4. `android/app/src/main/kotlin/com/fishmindlabs/app/TicketManiaWidgetProvider.kt` - Widget provider
5. `android/app/src/main/kotlin/com/fishmindlabs/app/TicketManiaWidgetService.kt` - Widget service
6. `android/app/src/main/res/values/strings.xml` - Widget strings

### Next Steps for Android Widget:
1. **Complete the Widget Service**: The `TicketManiaWidgetFactory` needs to properly parse JSON from SharedPreferences
2. **Add Deep Linking**: Handle widget clicks to open the app and book the selected favorite
3. **Test Widget**: Build and test the widget on an Android device

## iOS Widget Setup (Not Yet Implemented)

iOS widgets require:
1. Create a Widget Extension target in Xcode
2. Implement SwiftUI widget views
3. Configure App Groups for data sharing
4. Handle widget interactions

## Usage

### Adding Favorites:
1. Go to Booking page
2. Select a ticket type, stations (optional), and quantity
3. Click the heart icon next to the ticket type
4. The favorite will appear in the Favorites section

### Booking from Favorites:
1. In the Favorites section, tap on a favorite card
2. The booking form will be auto-filled
3. Ticket will be booked automatically

### Using Home Widget:
1. Long press on home screen
2. Add "Ticket Mania" widget
3. Widget shows up to 4 favorite tickets
4. Tap a favorite to open app and book

## Database Schema

### favorite_tickets table:
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key to auth.users)
- `ticket_type_id` (UUID, foreign key to ticket_types)
- `from_station_id` (UUID, nullable, foreign key to stations)
- `to_station_id` (UUID, nullable, foreign key to stations)
- `quantity` (integer, default 1)
- `created_at`, `updated_at` (timestamps)

### ticket_types table:
- Added `category` column (TEXT, default 'general')

## Notes

- Widget updates happen automatically when favorites are added/removed
- Widget shows maximum 4 favorites
- Widget requires app to be installed and user to be logged in
- Deep linking for widget clicks needs to be implemented for full functionality

