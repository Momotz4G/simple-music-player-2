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

In PocketBase Admin UI, create these collections with the following fields:

#### Collection: `metrics`
| Field | Type |
|-------|------|
| user_id | Text |
| hostname | Text |
| os | Text |
| os_version | Text |
| play_count | Number |
| daily_play_count | Number |
| download_count | Number |
| daily_download_count | Number |
| local_total_plays | Number |
| last_active | DateTime |
| last_play_date | DateTime |
| last_download_date | DateTime |
| is_banned | Boolean |

**API Rules for `metrics`:**
| Rule | Setting |
|------|---------|
| List | 🔒 Admins only |
| View | Empty (open) |
| Create | Empty (open) |
| Update | Empty (open) |
| Delete | 🔒 Admins only |

#### Collection: `sessions`
| Field | Type |
|-------|------|
| user_id | Text |
| device_name | Text |
| current_title | Text |
| current_artist | Text |
| album_art_url | URL |
| is_playing | Boolean |
| volume | Number |
| last_command | Text |

**API Rules for `sessions`:**
| Rule | Setting |
|------|---------|
| List | 🔒 Admins only |
| View | Empty (open) |
| Create | Empty (open) |
| Update | Empty (open) |
| Delete | Empty (open) |

#### Collection: `settings`
| Field | Type | Description |
|-------|------|-------------|
| access_code | Text | Admin code - full access (ban, delete, reset all) |
| viewer_code | Text | Viewer code - can only reset own quota |

**API Rules for `settings`:**
| Rule | Setting |
|------|---------|
| List | 🔒 Admins only |
| View | 🔒 Admins only |
| Create | 🔒 Admins only |
| Update | 🔒 Admins only |
| Delete | 🔒 Admins only |

> **Access Levels:**
> - **Admin (access_code):** Full control - ban users, delete records, reset any quota
> - **Viewer (viewer_code):** Read-only + can reset their OWN quota only

> **Setup:** Create one record in `settings` with your codes:
> - `access_code`: Your private admin password
> - `viewer_code`: Code to share with users for self-service quota reset

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
