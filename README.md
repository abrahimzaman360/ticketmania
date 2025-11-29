# Ticket Mania

A full-stack ticket management application built with Flutter, NestJS, and TanStack Router, integrated with Supabase for authentication and backend services.

## Project Structure

```
ticketmania/
├── app/          # Flutter mobile/desktop app (iOS, Android, Web, Linux, Windows, macOS)
├── backend/      # NestJS backend API
├── web/          # Web app with TanStack Router
└── iot/          # IoT project (not set up yet)
```

## Prerequisites

- Flutter SDK (latest stable version)
- Node.js (v20 or higher)
- pnpm (for web and backend)
- Supabase account and project

## Supabase Configuration

The project uses the following Supabase project:
- **Project URL**: `https://zthekwndkbowxmlneplh.supabase.co`
- **Project Name**: Ticket Mania

### Getting Your Service Role Key

For the backend, you'll need the service role key from your Supabase dashboard:
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to Settings > API
4. Copy the `service_role` key (keep this secret!)

## Setup Instructions

### 1. Flutter App

```bash
cd app
flutter pub get
flutter run
```

The app supports:
- iOS
- Android
- Web (Chrome)
- Linux
- Windows
- macOS

**Configuration**: Supabase credentials are configured in `lib/config/supabase_config.dart`

### 2. NestJS Backend

```bash
cd backend
pnpm install

# Create .env file (copy from .env.example)
cp .env.example .env
# Edit .env and add your SUPABASE_SERVICE_ROLE_KEY

pnpm run start:dev
```

The backend will run on `http://localhost:3000`

**Environment Variables**:
- `PORT` - Server port (default: 3000)
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key (required for backend)

### 3. Web App (TanStack Router)

```bash
cd web
pnpm install
pnpm run dev
```

The web app will run on `http://localhost:3000`

**Environment Variables**: Already configured in `.env` file with:
- `VITE_SUPABASE_URL` - Your Supabase project URL
- `VITE_SUPABASE_ANON_KEY` - Your Supabase anon/public key

## Authentication

All three applications (Flutter app, web app, and backend) are integrated with Supabase Authentication.

### Features Implemented

- ✅ Email/Password authentication (Sign Up & Sign In)
- ✅ Session management
- ✅ Protected routes (web app)
- ✅ Auth state listeners
- ✅ Sign out functionality

### Authentication Flow

1. **Flutter App**: 
   - Shows `AuthPage` when not authenticated
   - Shows `HomePage` when authenticated
   - Automatically redirects based on auth state

2. **Web App**:
   - `/auth` route for authentication
   - `/` route is protected and requires authentication
   - Automatically redirects to `/auth` if not authenticated

3. **Backend**:
   - Configured with Supabase client
   - CORS enabled for frontend and mobile app
   - Ready for implementing protected API endpoints

## Next Steps

1. **Backend**: Add your service role key to `backend/.env`
2. **Database**: Set up your database schema in Supabase
3. **RLS Policies**: Configure Row Level Security policies in Supabase
4. **API Endpoints**: Implement your API endpoints in the NestJS backend
5. **Features**: Build out your ticket management features

## Development

### Flutter
```bash
cd app
flutter run -d chrome        # Run on Chrome
flutter run -d linux         # Run on Linux
flutter run -d windows       # Run on Windows
```

### Backend
```bash
cd backend
pnpm run start:dev          # Development mode with hot reload
pnpm run build              # Build for production
pnpm run start:prod         # Run production build
```

### Web
```bash
cd web
pnpm run dev                # Development server
pnpm run build              # Build for production
pnpm run serve              # Preview production build
```

## Notes

- The Flutter app package name is configured as `com.fishmindlabs.ticketmania`
- All platforms are enabled in the Flutter app
- The backend has CORS enabled to allow requests from the frontend and mobile app
- Environment variables are already configured for the web app
- You need to add the service role key to the backend `.env` file

## Troubleshooting

1. **Flutter**: If you get dependency errors, run `flutter pub get` again
2. **Backend**: Make sure you've added the `SUPABASE_SERVICE_ROLE_KEY` to `.env`
3. **Web**: The `.env` file should already be configured, but verify the values if needed
4. **Authentication**: Make sure email confirmation is disabled in Supabase Auth settings for testing, or implement email verification flow

