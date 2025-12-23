# macOS Distribution Files

This folder contains scripts for creating user-friendly macOS distribution packages.

## Files

### For Users (included in distribution)
- **SimpleMusicPlayer_Setup.command** - One-click installer for end users
- **README_macOS.md** - User installation instructions

### For Developers (you)
- **create_distribution.sh** - Creates the distribution ZIP package

---

## How to Create Distribution Package

### On Your Mac:

1. **Build the app**
   ```bash
   flutter build macos --release
   ```

2. **Run the distribution script**
   ```bash
   cd macos_distribution
   chmod +x create_distribution.sh
   ./create_distribution.sh
   ```

3. **Upload the ZIP**
   - Find `SimpleMusicPlayer_macOS_v*.zip` in project root
   - Upload to GitHub Releases

---

## What Gets Packaged

```
SimpleMusicPlayer_macOS_Package/
├── simple_music_player_2.app       (Your built app)
├── SimpleMusicPlayer_Setup.command (One-click installer)
├── README.txt                      (User instructions)
└── VERSION.txt                     (Version info)
```

All of this gets zipped into: `SimpleMusicPlayer_macOS_v1.7.0.zip`

---

## User Experience

1. User downloads and extracts ZIP
2. User double-clicks `SimpleMusicPlayer_Setup.command`
3. Script automatically:
   - Removes quarantine flags
   - Fixes permissions
   - Launches the app
   - Fixes streaming binary permissions
4. Done! ✅

---

## Testing the Package

Before distributing, test it yourself:

```bash
# Simulate a fresh download
cd ~/Downloads
unzip SimpleMusicPlayer_macOS_v*.zip
cd SimpleMusicPlayer_macOS_Package

# Run as a user would
./SimpleMusicPlayer_Setup.command
```

---

## Notes

- The setup script must have execute permissions (`chmod +x`)
- The ZIP must be created on macOS (not Windows) to preserve permissions
- Users may still need to allow binaries in System Preferences on first stream
- The app is universal (works on both Intel and Apple Silicon Macs)
