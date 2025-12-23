#!/bin/bash
# macOS Streaming Diagnostic & Fix Script
# Run this on your Mac to diagnose and fix streaming issues

set -e  # Exit on error

echo "==================================="
echo "macOS Streaming Diagnostic & Fix"
echo "==================================="
echo ""

PROJECT_DIR="$PWD"
APP_BUNDLE="build/macos/Build/Products/Release/simple_music_player_2.app"
BUNDLE_ID="com.momotz4g.simpleMusicPlayer2"

# 1. Check project binaries
echo "1️⃣ Checking project binaries..."
echo "-----------------------------------"
if [ -d "assets/binaries" ]; then
    ls -lah assets/binaries/
    echo ""
    
    # Check for required files
    for binary in yt-dlp_macos ffmpeg_macos ffprobe_macos; do
        if [ -f "assets/binaries/$binary" ]; then
            echo "✅ Found: $binary"
            
            # Check if executable
            if [ -x "assets/binaries/$binary" ]; then
                echo "   ✅ Executable"
            else
                echo "   ❌ NOT executable - FIXING..."
                chmod +x "assets/binaries/$binary"
                echo "   ✅ Fixed!"
            fi
        else
            echo "❌ MISSING: $binary"
        fi
    done
else
    echo "❌ assets/binaries/ directory not found!"
    exit 1
fi

echo ""
echo "2️⃣ Checking app bundle..."
echo "-----------------------------------"
if [ -d "$APP_BUNDLE" ]; then
    echo "✅ App bundle exists"
    
    # Check if binaries are bundled in the app
    ASSET_PATH="$APP_BUNDLE/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/binaries"
    
    if [ -d "$ASSET_PATH" ]; then
        echo "✅ Binaries folder exists in app bundle"
        echo ""
        echo "Bundled binaries:"
        ls -lah "$ASSET_PATH/"
        echo ""
        
        # Check each binary in the bundle
        for binary in yt-dlp_macos ffmpeg_macos ffprobe_macos; do
            if [ -f "$ASSET_PATH/$binary" ]; then
                echo "✅ Bundled: $binary"
            else
                echo "❌ NOT bundled: $binary"
            fi
        done
    else
        echo "❌ Binaries folder NOT in app bundle!"
        echo "   This means flutter build didn't include them."
        echo "   Try: flutter clean && flutter pub get && flutter build macos --release"
    fi
else
    echo "❌ App bundle not found! Build the app first:"
    echo "   flutter build macos --release"
    exit 1
fi

echo ""
echo "3️⃣ Checking app support directory..."
echo "-----------------------------------"
APP_SUPPORT="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support/$BUNDLE_ID/bin"

if [ -d "$APP_SUPPORT" ]; then
    echo "✅ App support bin directory exists"
    echo ""
    ls -lah "$APP_SUPPORT/"
    echo ""
    
    # Check permissions
    for binary in yt-dlp ffmpeg ffprobe; do
        if [ -f "$APP_SUPPORT/$binary" ]; then
            echo "✅ Copied: $binary"
            
            # Check executable permission
            if [ -x "$APP_SUPPORT/$binary" ]; then
                echo "   ✅ Executable"
            else
                echo "   ❌ NOT executable - FIXING..."
                chmod +x "$APP_SUPPORT/$binary"
                echo "   ✅ Fixed!"
            fi
            
            # Test manual execution
            echo "   Testing execution..."
            if "$APP_SUPPORT/$binary" --version &>/dev/null; then
                echo "   ✅ Runs successfully!"
            else
                echo "   ❌ Failed to run - checking Gatekeeper..."
                
                # Remove quarantine attribute
                xattr -d com.apple.quarantine "$APP_SUPPORT/$binary" 2>/dev/null || true
                chmod +x "$APP_SUPPORT/$binary"
                
                # Try again
                if "$APP_SUPPORT/$binary" --version &>/dev/null; then
                    echo "   ✅ Fixed! (Removed Gatekeeper quarantine)"
                else
                    echo "   ❌ Still fails - macOS may be blocking it"
                fi
            fi
        else
            echo "❌ NOT copied: $binary"
        fi
    done
else
    echo "⚠️  App support directory doesn't exist yet"
    echo "   This is normal before first run."
    echo "   Binaries will be copied on first launch."
fi

echo ""
echo "4️⃣ Checking entitlements..."
echo "-----------------------------------"
if [ -f "macos/Runner/Release.entitlements" ]; then
    echo "Checking for required entitlements:"
    
    if grep -q "com.apple.security.cs.allow-jit" macos/Runner/Release.entitlements; then
        echo "✅ JIT entitlement found"
    else
        echo "❌ Missing: com.apple.security.cs.allow-jit"
    fi
    
    if grep -q "com.apple.security.network.server" macos/Runner/Release.entitlements; then
        echo "✅ Network server entitlement found"
    else
        echo "❌ Missing: com.apple.security.network.server"
    fi
    
    if grep -q "com.apple.security.device.audio-input" macos/Runner/Release.entitlements; then
        echo "✅ Audio input entitlement found"
    else
        echo "❌ Missing: com.apple.security.device.audio-input"
    fi
fi

echo ""
echo "==================================="
echo "Summary & Next Steps"
echo "==================================="
echo ""

# Final recommendations
if [ -d "$APP_SUPPORT" ]; then
    echo "✅ Binaries have been copied to app support"
    echo "✅ Permissions and quarantine have been fixed"
    echo ""
    echo "🎵 Try streaming now! If it still fails:"
    echo "   1. Close the app completely"
    echo "   2. Run: open $APP_BUNDLE"
    echo "   3. Try streaming a song"
else
    echo "⚠️  Binaries not yet copied (app hasn't run)"
    echo ""
    echo "Next steps:"
    echo "   1. Run: open $APP_BUNDLE"
    echo "   2. Once app starts, close it"
    echo "   3. Run this script again to verify binaries were copied"
    echo "   4. Then try streaming"
fi

echo ""
echo "To run the app with console output:"
echo "   $APP_BUNDLE/Contents/MacOS/simple_music_player_2"
echo ""
