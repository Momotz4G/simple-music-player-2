#!/bin/bash

# Simple Music Player - macOS Setup Script
# This script automatically fixes permissions and launches the app

clear
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║       Simple Music Player - macOS Setup               ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "This will set up Simple Music Player on your Mac."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="$SCRIPT_DIR/simple_music_player_2.app"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: simple_music_player_2.app not found!"
    echo "   Make sure this script is in the same folder as the app."
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

echo "📦 Found app at: $APP_PATH"
echo ""

# Step 1: Remove quarantine from app
echo "🔧 Step 1/3: Removing quarantine flags from app..."
xattr -cr "$APP_PATH" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ App permissions fixed!"
else
    echo "   ⚠️  Warning: Could not modify app permissions"
    echo "   You may need to run: xattr -cr \"$APP_PATH\""
fi
echo ""

# Step 2: Open the app
echo "🚀 Step 2/3: Launching Simple Music Player..."
open "$APP_PATH"
echo "   ✅ App launched!"
echo ""

# Give app time to copy binaries
echo "⏳ Waiting for app to initialize (5 seconds)..."
sleep 5
echo ""

# Step 3: Fix binary permissions
echo "🔧 Step 3/3: Fixing binary permissions for streaming..."
BIN_DIR="$HOME/Library/Containers/com.momotz4g.simpleMusicPlayer2/Data/Library/Application Support/com.momotz4g.simpleMusicPlayer2/bin"

if [ -d "$BIN_DIR" ]; then
    xattr -cr "$BIN_DIR" 2>/dev/null
    chmod +x "$BIN_DIR"/* 2>/dev/null
    echo "   ✅ Streaming binaries fixed!"
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║              ✅ SETUP COMPLETE! ✅                     ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
else
    echo "   ⚠️  Binaries not yet copied (this is normal)"
    echo "   They'll be automatically fixed on first stream."
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║         ✅ SETUP COMPLETE (Partial) ✅                 ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
fi

echo ""
echo "📝 IMPORTANT NOTES:"
echo ""
echo "   • Simple Music Player is now running!"
echo "   • First time streaming may trigger macOS security warnings"
echo "   • If you see 'Operation not permitted' errors:"
echo "     1. Go to System Preferences → Privacy & Security"
echo "     2. Click 'Allow Anyway' for yt-dlp, ffmpeg, ffprobe"
echo "     3. Or run this script again after the app starts"
echo ""
echo "   • To move app to Applications folder (optional):"
echo "     Drag 'simple_music_player_2.app' to /Applications"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🎵 Enjoy your music! 🎵"
echo ""
read -p "Press Enter to close this window..."
