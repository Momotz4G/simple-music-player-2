# 🎵 Simple Music Player New Gen

![Simple Music Player Home](assets/screenshots/home_preview.png)

> A stunning, modern, and feature-rich music player built with Flutter. Experience your music with a beautiful Glassmorphism UI and powerful tools. Available on Windows, macOS, Android, and iOS.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

---

## ✨ Key Features

### 🎨 **Stunning UI/UX**
- **Glassmorphism Design**: A sleek, modern interface with frosted glass effects and dynamic backgrounds
- **Custom Window Frame**: A fully custom, borderless window experience that blends seamlessly with your desktop
- **Themes**: Beautiful dark mode and accent color customization
- **Smart Art**: Dynamic album art that adapts to your music, with automatic online fetching from Spotify
- **Spotify Canvas**: Dynamic video backgrounds while in full-screen mode, automatically fetched from Spotify

### 🎧 **Advanced Audio Experience**
- **Powerful Equalizer**: Fine-tune your audio with a built-in multi-band equalizer
- **Audio Visualizer**: Watch your music come to life with real-time audio waveform visualization
- **Sleep Timer**: Fall asleep to your favorite tunes with a customizable timer (hours, minutes, or songs)
- **Playback Queue**: Persistent queue that remembers your playlist between sessions
- **Multiple Audio Versions**: Choose between different versions of a song (original, acoustic, live, etc.)

### 🎤 **Lyrics & Metadata**
- **Synced Lyrics**: Sing along with time-synced lyrics (LRC) fetched automatically from LRCLIB.net
- **Lyrics Panel**: Beautiful, scrollable lyrics view with auto-scroll and tap-to-seek
- **Metadata Editor**: Edit song tags, album art, and details directly within the app
- **Smart Recognition**: Search and fetch missing metadata and album art using Spotify's database
- **Wikipedia Integration**: Artist information and biographies fetched from Wikipedia

### 🌟 **Smart Downloader**
- **YouTube Support**: Download tracks directly with high-quality audio extraction
- **Bulk Downloads**: Queue multiple songs for download at once
- **Resilient Downloading**: Robust error handling prevents crashes even if network issues occur
- **Automatic Metadata**: Tags downloaded files with correct artist, title, and album art from Spotify
- **Import Spotify Playlist**: Paste your Spotify playlist link to import the entire playlist. Stream or download all tracks directly from the app
- **FLAC Streaming and Download**: You can stream or download all songs with lossless quality if available. (Just adjust your settings preferences)

### 📊 **Statistics & History**
- **Play Statistics**: Track your listening habits with detailed stats
- **Listening History**: See your recently played songs
- **Top Artists & Albums**: Discover your most-played music
- **Shareable Stats**: Generate beautiful stat cards to share on social media
- **Cloud Sync**: Play counts synced across sessions via PocketBase

### 📚 **Library Management**
- **Smart Library**: Browse by Songs, Albums, Artists, or Playlists
- **Custom Playlists**: Create and manage your own playlists
- **Search**: Powerful search across your entire library
- **Folder Import**: Import music from any folder on your computer
- **Album/Artist Pages**: Detailed pages with all tracks, info, and actions

### 🛠️ **Power User Tools**
- **Discord Rich Presence**: Show what you're listening to on your Discord profile
- **Auto-Updates**: Seamless background updates via GitHub releases
- **Taskbar Integration**: Control playback from Windows taskbar thumb buttons (SMTC)
- **Mini Player**: Compact, always-on-top window for minimal distraction
- **Full-Screen Mode**: Immersive full-screen player with Canvas video support
- **Remote Control**: Control the player from your phone via QR code pairing (web-based)
- **Admin Dashboard**: Hidden admin panel for managing users and viewing metrics

### ☁️ **Cloud Features**
- **PocketBase Backend**: Self-hosted or cloud-based sync server
- **Metrics Tracking**: Anonymous usage statistics
- **Remote Control Server**: Real-time playback control from any device
- **Secure API**: Protected endpoints with admin authentication

---

## 🚀 Installation

### 📦 Download

