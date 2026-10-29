#!/usr/bin/env python3
"""Generate GRUB splash background for Capyloon x86_64 ISO."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # repo root (scripts/ is directly under root)
LOGO = os.path.join(ROOT, "iso/livebuild/config/includes.binary/boot/grub/themes/capyloon/logo.png")
OUT = os.path.join(ROOT, "iso/livebuild/config/includes.binary/boot/grub/splash.png")

W, H = 1920, 1080

img = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(img)

# Vertical gradient: dark slate -> slightly warmer dark
top = (16, 20, 26)
bottom = (30, 36, 48)
for y in range(H):
    t = y / (H - 1)
    r = int(top[0] + (bottom[0] - top[0]) * t)
    g = int(top[1] + (bottom[1] - top[1]) * t)
    b = int(top[2] + (bottom[2] - top[2]) * t)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# Subtle accent line under the logo area
accent = (255, 127, 42)  # capyloon orange
draw.rectangle([0, H - 3, W, H - 1], fill=accent)

# Load and paste logo, centered horizontally, upper-middle area
if os.path.exists(LOGO):
    logo = Image.open(LOGO).convert("RGBA")
    # scale to 44% of width
    lw = int(W * 0.44)
    lh = int(logo.height * lw / logo.width)
    logo = logo.resize((lw, lh), Image.LANCZOS)
    lx = (W - lw) // 2
    ly = int(H * 0.18)
    # paste with alpha
    img.paste(logo, (lx, ly), logo)
else:
    print(f"WARNING: logo not found at {LOGO}")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG")
print("saved:", OUT, img.size)
