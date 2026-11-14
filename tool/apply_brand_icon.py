"""Apply the SkillBridge Academy brand icon everywhere.

Usage (from the project root):

    pip install pillow
    python tool/apply_brand_icon.py "C:\\path\\to\\final_icon.png"
    dart run flutter_launcher_icons

Reads the one supplied logo and writes every variant the app needs:
  assets/icon/app_icon.png             full-bleed icon / in-app logo (1024)
  assets/icon/app_icon_background.png  Android adaptive background (solid white)
  assets/icon/app_icon_foreground.png  Android adaptive foreground (inside safe zone)
  assets/icon/app_icon_monochrome.png  Android 13+ themed icon
  web/icons/Icon-*.png, web/favicon.png  browser / PWA icons

Do NOT run tool/make_app_icon.py afterwards: it draws the old robot icon and
would overwrite these files.
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
WHITE = (255, 255, 255, 255)


def content_box(img: Image.Image) -> tuple:
    """Bounding box of the artwork (everything that is not near-white)."""
    rgb = img.convert("RGB")
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, (255, 255, 255)))
    mask = diff.convert("L").point(lambda v: 255 if v > 24 else 0)
    return mask.getbbox() or (0, 0, *img.size)


def square_on(canvas_size: int, art: Image.Image, scale: float,
              background=WHITE) -> Image.Image:
    """Centres [art] on a square canvas so it fills [scale] of the width."""
    canvas = Image.new("RGBA", (canvas_size, canvas_size), background)
    target = int(canvas_size * scale)
    ratio = min(target / art.width, target / art.height)
    resized = art.resize(
        (max(1, int(art.width * ratio)), max(1, int(art.height * ratio))),
        Image.LANCZOS,
    )
    canvas.paste(
        resized,
        ((canvas_size - resized.width) // 2, (canvas_size - resized.height) // 2),
        resized if resized.mode == "RGBA" else None,
    )
    return canvas


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Image.open(sys.argv[1]).convert("RGBA")

    # Flatten onto white so the soft card shadow never shows as grey corners.
    flat = Image.new("RGBA", src.size, WHITE)
    flat.alpha_composite(src)

    art = flat.crop(content_box(flat))  # just the logo, no card margin
    pad = int(max(art.size) * 0.06)
    art = square_on(max(art.size) + pad * 2, art, 1.0 - 2 * pad / (max(art.size) + pad * 2))

    icon = square_on(1024, art, 0.88)  # full-bleed icon
    icon_dir = ROOT / "assets" / "icon"
    icon_dir.mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(icon_dir / "app_icon.png")

    Image.new("RGBA", (1024, 1024), WHITE).convert("RGB").save(
        icon_dir / "app_icon_background.png")

    # Adaptive foreground: Android masks to ~66% of the canvas, so stay inside.
    square_on(1024, art, 0.62, background=(255, 255, 255, 0)).save(
        icon_dir / "app_icon_foreground.png")

    # Themed (monochrome) icon: darkness of the artwork becomes the alpha.
    mono_src = square_on(1024, art, 0.62, background=(255, 255, 255, 255))
    alpha = mono_src.convert("L").point(lambda v: min(255, int((255 - v) * 1.35)))
    mono = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    mono.putalpha(alpha)
    mono.save(icon_dir / "app_icon_monochrome.png")

    web = ROOT / "web"
    icons = web / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        icon.resize((size, size), Image.LANCZOS).convert("RGB").save(
            icons / f"Icon-{size}.png")
        # Maskable icons need extra padding for the platform mask.
        square_on(size, art, 0.66).convert("RGB").save(
            icons / f"Icon-maskable-{size}.png")
    square_on(64, art, 0.96).convert("RGB").save(web / "favicon.png")

    print("Brand icon applied. Now run: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
