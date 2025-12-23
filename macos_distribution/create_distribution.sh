#!/bin/bash

# macOS Distribution Package Creator
# Run this script ON YOUR MAC to create the distribution ZIP

echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║   Simple Music Player - Distribution Builder          ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS!"
    exit 1
fi

# Get project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
DIST_DIR="$PROJECT_DIR/macos_distribution"
PACKAGE_DIR="$PROJECT_DIR/SimpleMusicPlayer_macOS_Package"

echo "📂 Project directory: $PROJECT_DIR"
echo ""

# Check if app exists
if [ ! -d "$BUILD_DIR/simple_music_player_2.app" ]; then
    echo "❌ Error: App not found!"
    echo "   Please build the app first:"
    echo "   flutter build macos --release"
    exit 1
fi

echo "✅ Found app at: $BUILD_DIR/simple_music_player_2.app"
echo ""

# Create package directory
echo "📦 Creating distribution package..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy app
echo "   Copying app..."
cp -r "$BUILD_DIR/simple_music_player_2.app" "$PACKAGE_DIR/"

# Copy setup script
echo "   Copying setup script..."
cp "$DIST_DIR/SimpleMusicPlayer_Setup.command" "$PACKAGE_DIR/"
chmod +x "$PACKAGE_DIR/SimpleMusicPlayer_Setup.command"

# Copy README
echo "   Copying README..."
cp "$DIST_DIR/README_macOS.md" "$PACKAGE_DIR/README.txt"

# Create version info file
echo "   Creating version info..."
VERSION=$(grep "version:" "$PROJECT_DIR/pubspec.yaml" | head -n 1 | awk '{print $2}')
cat > "$PACKAGE_DIR/VERSION.txt" << EOF
Simple Music Player for macOS
Version: $VERSION
Build Date: $(date "+%Y-%m-%d %H:%M:%S")
Architecture: Universal (Intel + Apple Silicon)

What's Included:
- simple_music_player_2.app (The main application)
- SimpleMusicPlayer_Setup.command (One-click installer)
- README.txt (Installation instructions)

Quick Start:
1. Double-click SimpleMusicPlayer_Setup.command
2. Enjoy!

For more information, see README.txt
EOF

echo ""
echo "✅ Package created at: $PACKAGE_DIR"
echo ""

# Create ZIP
echo "📦 Creating ZIP archive..."
cd "$PROJECT_DIR"
ZIP_NAME="SimpleMusicPlayer_macOS_v${VERSION}.zip"

# Remove old ZIP if exists
rm -f "$ZIP_NAME"

# Create ZIP (use ditto for macOS compatibility)
cd "$PACKAGE_DIR/.."
zip -r "$PROJECT_DIR/$ZIP_NAME" "$(basename "$PACKAGE_DIR")"

if [ $? -eq 0 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║              ✅ BUILD SUCCESSFUL! ✅                   ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "📦 Distribution package created:"
    echo "   $ZIP_NAME"
    echo ""
    
    # Get file size
    SIZE=$(du -h "$PROJECT_DIR/$ZIP_NAME" | awk '{print $1}')
    echo "   File size: $SIZE"
    echo ""
    
    echo "🚀 Ready to distribute!"
    echo ""
    echo "   • Upload to GitHub Releases"
    echo "   • Share via Google Drive, Dropbox, etc."
    echo "   • Users just download, extract, and run the setup script"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    
    # Ask to open folder
    echo ""
    read -p "Open the distribution folder? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$PROJECT_DIR"
    fi
else
    echo ""
    echo "❌ Error creating ZIP file!"
    exit 1
fi

echo ""
echo "✨ Done!"
echo ""
