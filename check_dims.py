
import os
try:
    from PIL import Image
    files = ['assets/badges/android.png', 'assets/badges/windows.png', 'assets/badges/macos.png']
    for f in files:
        if os.path.exists(f):
            try:
                with Image.open(f) as img:
                    print(f"{f}: {img.size}")
            except Exception as e:
                print(f"Error opening {f}: {e}")
        else:
            print(f"{f} not found")
except ImportError:
    print("PIL (Pillow) not installed")
