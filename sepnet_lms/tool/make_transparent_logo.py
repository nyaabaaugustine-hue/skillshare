"""Derive transparent in-app logo assets from the launcher icon.

The launcher icon (assets/icon/app_icon.png) is a full-bleed white tile with a
soft shadow, which looks like a white box when drawn on the app's dark or gold
surfaces. This script removes the white background and writes:

  assets/icon/app_logo.png  transparent logo: mark + wordmark + tagline
  assets/icon/app_mark.png  transparent logo mark only (cap, S, book)

Both keep the original colours; near-white pixels are made transparent and the
remaining colour is un-premultiplied so edges do not carry a white halo.

Run from the project root:

    python tool/make_transparent_logo.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "assets" / "icon" / "app_icon.png"
OUT_LOGO = ROOT / "assets" / "icon" / "app_logo.png"
OUT_MARK = ROOT / "assets" / "icon" / "app_mark.png"

# Any channel below this is fully transparent; above it, the pixel fades out.
WHITE_FLOOR = 96


def remove_white(source: Image.Image) -> Image.Image:
    """Return a copy with the white backdrop removed and colour restored."""
    rgba = source.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue

            # How far the darkest channel sits from white: white -> 0,
            # any saturated brand colour -> close to 255.
            darkness = 255 - min(r, g, b)
            if darkness <= 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue

            alpha = min(255, round(darkness * 255 / WHITE_FLOOR))
            # The launcher tile's soft drop shadow is neutral grey. Coloured
            # anti-aliased edges are kept; faint grey fringes are dropped so
            # no rounded-card arc survives around the mark.
            neutral = max(r, g, b) - min(r, g, b) < 42
            if alpha <= 4 or (neutral and alpha < 140):
                pixels[x, y] = (0, 0, 0, 0)
                continue

            # Un-premultiply against white so anti-aliased edges keep their
            # true colour instead of turning pale.
            scale = 255 / alpha
            nr = max(0, min(255, round((r - (255 - alpha)) * scale)))
            ng = max(0, min(255, round((g - (255 - alpha)) * scale)))
            nb = max(0, min(255, round((b - (255 - alpha)) * scale)))
            pixels[x, y] = (nr, ng, nb, alpha)

    # Crop to solid ink only: the launcher tile's faint shadow sits well below
    # this alpha, so its rounded-card arc is excluded from the content box.
    solid = rgba.getchannel("A").point(lambda v: 255 if v >= 140 else 0)
    bbox = solid.getbbox() or rgba.getbbox()
    return rgba.crop(bbox) if bbox else rgba


def trim_wordmark(logo: Image.Image) -> Image.Image:
    """Crop the top block (the mark) off the full logo.

    The wordmark starts below the book illustration; a little over half of the
    logo's height is the mark alone. The cut is found from the widest empty
    horizontal band in the lower half, so small layout changes still work.
    """
    alpha = logo.getchannel("A")
    width, height = logo.size
    row_ink = []
    for y in range(height):
        band = alpha.crop((0, y, width, y + 1))
        row_ink.append(sum(band.tobytes()))

    # Search for the quietest band between 50% and 68% of the height.
    start, end = int(height * 0.50), int(height * 0.70)
    candidates = range(start, end)
    cut = min(candidates, key=lambda y: row_ink[y])
    cropped = logo.crop((0, 0, width, cut))
    bbox = cropped.getbbox()
    return cropped.crop(bbox) if bbox else cropped


def main() -> None:
    if not ICON.exists():
        raise SystemExit(f"Missing launcher icon: {ICON}")

    source = Image.open(ICON)
    transparent = remove_white(source)

    logo = transparent.copy()
    logo.thumbnail((1024, 1024), Image.LANCZOS)
    logo.save(OUT_LOGO, optimize=True)
    print(f"wrote {OUT_LOGO.relative_to(ROOT)} {logo.size}")

    mark = trim_wordmark(transparent)
    mark.thumbnail((640, 640), Image.LANCZOS)
    mark.save(OUT_MARK, optimize=True)
    print(f"wrote {OUT_MARK.relative_to(ROOT)} {mark.size}")


if __name__ == "__main__":
    main()
