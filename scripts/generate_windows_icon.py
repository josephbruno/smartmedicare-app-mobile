"""Regenerate windows/runner/resources/app_icon.ico from assets/branding/logo.png.

Usage:
  python scripts/generate_windows_icon.py
  python scripts/generate_windows_icon.py --preview
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "branding" / "logo.png"
OUT_ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
PREVIEW_DIR = ROOT / "windows" / "runner" / "resources" / "_icon_previews"

# Windows shell / installer use several of these; keep a full set.
SIZES = [16, 24, 32, 40, 48, 64, 128, 256]


def content_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of non-near-black pixels."""
    pixels = img.load()
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 10 and (r + g + b) > 40:
                mp[x, y] = 255
    bbox = mask.getbbox()
    if not bbox:
        raise RuntimeError("No visible logo content found in source image")
    return bbox


def boost_icon_contrast(img: Image.Image) -> Image.Image:
    """Lift grey heart/vet tones so they stay readable on black at small sizes."""
    out = img.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 10:
                continue
            # Skip near-black background.
            if r + g + b < 45:
                continue
            # Blue animal marks: keep hue, nudge brightness a bit.
            if b > r + 25 and b > g + 10:
                px[x, y] = (
                    min(255, int(r * 1.05 + 8)),
                    min(255, int(g * 1.08 + 12)),
                    min(255, int(b * 1.05 + 10)),
                    a,
                )
                continue
            # Grey heart / veterinarian: lighten for taskbar contrast.
            lift = 1.35
            px[x, y] = (
                min(255, int(r * lift + 28)),
                min(255, int(g * lift + 28)),
                min(255, int(b * lift + 28)),
                a,
            )
    return out


def square_on_black(
    cropped: Image.Image,
    *,
    margin_ratio: float,
    contrast: float,
    sharpness: float,
) -> Image.Image:
    side = max(cropped.size)
    margin = int(side * margin_ratio)
    canvas_side = side + margin * 2
    base = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 255))
    ox = (canvas_side - cropped.size[0]) // 2
    oy = (canvas_side - cropped.size[1]) // 2
    base.paste(cropped, (ox, oy), cropped)
    base = ImageEnhance.Contrast(base).enhance(contrast)
    base = ImageEnhance.Sharpness(base).enhance(sharpness)
    return base


def make_size(cropped: Image.Image, master: Image.Image, n: int) -> Image.Image:
    # Tiny sizes: tighter crop + extra sharpening so the mark stays readable.
    if n <= 32:
        base = square_on_black(
            cropped, margin_ratio=0.02, contrast=1.15, sharpness=1.35
        )
        return base.resize((n, n), Image.Resampling.LANCZOS)
    return master.resize((n, n), Image.Resampling.LANCZOS)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Also write PNG previews under windows/runner/resources/_icon_previews/",
    )
    args = parser.parse_args()

    img = Image.open(SRC).convert("RGBA")
    print(f"source: {img.size}")

    bbox = content_bbox(img)
    print(f"content bbox: {bbox}")

    cw, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = int(max(cw, ch) * 0.06)
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(img.size[0], bbox[2] + pad)
    bottom = min(img.size[1], bbox[3] + pad)
    cropped = boost_icon_contrast(img.crop((left, top, right, bottom)))
    print(f"cropped: {cropped.size}")

    master_base = square_on_black(
        cropped, margin_ratio=0.06, contrast=1.1, sharpness=1.2
    )
    master = master_base.resize((512, 512), Image.Resampling.LANCZOS)
    if args.preview:
        PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        master.save(PREVIEW_DIR / "master_512.png")

    icons: list[Image.Image] = []
    for n in SIZES:
        im = make_size(cropped, master, n).convert("RGBA")
        if args.preview:
            im.save(PREVIEW_DIR / f"icon_{n}.png")
        icons.append(im)
        print(f"generated {n}x{n}")

    # Largest first for a cleaner ICO directory.
    largest = icons[-1]
    largest.save(
        OUT_ICO,
        format="ICO",
        sizes=[(n, n) for n in SIZES],
        append_images=icons[:-1],
    )

    verify = Image.open(OUT_ICO)
    print(f"wrote {OUT_ICO} ({OUT_ICO.stat().st_size} bytes)")
    print(f"ico sizes: {verify.info.get('sizes')}")


if __name__ == "__main__":
    main()
