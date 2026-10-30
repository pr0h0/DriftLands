"""Draws the app icon (dusk sky, a floating island and its beacon) for the project and the
home-screen web app. Writes icon.png (512) and tools/web/icon-192.png / icon-512.png.

Usage: python3 tools/gen_icon.py
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
S = 1024  # drawn at 2x, downsampled for smooth edges


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, mid, low = (38, 30, 62), (196, 104, 112), (246, 184, 120)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=lerp(top, mid, t / 0.62) if t < 0.62 else lerp(mid, low, (t - 0.62) / 0.38))

# Cloud sea
clouds = Image.new("RGBA", (S, S), (0, 0, 0, 0))
cd = ImageDraw.Draw(clouds)
for i, (x, y, r) in enumerate([(120, 900, 170), (330, 940, 190), (560, 910, 180), (790, 945, 200), (980, 905, 170)]):
    cd.ellipse([x - r, y - r * 0.55, x + r, y + r * 0.55], fill=(255, 226, 205, 235))
img.paste(clouds.filter(ImageFilter.GaussianBlur(6)), (0, 0), clouds.filter(ImageFilter.GaussianBlur(6)))

# Beacon beam
beam = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(beam)
bd.polygon([(492, 0), (532, 0), (546, 470), (478, 470)], fill=(255, 244, 214, 150))
beam = beam.filter(ImageFilter.GaussianBlur(14))
img.paste(beam, (0, 0), beam)

# Floating island: rock underside, grass top, monolith
d = ImageDraw.Draw(img)
d.polygon([(250, 520), (774, 520), (640, 700), (560, 830), (512, 880), (470, 800), (380, 690)], fill=(86, 62, 70))
d.polygon([(250, 520), (774, 520), (700, 600), (512, 640), (330, 600)], fill=(110, 80, 84))
d.ellipse([240, 470, 784, 570], fill=(118, 168, 92))
d.ellipse([270, 470, 754, 545], fill=(140, 190, 104))
d.polygon([(492, 505), (532, 505), (526, 330), (512, 300), (498, 330)], fill=(214, 206, 196))
d.ellipse([496, 276, 528, 308], fill=(255, 246, 220))
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([452, 232, 572, 352], fill=(255, 236, 190, 120))
glow = glow.filter(ImageFilter.GaussianBlur(20))
img.paste(glow, (0, 0), glow)

img = img.resize((512, 512), Image.LANCZOS)
img.save(ROOT / "icon.png")
img.save(ROOT / "tools" / "web" / "icon-512.png")
img.resize((192, 192), Image.LANCZOS).save(ROOT / "tools" / "web" / "icon-192.png")
print("icons written")
