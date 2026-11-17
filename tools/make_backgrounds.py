"""Generates the chapter backgrounds (assets/backgrounds/chN.jpg).

Each chapter has its own mood, kept dark and soft so the four ball colours
always stand out (the board also dims the image when drawing it):
  1 Studio  - plum, soft lilac light, loose ink curves
  2 Garden  - deep green-teal, leaf shapes, fireflies
  3 Lab     - navy, graph paper, glass bubbles

python3 tools/make_backgrounds.py
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1280, 720
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "backgrounds")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def gradient(top, bottom):
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    img = hexc(top)[None, None, :] * (1 - t) + hexc(bottom)[None, None, :] * t
    return np.repeat(img, W, axis=1)


def glow(img, cx, cy, r, color, strength):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
    k = np.clip(1 - d, 0, 1) ** 2 * strength
    return img * (1 - k[..., None]) + hexc(color)[None, None, :] * k[..., None]


def overlay(img, layer, alpha):
    """Blend an RGBA PIL layer (drawn in white/colour) onto img."""
    a = np.asarray(layer, dtype=np.float32)
    al = a[..., 3:4] / 255.0 * alpha
    return img * (1 - al) + a[..., :3] * al


def grain(img, amount, seed):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, amount, (H, W, 1)).astype(np.float32)
    return img + n


def vignette(img, strength=0.35):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2) / math.sqrt(2)
    return img * (1 - strength * d[..., None] ** 2)


def save(img, name):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    path = os.path.join(OUT, name)
    im.save(path, quality=86, optimize=True, progressive=False)
    print(name, os.path.getsize(path) // 1024, "KB")


def studio():
    random.seed(1)
    img = gradient("#33284a", "#1b1626")
    img = glow(img, 300, 160, 520, "#6b4f99", 0.35)
    img = glow(img, 1050, 620, 480, "#4a3a72", 0.30)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Loose ink curves, like practice strokes on paper.
    for i in range(7):
        y0 = 80 + i * 95 + random.uniform(-20, 20)
        amp = random.uniform(25, 60)
        ph = random.uniform(0, math.tau)
        pts = [(x, y0 + math.sin(x / 210 + ph) * amp) for x in range(-20, W + 40, 16)]
        d.line(pts, fill=(222, 205, 255, 255), width=3, joint="curve")
    layer = layer.filter(ImageFilter.GaussianBlur(1.2))
    img = overlay(img, layer, 0.10)
    img = grain(img, 3.0, 1)
    return vignette(img, 0.30)


def garden():
    random.seed(2)
    img = gradient("#173a36", "#0f1f1d")
    img = glow(img, 980, 140, 560, "#2f6b5a", 0.35)
    img = glow(img, 220, 650, 500, "#244f45", 0.30)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Soft plants growing from the bottom edge and hanging from the top corners.
    def leaf(bx, by, length, width, angle):
        """Pointed leaf from its base (bx, by), pointing along angle."""
        pts = []
        for k in range(0, 33):
            t = k / 32
            pts.append((t * length, math.sin(t * math.pi) ** 0.8 * width * (1 - 0.3 * t)))
        pts += [(x, -y) for x, y in reversed(pts)]
        ca, sa = math.cos(angle), math.sin(angle)
        return [(bx + x * ca - y * sa, by + x * sa + y * ca) for x, y in pts]
    col = (120, 200, 160, 255)
    for i in range(9):
        bx = 60 + i * 145 + random.uniform(-40, 40)
        for j in range(random.randint(2, 4)):
            ang = -math.pi / 2 + random.uniform(-0.75, 0.75)
            d.polygon(leaf(bx, H + 10, random.uniform(150, 260), random.uniform(22, 36), ang), fill=col)
    for bx, a0 in [(30, 0.9), (110, 1.3), (W - 30, 2.25), (W - 110, 1.85)]:
        d.polygon(leaf(bx, -10, random.uniform(170, 230), 30, a0), fill=col)
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    img = overlay(img, layer, 0.14)
    # Fireflies.
    fl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fl)
    for i in range(46):
        x, y, r = random.uniform(0, W), random.uniform(0, H * 0.8), random.uniform(1.5, 3.2)
        fd.ellipse((x - r * 4, y - r * 4, x + r * 4, y + r * 4), fill=(230, 245, 170, 60))
        fd.ellipse((x - r, y - r, x + r, y + r), fill=(240, 250, 190, 255))
    fl = fl.filter(ImageFilter.GaussianBlur(1.5))
    img = overlay(img, fl, 0.30)
    img = grain(img, 3.0, 2)
    return vignette(img, 0.32)


def lab():
    random.seed(3)
    img = gradient("#1a2a45", "#0f1626")
    img = glow(img, 640, 300, 640, "#2c4f80", 0.30)
    img = glow(img, 1120, 120, 360, "#2a6c8a", 0.22)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Graph paper: fine and bold lines.
    for x in range(0, W, 32):
        d.line([(x, 0), (x, H)], fill=(170, 210, 255, 255 if x % 160 == 0 else 110), width=1)
    for y in range(0, H, 32):
        d.line([(0, y), (W, y)], fill=(170, 210, 255, 255 if y % 160 == 0 else 110), width=1)
    img = overlay(img, layer, 0.07)
    # Glass bubbles rising.
    bl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bl)
    for i in range(30):
        x, y = random.uniform(0, W), random.uniform(0, H)
        r = random.uniform(6, 26)
        bd.ellipse((x - r, y - r, x + r, y + r), outline=(190, 230, 255, 255), width=2)
        bd.ellipse((x - r * 0.5, y - r * 0.6, x - r * 0.2, y - r * 0.3), fill=(220, 240, 255, 255))
    bl = bl.filter(ImageFilter.GaussianBlur(0.8))
    img = overlay(img, bl, 0.16)
    img = grain(img, 2.5, 3)
    return vignette(img, 0.30)


def volcano():
    random.seed(4)
    img = gradient("#2a1418", "#160c10")
    img = glow(img, 480, 760, 620, "#ff5a2a", 0.42)     # heat from below
    img = glow(img, 1050, 700, 420, "#ff8a3a", 0.25)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Mountain silhouettes with a crater.
    d.polygon([(0, H), (0, 520), (160, 380), (300, 470), (470, 300), (530, 320), (590, 295), (760, 480),
               (930, 390), (1100, 500), (1280, 430), (1280, H)], fill=(12, 6, 8, 255))
    layer = layer.filter(ImageFilter.GaussianBlur(2))
    img = overlay(img, layer, 0.55)
    em = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ed = ImageDraw.Draw(em)
    for i in range(70):   # embers
        x, y, r = random.uniform(0, W), random.uniform(60, H), random.uniform(1.0, 2.6)
        ed.ellipse((x - r * 3, y - r * 3, x + r * 3, y + r * 3), fill=(255, 150, 60, 50))
        ed.ellipse((x - r, y - r, x + r, y + r), fill=(255, 200, 120, 255))
    em = em.filter(ImageFilter.GaussianBlur(1.2))
    img = overlay(img, em, 0.35)
    img = grain(img, 3.0, 4)
    return vignette(img, 0.3)


def space():
    random.seed(5)
    img = gradient("#141433", "#07070f")
    img = glow(img, 300, 200, 520, "#4a2f8a", 0.32)      # nebula
    img = glow(img, 980, 480, 460, "#1f4f8a", 0.28)
    st = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    for i in range(260):
        x, y = random.uniform(0, W), random.uniform(0, H)
        r = random.choice([0.6, 0.8, 1.0, 1.0, 1.4, 2.0])
        sd.ellipse((x - r, y - r, x + r, y + r), fill=(235, 240, 255, random.randint(120, 255)))
    img = overlay(img, st, 0.6)
    pl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pl)
    pd.ellipse((980, 60, 1160, 240), fill=(120, 110, 190, 255))          # planet
    pd.ellipse((1010, 50, 1200, 240), fill=(0, 0, 0, 0))
    pd.ellipse((930, 138, 1210, 166), outline=(190, 180, 240, 255), width=3)   # ring
    pl = pl.filter(ImageFilter.GaussianBlur(1.5))
    img = overlay(img, pl, 0.3)
    img = grain(img, 2.5, 5)
    return vignette(img, 0.3)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save(studio(), "ch1.jpg")
    save(garden(), "ch2.jpg")
    save(lab(), "ch3.jpg")
    save(volcano(), "ch4.jpg")
    save(space(), "ch5.jpg")
