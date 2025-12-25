# iOS Installation Guide - Sideloading

This guide explains how to install **Simple Music Player** on your iPhone without using the App Store.

---

## Download the IPA

1. Visit the [**Releases page**](https://github.com/Momotz4G/simple-music-player-2/releases)
2. Download `Simple.Music.Player.ipa` from the latest release
3. Choose one of the installation methods below

---

## Installation Methods

### Method 1: AltStore (Recommended - Most Compatible)

**Requirements:**
- iOS 12.2 or later
- Computer (Windows or Mac)
- Lightning/USB-C cable

**Steps:**

#### 1. Install AltStore on your computer
- **Windows:** Download from [altstore.io](https://altstore.io/)
- **Mac:** Download from [altstore.io](https://altstore.io/)

#### 2. Install AltStore on your iPhone
1. Connect your iPhone to computer via cable
2. Open AltServer on computer (check system tray/menu bar)
3. Click AltServer icon → **Install AltStore** → Select your iPhone
4. Enter your Apple ID (used only locally, never sent to servers)
5. AltStore app will appear on your iPhone

#### 3. Install Simple Music Player
1. Download `Simple.Music.Player.ipa` to your computer
2. Open iTunes/Finder and enable **File Sharing**
3. Drag the IPA file to AltStore's file sharing area
4. On your iPhone, open **AltStore**
5. Go to **My Apps** tab
6. Tap the **+** button
7. Select `Simple.Music.Player.ipa`
8. Wait for installation (may take a few minutes)

#### 4. Trust the App
1. Go to **Settings** → **General** → **VPN & Device Management**
2. Tap your Apple ID
3. Tap **Trust**

#### 5. Re-signing (Required Every 7 Days)
- Free Apple ID apps expire after 7 days
- Open AltStore on iPhone while connected to same WiFi as computer
- AltStore will automatically refresh apps
- Or manually refresh in **My Apps** tab

---

### Method 2: Sideloadly (Windows/Mac)

**Requirements:**
- Computer (Windows or Mac)
- iPhone connected via cable

**Steps:**

#### 1. Download Sideloadly
- Visit [sideloadly.io](https://sideloadly.io/)
- Download for Windows or Mac

#### 2. Install the IPA
1. Open Sideloadly
2. Connect your iPhone via cable
3. Drag `Simple.Music.Player.ipa` into Sideloadly
4. Enter your Apple ID email
5. Enter your Apple ID password (optional: use app-specific password)
6. Click **Start**
7. Wait for installation

#### 3. Trust the App
1. Go to **Settings** → **General** → **VPN & Device Management**
2. Tap your Apple ID certificate
3. Tap **Trust**

#### 4. Re-signing
- Apps expire after 7 days
- Repeat the installation process to refresh

---

### Method 3: TrollStore (Permanent - No Re-signing)

**Requirements:**
- iOS 14.0 - 16.6.1 (check [compatibility](https://ios.cfw.guide/installing-trollstore/))
- **NOT compatible with iOS 17+**

**Benefits:**
- ✅ **Permanent installation** - no 7-day limit
- ✅ No computer needed after initial setup
- ✅ Install directly on device

**Steps:**

#### 1. Install TrollStore
- Follow the guide at [ios.cfw.guide/installing-trollstore](https://ios.cfw.guide/installing-trollstore/)
- Installation method varies by iOS version

#### 2. Install the IPA
1. Download `Simple.Music.Player.ipa` on your iPhone (Safari)
2. Open in **Files** app
3. Tap the IPA → **Share** → **TrollStore**
4. Tap **Install**
5. App is permanently installed!

#### 3. No Re-signing Needed
- Apps installed via TrollStore don't expire
- No need to refresh or reinstall

---

## Troubleshooting

### "Untrusted Developer" Error
- Go to **Settings** → **General** → **VPN & Device Management**
- Find your Apple ID
- Tap **Trust**

### App Crashes on Launch
- Make sure you're on iOS 13.0 or later
- Try reinstalling the app
- Check if you have enough storage space

### "Unable to Install"
- Delete any existing version of the app
- Restart your iPhone
- Try a different installation method

### Re-signing Issues (AltStore)
- Make sure your iPhone and computer are on the same WiFi
- Keep AltServer running on your computer
- Open AltStore app to manually refresh

### Apple ID "Verification Failed"
- Use app-specific password instead of main password
- Generate at [appleid.apple.com](https://appleid.apple.com/)
- Go to **Sign-In and Security** → **App-Specific Passwords**

---

## Features Available

✅ **Full music player functionality**
✅ **Dynamic Island** media controls (iPhone 14 Pro+)
✅ **Lock screen** controls
✅ **Background playback**
✅ **Download songs**
✅ **Playlists and favorites**
✅ **Album art and metadata**

❌ No push notifications (limitation of sideloading)

---

## Comparison: Installation Methods

| Method | Complexity | Re-signing | iOS Version | Permanent |
|--------|-----------|-----------|-------------|-----------|
| **AltStore** | Medium | Every 7 days | 12.2+ | No |
| **Sideloadly** | Easy | Every 7 days | 12.0+ | No |
| **TrollStore** | Hard (initial) | Never | 14.0-16.6.1 | Yes ✅ |

---

## Need Help?

- Open an issue on [GitHub](https://github.com/Momotz4G/simple-music-player-2/issues)
- Check existing issues for solutions
- Join the discussion for tips and tricks

---

## Legal Note

Sideloading is permitted by Apple for personal use. You are responsible for complying with Apple's terms of service and local laws.
