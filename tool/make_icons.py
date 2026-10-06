"""Генерирует иконки PWA: гранёный (low-poly) крест из двух половин —
светлой травяной зелёной и тёмной насыщенной синей, в стиле иконки calorie_cam.

    python3 tool/make_icons.py [preview.png]
"""
import os
import sys

from PIL import Image, ImageDraw

SS = 4  # суперсэмплинг

# Левая половина креста в поле 512×512; правая — зеркальная.
# T/BT — верх и низ шва, M1..M3 — точки на шве, I/J/K/L — внутренние точки граней.
P = {
    'T': (256, 62), 'A': (178, 62), 'B': (178, 178), 'C': (62, 178), 'D': (62, 334),
    'E': (178, 334), 'F': (178, 450), 'BT': (256, 450),
    'M1': (256, 150), 'M2': (256, 256), 'M3': (256, 364),
    'I': (212, 116), 'J': (208, 262), 'K': (118, 236), 'L': (214, 404),
}
FACETS = [
    ('T', 'A', 'I'), ('A', 'B', 'I'), ('I', 'B', 'M1'), ('I', 'M1', 'T'),          # верхний луч
    ('B', 'M2', 'M1'), ('B', 'J', 'M2'), ('B', 'E', 'J'), ('J', 'E', 'M3'), ('J', 'M3', 'M2'),  # центр
    ('C', 'B', 'K'), ('K', 'B', 'E'), ('K', 'E', 'D'), ('C', 'K', 'D'),            # боковой луч
    ('E', 'L', 'M3'), ('E', 'F', 'L'), ('F', 'BT', 'L'), ('L', 'BT', 'M3'),        # нижний луч
]
OUTLINE = ['T', 'A', 'B', 'C', 'D', 'E', 'F', 'BT']

# Каждая половина переливается от тёмного к светлому тону; свет — сверху слева.
HALVES = [
    {'mirror': False, 'dark': (62, 127, 44), 'light': (178, 222, 132)},  # травяной зелёный
    {'mirror': True, 'dark': (9, 34, 120), 'light': (47, 107, 234)},     # насыщенный синий
]
JITTER = [0.08, -0.06, 0.1, -0.04, 0.05, -0.08, 0.06, -0.05, 0.09,
          -0.07, 0.04, -0.09, 0.07, -0.03, 0.02, -0.06, 0.05]

BG_FROM, BG_TO = (241, 248, 233), (227, 236, 255)


def mix(a, b, t):
    return tuple(round(v + (b[i] - v) * t) for i, v in enumerate(a))


def background(size):
    small = Image.new('RGB', (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            px[x, y] = mix(BG_FROM, BG_TO, (x + y) / 126)
    return small.resize((size, size), Image.BICUBIC).convert('RGBA')


def cross(size, scale):
    """Крест на прозрачном слое size×size; scale — доля поля под крест."""
    S = size * SS
    k = S / 512 * scale
    off = (S - 512 * k) / 2

    def tr(p):
        return (off + p[0] * k, off + p[1] * k)

    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lines = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for half in HALVES:
        def pt(key, h=half):
            x, y = P[key]
            return (512 - x, y) if h['mirror'] else (x, y)
        for i, f in enumerate(FACETS):
            pts = [pt(key) for key in f]
            cx = sum(p[0] for p in pts) / 3
            cy = sum(p[1] for p in pts) / 3
            t = min(1, max(0, 1.25 - (cx + cy) / 620 + JITTER[i] * 1.6))
            poly = [tr(p) for p in pts]
            d.polygon(poly, fill=mix(half['dark'], half['light'], t) + (255,))
            ld.line(poly + [poly[0]], fill=(255, 255, 255, 140), width=max(1, round(3 * k)), joint='curve')
    img.alpha_composite(lines)

    # шов и тёмный контур
    edge = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    seam = [tr(P[key]) for key in ('T', 'M1', 'M2', 'M3', 'BT')]
    ed.line(seam, fill=(255, 255, 255, 230), width=max(1, round(6 * k)), joint='curve')
    left = [P[key] for key in OUTLINE]
    outline = left + [(512 - x, y) for x, y in reversed(left[1:-1])]
    poly = [tr(p) for p in outline]
    ed.line(poly + [poly[0]], fill=(10, 40, 45, 180), width=max(1, round(7 * k)), joint='curve')
    img.alpha_composite(edge)
    return img.resize((size, size), Image.LANCZOS)


def icon(size, scale, bg=True):
    base = background(size) if bg else Image.new('RGBA', (size, size), (0, 0, 0, 0))
    base.alpha_composite(cross(size, scale))
    return base


here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..')
outputs = [
    ('web/icons/Icon-192.png', 192, 0.86, True),
    ('web/icons/Icon-512.png', 512, 0.86, True),
    # maskable обрезается системой — крест внутри безопасной зоны
    ('web/icons/Icon-maskable-192.png', 192, 0.66, True),
    ('web/icons/Icon-maskable-512.png', 512, 0.66, True),
    ('web/icons/apple-touch-icon.png', 180, 0.8, True),
    ('web/favicon.png', 64, 1.0, False),
    ('web/icons/logo.png', 256, 1.0, False),   # заставка загрузки
    ('assets/logo.png', 256, 1.0, False),      # логотип в приложении
]
for path, size, scale, bg in outputs:
    img = icon(size, scale, bg)
    (img.convert('RGB') if bg else img).save(os.path.join(root, path))
if len(sys.argv) > 1:
    icon(512, 0.86).convert('RGB').save(sys.argv[1])
print('ok')
