# 🛠️ Developer Setup Guide

This project relies on several external services for features like Metadata fetching, Lyrics, Cloud Sync, and Remote Control. To run the app fully, you need to configure your own API keys.

## 1. Environment Variables (`.env`)

Create a file named `.env` in the root of the project (`simple_music_player_2/.env`).
Copy the following template and fill in your keys:

```ini
# SPOTIFY (For Metadata & Art)
# Get yours at: https://developer.spotify.com/dashboard/
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret

# ACOUSTID (For Audio Fingerprinting) - 🚧 Under Development
# Get yours at: https://acoustid.org/applications
ACOUSTID_API_KEY=your_acoustid_key

# DISCORD (For Rich Presence)
# Optional: The app comes with a default ID pre-configured.
# Only add this if you want to use your own custom app name/images.
# DISCORD_APP_ID=your_discord_app_id
```

## 2. Remote Control Web App (`index.html`)

If you want to host your own Remote Control web app (or just test it locally), you need to configure Firebase.

1.  Go to [Firebase Console](https://console.firebase.google.com/).
2.  Create a project and enable **Firestore Database** and **Authentication** (Anonymous).
3.  Add a **Web App** to your project.
4.  Copy the `firebaseConfig` object.
5.  Open `remote_web_app/index.html`.
6.  Replace the placeholder config with yours:

```javascript
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.firebasestorage.app",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID",
    measurementId: "YOUR_MEASUREMENT_ID"
};
```

## 3. Firebase for Desktop App (`metrics_service.dart`)

To enable Cloud Sync and the desktop side of Remote Control:

1.  You need to replace the `firebase_options.dart` file or manually configure `MetricsService`.
2.  Currently, the app uses hardcoded fallback keys or `.env` specifically for the desktop client. Ensure your `.env` keys match your Firebase project if you modify `services/metrics_service.dart`.

## 4. Run the App

```bash
flutter pub get
flutter run -d windows
```
