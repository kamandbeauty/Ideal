#!/usr/bin/env python3
"""Make the 512 px Android/app icon from the shield artwork.

    python3 tools/build_icon.py

Requires Pillow. The source is the RGBA emblem used on the loading screen.
"""
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
SOURCE = PROJECT / "assets/textures/branding/emblem.png"
OUTPUT = PROJECT / "assets/textures/icon.png"


def main():
    emblem = Image.open(SOURCE).convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS)
    background = Image.new("RGBA", emblem.size, (17, 21, 25, 255))
    Image.alpha_composite(background, emblem).convert("RGB").save(OUTPUT, optimize=True)
    print("icon.png 512")


if __name__ == "__main__":
    main()
