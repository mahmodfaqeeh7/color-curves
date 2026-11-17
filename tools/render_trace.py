"""Dev tool: render a trace JSON (from trace_level.gd) to a PNG for inspection."""
import json, sys
from PIL import Image, ImageDraw
COL = {"blue": (105,174,255), "red": (255,118,126), "green": (126,214,163), "yellow": (255,211,121), "orange": (255,164,92), "purple": (216,140,255)}
TYPECOL = {"poison": (155,229,100), "lava": (255,106,61), "fan": (200,230,255), "conveyor": (90,90,110), "glass": (190,240,255),
           "door": (255,182,72), "portal": (143,184,255), "blackhole": (123,77,255), "magnet": (255,255,255), "zone": (111,195,214), "booster": (185,160,229)}
S = 2
d = json.load(open(sys.argv[1]))
lv = d["level"]; W = int(lv["board"]["width"]); H = int(lv["board"]["height"])
im = Image.new("RGB", (W*S, H*S), (33,28,44)); g = ImageDraw.Draw(im)
for x in range(0, W, 40):
    g.line([(x*S,0),(x*S,H*S)], fill=(45,40,58))
for y in range(0, H, 40):
    g.line([(0,y*S),(W*S,y*S)], fill=(45,40,58))
for z in lv["drawingRules"].get("forbiddenZones", []):
    if "rect" in z:
        x,y,w,h = z["rect"]; g.rectangle([x*S,y*S,(x+w)*S,(y+h)*S], outline=(120,60,60))
for p in d["polys"]:
    c = COL.get(p["color"], (121,116,134))
    pts = [(x*S,y*S) for x,y in p["points"]]
    if p["type"] in ("poison", "lava", "fan", "zone", "booster", "door", "glass", "blackhole", "portal", "magnet"):
        g.line(pts + [pts[0]], fill=TYPECOL[p["type"]], width=4 if p["type"] in ("lava", "poison") else 2)
        g.text(pts[0], p["type"][:4], fill=TYPECOL[p["type"]])
    else:
        g.polygon(pts, fill=TYPECOL.get(p["type"], c) if p["type"] == "conveyor" else c)
        if p["type"] == "mixer":
            g.line(pts + [pts[0]], fill=(255,255,255), width=2)
for o in lv["obstacles"]:
    if o["type"] == "portal":
        x, y = o["to"]; r = o["radius"]
        g.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S], outline=TYPECOL["portal"], width=3)
    if o["type"] in ("blackhole", "magnet"):
        x, y = o["center"]; r = o["reach"]
        g.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S], outline=(80,70,110), width=1)
for c in lv["collectors"]:
    x,y = c["center"]; r = c["innerRadius"]
    g.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S], outline=COL.get(c["targetColor"], (255,255,255)), width=3)
for l in lv["launchers"]:
    x,y = l["pos"]; vx,vy = l["velocity"]
    g.ellipse([(x-8)*S,(y-8)*S,(x+8)*S,(y+8)*S], fill=(200,200,200))
    g.line([(x*S,y*S),((x+vx*0.1)*S,(y+vy*0.1)*S)], fill=(255,255,255), width=3)
for r in d["rails"]:
    g.line([(x*S,y*S) for x,y in r], fill=(244,239,230), width=6, joint="curve")
for path in d["paths"]:
    for i in range(1, len(path)):
        a,b = path[i-1], path[i]
        g.line([(a[0]*S,a[1]*S),(b[0]*S,b[1]*S)], fill=COL.get(b[2], (200,200,200)), width=1)
g.text((6,6), json.dumps(d["result"]["collectors"]) + " " + d["result"]["reason"] + (" WON" if d["result"]["won"] else ""), fill=(255,255,255))
im.save(sys.argv[2])
