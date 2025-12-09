# 🎵 Simple Music Player New Gen

![Simple Music Player Home](assets/screenshots/home_preview.png)

> A stunning, modern, and feature-rich music player built with Flutter for Windows. Experience your music with a beautiful Glassmorphism UI and powerful tools.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

## ✨ Key Features

### 🎨 **Stunning UI/UX**
*   **Glassmorphism Design**: A sleek, modern interface with frosted glass effects and dynamic backgrounds.
*   **Custom Window Frame**: A fully custom, borderless window experience that blends seamlessly with your desktop.
*   **Themes**: Beautiful dark mode and accent color customization.
*   **Smart Art**: Dynamic album art that adapts to your music, with automatic online fetching.

### 🎧 **Advanced Audio Experience**
*   **Powerful Equalizer**: Fine-tune your audio with a built-in multi-band equalizer.
*   **Visualizer**: Watch your music come to life with real-time audio visualization using `libwinmedia`.
*   **Gapless Playback**: Seamless transitions between tracks.
*   **Sleep Timer**: Fall asleep to your favorite tunes with a customizable timer.

### 🎤 **Lyrics & Metadata**
*   **Synced Lyrics**: Sing along with time-synced lyrics (LRC) fetched automatically from LRCLIB.net.
*   **Metadata Editor**: Edit song tags, album art, and details directly within the app.
*   **Smart Recognition**: Automatically fetch missing metadata and album art using advanced matching algorithms.

### 🌟 **Smart Downloader**
*   **YouTube Support**: Download your favorite tracks directly with high-quality audio extraction.
*   **Resilient Downloading**: Robust error handling prevents crashes even if network issues occur.
*   **Metadata Tagging**: Automatically tags downloaded files with correct artist, title, and album art.

### 🛠️ **Power User Tools**
*   **Discord Rich Presence**: Show off what you're listening to on your Discord profile.
*   **Auto-Updates**: Seamless background updates so you're always on the latest version.
*   **Taskbar Integration**: Control playback directly from the Windows taskbar thumb buttons (SMTC).
*   **Mini Player**: Keep the music playing in a stable, compact, fixed-size window while you work.
*   **Remote Control**: Control the player from your phone via QR code pairing.

## 🚀 Installation

1.  Go to the [Releases](https://github.com/Momotz4G/simple-music-player-2/releases) page.
2.  Download the latest installer (`.exe`).
3.  Run the installer.
4.  Enjoy!

> **For Developers:** If you want to build from source or fork the project, please check out the [Setup Guide](SETUP.md) to configure API keys.

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/)
*   **Language**: [Dart](https://dart.dev/)
*   **Audio Engine**: `just_audio`
*   **Database**: `Isar` (High-performance NoSQL)
*   **State Management**: `Riverpod`
*   **Lyrics & Metadata**: `metadata_god`, `flutter_media_metadata`, `LRCLIB API`
*   **Windows Integration**: `bitsdojo_window`, `smtc_windows`, `window_manager`
*   **Downloader**: `yt-dlp` (via process), `ffmpeg`
*   **Styling**: Custom Glassmorphism components

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/Momotz4G/simple-music-player-2/issues).

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📝 License

Distributed under the MIT License. See `LICENSE` for more information.

---

Made with ❤️ by **Momotz4G**
