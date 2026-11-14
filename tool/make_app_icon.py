"""Draws the SkillsBridge robot app icon.

Usage (from the project root):
    pip install pillow
    python tool/make_app_icon.py

Writes:
    assets/icon/app_icon.png             1024x1024, full-bleed (iOS, web, Windows)
    assets/icon/app_icon_foreground.png  1024x1024, transparent (Android adaptive)
    assets/icon/app_icon_background.png  1024x1024, gradient (Android adaptive)
    assets/icon/app_icon_monochrome.png  1024x1024, white silhouette (Android 13+ themed icon)
    android/.../res/drawable-nodpi/launch_logo.png  (native launch screen)
    web/favicon.png, favicon-32.png, favicon.ico, apple-touch-icon.png and
    web/icons/*  (a dedicated, simplified favicon: see favicon_master)

Everything is drawn at 2x and downsampled, so edges are smooth.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 2048  # working canvas; downsampled to 1024 at the end
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "icon")
if len(sys.argv) > 1:
    OUT = sys.argv[1]
    ROOT = os.path.join(OUT, "_project")  # keep test runs out of a real project


def gradient(size, c1, c2, vertical=True):
    """Linear gradient from c1 to c2 as an RGB image."""
    base = Image.linear_gradient("L")  # 256x256, black (top) -> white (bottom)
    if not vertical:
        base = base.rotate(90)
    mask = base.resize(size)
    return Image.composite(
        Image.new("RGB", size, c2), Image.new("RGB", size, c1), mask
    )


def diagonal_gradient(size, c1, c2):
    a = gradient(size, c1, c2, vertical=True)
    b = gradient(size, c1, c2, vertical=False)
    return Image.blend(a, b, 0.5)


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def paste_gradient(img, box, radius, c1, c2):
    x0, y0, x1, y1 = box
    g = gradient((x1 - x0, y1 - y0), c1, c2)
    m = rounded_mask((x1 - x0, y1 - y0), (0, 0, x1 - x0 - 1, y1 - y0 - 1), radius)
    img.paste(g, (x0, y0), m)


def glow(img, center, radius, color, strength=1.0, blur=None):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color + (int(255 * strength),))
    layer = layer.filter(ImageFilter.GaussianBlur(blur or radius * 0.6))
    img.alpha_composite(layer)


def shadow(img, box, radius, offset=(0, 40), blur=50, alpha=110):
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        (x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]),
        radius=radius,
        fill=(3, 12, 40, alpha),
    )
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def draw_robot(img, scale=1.0, cx=S // 2, cy=int(S * 0.52)):
    """Draws the robot centred on (cx, cy). scale=1.0 fills ~62% of the canvas."""
    k = scale * S / 1000.0  # design units -> pixels

    def P(x, y):  # design coords (0,0 = robot centre) -> canvas
        return (int(cx + x * k), int(cy + y * k))

    def B(x0, y0, x1, y1):
        a, b = P(x0, y0), P(x1, y1)
        return (a[0], a[1], b[0], b[1])

    d = ImageDraw.Draw(img)

    # ---- antenna ----
    ax0, ay0, ax1, ay1 = B(-12, -420, 12, -300)
    d.rounded_rectangle((ax0, ay0, ax1, ay1), radius=int(12 * k), fill=(196, 214, 240))
    glow(img, P(0, -440), int(70 * k), (255, 196, 64), 0.55)
    bx = P(0, -440)
    r = int(36 * k)
    ball = gradient((2 * r, 2 * r), (255, 226, 130), (240, 160, 20))
    bm = Image.new("L", (2 * r, 2 * r), 0)
    ImageDraw.Draw(bm).ellipse((0, 0, 2 * r - 1, 2 * r - 1), fill=255)
    img.paste(ball, (bx[0] - r, bx[1] - r), bm)

    # ---- shoulders / body (peeks under the head) ----
    body = B(-250, 250, 250, 470)
    shadow(img, body, int(120 * k), offset=(0, int(26 * k)), blur=int(36 * k), alpha=90)
    paste_gradient(img, body, int(120 * k), (232, 240, 252), (150, 178, 218))
    # chest light
    cl = B(-70, 335, 70, 375)
    d.rounded_rectangle(cl, radius=int(20 * k), fill=(24, 44, 92))
    d.rounded_rectangle(B(-40, 345, 40, 365), radius=int(10 * k), fill=(94, 234, 212))

    # ---- ear pods ----
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 318, sx * 372))
        pod = B(x0, -70, x1, 90)
        paste_gradient(img, pod, int(38 * k), (255, 214, 107), (242, 168, 29))

    # ---- head ----
    head = B(-340, -300, 340, 250)
    shadow(img, head, int(150 * k), offset=(0, int(34 * k)), blur=int(44 * k), alpha=120)
    paste_gradient(img, head, int(150 * k), (255, 255, 255), (186, 206, 240))
    # top gloss
    gloss = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.rounded_rectangle(
        B(-318, -288, 318, -80), radius=int(130 * k), fill=(255, 255, 255, 120)
    )
    gloss = gloss.filter(ImageFilter.GaussianBlur(int(10 * k)))
    mask = rounded_mask(img.size, head, int(150 * k))
    gloss.putalpha(ImageChops.multiply(gloss.getchannel("A"), mask))
    img.alpha_composite(gloss)

    # ---- visor ----
    visor = B(-270, -190, 270, 140)
    paste_gradient(img, visor, int(112 * k), (20, 36, 82), (6, 14, 40))
    # visor rim light
    d.rounded_rectangle(
        visor, radius=int(112 * k), outline=(70, 120, 220), width=max(2, int(6 * k))
    )

    # ---- eyes (glowing) ----
    for ex in (-110, 110):
        glow(img, P(ex, -30), int(70 * k), (60, 200, 255), 0.8, blur=int(38 * k))
        e = B(ex - 46, -78, ex + 46, 18)
        d.rounded_rectangle(e, radius=int(46 * k), fill=(120, 232, 255))
        d.rounded_rectangle(
            B(ex - 28, -66, ex + 6, -34), radius=int(16 * k), fill=(236, 252, 255)
        )

    # ---- smile ----
    sm = B(-70, 38, 70, 104)
    d.arc(sm, start=20, end=160, fill=(120, 232, 255), width=max(3, int(16 * k)))


def background():
    bg = diagonal_gradient((S, S), (14, 30, 76), (18, 108, 230)).convert("RGBA")
    # soft light blooms for depth
    glow(bg, (int(S * 0.22), int(S * 0.18)), int(S * 0.45), (90, 170, 255), 0.35, blur=int(S * 0.25))
    glow(bg, (int(S * 0.85), int(S * 0.9)), int(S * 0.4), (0, 40, 120), 0.5, blur=int(S * 0.22))
    return bg


# --------------------------------------------------------------------------
# Browser favicon + web icons
# --------------------------------------------------------------------------
# A favicon is seen at 16-32px, so it is NOT the app icon shrunk: the detailed
# robot (smile, ear pods, body) turns to mush there. This is a dedicated mark:
# a bold head, a big visor and two large glowing eyes, with one gold antenna
# dot for a hit of colour. Everything is chunky enough to survive 16px.
def favicon_master():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Rounded tile, bright at the top-left, deep at the bottom-right.
    tile = diagonal_gradient((S, S), (34, 140, 255), (8, 44, 132)).convert("RGBA")
    img.paste(tile, (0, 0), rounded_mask((S, S), (0, 0, S - 1, S - 1), int(S * 0.23)))

    def B(x0, y0, x1, y1):
        return (int(S * x0), int(S * y0), int(S * x1), int(S * y1))

    d = ImageDraw.Draw(img)

    # Antenna: short stem + gold ball.
    d.rounded_rectangle(B(0.475, 0.15, 0.525, 0.30), radius=int(S * 0.025), fill=(214, 228, 250))
    glow(img, (S // 2, int(S * 0.125)), int(S * 0.09), (255, 196, 64), 0.6, blur=int(S * 0.05))
    r = int(S * 0.075)
    ball = gradient((2 * r, 2 * r), (255, 226, 130), (244, 166, 24))
    bm = Image.new("L", (2 * r, 2 * r), 0)
    ImageDraw.Draw(bm).ellipse((0, 0, 2 * r - 1, 2 * r - 1), fill=255)
    img.paste(ball, (S // 2 - r, int(S * 0.125) - r), bm)

    # Gold ear pods.
    for x0, x1 in ((0.075, 0.16), (0.84, 0.925)):
        paste_gradient(img, B(x0, 0.48, x1, 0.70), int(S * 0.04), (255, 214, 107), (240, 160, 24))

    # Head.
    head = B(0.14, 0.29, 0.86, 0.88)
    shadow(img, head, int(S * 0.2), offset=(0, int(S * 0.02)), blur=int(S * 0.03), alpha=110)
    paste_gradient(img, head, int(S * 0.2), (255, 255, 255), (196, 214, 244))

    # Visor.
    visor = B(0.22, 0.39, 0.78, 0.76)
    paste_gradient(img, visor, int(S * 0.13), (20, 36, 86), (6, 14, 42))

    # Two big glowing eyes.
    for cx in (0.37, 0.63):
        glow(img, (int(S * cx), int(S * 0.575)), int(S * 0.11), (60, 200, 255), 0.85, blur=int(S * 0.05))
        d.ellipse(B(cx - 0.075, 0.5, cx + 0.075, 0.65), fill=(126, 236, 255))
        d.ellipse(B(cx - 0.045, 0.52, cx + 0.005, 0.57), fill=(240, 253, 255))
    return img


def write_png(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print("wrote", os.path.normpath(path))


def write_web_icons(web_dir):
    """Favicon set + PWA icons. Skipped if the project has no web/ folder."""
    if not os.path.isdir(web_dir):
        return
    fav = favicon_master()
    write_png(fav, os.path.join(web_dir, "favicon.png"), 64)
    write_png(fav, os.path.join(web_dir, "favicon-32.png"), 32)
    ico = os.path.join(web_dir, "favicon.ico")
    fav.resize((256, 256), Image.LANCZOS).save(
        ico, format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)]
    )
    print("wrote", os.path.normpath(ico))

    # Full-bleed app icon (iOS rounds the corners itself) for home screens.
    full = background()
    draw_robot(full, scale=0.80, cy=int(S * 0.53))
    write_png(full, os.path.join(web_dir, "apple-touch-icon.png"), 180)
    write_png(full, os.path.join(web_dir, "icons", "Icon-192.png"), 192)
    write_png(full, os.path.join(web_dir, "icons", "Icon-512.png"), 512)

    # Maskable: the robot stays inside the ~80% safe zone so no launcher mask
    # can clip it.
    mask_icon = background()
    draw_robot(mask_icon, scale=0.62, cy=int(S * 0.535))
    write_png(mask_icon, os.path.join(web_dir, "icons", "Icon-maskable-192.png"), 192)
    write_png(mask_icon, os.path.join(web_dir, "icons", "Icon-maskable-512.png"), 512)


# --------------------------------------------------------------------------
# Android extras: themed (monochrome) icon + native launch logo
# --------------------------------------------------------------------------
def draw_robot_mono(img, scale=0.56, cx=S // 2, cy=int(S * 0.535)):
    """One-colour robot silhouette for Android 13+ themed icons.

    The system tints every opaque pixel with the user's wallpaper colour, so the
    shapes are plain white and the visor is a transparent cut-out with the eyes
    left solid, which keeps the robot's face readable in any tint.
    """
    k = scale * S / 1000.0
    white = (255, 255, 255, 255)
    clear = (0, 0, 0, 0)

    def P(x, y):
        return (int(cx + x * k), int(cy + y * k))

    def B(x0, y0, x1, y1):
        a, b = P(x0, y0), P(x1, y1)
        return (a[0], a[1], b[0], b[1])

    d = ImageDraw.Draw(img)
    d.rounded_rectangle(B(-12, -420, 12, -300), radius=int(12 * k), fill=white)   # antenna
    d.ellipse(B(-38, -478, 38, -402), fill=white)                                  # antenna ball
    d.rounded_rectangle(B(-250, 262, 250, 470), radius=int(120 * k), fill=white)  # body
    d.rounded_rectangle(B(-70, 335, 70, 375), radius=int(20 * k), fill=clear)      # chest slot
    for sx in (-1, 1):                                                              # ear pods
        x0, x1 = sorted((sx * 322, sx * 376))
        d.rounded_rectangle(B(x0, -70, x1, 90), radius=int(38 * k), fill=white)
    d.rounded_rectangle(B(-340, -300, 340, 250), radius=int(150 * k), fill=white)  # head
    d.rounded_rectangle(B(-270, -190, 270, 140), radius=int(112 * k), fill=clear)  # visor hole
    for ex in (-110, 110):                                                          # eyes
        d.rounded_rectangle(B(ex - 46, -78, ex + 46, 18), radius=int(46 * k), fill=white)
    d.arc(B(-70, 38, 70, 104), start=20, end=160, fill=white, width=max(3, int(16 * k)))


def write_android_extras(res_dir):
    """Native launch-screen logo (transparent robot) for the Android splash."""
    if not os.path.isdir(res_dir):
        return
    logo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # Android 12+ draws this inside a 192dp circle of a 288dp canvas, so the
    # robot is kept to roughly the central half.
    draw_robot(logo, scale=0.50, cy=int(S * 0.52))
    path = os.path.join(res_dir, "drawable-nodpi", "launch_logo.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    logo.resize((768, 768), Image.LANCZOS).save(path, optimize=True)
    print("wrote", os.path.normpath(path))


def finish(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.resize((1024, 1024), Image.LANCZOS).save(path, optimize=True)
    print("wrote", os.path.normpath(path))


def main():
    # Full-bleed icon (the OS rounds the corners itself).
    full = background()
    draw_robot(full, scale=0.80, cy=int(S * 0.53))
    finish(full, "app_icon.png")

    # Android adaptive foreground: transparent, robot kept inside the ~66% safe
    # zone so no launcher mask can crop it.
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_robot(fg, scale=0.56, cy=int(S * 0.535))
    finish(fg, "app_icon_foreground.png")
    finish(background(), "app_icon_background.png")

    mono = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_robot_mono(mono)
    finish(mono, "app_icon_monochrome.png")

    write_web_icons(os.path.join(ROOT, "web"))
    write_android_extras(os.path.join(ROOT, "android", "app", "src", "main", "res"))


if __name__ == "__main__":
    main()
