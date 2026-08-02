from pathlib import Path

from PIL import Image

src_path = Path(__file__).resolve().parents[1] / 'assets' / 'branding' / 'logo.png'
root = Path(__file__).resolve().parents[1]
img = Image.open(src_path).convert('RGBA')


def fit_square(source: Image.Image, size: int) -> Image.Image:
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 255))
    thumb = source.copy()
    thumb.thumbnail((size, size), Image.Resampling.LANCZOS)
    x = (size - thumb.width) // 2
    y = (size - thumb.height) // 2
    canvas.paste(thumb, (x, y), thumb)
    return canvas


android = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
res = root / 'android' / 'app' / 'src' / 'main' / 'res'
for folder, size in android.items():
    out = res / folder / 'ic_launcher.png'
    fit_square(img, size).save(out, 'PNG')
    print('android', out, size)

ico_sizes = [16, 32, 48, 64, 128, 256]
ico_imgs = [fit_square(img, size) for size in ico_sizes]
ico_path = root / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
ico_imgs[0].save(
    ico_path,
    format='ICO',
    sizes=[(s, s) for s in ico_sizes],
    append_images=ico_imgs[1:],
)
print('windows', ico_path)

fav = Path(__file__).resolve().parents[2] / 'maran-billing-backend' / 'public' / 'favicon.ico'
if fav.parent.exists():
    fav_imgs = [fit_square(img, 16), fit_square(img, 32)]
    fav_imgs[0].save(fav, format='ICO', sizes=[(16, 16), (32, 32)], append_images=fav_imgs[1:])
    print('backend', fav)

web = root / 'web'
if web.exists():
    for name, size in [
        ('favicon.png', 32),
        ('icons/Icon-192.png', 192),
        ('icons/Icon-512.png', 512),
        ('icons/Icon-maskable-192.png', 192),
        ('icons/Icon-maskable-512.png', 512),
    ]:
        out = web / name
        out.parent.mkdir(parents=True, exist_ok=True)
        fit_square(img, size).save(out, 'PNG')
        print('web', out)

print('done')
