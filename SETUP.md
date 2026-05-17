# 🎵 Simple Music Player - Complete Setup Guide

This guide will help you set up and compile the Simple Music Player from source. The project uses several external services for metadata, lyrics, cloud sync, and remote control features.

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Clone the Repository](#2-clone-the-repository)
3. [Environment Variables](#3-environment-variables)
4. [PocketBase Setup](#4-pocketbase-setup)
5. [Generate Secure Code](#5-generate-secure-code)
6. [Build & Run](#6-build--run)
7. [Remote Control Web App](#7-remote-control-web-app)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites

Before you begin, ensure you have the following installed:

| Tool | Version | Download |
|------|---------|----------|
| **Flutter SDK** | 3.2.3 or higher | [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started/install) |
| **Dart SDK** | Included with Flutter | - |
| **Git** | Any recent version | [git-scm.com](https://git-scm.com/) |
| **Visual Studio** | 2019 or 2022 (with C++ tools) | Required for Windows builds |

### Verify Installation
```bash
flutter doctor
```
Ensure all checks pass for your target platform (Windows/Android).

---

## 2. Clone the Repository

```bash
git clone https://github.com/Momotz4G/simple-music-player-2.git
cd simple-music-player-2
```

---

## 3. Environment Variables

Create a file named `.env` in the project root directory.

### Full `.env` Template

```ini
# ══════════════════════════════════════════════════════════════
# SPOTIFY API (Required for Metadata & Album Art)
# Get yours at: https://developer.spotify.com/dashboard/
# ══════════════════════════════════════════════════════════════
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret

# ══════════════════════════════════════════════════════════════
# POCKETBASE (Required for Cloud Sync & Remote Control)
# Your self-hosted PocketBase server URL
# ══════════════════════════════════════════════════════════════
POCKETBASE_URL=https://your-pocketbase-url.com
POCKETBASE_ADMIN_EMAIL=your-admin@email.com
POCKETBASE_ADMIN_PASSWORD=your-admin-password

# ══════════════════════════════════════════════════════════════
# DISCORD RICH PRESENCE (Optional)
# The app has a default App ID. Only add this if you want 
# a custom app name/icon on Discord.
# Get yours at: https://discord.com/developers/applications
# ══════════════════════════════════════════════════════════════
# DISCORD_APP_ID=your_discord_app_id

# ══════════════════════════════════════════════════════════════
# QOBUZ APP ID (Optional)
# Used for FLAC metadata lookups.
# Default public ID is used if left blank (no registration needed).
# ══════════════════════════════════════════════════════════════
# QOBUZ_APP_ID=798273057

# ══════════════════════════════════════════════════════════════
# ACOUSTID (Optional - Under Development)
# For audio fingerprinting / song recognition
# Get yours at: https://acoustid.org/applications
# ══════════════════════════════════════════════════════════════
# ACOUSTID_API_KEY=your_acoustid_key

# ══════════════════════════════════════════════════════════════
# REMOTE CONTROL (Required for QR Code Remote)
# Your self-hosted remote control web app URL
# ══════════════════════════════════════════════════════════════
REMOTE_CONTROL_URL=https://your-remote-control-url.com

# ══════════════════════════════════════════════════════════════
# ROMAJI API (Required for Lyrics Romanization & Translation)
# Your own Vercel-hosted API for Japanese/Chinese romanization
# and lyrics translation. Deploy from: romaji-api/ folder
# ══════════════════════════════════════════════════════════════
ROMAJI_API_URL=https://your-romaji-api.vercel.app
```

### How to Get API Keys

#### Spotify API (Required)
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/)
2. Log in with your Spotify account
3. Click **"Create App"**
4. Fill in app name and description
5. Set Redirect URI to `http://localhost:8888/callback`
6. Copy the **Client ID** and **Client Secret**

#### Discord Rich Presence (Optional)
1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **"New Application"**
3. Name it (this name shows on Discord status)
4. Copy the **Application ID**

#### Qobuz App ID (Optional)
- **No registration required.**
- The app comes with a default public ID (`798273057`) which works out of the box.
- You only need to change this if you have a specific private App ID.

#### Romaji API (Required)
This API handles Japanese romanization (Kuroshiro), Chinese Pinyin conversion, and lyrics translation (Google Translate). You need to deploy your own instance to avoid quota issues.

1. Navigate to the `romaji-api/` folder in the repository
2. Install [Vercel CLI](https://vercel.com/docs/cli): `npm i -g vercel`
3. Deploy:
   ```bash
   cd romaji-api
   vercel --prod
   ```
4. Copy your deployment URL (e.g., `https://your-romaji-api.vercel.app`)
5. Set `ROMAJI_API_URL=https://your-romaji-api.vercel.app` in `.env`

The API provides 3 endpoints:
| Endpoint | Purpose |
|----------|---------|
| `/api/romanize` | Japanese → Romaji (Kuroshiro) |
| `/api/pinyin` | Chinese → Pinyin |
| `/api/translate` | Lyrics translation (Google Translate) |

> ⚠️ **Important:** Each user must deploy their own Romaji API. Using someone else's URL will consume their Vercel quota.

---

## 4. PocketBase Setup

PocketBase is used for cloud metrics, remote control, and admin dashboard features.

### Option A: Self-Host on VPS (Recommended for Production)

1. **Get a VPS** (DigitalOcean, Linode, Vultr, etc.)

2. **Download PocketBase** (v0.23+):
   ```bash
   wget https://github.com/pocketbase/pocketbase/releases/download/v0.23.4/pocketbase_0.23.4_linux_amd64.zip
   unzip pocketbase_0.23.4_linux_amd64.zip
   chmod +x pocketbase
   ```

3. **Start PocketBase**:
   ```bash
   ./pocketbase serve --http="0.0.0.0:8090"
   ```

4. **Create Admin Account**:
   - Visit `http://YOUR_VPS_IP:8090/_/`
   - Create your admin account
   - **Save these credentials** - you'll need them for `.env`

5. **(Optional) Expose with Cloudflare Tunnel**:
   ```bash
   # Install cloudflared
   curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
   chmod +x cloudflared
   
   # Start tunnel
   ./cloudflared tunnel --url http://127.0.0.1:8090
   ```
   This gives you a public HTTPS URL like `https://xxx-xxx-xxx.trycloudflare.com`

### Option B: Run Locally (For Development)

1. Download PocketBase for your OS from [pocketbase.io/docs](https://pocketbase.io/docs)
2. Extract and run:
   ```bash
   ./pocketbase serve
   ```
3. Visit `http://127.0.0.1:8090/_/` to set up admin
4. Set `POCKETBASE_URL=http://127.0.0.1:8090` in `.env`

### Option C: PocketBase Cloud (Easiest - No Server Needed)

[PocketBase Cloud](https://pocketbase.io/cloud/) is the official hosted version - no VPS required!

1. Go to [pocketbase.io/cloud](https://pocketbase.io/cloud/)
2. Sign up and create a new project
3. Your URL will be something like `https://your-project.pockethost.io`
4. Set up admin credentials and collections (see below)
5. Use this URL in your `.env`:
   ```ini
   POCKETBASE_URL=https://your-project.pockethost.io
   ```

> **Pricing:** PocketBase Cloud has a free tier with generous limits for personal use.

### Option D: Firebase (Alternative Backend)

If you prefer Firebase over PocketBase, you can use it as an alternative. However, this requires code modifications since the current codebase is built for PocketBase.

#### Firebase Setup Steps:

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click **"Add Project"**
   - Follow the setup wizard

2. **Enable Firestore Database**
   - In Firebase Console → Build → Firestore Database
   - Click **"Create Database"**
   - Start in **test mode** (configure security rules later)

3. **Enable Authentication (Optional)**
   - Build → Authentication → Get Started
   - Enable **Email/Password** or **Anonymous** sign-in

4. **Get Firebase Config**
   - Project Settings → General → Your Apps
   - Click **Web (`</>`)** to add a web app
   - Copy the config object

5. **Add to `.env`**
   ```ini
   # FIREBASE (Alternative to PocketBase)
   FIREBASE_API_KEY=your_api_key
   FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_STORAGE_BUCKET=your-project.appspot.com
   FIREBASE_MESSAGING_SENDER_ID=123456789
   FIREBASE_APP_ID=1:123456789:web:abcdef
   ```

6. **Modify the Code**
   To use Firebase instead of PocketBase, you'll need to:
   - Uncomment Firebase dependencies in `pubspec.yaml`
   - Modify `lib/services/` to use Firestore instead of PocketBase
   - The old Firebase code is available in git history for reference

> ⚠️ **Note:** Firebase has usage-based pricing. For high-traffic apps, PocketBase self-hosted may be more cost-effective.

#### Firebase Collections Structure:

If using Firebase, create these Firestore collections:

| Collection | Documents |
|------------|-----------|
| `metrics` | One document per user (doc ID = user hardware ID) |
| `sessions` | One document per active session |
| `settings` | Single document with `access_code` field |


### Create Required Collections

In your PocketBase Admin UI (`/_/`), you need to create **6 custom collections** with the following fields and API Rules:

#### 1. Collection: `metrics` (Tracks user listening statistics)
| Field | Type | Description |
|-------|------|-------------|
| `user_id` | Text | Unique hardware identifier |
| `nickname` | Text | Custom user profile nickname |
| `avatar` | File | User profile picture (Single image limit) |
| `hostname` | Text | User's active device name / computer name |
| `os` | Text | Operating system (windows, android, etc.) |
| `os_version` | Text | OS build / version string |
| `client_version` | Text | Version of SMP client (e.g. 2.6.9) |
| `play_count` | Number | Lifetime play count across all devices |
| `daily_play_count` | Number | Active daily play count (resets daily) |
| `weekly_play_count` | Number | Active weekly play count (resets weekly) |
| `download_count` | Number | Lifetime download count |
| `daily_download_count` | Number | Active daily download count (resets daily) |
| `local_total_plays` | Number | Total plays cached locally on device |
| `total_minutes` | Number | Lifetime minutes played across all tracks |
| `top_artist` | Text | Name of the user's top streamed artist |
| `top_track` | Text | Name of the user's top streamed track |
| `selected_title` | Text | User's equipped profile title |
| `max_repeat_streak` | Number | Maximum times user listened to the same track sequentially |
| `weekly_wins_count` | Number | Number of times user ranked #1 on weekly leaderboard |
| `weekly_podiums_count` | Number | Number of times user finished top 3 on weekly leaderboard |
| `artist_minutes` | JSON | Key-value dictionary of `Artist -> played_minutes` |
| `last_active` | DateTime | Timestamp of user's last activity heartbeat |
| `last_play_date` | DateTime | Timestamp of user's last played song |
| `last_download_date` | DateTime | Timestamp of user's last downloaded track |
| `is_banned` | Boolean | Administrative ban status |

**API Rules for `metrics`:**
| Rule | Setting |
|------|---------|
| List | 🔒 Admins only (`@request.auth.id != ""`) or completely restricted |
| View | Empty (open) |
| Create | Empty (open) |
| Update | Empty (open) |
| Delete | 🔒 Admins only |

---

#### 2. Collection: `sessions` (Handles real-time Remote Control state)
| Field | Type | Description |
|-------|------|-------------|
| `user_id` | Text | Unique user identifier |
| `current_title` | Text | Title of active track |
| `current_artist` | Text | Artist of active track |
| `current_album` | Text | Album name of active track |
| `is_playing` | Boolean | Playback state (playing or paused) |
| `volume` | Number | Player volume setting |
| `is_shuffle` | Boolean | Shuffle playback mode status |
| `loop_mode` | Number | Active loop mode index |
| `position_seconds` | Number | Current playback progress in seconds (High precision double) |
| `duration_seconds` | Number | Total track duration in seconds (High precision double) |
| `album_art_url` | Text | Live HTTP URL to active album artwork |
| `source_url` | Text | Source stream/audio URL |
| `spotify_id` | Text | Active Spotify track identifier |
| `queue` | JSON | Current playlist play queue (list of songs) |
| `active_album_details` | JSON | Details of currently playing album |
| `active_device_id` | Text | Unique identifier of active player device |
| `active_device_name` | Text | Name of the active player device |
| `last_active` | DateTime | Active polling heartbeat |
| `last_command` | Text | Packed command string (`action|payload|timestamp`) |
| `cmd_payload` | Text | Additional arguments for the last command |
| `available_devices` | JSON | List of all registered online remote devices |
| `search_results` | JSON | Direct results of remote music searches (Party mode) |
| `last_update` | DateTime | Last changed timestamp |

**API Rules for `sessions`:**
| Rule | Setting |
|------|---------|
| List | 🔒 Admins only |
| View | Empty (open) |
| Create | Empty (open) |
| Update | Empty (open) |
| Delete | Empty (open) |

---

#### 3. Collection: `settings` (Dashboard credentials & controls)
| Field | Type | Description |
|-------|------|-------------|
| `access_code` | Text | Admin code - full global system access |
| `viewer_code` | Text | Viewer code - can only trigger self-service resets |

**API Rules for `settings`:**
| Rule | Setting |
|------|---------|
| List | 🔒 Admins only |
| View | 🔒 Admins only |
| Create | 🔒 Admins only |
| Update | 🔒 Admins only |
| Delete | 🔒 Admins only |

---

#### 4. Collection: `artist_metrics` (Aggregates global artist plays)
| Field | Type | Description |
|-------|------|-------------|
| `name` | Text | Name of the artist |
| `play_count` | Number | Lifetime global plays across all users |
| `daily_play_count` | Number | Total play count today |
| `weekly_play_count` | Number | Total play count this week |
| `last_play_date` | DateTime | Timestamp of the last global play |

**API Rules for `artist_metrics`:**
*(Since all modifications are performed securely via the admin client)*
| Rule | Setting |
|------|---------|
| List | Empty (open) or 🔒 Admins only |
| View | Empty (open) |
| Create | 🔒 Admins only |
| Update | 🔒 Admins only |
| Delete | 🔒 Admins only |

---

#### 5. Collection: `shared_playlists` (Cloud playlist sharing engine)
| Field | Type | Description |
|-------|------|-------------|
| `user_id` | Text | Owner's user identifier |
| `playlist_id` | Text | Local playlist identifier |
| `data` | Text | Compressed, base64-encoded playlist content |
| `is_compressed` | Boolean | Compression status flag (GZIP encoded) |
| `share_code` | Text | Unique shared playlist pin (e.g. alphanumeric code) |

**API Rules for `shared_playlists`:**
| Rule | Setting |
|------|---------|
| List | Empty (open) |
| View | Empty (open) |
| Create | Empty (open) |
| Update | Empty (open) |
| Delete | Empty (open) |

---

#### 6. Collection: `broadcasts` (Global system alerts & notices)
| Field | Type | Description |
|-------|------|-------------|
| `message` | Text | Broadcast notification alert message |

**API Rules for `broadcasts`:**
| Rule | Setting |
|------|---------|
| List | Empty (open) |
| View | Empty (open) |
| Create | 🔒 Admins only |
| Update | 🔒 Admins only |
| Delete | 🔒 Admins only |

---

> **Access Levels (Settings configuration):**
> - **Admin (access_code):** Full control - ban users, delete records, reset any quota
> - **Viewer (viewer_code):** Read-only + can reset their OWN quota only
> 
> **Setup:** Create exactly one record in the `settings` collection with your preferred codes.

---

## 5. Generate Secure Code

After setting up your `.env` file, you **must** run this command to generate the obfuscated environment variables:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This creates `lib/env/env.g.dart` which contains your encrypted API keys.

> ⚠️ **Important:** Run this command every time you change `.env`

---

## 6. Build & Run

### Development

```bash
# Get dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Android (with device connected)
flutter run -d android
```

### Production Build

#### Windows
```bash
flutter build windows --release
```
The executable will be in `build/windows/x64/runner/Release/`

#### Android
```bash
flutter build apk --release
```
The APK will be in `build/app/outputs/apk/release/`

---

## 7. Remote Control Web App

The remote control web app is located in `remote_web_app/` folder.

### Setup

1. Create `remote_web_app/config.js`:
   ```javascript
   window.POCKETBASE_CONFIG = {
       url: "https://your-pocketbase-url.com"
   };
   ```

2. **For local testing:** Open `remote_web_app/index.html` in a browser

3. **For deployment (Self-Hosted via Cloudflare Tunnel - Recommended):**
   - Copy files to your VPS: `/var/www/remote/`
   - Configure nginx to serve on port 8091
   - Add a public hostname in Cloudflare Tunnel (e.g., `remote.yourdomain.com` → `localhost:8091`)
   - Update the QR code URL in `lib/ui/components/player_bar.dart`

4. **Alternative (Netlify/Vercel):**
   - Deploy the `remote_web_app/` folder
   - Make sure `config.js` is included in the deployment
   - Update the web app URL in the QR code

---

## 8. Troubleshooting

### Common Issues

#### "Environment variables not found"
- Make sure `.env` exists in project root
- Run `dart run build_runner build --delete-conflicting-outputs`
- Restart the app

#### "PocketBase connection failed"
- Verify your PocketBase server is running
- Check the URL in `.env` is correct (include `https://` or `http://`)
- If using Cloudflare Tunnel, ensure the tunnel is active

#### "Admin authentication failed"
- Ensure PocketBase is v0.23 or higher
- Verify `POCKETBASE_ADMIN_EMAIL` and `POCKETBASE_ADMIN_PASSWORD` match your admin account
- Check that you created the admin account in PocketBase admin panel

#### "Build failed - Isar"
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

#### "Windows build requires Visual Studio"
Install Visual Studio 2019 or 2022 with:
- "Desktop development with C++" workload
- Windows 10 SDK

---

## 📁 Project Structure

```
simple_music_player_2/
├── .env                    # Your API keys (gitignored)
├── lib/
│   ├── env/
│   │   ├── env.dart        # Environment variable definitions
│   │   └── env.g.dart      # Generated (gitignored)
│   ├── services/           # API services
│   ├── providers/          # State management
│   └── ui/                 # UI components
├── remote_web_app/
│   ├── index.html          # Remote control web UI
│   └── config.js           # PocketBase config (gitignored)
└── backend/
    └── pocketbase/         # PocketBase binary (optional)
```

---

## 🔐 Security Notes

- `.env` and `env.g.dart` are gitignored - never commit them
- `remote_web_app/config.js` is gitignored - deploy it separately
- PocketBase API rules should be configured as shown above
- For production, always use HTTPS (Cloudflare Tunnel provides this)

---

## 📞 Need Help?

If you encounter issues not covered here, please open an issue on GitHub with:
- Your Flutter version (`flutter --version`)
- Error messages/logs
- Steps to reproduce

---

Happy coding! 🎶
