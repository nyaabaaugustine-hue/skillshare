"""Builds the SkillBridge Python Lab launcher icons from the supplied artwork.

Source image: the final_icon render (2048x2048). This script produces the three
files flutter_launcher_icons expects, matching the contract of the original
hand-drawn generator:

    assets/icon/app_icon.png             1024x1024, full-bleed (iOS, web, Windows)
    assets/icon/app_icon_foreground.png  1024x1024, transparent, robot in safe zone
    assets/icon/app_icon_background.png  1024x1024, brand gradient (Android adaptive)

Usage (from the project root):
    python tool/make_app_icon_from_image.py [source.png]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 1024  # final output size for each asset
SRC = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.join(
        os.environ.get("TEMP", "."), "final_icon.png"
    )
)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icon")


def brand_gradient(size):
    """Diagonal navy -> bright blue gradient matching the artwork."""
    base = Image.linear_gradient("L").resize(size)
    top = Image.new("RGB", size, (14, 30, 76))
    bot = Image.new("RGB", size, (18, 108, 230))
    vert = Image.composite(bot, top, base)
    horiz = Image.composite(bot, top, base.rotate(90))
    return Image.blend(vert, horiz, 0.5).convert("RGBA")


def isolate_foreground(src):
    """Chroma-key the flat background away and return a transparent cut-out.

    The artwork sits on a near-uniform light background; anything close to that
    colour is treated as background and made transparent, with a soft edge so
    the result has no hard cut line.
    """
    rgb = src.convert("RGB")
    w, h = rgb.size
    bg = rgb.getpixel((6, 6))  # corner sample

    # Distance from the background colour, as a 0-255 matte.
    px = rgb.load()
    matte = Image.new("L", (w, h), 0)
    mp = matte.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
            # <30 => fully background, >90 => fully subject, in between ramps.
            if d <= 30:
                v = 0
            elif d >= 90:
                v = 255
            else:
                v = int((d - 30) * 255 / (90 - 30))
            mp[x, y] = v

    # Feather the matte so downscaling never shows stair-stepping.
    matte = matte.filter(ImageFilter.GaussianBlur(1.2))
    fg = rgb.convert("RGBA")
    fg.putalpha(matte)
    return fg


def fit(img, box_ratio, size):
    """Scale img so its non-transparent bbox fits box_ratio of a `size` square,
    then centre it on a transparent canvas."""
    bbox = img.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped = img.crop(bbox)
    target = int(size * box_ratio)
    scale = target / max(cropped.width, cropped.height)
    new = cropped.resize(
        (max(1, int(cropped.width * scale)), max(1, int(cropped.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(new, ((size - new.width) // 2, (size - new.height) // 2))
    return canvas


def write(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.normpath(os.path.join(OUT, name))
    img.convert("RGB").save(path, optimize=True) if name.endswith("background.png") else img.save(path, optimize=True)
    print("wrote", path)


def main():
    if not os.path.exists(SRC):
        raise SystemExit(f"source image not found: {SRC}")
    raw = Image.open(SRC).convert("RGB")
    fg_full = isolate_foreground(raw)

    # 1) Full-bleed: brand gradient background + the robot filling ~80%.
    full = brand_gradient((S, S))
    full.alpha_composite(fit(fg_full, 0.80, S))
    write(full, "app_icon.png")

    # 2) Adaptive background: plain brand gradient.
    write(brand_gradient((S, S)), "app_icon_background.png")

    # 3) Adaptive foreground: transparent, robot inside the ~66% safe zone.
    write(fit(fg_full, 0.66, S), "app_icon_foreground.png")


if __name__ == "__main__":
    main()