Go to the [Releases](https://github.com/Momotz4G/simple-music-player-2/releases) page and download the file for your platform:

| Platform | File | Install Method |
|----------|------|----------------|
| **Windows** | `.exe` | Run installer |
| **macOS** | `.zip` | Extract and run setup script |
| **Android** | `.apk` | Enable unknown sources, tap to install |
| **iOS** | `.ipa` | Sideload (see below) |

---

### 🪟 Windows
1. Download the `.exe` installer
2. Run the installer
3. Done! Launch from Start menu

---

### 🍎 macOS
1. Download and extract the `.zip` file
2. **Double-click** `SimpleMusicPlayer_Setup.command`
3. Done! The app will launch automatically

> 💡 **First stream:** macOS may ask to allow binaries (yt-dlp, ffmpeg). Go to **System Preferences → Privacy & Security** and click "Allow Anyway"

> 📖 See `README.txt` in the ZIP for detailed instructions

---

### 🤖 Android
1. Download the `.apk` file
2. Enable "Install from unknown sources" in Settings
3. Tap the APK to install
4. Done!

---

### 📱 iOS (Sideloading Required)

> ⚠️ **Note:** iOS requires sideloading because this app is not on the App Store. Apps sideloaded with a free Apple ID expire every **7 days** and must be re-installed.

> 📖 **Full Guide:** See [IOS_SIDELOAD_GUIDE.md](IOS_SIDELOAD_GUIDE.md) for detailed instructions, troubleshooting, and all installation methods.

#### Quick Install Options

**Method 1: AltStore** (iOS 12.2+) - Most Compatible
- Install AltStore on your computer
- Connect iPhone via USB
- Add the IPA through AltStore app
- Re-sign every 7 days

**Method 2: Sideloadly** - Simplest
- Download [Sideloadly](https://sideloadly.io)
- Connect iPhone, drag IPA, enter Apple ID
- Re-sign every 7 days

**Method 3: TrollStore** (iOS 14-16.6.1 only) - **PERMANENT!** ⭐
- No re-signing needed
- One-time installation
- Not compatible with iOS 17+
- See guide for installation steps

#### What Works on iOS?
✅ Dynamic Island media controls (iPhone 14 Pro+)  
✅ Lock screen controls  
✅ Background playback  
✅ All music player features  
❌ Push notifications (sideloading limitation)

---

### 🛠️ For Developers

If you want to build from source or fork the project, check out the [Setup Guide](SETUP.md) to configure API keys and backend services.

```bash
# Clone the repository
git clone https://github.com/Momotz4G/simple-music-player-2.git
cd simple-music-player-2

# Install dependencies
flutter pub get

# Configure environment (see SETUP.md)
# Then run:
flutter run -d windows   # Windows
flutter run -d macos     # macOS
flutter run              # Android (with device connected)
```

---

## ⚠️ Limitations

- **Daily Download Cap**: To ensure service quality and fair usage, downloads are limited to **50 songs per day** per user
- **iOS Sideloading**: iOS requires sideloading (not on App Store). Apps expire every **7 days** with a free Apple ID
- **Equalizer**: Audio equalizer only works on Android
- **Internet Required**: Some features require internet (lyrics, metadata, streaming, remote control)

---

## 🔒 Privacy Policy

- **Anonymous ID**: Your machine's hardware information is hashed to create a unique, anonymous ID
- **No Personal Data**: We don't collect names, emails, or personal information
- **Usage Only**: The ID is used only for download rate limiting and abuse prevention
- **Local First**: All your music and playlists are stored locally on your device

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | [Flutter](https://flutter.dev/) |
| **Language** | [Dart](https://dart.dev/) |
| **Audio Engine** | `just_audio` + `media_kit` |
| **Local Database** | `Isar` (High-performance NoSQL) |
| **Cloud Backend** | `PocketBase` (self-hosted or cloud) |
| **State Management** | `Riverpod` |
| **Lyrics API** | LRCLIB.net |
| **Metadata API** | Spotify Web API |
| **Windows Integration** | `bitsdojo_window`, `smtc_windows`, `window_manager` |
| **Downloader** | `yt-dlp`, `ffmpeg` |
| **Rich Presence** | `flutter_discord_rpc` |
| **Styling** | Custom Glassmorphism components |

---

## 📸 Screenshots

| Home | Full Screen | Stats |
|------|-------------|-------|
| ![Home](assets/screenshots/home_preview.png) | *Coming soon* | *Coming soon* |

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/Momotz4G/simple-music-player-2/issues).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

Distributed under the MIT License. See `LICENSE` for more information.

---

## 🙏 Acknowledgments

- [Spotify](https://developer.spotify.com/) - Metadata and album art API
- [LRCLIB](https://lrclib.net/) - Synced lyrics database
- [PocketBase](https://pocketbase.io/) - Backend server
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - YouTube downloading
- [Flutter](https://flutter.dev/) - Amazing cross-platform framework

---

<p align="center">Made with ❤️ by <strong>Momotz4G</strong></p>
