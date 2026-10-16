"""Generates Dadliplug app icons and in-app logo assets from the source icon.

Usage: python scripts/make_brand_assets.py <path-to-square-app-icon>

The source icon has rounded white corners baked in. Launchers apply their own
mask, so the corners are cropped off to give a full-bleed square first.
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "app")

# The baked-in rounded corners end ~6% of the way in (80px on a 1254px
# source, 55px on 1024px). Cropping 7.2% clears them with a margin.
CORNER_CROP_RATIO = 0.072

LANCZOS = Image.Resampling.LANCZOS


def full_bleed(src: Image.Image) -> Image.Image:
    w, h = src.size
    m = round(w * CORNER_CROP_RATIO)
    return src.crop((m, m, w - m, h - m))


def rounded(img: Image.Image, radius_ratio: float = 0.22) -> Image.Image:
    """The icon with transparent rounded corners, for use inside the app."""
    out = img.convert("RGBA")
    width, height = out.size
    mask = Image.new("L", out.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width, height), int(width * radius_ratio), fill=255
    )
    out.putalpha(mask)
    return out


def square(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), LANCZOS)


def main(path: str) -> None:
    icon = full_bleed(Image.open(path).convert("RGB"))

    # Android legacy launcher icons, plus the adaptive foreground: a 108dp
    # canvas with the artwork in the central 72dp so the mask shows all of it.
    res = os.path.join(APP, "android", "app", "src", "main", "res")
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        square(icon, size).save(os.path.join(res, folder, "ic_launcher.png"))
        canvas_size = size * 108 // 48
        inner = canvas_size * 72 // 108
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        offset = (canvas_size - inner) // 2
        canvas.paste(square(icon, inner), (offset, offset))
        canvas.save(os.path.join(res, folder, "ic_launcher_foreground.png"))

    # iOS: square, no alpha; iOS applies the mask. Sizes come from the file
    # names Flutter generated, e.g. Icon-App-60x60@3x.png.
    ios = os.path.join(APP, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    for name in os.listdir(ios):
        if not name.endswith(".png"):
            continue
        dims = name.removeprefix("Icon-App-").removesuffix(".png")
        base, scale = dims.split("@")
        px = round(float(base.split("x")[0]) * int(scale.rstrip("x")))
        square(icon, px).save(os.path.join(ios, name))

    # In-app logo mark, rounded like an app icon.
    assets = os.path.join(APP, "assets", "images")
    rounded(square(icon, 384)).save(os.path.join(assets, "logo_mark.png"))
    print("ok")


if __name__ == "__main__":
    main(sys.argv[1])
