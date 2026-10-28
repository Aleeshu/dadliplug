"""Builds the Dadliplug pin mark (2026-10-28 redesign) from the palm logo.

The redesign's mark is a yellow map pin with a navy palm inside. The palm is
cut from docs/design/brand/palm_logo_source.png (the blue-and-gold palm over
"DadliPlug"), so the mark and the source logo can never drift apart.

Usage: python scripts/make_pin_logo.py

Writes:
  app/assets/images/logo_pin.png         the pin mark, transparent, 512 px
  app/assets/images/app_icon_source.png  1024 px navy square with the pin,
                                         for scripts/make_brand_assets.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "docs", "design", "brand", "palm_logo_source.png")
OUT = os.path.join(ROOT, "app", "assets", "images")

YELLOW = (255, 199, 44, 255)
NAVY = (10, 31, 68, 255)
# Where the palm sits in the source (found by its saturated pixels).
PALM_BOX = (446, 362, 830, 770)


def palm_mask() -> Image.Image:
    """The palm as a white-on-black mask: every saturated pixel."""
    src = Image.open(SOURCE).convert("RGB").crop(PALM_BOX)
    mask = Image.new("L", src.size, 0)
    sp, mp = src.load(), mask.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b = sp[x, y]
            mx, mn = max(r, g, b), min(r, g, b)
            if mx > 70 and (mx - mn) > 60:
                mp[x, y] = 255
    return mask.filter(ImageFilter.GaussianBlur(0.8))


def pin_mark(size: int = 512) -> Image.Image:
    """A yellow teardrop pin with the navy palm in its head."""
    s = size * 4  # draw large, then shrink: smooth edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(s * 0.36)
    cx, cy = s // 2, int(s * 0.40)
    tip = (cx, int(s * 0.97))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=YELLOW)
    d.polygon(
        [(cx - int(r * 0.80), cy + int(r * 0.60)), tip, (cx + int(r * 0.80), cy + int(r * 0.60))],
        fill=YELLOW,
    )
    # The palm, navy, fitted inside the head.
    mask = palm_mask()
    box = int(r * 1.45)
    scale = box / max(mask.size)
    mask = mask.resize((int(mask.width * scale), int(mask.height * scale)), Image.Resampling.LANCZOS)
    navy = Image.new("RGBA", mask.size, NAVY)
    img.paste(navy, (cx - mask.width // 2, cy - mask.height // 2 + int(r * 0.04)), mask)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def app_icon(size: int = 1024) -> Image.Image:
    """Navy square with the pin, for the launcher icon."""
    icon = Image.new("RGBA", (size, size), NAVY)
    mark = pin_mark(int(size * 0.74))
    icon.alpha_composite(mark, ((size - mark.width) // 2, int(size * 0.12)))
    return icon


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    pin_mark().save(os.path.join(OUT, "logo_pin.png"))
    app_icon().save(os.path.join(OUT, "app_icon_source.png"))
    # Sanity: the palm is really in there (navy pixels inside the yellow).
    mark = pin_mark(256)
    navy_pixels = sum(
        1 for p in mark.get_flattened_data() if p[3] > 200 and p[2] < 120 and p[0] < 60
    )
    print(f"logo_pin.png written; palm pixels at 256px: {navy_pixels}")


if __name__ == "__main__":
    main()
