# Simple Music Player for macOS

## 🎵 Quick Start

**Just 2 steps:**

1. **Double-click** `SimpleMusicPlayer_Setup.command`
2. **Enjoy!** The app will open automatically

That's it! The setup script handles all permissions for you.

---

## 📝 What the Setup Script Does

✅ Removes macOS quarantine flags  
✅ Fixes app permissions  
✅ Launches the app  
✅ Fixes streaming binary permissions  

---

## ⚠️ First Time Streaming

When you first try to stream a song, macOS may show security warnings for:
- `yt-dlp` (YouTube downloader)
- `ffmpeg` (Audio converter)
- `ffprobe` (Audio analyzer)

**To fix:**
1. Go to **System Preferences** → **Privacy & Security**
2. Scroll down to find "yt-dlp was blocked" (or similar)
3. Click **"Allow Anyway"**
4. Repeat for `ffmpeg` and `ffprobe` if prompted

**Or run the setup script again** after these warnings appear.

---

## 📂 Moving to Applications Folder (Optional)

After setup, you can move the app to your Applications folder:

1. Open **Finder**
2. Drag `simple_music_player_2.app` to **/Applications**
3. Delete the downloaded folder

---

## 🔧 Troubleshooting

### "Cannot be opened because the developer cannot be verified"
- Make sure you ran `SimpleMusicPlayer_Setup.command` first
- If you still see this, go to **System Preferences** → **Privacy & Security** and click **"Open Anyway"**

### "Operation not permitted" when streaming
1. Go to **System Preferences** → **Privacy & Security**
2. Click **"Allow Anyway"** for blocked binaries
3. Or run `SimpleMusicPlayer_Setup.command` again

### Manual permission fix (if needed)
```bash
# Remove quarantine
xattr -cr simple_music_player_2.app

# Fix streaming binaries
xattr -cr ~/Library/Containers/com.momotz4g.simpleMusicPlayer2/Data/Library/Application\ Support/com.momotz4g.simpleMusicPlayer2/bin/
chmod +x ~/Library/Containers/com.momotz4g.simpleMusicPlayer2/Data/Library/Application\ Support/com.momotz4g.simpleMusicPlayer2/bin/*
```

---

## ✨ Features

- 🎵 Play local music files
- 🌐 Stream songs from YouTube
- ⬇️ Download songs for offline playback
- 📱 Remote control via web interface
- 🎤 Synchronized lyrics display
- 📊 Playback statistics
- 🎨 Beautiful, modern UI

---

## 💡 Tips

- **Keyboard shortcuts work!** Spacebar to play/pause
- **Drag & drop** songs into the app
- **Search** for any song on YouTube
- **Create playlists** for easy organization
- **Check stats** to see your most played songs

---

## 🆘 Need Help?

If you encounter any issues:
1. Try running the setup script again
2. Check System Preferences → Privacy & Security for blocked items
3. Report issues on GitHub: [Your GitHub URL]

---

## 🎉 Enjoy!

Thank you for using Simple Music Player!

Made with ❤️ by Momotz4G
