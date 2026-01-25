# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter cross-platform application (mobile + web) for a university student engagement platform. The app integrates with Microsoft Azure AD for authentication (restricted to @modelo.edu.mx accounts) and provides features like:

- Event check-ins with QR codes
- Weekly challenges and achievements
- Digital student cards with customizable assets
- Album/collection system
- Virtual currency (Hurra coins and Antorcha points)
- Store for digital items

## Development Commands

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Run on Chrome (web)
flutter run -d chrome

# Run with dart-defines for web build
flutter run -d chrome \
  --dart-define=AZURE_CLIENT_ID=your_client_id \
  --dart-define=AZURE_TENANT_ID=your_tenant_id \
  --dart-define=AZURE_REDIRECT_URI_WEB=your_redirect_uri \
  --dart-define=EVENTS_API_BASE_URL=your_api_url \
  --dart-define=API_BASE_URL=your_api_url
```

### Building

```bash
# Build APK for Android
flutter build apk

# Build iOS (macOS only)
flutter build ios

# Build web
flutter build web \
  --dart-define=AZURE_CLIENT_ID=your_client_id \
  --dart-define=AZURE_TENANT_ID=your_tenant_id \
  --dart-define=AZURE_REDIRECT_URI_WEB=your_redirect_uri \
  --dart-define=EVENTS_API_BASE_URL=your_api_url \
  --dart-define=API_BASE_URL=your_api_url
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Maintenance

```bash
# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Analyze code
flutter analyze

# Clean build artifacts
flutter clean
```

## Architecture

### Platform-Specific Authentication Flow

The app has distinct authentication implementations for mobile and web:

**Mobile (iOS/Android):**
- Uses `flutter_appauth` package
- Direct OAuth 2.0 flow with Azure AD
- Secure token storage via `flutter_secure_storage`
- Supports refresh tokens

**Web:**
- Uses `openid_client` with browser authenticator
- OAuth 2.0 implicit flow with fragment handling
- Custom fragment capture in `web/index.html` stores auth data in localStorage
- Fallback parsing via `web_fragment_storage.dart` (platform-conditional implementation using stub pattern)
- Token storage via `shared_preferences`

See `lib/services/auth_service.dart:81-142` for web sign-in completion logic and `lib/services/auth_service.dart:290-336` for web sign-in initiation.

### Configuration System

**Environment Variables:**
- Uses `--dart-define` for compile-time configuration
- `lib/config/app_config.dart` handles platform-specific config loading
- Web builds receive config via dart-defines; mobile can use same approach
- `lib/config/azure_config.dart` wraps Azure-specific settings

**Required Variables:**
- `AZURE_CLIENT_ID` - Azure AD application ID
- `AZURE_TENANT_ID` - Azure AD tenant ID
- `AZURE_REDIRECT_URI` - Mobile redirect URI (e.g., `mx.edu.modelo.centralizado://oauth2redirect`)
- `AZURE_REDIRECT_URI_WEB` - Web redirect URI (e.g., `http://localhost:port/`)
- `EVENTS_API_BASE_URL` - Primary backend API URL
- `API_BASE_URL` - Fallback API URL

### Service Layer Pattern

All API integrations follow a consistent pattern:

1. **Service classes** (`lib/services/`) handle HTTP communication
2. Each service:
   - Takes token via parameter (stateless)
   - Uses `http.Client` (injectable for testing)
   - Normalizes base URLs
   - Throws `TokenExpiredException` on 401 responses
   - Returns null/empty on failures (no exceptions for missing data)

3. **Example pattern:**
   ```dart
   Future<T?> fetchData(String token) async {
     final uri = Uri.parse('$baseUrl/api/endpoint');
     final response = await _client.get(
       uri,
       headers: {'Authorization': 'Bearer $token'},
     );
     if (response.statusCode == 401) {
       throw const TokenExpiredException();
     }
     if (response.statusCode != 200) {
       return null;
     }
     // Parse and return data
   }
   ```

### Session Management

- `AuthService.getValidSession()` returns valid session or attempts refresh
- `AuthService.refreshSession()` explicitly refreshes tokens (mobile only; web requires re-authentication)
- `SessionStorage` abstracts platform-specific storage (secure storage on mobile, SharedPreferences on web)
- Token expiration checked via JWT `exp` claim with 30-second leeway

### Screen Organization

- `SplashScreen` → checks maintenance mode & session validity → routes to `LoginScreen` or `HomeScreen`
- `HomeScreen` is the main hub with bottom navigation and feed system
- Feature screens:
  - `UserCardScreen` - customizable digital student card
  - `AlbumScreen` - collection of unlocked items
  - `StoreScreen` - purchase card assets with virtual currency
  - `EventCheckinScreen` - event attendance with QR scanning
  - `QRScannerScreen` - mutual QR scanning for challenges
  - `CardPreviewScreen` - preview card before saving

### Data Models

All models in `lib/models/` follow JSON serialization pattern:
- `fromJson(Map<String, dynamic>)` constructor
- Immutable fields
- Nullable types for optional fields

Key models:
- `UserProfile` - user data with balance, photo, stats
- `AuthSession` - authentication tokens and metadata
- `CardSelection` - current card customization
- `CardAsset` - purchasable/unlockable card components
- `WeeklyChallenge` - challenge definition with rewards
- `EventSummary` - event with check-in details
- `AlbumEntry` - collection item

### Asset System

Card customization assets stored in `assets/card/`:
- `backgrounds/` - full card backgrounds
- `banners/` - top decorative banners
- `frames/` - card border frames
- `nameplates/` - name display styles
- `photo_frames/` - profile photo frames
- `title_badges/` - achievement badges
- `medals/` - accomplishment indicators

Assets referenced by filename in API responses and resolved to full URLs by services.

### Special Web Considerations

1. **Fragment Authentication:** `web/index.html` has inline script capturing OAuth redirect fragment before Flutter initializes
2. **Conditional Implementations:** `web_fragment_storage.dart` uses export with conditional imports for web vs. non-web implementations
3. **No Refresh Tokens:** Web users must re-authenticate when tokens expire
4. **CORS:** Backend must allow cross-origin requests from web app domain

## Important Constraints

1. **Email Domain Restriction:** Only `@modelo.edu.mx` email addresses are allowed (enforced in `lib/services/auth_service.dart:209`)
2. **No Offline Mode:** App requires active internet connection for all operations
3. **Token-Based API:** All API calls require valid JWT token in Authorization header
4. **Maintenance Mode:** App checks `/api/vnext/status` endpoint for maintenance flag on startup
