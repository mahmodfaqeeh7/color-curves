"""Authoring source for the campaign. Generates levels/*.json and the stored
verification solutions in levels/solutions/*.json. Re-run after edits, then run
tools/verify_levels.gd to prove every level is solvable within its budgets.

python3 tools/build_levels.py
"""
import json, math, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "levels")
LEVELS = []


def rect(id, cx, cy, w, h, rot=0, color=None):
    o = {"id": id, "type": "painter" if color else "neutral", "shape": "rect",
         "center": [cx, cy], "size": [w, h], "rotation": rot}
    if color: o["color"] = color
    return o


def reg(id, cx, cy, r, sides, rot=0, color=None):
    o = {"id": id, "type": "painter" if color else "neutral", "shape": "regular",
         "center": [cx, cy], "radius": r, "sides": sides, "rotation": rot}
    if color: o["color"] = color
    return o


def poly(id, pts, color=None):
    o = {"id": id, "type": "painter" if color else "neutral", "shape": "poly", "points": pts}
    if color: o["color"] = color
    return o


def launcher(id, pos, vel, colors, count, interval=0.55, delay=0.0):
    return {"id": id, "pos": pos, "velocity": vel, "ballRadius": 6, "colors": colors,
            "count": count, "interval": interval, "delay": delay}


def collector(id, center, color, r=24):
    return {"id": id, "center": center, "innerRadius": r, "targetColor": color, "requiredCount": 5}


def curve(*ctrl, n=24):
    """Polyline sampled from a Catmull-Rom spline through the control points."""
    pts = [list(map(float, p)) for p in ctrl]
    if len(pts) == 2:
        (x0, y0), (x1, y1) = pts
        k = max(2, int(math.dist(pts[0], pts[1]) / 8))
        return [[round(x0 + (x1 - x0) * i / k, 2), round(y0 + (y1 - y0) * i / k, 2)] for i in range(k + 1)]
    ext = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        seg = max(3, int(math.dist(p1, p2) / 8))
        for j in range(seg):
            t = j / seg
            t2, t3 = t * t, t * t * t
            out.append([round(0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3), 2) for c in (0, 1)])
    out.append([round(pts[-1][0], 2), round(pts[-1][1], 2)])
    return out


CTRL_PATH = os.path.join(os.path.dirname(__file__), "solution_ctrl.json")
CTRL = json.load(open(CTRL_PATH)) if os.path.exists(CTRL_PATH) else {}


def level(num, title, difficulty, launchers, obstacles, collectors, max_strokes, par,
          solution, tip=None, hint=None, ink=None, zones=None, lifetime=20.0, duration=45.0):
    lid = "c1_%02d" % num
    ctrl = CTRL.get(lid, solution)
    CTRL.setdefault(lid, solution)
    solution = [curve(*c) for c in ctrl]
    data = {
        "schemaVersion": 1, "levelId": lid, "revision": 1, "rulesVersion": 1,
        "title": title, "difficulty": difficulty, "chapter": 1, "number": num,
        "board": {"width": 640, "height": 360}, "gravity": [0, 420],
        "material": {"obstacle": {"restitution": 0.5, "friction": 0.6},
                     "rail": {"restitution": 0.25, "friction": 0.35}},
        "runDurationLimit": duration, "ballLifetime": lifetime,
        "launchers": launchers, "obstacles": obstacles, "collectors": collectors,
        "drawingRules": {"maxStrokes": max_strokes, "maxInkLength": ink, "minStrokeLength": 12,
                         "railWidth": 6, "forbiddenZones": zones or []},
        "scoring": {"parStrokes": par},
        "tip": tip or {}, "hint": hint or {},
    }
    LEVELS.append((lid, data, {"levelId": lid, "revision": 1, "rulesVersion": 1, "strokes": solution}))


# ---------------------------------------------------------------- Level 1
level(1, {"en": "First Guide", "ar": "أول خط"}, "intro",
      [launcher("L1", [60, 70], [170, -60], ["blue"], 8)],
      [],
      [collector("C1", [500, 300], "blue", 30)],
      6, 1,
      [[[150, 165], [260, 195], [355, 212]]],
      tip={"en": "Drag to draw a rail under the balls, then press Launch.", "ar": "اسحب لترسم خطًا تحت الكرات، ثم اضغط إطلاق."},
      hint={"en": "A gentle downhill ramp toward the blue circle is enough.", "ar": "منحدر خفيف باتجاه الدائرة الزرقاء يكفي."})

# ---------------------------------------------------------------- Level 2
level(2, {"en": "Over the Block", "ar": "فوق المكعب"}, "intro",
      [launcher("L1", [60, 80], [150, -40], ["blue"], 8)],
      [rect("N1", 330, 270, 90, 90)],
      [collector("C1", [520, 310], "blue", 30)],
      5, 1,
      [[[140, 170], [260, 190], [360, 202], [400, 210]]],
      tip={"en": "Rails are neutral: they guide balls but never change their color.", "ar": "الخطوط محايدة: توجّه الكرات ولا تغيّر لونها."},
      hint={"en": "Curve your ramp over the grey block.", "ar": "اجعل المنحدر يمر فوق المكعب الرمادي."})

# ---------------------------------------------------------------- Level 3
level(3, {"en": "Touch the Red", "ar": "المس الأحمر"}, "intro",
      [launcher("L1", [60, 80], [150, -40], ["blue"], 8)],
      [rect("P1", 450, 200, 18, 150, color="red")],
      [collector("C1", [415, 318], "red", 30)],
      5, 1,
      [[[140, 170], [260, 200], [360, 220]]],
      tip={"en": "A ball takes the color of the last colored shape it touches.", "ar": "الكرة تأخذ لون آخر شكل ملوّن تلمسه."},
      hint={"en": "Send the balls into the red wall; they bounce back red.", "ar": "وجّه الكرات نحو الجدار الأحمر؛ سترتد حمراء."})

# ---------------------------------------------------------------- Level 4
level(4, {"en": "Red Stepping Stone", "ar": "حجر أحمر"}, "easy",
      [launcher("L1", [60, 70], [120, -80], ["blue"], 7)],
      [rect("P1", 260, 200, 70, 24, color="red"), rect("N1", 560, 230, 20, 260)],
      [collector("C1", [490, 320], "red", 30)],
      4, 1,
      [[[110, 150], [200, 170], [240, 180]]],
      tip={"en": "You may draw several rails before launching.", "ar": "يمكنك رسم أكثر من خط قبل الإطلاق."},
      hint={"en": "Let the balls roll across the red slab, then catch them with a second ramp.", "ar": "دع الكرات تتدحرج على اللوح الأحمر، ثم التقطها بمنحدر ثانٍ."})

# ---------------------------------------------------------------- Level 5
level(5, {"en": "Pentagon Angle", "ar": "زاوية المخمّس"}, "easy",
      [launcher("L1", [60, 70], [160, -40], ["blue"], 7)],
      [reg("P1", 330, 210, 38, 5, 0, color="green")],
      [collector("C1", [455, 315], "green", 30)],
      4, 1,
      [[[150, 160], [240, 175], [285, 180]]],
      tip={"en": "Shapes deflect balls by their angle. Color only decides the paint.", "ar": "الأشكال تحرف الكرات حسب زاويتها. اللون يحدد الطلاء فقط."},
      hint={"en": "Roll the balls onto the pentagon's upper face.", "ar": "دحرج الكرات على الوجه العلوي للمخمّس."})

# ---------------------------------------------------------------- Level 6
level(6, {"en": "Stay Red", "ar": "ابقَ أحمر"}, "easy",
      [launcher("L1", [60, 70], [120, -80], ["blue"], 7)],
      [rect("P1", 250, 195, 80, 22, color="red"), rect("P2", 380, 300, 70, 70, 0, color="blue")],
      [collector("C1", [540, 300], "red", 30)],
      4, 2,
      [[[110, 150], [180, 168], [205, 175]], [[310, 225], [400, 240], [450, 250]]],
      tip={"en": "Only the LAST color touched counts.", "ar": "اللون الأخير الذي تلمسه الكرة هو الذي يُحتسب."},
      hint={"en": "After the red slab, keep the balls away from the blue square.", "ar": "بعد اللوح الأحمر، أبعد الكرات عن المربع الأزرق."})

# ---------------------------------------------------------------- Level 7
level(7, {"en": "Grey Garden", "ar": "حديقة رمادية"}, "easy",
      [launcher("L1", [50, 60], [190, 0], ["blue"], 7)],
      [reg("N1", 250, 200, 34, 5, 0), rect("N2", 380, 140, 50, 50, 45), rect("N3", 420, 290, 60, 60, 20),
       rect("N4", 150, 300, 70, 30, -15)],
      [collector("C1", [570, 300], "blue", 30)],
      4, 1,
      [[[105, 95], [180, 120], [260, 150], [330, 190], [440, 225], [500, 240]]],
      tip={"en": "Grey shapes never change color.", "ar": "الأشكال الرمادية لا تغيّر اللون."},
      hint={"en": "One long ramp can thread between the grey shapes.", "ar": "منحدر واحد طويل يمكنه المرور بين الأشكال الرمادية."})

# ---------------------------------------------------------------- Level 8
level(8, {"en": "Jump to the Ceiling", "ar": "اقفز للسقف"}, "easy",
      [launcher("L1", [40, 60], [220, -40], ["blue"], 7)],
      [rect("P1", 480, 130, 100, 20, color="red"), rect("N1", 200, 330, 90, 60)],
      [collector("C1", [500, 300], "red", 30)],
      4, 1,
      [[[200, 150], [290, 250], [340, 285], [390, 270], [425, 220]]],
      tip={"en": "Curve a rail upward to throw balls into the air.", "ar": "اجعل الخط ينحني للأعلى لترمي الكرات في الهواء."},
      hint={"en": "Build a ski jump that hits the red ceiling.", "ar": "اصنع قفزة تزلج تضرب السقف الأحمر."})

# ---------------------------------------------------------------- Level 9
level(9, {"en": "Two Roads", "ar": "طريقان"}, "medium",
      [launcher("L1", [320, 40], [20, 0], ["blue"], 7)],
      [rect("P1", 470, 200, 60, 60, 0, color="red"), reg("P2", 170, 200, 34, 5, 0, color="green"),
       rect("N1", 320, 150, 40, 40, 45)],
      [collector("C1", [320, 310], "green", 30)],
      3, 2,
      [[[345, 80], [270, 120], [205, 150]], [[200, 240], [250, 270], [285, 285]]],
      tip={"en": "Two painters, one target. Pick the right road.", "ar": "لونان وهدف واحد. اختر الطريق الصحيح."},
      hint={"en": "Send the balls left onto the green pentagon, then back to the middle.", "ar": "أرسل الكرات يسارًا إلى المخمّس الأخضر، ثم أعدها للمنتصف."})

# ---------------------------------------------------------------- Level 10
level(10, {"en": "The Long Curve", "ar": "المنحنى الطويل"}, "medium",
      [launcher("L1", [50, 60], [170, 0], ["blue"], 6)],
      [rect("P1", 300, 150, 60, 20, color="red"), rect("N1", 470, 320, 70, 80), rect("N2", 300, 290, 120, 20, -10)],
      [collector("C1", [580, 300], "red", 28)],
      2, 2,
      [[[105, 95], [200, 118], [265, 132]], [[340, 175], [430, 200], [520, 215]]],
      tip={"en": "Only two strokes here. Make each one count.", "ar": "خطان فقط هنا. اجعل كل خط مهمًا."},
      hint={"en": "After the red bar, one long curve can carry balls over the grey block.", "ar": "بعد الشريط الأحمر، منحنى طويل واحد يحمل الكرات فوق الكتلة الرمادية."})


# ---------------------------------------------------------------- Level 11
level(11, {"en": "Odd Shape", "ar": "شكل غريب"}, "medium",
      [launcher("L1", [50, 60], [170, 0], ["blue"], 6)],
      [poly("P1", [[250, 175], [330, 150], [395, 185], [370, 240], [300, 262], [255, 225]], color="green"),
       rect("N1", 575, 230, 16, 160)],
      [collector("C1", [505, 315], "green", 28)],
      3, 1,
      [[[100, 95], [180, 120], [240, 140]]],
      tip={"en": "Every face of a shape bounces differently.", "ar": "كل وجه من الشكل يرتد بطريقة مختلفة."},
      hint={"en": "Land on the long upper face so balls roll off to the right.", "ar": "اجعل الكرات تهبط على الوجه العلوي الطويل لتتدحرج يمينًا."})

# ---------------------------------------------------------------- Level 12
level(12, {"en": "Color Relay", "ar": "تتابع الألوان"}, "medium",
      [launcher("L1", [50, 60], [140, 0], ["blue"], 6)],
      [rect("P1", 150, 150, 90, 18, 12, color="red"), reg("P2", 360, 175, 32, 5, 0, color="green"),
       rect("P3", 470, 300, 110, 18, -8, color="red")],
      [collector("C1", [590, 250], "green", 28)],
      3, 2,
      [[[215, 185], [260, 160], [300, 150]], [[400, 230], [480, 240], [540, 225]]],
      tip={"en": "Plan the order: the final color must be green.", "ar": "خطّط للترتيب: اللون الأخير يجب أن يكون أخضر."},
      hint={"en": "Red first is fine — just make sure green is the last touch.", "ar": "الأحمر أولًا لا بأس — فقط اجعل الأخضر آخر لمسة."})

# ---------------------------------------------------------------- Level 13
level(13, {"en": "Over the Wall", "ar": "فوق الجدار"}, "medium",
      [launcher("L1", [50, 60], [200, -30], ["blue"], 6)],
      [rect("N1", 330, 260, 24, 200)],
      [collector("C1", [520, 310], "blue", 28)],
      2, 2,
      [[[80, 95], [180, 200], [250, 230], [290, 170]], [[380, 200], [430, 240], [470, 260]]],
      tip={"en": "Throw the balls over the wall, then catch them.", "ar": "ارمِ الكرات فوق الجدار، ثم التقطها."},
      hint={"en": "A ski jump on the left and a soft landing ramp on the right.", "ar": "قفزة على اليسار ومنحدر هبوط ناعم على اليمين."})

# ---------------------------------------------------------------- Level 14
level(14, {"en": "Every Ball Counts", "ar": "كل كرة مهمة"}, "medium",
      [launcher("L1", [50, 60], [160, -20], ["blue"], 5)],
      [rect("P1", 320, 340, 160, 24, color="red"), rect("N1", 470, 250, 20, 80, 0)],
      [collector("C1", [560, 300], "red", 28)],
      3, 2,
      [[[100, 110], [200, 220], [250, 300]], [[400, 300], [430, 270], [440, 220]]],
      tip={"en": "Exactly five balls. You can't lose a single one.", "ar": "خمس كرات بالضبط. لا يمكنك خسارة أي واحدة."},
      hint={"en": "Bounce on the red floor, then lift the balls to the right.", "ar": "ارتد عن الأرضية الحمراء، ثم ارفع الكرات إلى اليمين."})

# ---------------------------------------------------------------- Level 15
level(15, {"en": "Short on Ink", "ar": "الحبر قليل"}, "medium",
      [launcher("L1", [50, 60], [170, 0], ["blue"], 6)],
      [rect("P1", 210, 225, 80, 18, 20, color="green"), reg("P2", 400, 140, 30, 5, 36, color="red")],
      [collector("C1", [520, 320], "green", 28)],
      3, 1,
      [[[100, 100], [160, 150], [190, 175]]],
      ink=300,
      tip={"en": "New: an ink budget limits the total length of your rails.", "ar": "جديد: كمية الحبر تحدد الطول الكلي لخطوطك."},
      hint={"en": "The green slab already paints. A short catch line is all you need.", "ar": "اللوح الأخضر يلوّن الكرات أصلًا. خط التقاط قصير هو كل ما تحتاجه."})

# ---------------------------------------------------------------- Level 16
level(16, {"en": "Two Lanes", "ar": "مساران"}, "medium",
      [launcher("L1", [50, 50], [200, 0], ["red"], 6), launcher("L2", [50, 200], [120, -60], ["blue"], 6, delay=0.27)],
      [rect("N1", 330, 150, 220, 14, 0)],
      [collector("C1", [580, 230], "red", 28), collector("C2", [300, 320], "blue", 28)],
      5, 2,
      [[[150, 85], [300, 120], [470, 160]], [[100, 250], [180, 280], [240, 300]]],
      tip={"en": "Two launchers, two targets. Keep the colors apart.", "ar": "مدفعان وهدفان. افصل بين الألوان."},
      hint={"en": "Red stays high and goes far; blue stays low and stops short.", "ar": "الأحمر يبقى عاليًا ويذهب بعيدًا؛ الأزرق منخفض ويتوقف قريبًا."})

# ---------------------------------------------------------------- Level 17
level(17, {"en": "One Changes", "ar": "واحد يتغيّر"}, "hard",
      [launcher("L1", [50, 50], [190, 0], ["red"], 6), launcher("L2", [50, 220], [150, -80], ["red"], 6, delay=0.27)],
      [rect("N1", 300, 160, 260, 14, 0), reg("P1", 300, 290, 28, 5, 0, color="green")],
      [collector("C1", [590, 240], "red", 28), collector("C2", [410, 318], "green", 28)],
      4, 2,
      [[[140, 80], [300, 115], [480, 150]], [[130, 270], [200, 255], [255, 260]]],
      tip={"en": "Only the lower stream should turn green.", "ar": "التيار السفلي فقط يجب أن يصبح أخضر."},
      hint={"en": "Bounce the lower balls off the green pentagon toward the green circle.", "ar": "ارتدّ بالكرات السفلية عن المخمّس الأخضر نحو الدائرة الخضراء."})

# ---------------------------------------------------------------- Level 18
level(18, {"en": "Paint Field", "ar": "حقل الألوان"}, "hard",
      [launcher("L1", [50, 60], [160, 0], ["blue"], 6)],
      [rect("P1", 190, 200, 40, 40, 20, color="red"), reg("P2", 300, 120, 26, 5, 0, color="green"),
       rect("P3", 330, 260, 46, 46, 45, color="blue"), reg("P4", 450, 180, 28, 6, 0, color="red"),
       rect("P5", 470, 320, 60, 18, 0, color="blue")],
      [collector("C1", [580, 290], "green", 28)],
      2, 2,
      [[[100, 95], [200, 105], [260, 100]], [[340, 170], [420, 225], [520, 250]]],
      tip={"en": "Lots of paint here. Watch the very last touch.", "ar": "ألوان كثيرة هنا. انتبه لآخر لمسة."},
      hint={"en": "Touch green, then keep the balls clear of every other color.", "ar": "المس الأخضر، ثم أبعد الكرات عن كل لون آخر."})

# ---------------------------------------------------------------- Level 19
level(19, {"en": "One Line", "ar": "خط واحد"}, "hard",
      [launcher("L1", [50, 60], [200, -30], ["blue"], 6)],
      [rect("P1", 330, 175, 130, 16, 0, color="red"), rect("N1", 160, 300, 60, 60, 30)],
      [collector("C1", [570, 300], "red", 28)],
      1, 1,
      [[[90, 100], [200, 210], [330, 240], [470, 260]]],
      tip={"en": "One stroke has to do everything.", "ar": "خط واحد عليه أن يقوم بكل شيء."},
      hint={"en": "Let the line make the balls hop up into the red bar, then carry them on.", "ar": "اجعل الخط يقفز بالكرات نحو الشريط الأحمر، ثم يكمل بها."})

# ---------------------------------------------------------------- Level 20
level(20, {"en": "Final Color", "ar": "اللون الأخير"}, "hard",
      [launcher("L1", [50, 60], [170, 0], ["red"], 5)],
      [rect("P1", 200, 200, 60, 20, -20, color="blue"), reg("P2", 330, 110, 28, 5, 180, color="green"),
       rect("P3", 420, 240, 50, 50, 30, color="red"), reg("P4", 250, 320, 30, 6, 0, color="green"),
       rect("N1", 520, 180, 16, 120, 0)],
      [collector("C1", [590, 310], "green", 28)],
      2, 2,
      [[[100, 100], [200, 80], [290, 100]], [[350, 180], [440, 180], [500, 280]]],
      tip={"en": "Five balls, two strokes, one final color.", "ar": "خمس كرات، خطان، ولون أخير واحد."},
      hint={"en": "Find a green touch that is not followed by red or blue.", "ar": "ابحث عن لمسة خضراء لا يتبعها أحمر أو أزرق."})


# =====================================================================
# Phase 2 sandbox: one small level per new piece (rules version 2).
# =====================================================================

def level2(num, title, launchers, obstacles, collectors, max_strokes, par, solution,
           tip=None, hint=None, extra=None, board=(640, 360), lifetime=20.0, duration=45.0):
    lid = "s2_%02d" % num
    ctrl = CTRL.get(lid, solution)
    CTRL.setdefault(lid, solution)
    sol = [curve(*c) for c in ctrl]
    data = {
        "schemaVersion": 1, "levelId": lid, "revision": 1, "rulesVersion": 2,
        "title": title, "difficulty": "medium", "chapter": "lab", "number": num,
        "board": {"width": board[0], "height": board[1]}, "gravity": [0, 420],
        "material": {"obstacle": {"restitution": 0.5, "friction": 0.6},
                     "rail": {"restitution": 0.25, "friction": 0.35}},
        "runDurationLimit": duration, "ballLifetime": lifetime,
        "launchers": launchers, "obstacles": obstacles, "collectors": collectors,
        "drawingRules": {"maxStrokes": max_strokes, "maxInkLength": None, "minStrokeLength": 12,
                         "railWidth": 6, "forbiddenZones": []},
        "scoring": {"parStrokes": par}, "tip": tip or {}, "hint": hint or {},
    }
    data.update(extra or {})
    LEVELS.append((lid, data, {"levelId": lid, "revision": 1, "rulesVersion": 2, "strokes": sol}))


def gate(id, cx, cy, w, h, color, rot=0):
    return {"id": id, "type": "gate", "color": color, "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": rot}


def switch(id, cx, cy, w, h, color, move, speed=300):
    return {"id": id, "type": "switch", "color": color, "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": 0, "move": move, "speed": speed}


def splitter(id, cx, cy, r=28, rot=90):
    return {"id": id, "type": "splitter", "shape": "regular", "center": [cx, cy], "radius": r, "sides": 3, "rotation": rot}


def bumper(id, cx, cy, r=22):
    return {"id": id, "type": "bumper", "shape": "regular", "center": [cx, cy], "radius": r, "sides": 16, "rotation": 0}


def flip(id, cx, cy, w, h, rot=0):
    return {"id": id, "type": "flip", "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": rot}


def booster(id, cx, cy, w, h, push, rot=0):
    return {"id": id, "type": "booster", "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": rot, "push": push}


def zone(id, cx, cy, w, h, gravity, drag=0.0):
    return {"id": id, "type": "zone", "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": 0, "gravity": gravity, "drag": drag}


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from strings_ar import AR
T = lambda en: {"en": en, "ar": AR[en]}

level2(1, T("Blue Door"),
       [launcher("L1", [50, 70], [170, 0], ["yellow"], 7)],
       [rect("B1", 205, 192, 110, 16, 8, color="blue"), rect("W1", 390, 60, 16, 120),
        gate("G1", 390, 210, 16, 180, "blue"), rect("W2", 390, 330, 16, 60), rect("R1", 470, 262, 64, 14, 10, color="red")],
       [collector("C1", [585, 300], "red", 28)], 3, 3,
       [[[95, 102], [125, 125], [148, 160]], [[268, 212], [310, 222], [355, 232]], [[506, 278], [530, 286], [548, 292]]],
       tip=T("Gates only let their own color through."),
       hint=T("Turn blue to pass the blue door, then turn red for the goal."))

level2(2, T("Red Switch"),
       [launcher("L1", [50, 70], [170, 0], ["blue"], 8)],
       [rect("R1", 250, 205, 90, 16, 8, color="red"), switch("S1", 420, 140, 16, 280, "red", [0, -180]),
        rect("W2", 420, 325, 16, 90)],
       [collector("C1", [585, 305], "red", 28)], 3, 3,
       [[[95, 102], [130, 128], [170, 170]], [[302, 222], [345, 233], [392, 244]], [[455, 262], [495, 276], [540, 292]]],
       tip=T("A red ball slides the red switch wall open."),
       hint=T("Paint the balls red before they reach the wall."))

level2(3, T("Split Paths"),
       [launcher("L1", [50, 70], [170, 0], ["blue"], 6)],
       [splitter("X1", 262, 168, 24), rect("P1", 410, 200, 100, 14, 6, color="red"),
        rect("P2", 400, 290, 110, 14, 6, color="yellow")],
       [collector("C1", [585, 235], "red", 28), collector("C2", [585, 330], "yellow", 28)], 4, 3,
       [[[95, 100], [160, 140], [222, 166]], [[470, 214], [520, 222], [548, 228]], [[466, 302], [520, 312], [550, 318]]],
       tip=T("The prism turns one ball into two."),
       hint=T("Send one copy over red and the other over yellow."))

level2(4, T("Power Shot"),
       [dict(launcher("L1", [40, 320], [520, -430], ["red"], 6), power=True)],
       [rect("W1", 330, 270, 20, 180)],
       [collector("C1", [560, 300], "red", 28)], 2, 1,
       [[[610, 120], [600, 200], [585, 250]]],
       extra={"maxSpeed": 1200},
       tip=T("Power launchers fire fast, long shots."),
       hint=T("Catch the shot on the far side and drop it into the goal."))

level2(5, T("Boost Ramp"),
       [launcher("L1", [50, 70], [150, 0], ["green"], 6)],
       [rect("N1", 430, 300, 220, 120), booster("U1", 270, 300, 70, 30, [600, -1100])],
       [collector("C1", [580, 200], "green", 28)], 3, 2,
       [[[100, 100], [180, 200], [230, 290]]],
       tip=T("Booster pads push balls along their arrows."),
       hint=T("Roll the balls across the pad to jump onto the ledge."))

level2(6, T("Bumper Court"),
       [launcher("L1", [50, 70], [160, 0], ["red"], 6)],
       [bumper("B1", 300, 300, 22), rect("N1", 470, 300, 20, 120)],
       [collector("C1", [470, 110], "red", 28)], 3, 2,
       [[[100, 100], [200, 190], [270, 260]]],
       tip=T("Bumpers bounce balls back harder."),
       hint=T("Aim at the bumper so it throws the balls up and over."))

level2(7, T("Red, Then Blue"),
       [launcher("L1", [50, 50], [200, 0], ["red"], 6),
        launcher("L2", [50, 200], [120, -60], ["blue"], 7, delay=3.0)],
       [rect("N1", 330, 150, 220, 14, 0)],
       [collector("C1", [580, 230], "red", 28), dict(collector("C2", [300, 320], "blue", 28), after="C1")], 5, 2,
       [[[132, 122], [295, 128], [526, 112]], [[48, 273], [200, 254], [254, 290]]],
       tip=T("A locked goal opens when the goal before it is full."),
       hint=T("Fill red first; the blue goal unlocks after."))

level2(8, T("Up Draft"),
       [launcher("L1", [50, 300], [200, 0], ["blue"], 6)],
       [zone("Z1", 330, 185, 120, 330, [0, -420]), rect("N1", 360, 22, 260, 16)],
       [collector("C1", [560, 120], "blue", 28)], 3, 2,
       [[[420, 60], [480, 80], [510, 100]]],
       tip=T("Inside this zone, gravity points up."),
       hint=T("Let the balls rise to the ceiling, then guide them right."))

level2(9, T("Upside Garden"),
       [launcher("L1", [50, 70], [150, 0], ["green"], 6)],
       [flip("F1", 300, 335, 110, 12)],
       [collector("C1", [470, 60], "green", 28)], 3, 2,
       [[[100, 100], [190, 220], [260, 310]]],
       tip=T("Flip pads make a ball fall upward."),
       hint=T("Drop the balls on the pad, then steer them up into the goal."))

level2(10, T("Float Room"),
       [launcher("L1", [50, 110], [260, -40], ["red"], 6)],
       [zone("Z1", 400, 180, 320, 300, [0, 0], 0.3), rect("N1", 400, 345, 320, 14)],
       [collector("C1", [500, 80], "red", 28)], 3, 1,
       [[[480, 270], [520, 220]]],
       tip=T("Zero gravity: balls fly straight. Rails work like mirrors."),
       hint=T("Place one angled rail to bounce the balls up into the goal."))

level2(11, T("Sideways"),
       [launcher("L1", [60, 60], [0, 120], ["blue"], 6)],
       [rect("N1", 420, 240, 30, 140)],
       [collector("C1", [580, 300], "blue", 28)], 3, 2,
       [[[300, 120], [380, 150], [440, 170]]],
       extra={"gravity": [420, 0]},
       tip=T("In this level, gravity pulls to the right."),
       hint=T("Use rails as floors that lead around the grey wall."))

# =====================================================================
# Chapter 2 (rules version 2): 960 x 540 board, ink budgets, new pieces.
# Pieces are introduced one at a time, with gentle mixes between them.
# =====================================================================
import copy
NO_INK = os.environ.get("BUILD_NO_INK") == "1"   # tuner: search without a budget
INK_SLACK = {"intro": 1.6, "easy": 1.45, "medium": 1.3, "hard": 1.2, "expert": 1.12}
C2_GRAVITY = 630
C2_MAXSPEED = 1080


def ceil10(x):
    return int(math.ceil(x / 10.0) * 10)


def path_len(pts):
    return sum(math.dist(pts[i - 1], pts[i]) for i in range(1, len(pts)))


def rock(id, pts):
    return {"id": id, "type": "rock", "shape": "poly", "points": pts}


def level_c2(num, title, difficulty, launchers, obstacles, collectors, solution,
             tip=None, hint=None, extra=None, chapter=2):
    lid = "c%d_%02d" % (chapter, num)
    ctrl = CTRL.get(lid, solution)
    CTRL.setdefault(lid, solution)
    sol = [curve(*c) for c in ctrl]
    S = sum(path_len(r) for r in sol)
    ink = None if NO_INK else ceil10(S * INK_SLACK[difficulty] + 40)
    data = {
        "schemaVersion": 1, "levelId": lid, "revision": 1, "rulesVersion": 2,
        "title": title, "difficulty": difficulty, "chapter": chapter, "number": num,
        "board": {"width": 960, "height": 540}, "gravity": [0, C2_GRAVITY], "maxSpeed": C2_MAXSPEED,
        "material": {"obstacle": {"restitution": 0.5, "friction": 0.6},
                     "rail": {"restitution": 0.25, "friction": 0.35}},
        "runDurationLimit": 60 if chapter >= 3 else 50, "ballLifetime": 22,
        "launchers": launchers, "obstacles": obstacles, "collectors": collectors,
        "drawingRules": {"maxStrokes": 0, "maxInkLength": ink, "minStrokeLength": 12,
                         "railWidth": 6, "forbiddenZones": []},
        "scoring": {"parStrokes": len(ctrl), "parInk": ceil10(S * 1.1)},
        "tip": tip or {}, "hint": hint or {},
    }
    data.update(extra or {})
    LEVELS.append((lid, data, {"levelId": lid, "revision": 1, "rulesVersion": 2, "strokes": sol}))


def port_sandbox(src_id, num, difficulty, keep_title=True):
    """Rebuild a Phase 2 sandbox level at 960 x 540: space x1.5, and gravity and
    speeds x1.5 too so balls keep the same timing. Balls and rails keep their
    size (so they draw smaller on the bigger board)."""
    k = 1.5
    src = next(d for (lid, d, _s) in LEVELS if lid == src_id)
    d = copy.deepcopy(src)
    sc = lambda v: [round(v[0] * k, 2), round(v[1] * k, 2)]
    for l in d["launchers"]:
        l["pos"] = sc(l["pos"]); l["velocity"] = sc(l["velocity"])
    for o in d["obstacles"]:
        if "center" in o: o["center"] = sc(o["center"])
        if "size" in o: o["size"] = sc(o["size"])
        if "radius" in o: o["radius"] = round(o["radius"] * k, 2)
        if "points" in o: o["points"] = [sc(p) for p in o["points"]]
        for key in ("push", "gravity", "move"):
            if key in o: o[key] = sc(o[key])
        if "speed" in o: o["speed"] = round(o["speed"] * k, 1)
    for c in d["collectors"]:
        c["center"] = sc(c["center"]); c["innerRadius"] = 34
    g = sc(d.get("gravity", [0, 420]))
    ctrl = CTRL.get("c2_%02d" % num) or [[sc(p) for p in stroke] for stroke in CTRL[src_id]]
    extra = {"gravity": g}
    if "maxSpeed" in d:
        extra["maxSpeed"] = int(min(1500, d["maxSpeed"] * k))
    level_c2(num, d["title"], difficulty, d["launchers"], d["obstacles"], d["collectors"], ctrl,
             tip=d.get("tip"), hint=d.get("hint"), extra=extra)


L = lambda *a, **kw: launcher(*a, **kw)

# 1 -------------------------------------------------------------------
level_c2(1, T("Wide Open"), "intro",
         [L("L1", [75, 100], [255, 0], ["blue"], 8)],
         [reg("N1", 420, 330, 50, 5, 0), rect("N2", 640, 200, 120, 24, -10)],
         [collector("C1", [840, 450], "blue", 34)],
         [[[150, 160], [350, 240], [520, 280]], [[600, 330], [720, 380], [790, 400]]],
         tip=T("Bigger board, limited ink. Watch the ink bar while you draw."),
         hint=T("Two gentle ramps around the grey shapes reach the circle."))
# 2-4: ported intros (gate, two doors new, switch)
port_sandbox("s2_01", 2, "easy")
level_c2(3, T("Two Doors"), "easy",
         [L("L1", [75, 100], [240, 0], ["yellow"], 7)],
         [rect("R1", 215, 215, 130, 22, -20, color="red"),
          rect("W1", 400, 120, 24, 240), gate("G1", 400, 390, 24, 300, "red"),
          rect("B1", 545, 462, 130, 22, 8, color="blue"),
          rect("W3", 680, 120, 24, 240), gate("G2", 680, 390, 24, 300, "blue")],
         [collector("C1", [770, 495], "blue", 34)],
         [[[130, 150], [170, 210], [190, 250]], [[325, 300], [355, 308], [378, 314]], [[420, 330], [470, 350], [490, 360]],
          [[610, 395], [640, 402], [660, 408]], [[700, 420], [750, 428], [790, 435]]],
         tip=T("Red door first, then the blue door."),
         hint=T("Turn red for the first door, then blue for the second."))
port_sandbox("s2_02", 4, "easy")
# 5 -------------------------------------------------------------------
level_c2(5, T("Switch and Door"), "easy",
         [L("L1", [75, 100], [240, 0], ["red", "blue"], 12)],
         [switch("S1", 430, 200, 24, 400, "red", [0, -330], 450), rect("W2", 430, 470, 24, 140),
          rect("W5", 650, 110, 24, 220), gate("G1", 650, 340, 24, 240, "blue"), rect("W6", 650, 500, 24, 80)],
         [collector("C1", [830, 420], "blue", 34)],
         [[[130, 150], [250, 230], [380, 280]], [[470, 300], [560, 330], [625, 345]], [[680, 380], [750, 400], [790, 410]]],
         tip=T("This launcher alternates red and blue balls."),
         hint=T("Red balls open the switch; only blue balls pass the door."))
port_sandbox("s2_03", 6, "easy")
# 7 Cave Run ----------------------------------------------------------
level_c2(7, T("Cave Run"), "easy",
         [L("L1", [60, 60], [270, 0], ["green"], 7)],
         [rock("K1", [[560, 0], [960, 0], [960, 215], [890, 240], [820, 205], [740, 222], [660, 160], [610, 110], [575, 55]]),
          rock("K2", [[0, 350], [110, 325], [210, 372], [290, 425], [320, 540], [0, 540]]),
          rock("K3", [[420, 300], [485, 268], [535, 312], [515, 400], [445, 425], [402, 362]]),
          rock("K4", [[600, 540], [640, 470], [720, 500], [960, 480], [960, 540]])],
         [collector("C1", [820, 390], "green", 34)],
         [[[115, 100], [220, 170], [300, 215]], [[340, 230], [470, 250], [580, 270]]],
         tip=T("Dark rock can't be drawn on or passed. Find the corridor."),
         hint=T("Stay above the middle rock and below the top one."))
# 8 The Narrow Way ----------------------------------------------------
level_c2(8, T("The Narrow Way"), "medium",
         [L("L1", [60, 60], [245, 0], ["blue"], 7)],
         [rect("P1", 330, 205, 90, 16, 8, color="red"),
          rock("K1", [[560, 0], [960, 0], [960, 215], [890, 240], [820, 205], [740, 222], [660, 160], [610, 110], [575, 55]]),
          rock("K2", [[0, 350], [110, 325], [210, 372], [290, 425], [320, 540], [0, 540]]),
          rock("K3", [[420, 300], [485, 268], [535, 312], [515, 400], [445, 425], [402, 362]]),
          rock("K4", [[640, 540], [640, 402], [690, 362], [760, 345], [760, 372], [702, 388], [672, 425], [672, 540]]),
          rock("K5", [[800, 345], [890, 328], [960, 300], [960, 540], [932, 540], [932, 402], [902, 374], [800, 372]]),
          rock("K6", [[672, 512], [932, 512], [932, 540], [672, 540]])],
         [collector("C1", [800, 455], "red", 30)],
         [[[115, 100], [180, 135], [262, 182]], [[390, 222], [480, 245], [560, 268], [690, 312]]],
         tip=T("The goal sits in a chamber with one small way in."),
         hint=T("Turn red, then drop into the gap at the chamber's top."))
port_sandbox("s2_04", 9, "medium")
port_sandbox("s2_06", 10, "medium")
port_sandbox("s2_05", 11, "medium")
# 12 Rock Garden ------------------------------------------------------
level_c2(12, T("Rock Garden"), "medium",
         [L("L1", [75, 100], [240, 0], ["red"], 7)],
         [rock("K1", [[0, 400], [200, 380], [330, 460], [330, 540], [0, 540]]),
          booster("U1", 430, 470, 120, 36, [900, -1300]), bumper("B1", 620, 300, 30),
          rock("K2", [[700, 540], [760, 420], [960, 400], [960, 540]])],
         [collector("C1", [830, 170], "red", 34)],
         [[[130, 150], [260, 300], [360, 440]]],
         tip=T("Pads and bumpers work together."),
         hint=T("Roll onto the pad so the bumper throws the balls up to the goal."))
port_sandbox("s2_07", 13, "medium")
port_sandbox("s2_08", 14, "medium")
port_sandbox("s2_09", 15, "medium")
port_sandbox("s2_10", 16, "medium")
port_sandbox("s2_11", 17, "medium")
# 18 Door Sorter (showcase) -------------------------------------------
level_c2(18, T("Door Sorter"), "hard",
         [L("L1", [75, 100], [240, 0], ["blue"], 6)],
         [splitter("X1", 360, 250, 36), rect("P1", 560, 215, 130, 20, 6, color="red"),
          rect("P2", 540, 350, 140, 20, 6, color="yellow"),
          rect("W1", 760, 50, 24, 100), gate("G1", 760, 180, 24, 160, "red"), rect("W2", 760, 280, 24, 40),
          gate("G2", 760, 380, 24, 160, "yellow"), rect("W3", 760, 500, 24, 80)],
         [collector("C1", [875, 270], "red", 34), collector("C2", [880, 400], "yellow", 34)],
         [[[140, 150], [240, 215], [315, 245]], [[640, 232], [700, 240], [740, 244]], [[625, 365], [690, 375], [740, 382]]],
         tip=T("Each door only opens for its own color."),
         hint=T("Split, then paint each copy to match the door it's heading for."))
# 19 Key and Lock (showcase) ------------------------------------------
level_c2(19, T("Key and Lock"), "hard",
         [L("L1", [75, 100], [240, 0], ["blue"], 8)],
         [rect("P1", 330, 300, 120, 20, 8, color="red"),
          switch("S1", 520, 230, 24, 340, "red", [0, -280], 450), rect("W2", 520, 470, 24, 140),
          rect("P2", 680, 380, 120, 20, 8, color="blue")],
         [collector("C1", [850, 450], "blue", 34)],
         [[[130, 150], [220, 230], [270, 280]], [[400, 320], [450, 330], [495, 335]], [[560, 350], [600, 360], [620, 368]], [[745, 400], [790, 415], [810, 425]]],
         tip=T("The lock needs red. The goal needs blue."),
         hint=T("Red opens the switch; repaint blue on the far side."))
# 20 Turnaround (showcase) --------------------------------------------
level_c2(20, T("Turnaround"), "hard",
         [L("L1", [75, 100], [260, 0], ["yellow"], 7)],
         [rect("P1", 300, 200, 130, 20, 6, color="blue"), rect("N1", 470, 290, 600, 20, 0),
          zone("Z1", 860, 270, 200, 540, [-630, 200]), gate("G1", 380, 420, 24, 240, "blue"),
          rect("W1", 380, 320, 24, 40)],
         [collector("C1", [170, 450], "blue", 34)],
         [[[130, 150], [200, 185], [240, 195]], [[370, 225], [520, 255], [740, 270]], [[700, 360], [560, 400], [420, 420]], [[340, 430], [260, 440], [210, 445]]],
         tip=T("In the blue zone, gravity pulls left. Bring the balls back."),
         hint=T("Go right on top, come back underneath through the blue door."))

# =====================================================================
# Chapter 3 (rules version 2): hard mixed levels only. Every level chains
# two or more Chapter 2 ideas; ink slack is "hard" (1.2) or "expert" (1.12).
# =====================================================================
C3 = lambda *a, **kw: level_c2(*a, chapter=3, **kw)
CEIL = lambda x0, x1: rock("KC%d" % x0, [[x0, 0], [x1, 0], [x1, 14], [x0, 14]])

# 1 Two Keys: red opens the first switch, blue the second.
C3(1, T("Two Keys"), "hard",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [rect("P1", 215, 215, 130, 22, -20, color="red"),
    switch("S1", 400, 200, 24, 400, "red", [0, -360], 450), rect("W1", 400, 470, 24, 140),
    rect("P2", 530, 400, 120, 20, 8, color="blue"),
    switch("S2", 690, 220, 24, 440, "blue", [0, -400], 450), rect("W2", 690, 490, 24, 100)],
   [collector("C1", [850, 470], "blue", 34)],
   [[[105, 225], [85, 290], [125, 335], [250, 335], [385, 330]], [[592, 418], [630, 425], [672, 430]], [[715, 445], [770, 455], [810, 462]]],
   tip=T("Two locks, two keys."),
   hint=T("Red opens the first wall. Repaint blue for the second."))

# 2 Prism Run: one colour in, two colours out.
C3(2, T("Prism Run"), "hard",
   [L("L1", [75, 100], [240, 0], ["yellow"], 5)],
   [splitter("X1", 330, 270, 36), rect("P1", 520, 300, 130, 20, 6, color="red"),
    rect("P2", 500, 460, 130, 20, 6, color="blue"),
    rect("W1", 760, 75, 24, 150), gate("G1", 760, 250, 24, 200, "red"), rect("W2", 760, 375, 24, 50),
    gate("G2", 760, 470, 24, 140, "blue"), rect("WB", 952, 270, 16, 540)],
   [collector("C1", [865, 315], "red", 34), collector("C2", [870, 470], "blue", 34)],
   [[[130, 150], [220, 220], [295, 262]], [[595, 312], [680, 300], [740, 280]], [[575, 472], [660, 478], [740, 478]]],
   tip=T("Five balls, ten goals' worth. Every copy counts."),
   hint=T("Split once, then send one copy over red and one over blue."))

# 3 Grand Curve: over the hill, around and back underneath.
C3(3, T("Grand Curve"), "expert",
   [L("L1", [75, 100], [250, 0], ["yellow"], 7)],
   [rock("K1", [[330, 190], [620, 235], [620, 420], [330, 420]]),
    rect("P1", 754, 385, 16, 150, 0, color="green"),
    rock("K2", [[0, 380], [240, 380], [240, 400], [0, 400]])],
   [collector("C1", [120, 475], "green", 34)],
   [[[150, 150], [240, 185], [325, 190]],
    [[650, 260], [760, 330], [740, 430], [620, 465], [420, 480], [250, 495]]],
   tip=T("Paint green at the far wall. The long way round is the only way."),
   hint=T("Roll over the rock, turn around at the far side and come back underneath."))

# 4 Deep Float: zero gravity everywhere right of the start.
C3(4, T("Deep Float"), "hard",
   [L("L1", [75, 100], [260, 0], ["red"], 6)],
   [zone("Z1", 605, 270, 710, 540, [0, 0], 0.0),
    rock("K1", [[600, 0], [640, 0], [640, 300], [600, 300]]),
    rect("P1", 560, 488, 110, 16, 0, color="blue")],
   [collector("C1", [860, 110], "blue", 34)],
   [[[345, 385], [395, 455], [470, 478]], [[640, 480], [780, 450], [850, 260]]],
   tip=T("No gravity here: balls fly straight until a rail turns them."),
   hint=T("Turn blue on the low slab, then bounce up behind the wall."))

# 5 Upside Twice: flip up, paint on the ceiling, flip back down.
C3(5, T("Upside Twice"), "hard",
   [L("L1", [75, 100], [240, 0], ["green"], 6)],
   [flip("F1", 300, 470, 130, 14), rect("P1", 540, 40, 140, 20, 0, color="blue"),
    flip("F2", 740, 26, 120, 14), rock("K1", [[420, 300], [640, 300], [640, 540], [420, 540]])],
   [collector("C1", [850, 470], "blue", 34)],
   [[[130, 150], [220, 300], [265, 440]], [[360, 70], [420, 60], [465, 55]], [[790, 200], [800, 330], [820, 420]]],
   tip=T("Flip pads work both ways."),
   hint=T("Fall up to the blue ceiling, then flip again to fall down to the goal."))

# 6 Rainbow Road: red key, blue door, yellow goal.
C3(6, T("Rainbow Road"), "expert",
   [L("L1", [75, 100], [240, 0], ["green"], 8)],
   [rect("P1", 215, 215, 120, 20, -20, color="red"),
    switch("S1", 360, 190, 24, 380, "red", [0, -340], 450), rect("W1", 360, 460, 24, 160),
    rect("P2", 480, 380, 110, 20, 8, color="blue"),
    rect("W2", 600, 90, 24, 180), gate("G1", 600, 330, 24, 300, "blue"), rect("W3", 600, 510, 24, 60),
    rect("P3", 730, 450, 110, 20, 8, color="yellow")],
   [collector("C1", [880, 495], "yellow", 30)],
   [[[105, 225], [85, 290], [125, 330], [240, 325], [345, 315]], [[380, 330], [410, 345], [432, 360]], [[540, 395], [565, 400], [588, 404]],
    [[618, 415], [650, 428], [678, 438]], [[790, 470], [815, 478], [840, 485]]],
   tip=T("Three colours in a row."),
   hint=T("Red for the wall, blue for the door, yellow for the goal."))

# 7 Power Door: a power shot that has to change colour mid-flight.
C3(7, T("Power Door"), "hard",
   [dict(L("L1", [60, 470], [640, -620], ["red"], 6), power=True)],
   [rect("P1", 420, 330, 160, 20, 0, color="blue"),
    rect("W1", 560, 80, 24, 160), gate("G1", 560, 350, 24, 380, "blue"),
    rock("K1", [[620, 330], [680, 330], [680, 350], [640, 350], [640, 540], [620, 540]]),
    rock("K2", [[820, 330], [960, 330], [960, 540], [940, 540], [940, 350], [820, 350]])],
   [collector("C1", [790, 460], "blue", 34)],
   [[[230, 60], [330, 80], [430, 90]], [[480, 200], [520, 260], [545, 300]], [[600, 300], [700, 260], [830, 250]]],
   extra={"maxSpeed": 1500},
   tip=T("Power shots are fast. Catch them softly."),
   hint=T("Knock the shot down onto the blue slab, then roll it through the door."))

# 8 Side Door: gravity pulls right, the door wants red.
C3(8, T("Side Door"), "hard",
   [L("L1", [60, 60], [0, 200], ["yellow"], 7)],
   [rect("P1", 300, 120, 20, 140, 0, color="red"),
    gate("G1", 600, 160, 24, 320, "red"), rect("W1", 600, 430, 24, 220),
    rock("K1", [[380, 330], [520, 330], [520, 540], [380, 540]])],
   [collector("C1", [880, 250], "red", 34)],
   [[[200, 200], [250, 240], [280, 260]], [[330, 260], [450, 230], [570, 210]]],
   extra={"gravity": [630, 0]},
   tip=T("Sideways again, with a door this time."),
   hint=T("Rails are floors that face left. Paint red before the door."))

# 9 Updraft Key: rise to paint, then open the wall.
C3(9, T("Updraft Key"), "hard",
   [L("L1", [75, 460], [260, -200], ["blue"], 7)],
   [zone("Z1", 320, 270, 180, 540, [0, -630]), CEIL(250, 960),
    rect("P1", 330, 40, 120, 20, 0, color="red"),
    switch("S1", 560, 180, 24, 330, "red", [0, -330], 450),
    rock("K1", [[450, 345], [650, 345], [650, 540], [450, 540]])],
   [collector("C1", [850, 450], "red", 34)],
   [[[120, 450], [200, 430], [255, 410]], [[400, 60], [470, 80], [540, 110]], [[600, 200], [700, 320], [790, 400]]],
   tip=T("Up, across, and down."),
   hint=T("Ride the updraft to the red ceiling, then hit the switch."))

# 10 Locked Pair: red fills first, then the blue goal opens.
C3(10, T("Locked Pair"), "hard",
   [L("L1", [75, 80], [240, 0], ["red"], 6), L("L2", [75, 300], [240, -80], ["blue"], 7, delay=6.0)],
   [rect("W1", 760, 60, 24, 120), gate("G1", 760, 210, 24, 180, "red"), rect("W2", 760, 330, 24, 60),
    gate("G2", 480, 410, 24, 180, "blue", 90), rect("W3", 380, 470, 24, 140), rect("W4", 580, 470, 24, 140),
    rect("WB", 952, 200, 16, 400), rect("SH", 880, 315, 150, 14, -10)],
   [collector("C1", [865, 275], "red", 34), dict(collector("C2", [480, 480], "blue", 34), after="C1")],
   [[[130, 130], [400, 160], [740, 200]], [[130, 300], [260, 330], [400, 370]]],
   tip=T("Two launchers, two doors, and an order."),
   hint=T("Red goes right over the blue door. Blue drops through it later."))

# 11 Narrow Prism: split, then funnel every copy into one small way in.
C3(11, T("Narrow Prism"), "hard",
   [L("L1", [75, 100], [240, 0], ["blue"], 5)],
   [splitter("X1", 420, 250, 36),
    rock("K4", [[640, 540], [640, 402], [690, 362], [760, 345], [760, 372], [702, 388], [672, 425], [672, 540]]),
    rock("K5", [[800, 345], [890, 328], [960, 300], [960, 540], [932, 540], [932, 402], [902, 374], [800, 372]]),
    rock("K6", [[672, 512], [932, 512], [932, 540], [672, 540]])],
   [collector("C1", [800, 455], "blue", 30)],
   [[[130, 150], [250, 220], [385, 245]], [[500, 255], [650, 300], [755, 338]], [[930, 200], [870, 280], [808, 338]]],
   tip=T("Every ball becomes two. Five must find the small door."),
   hint=T("Split first, then funnel both copies into the gap."))

# 12 Bumper Climb: red and blue take turns; only red gets through the door.
C3(12, T("Bumper Climb"), "hard",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 12)],
   [rock("K1", [[0, 400], [200, 380], [330, 460], [330, 540], [0, 540]]),
    booster("U1", 430, 470, 120, 36, [900, -1300]), bumper("B1", 620, 300, 30),
    rock("K2", [[700, 540], [760, 420], [960, 400], [960, 540]]),
    gate("G1", 735, 135, 24, 270, "red")],
   [collector("C1", [830, 170], "red", 34)],
   [[[160, 161], [328, 273], [416, 263]]],
   tip=T("Red and blue take turns. Only red gets through the door."),
   hint=T("Roll onto the pad and let the bumper aim the balls at the goal."))

# 13 Flip Lock: fall up to the key, open the wall, flip back down.
C3(13, T("Flip Lock"), "expert",
   [L("L1", [75, 100], [240, 0], ["green"], 6)],
   [flip("F1", 330, 480, 140, 14), rect("P1", 520, 60, 160, 20, -8, color="red"), CEIL(600, 960),
    switch("S1", 700, 150, 24, 270, "red", [0, -290], 450), flip("F2", 790, 34, 100, 14)],
   [collector("C1", [860, 470], "red", 34)],
   [[[320, 95], [390, 70], [440, 55]], [[612, 70], [660, 50], [690, 40]], [[800, 200], [820, 320], [840, 420]]],
   tip=T("Up to the key, down to the goal."),
   hint=T("Fall up onto the red slab, roll into the switch, then flip back down."))

# 14 Turnaround II: the long way back, around a rock.
C3(14, T("Turnaround II"), "expert",
   [L("L1", [75, 100], [260, 0], ["yellow"], 7)],
   [rect("P1", 300, 200, 130, 20, 6, color="blue"), rect("N1", 470, 290, 600, 20, 0),
    zone("Z1", 860, 270, 200, 540, [-630, 200]), gate("G1", 380, 420, 24, 240, "blue"),
    rect("W1", 380, 320, 24, 40), rock("K1", [[520, 380], [620, 362], [640, 432], [545, 452]])],
   [collector("C1", [170, 450], "blue", 34)],
   [[[130, 150], [200, 185], [240, 195]], [[370, 225], [520, 255], [740, 270]], [[700, 360], [600, 345], [500, 360], [420, 420]], [[340, 430], [260, 440], [210, 445]]],
   tip=T("Same trip as before, with a rock in the way."),
   hint=T("Come back above the rock, then drop through the blue door."))

# 15 Float Gate: paint, then fly over the rock and through the door.
C3(15, T("Float Gate"), "hard",
   [L("L1", [75, 100], [260, 0], ["yellow"], 6)],
   [rect("P1", 270, 300, 120, 20, 10, color="red"),
    zone("Z1", 640, 270, 640, 540, [0, 0], 0.0),
    rock("K1", [[450, 150], [520, 150], [520, 540], [450, 540]]),
    gate("G1", 680, 150, 24, 300, "red"), rect("W1", 680, 420, 24, 240),
    CEIL(692, 960), rect("WP", 820, 300, 264, 16), rect("WB", 952, 150, 16, 300)],
   [collector("C1", [820, 155], "red", 44)],
   [[[340, 330], [380, 250], [440, 120]], [[540, 100], [600, 120], [650, 140]]],
   tip=T("No gravity past the red slab."),
   hint=T("Turn the balls upward before the rock, then level them out for the door."))

# 16 Side Split: sideways gravity, one colour in, two out.
C3(16, T("Side Split"), "hard",
   [L("L1", [60, 60], [0, 220], ["yellow"], 9)],
   [splitter("X1", 300, 270, 36), rect("P1", 560, 150, 20, 140, 0, color="red"),
    rect("P2", 560, 420, 20, 140, 0, color="blue"),
    gate("G1", 760, 130, 24, 260, "red"), rect("W1", 760, 270, 24, 20), gate("G2", 760, 410, 24, 260, "blue"),
    rect("WB", 952, 270, 16, 540), rect("WM", 860, 270, 184, 16),
    rect("WT", 860, 8, 184, 16), rect("WF", 860, 532, 184, 16)],
   [collector("C1", [910, 130], "red", 34), collector("C2", [910, 420], "blue", 34)],
   [[[400, 200], [470, 170], [540, 150]], [[400, 340], [470, 380], [540, 410]]],
   extra={"gravity": [630, 0]},
   tip=T("Gravity pulls right. The prism still splits."),
   hint=T("Send one copy up onto red and the other down onto blue."))

# 17 Power Vault: a blue key slides the lid, red fills the vault.
C3(17, T("Power Vault"), "expert",
   [dict(L("L1", [60, 480], [600, -700], ["blue", "red"], 12), power=True)],
   [rock("K1", [[700, 200], [720, 200], [720, 460], [700, 460]]),
    rock("K2", [[700, 440], [960, 440], [960, 460], [700, 460]]),
    rock("K3", [[940, 200], [960, 200], [960, 440], [940, 440]]),
    switch("S1", 830, 190, 220, 20, "blue", [240, 0], 500)],
   [collector("C1", [830, 350], "red", 34)],
   [[[560, 90], [650, 120], [740, 170]]],
   extra={"maxSpeed": 1500},
   tip=T("This power launcher fires blue, then red, then blue..."),
   hint=T("Bring the shot down onto the lid. Blue slides it open; red drops in."))

# 18 Up and Over: rise in the updraft, flip, and pass the door.
C3(18, T("Up and Over"), "expert",
   [L("L1", [75, 460], [260, -200], ["red"], 7)],
   [zone("Z1", 320, 270, 180, 540, [0, -630]), CEIL(230, 410),
    rect("P1", 480, 120, 120, 20, 8, color="blue"), flip("F1", 590, 300, 110, 14),
    rect("W1", 700, 110, 24, 220), gate("G1", 700, 380, 24, 320, "blue"), rect("WB", 952, 380, 16, 320)],
   [collector("C1", [900, 470], "blue", 34)],
   [[[120, 450], [200, 430], [255, 410]], [[400, 40], [430, 80], [445, 105]], [[640, 330], [670, 360], [690, 380]]],
   tip=T("Up, across, flip, down."),
   hint=T("Leave the updraft onto the blue slab, then drop through the door."))

# 19 Ink Miser: everything almost works by itself. Fix it with a little ink.
C3(19, T("Ink Miser"), "expert",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [rect("P1", 230, 240, 130, 22, 10, color="red"),
    switch("S1", 400, 200, 24, 400, "red", [0, -360], 450), rect("W1", 400, 470, 24, 140),
    rect("P2", 530, 400, 120, 20, 8, color="blue"),
    switch("S2", 690, 220, 24, 440, "blue", [0, -400], 450), rect("W2", 690, 490, 24, 100),
    bumper("B1", 775, 405, 22)],
   [collector("C1", [850, 470], "blue", 34)],
   [[[712, 368], [760, 368], [805, 392], [830, 425]]],
   tip=T("Almost everything works by itself. Use very little ink."),
   hint=T("One short line over the bumper is enough."))

# 20 Grand Finale: split, paint and sort, squeezed between rock walls.
C3(20, T("Grand Finale"), "expert",
   [L("L1", [75, 100], [240, 0], ["blue"], 6)],
   [splitter("X1", 360, 250, 36), rect("P1", 560, 215, 130, 20, 6, color="red"),
    rect("P2", 540, 350, 140, 20, 6, color="yellow"),
    rect("W1", 760, 50, 24, 100), gate("G1", 760, 180, 24, 160, "red"), rect("W2", 760, 280, 24, 40),
    gate("G2", 760, 380, 24, 160, "yellow"), rect("W3", 760, 500, 24, 80),
    rock("K1", [[400, 0], [740, 0], [740, 100], [600, 140], [460, 150], [400, 120]]),
    rock("K2", [[380, 540], [380, 440], [480, 400], [560, 410], [590, 470], [590, 540]]),
    rock("K3", [[0, 330], [150, 300], [260, 340], [300, 540], [0, 540]])],
   [collector("C1", [875, 270], "red", 34), collector("C2", [880, 400], "yellow", 34)],
   [[[140, 149], [254, 269], [333, 267]], [[713, 264], [642, 246], [739, 237]], [[597, 434], [712, 353], [680, 372]]],
   tip=T("Everything you've learned, in one run."),
   hint=T("Split, paint each copy, and send it through its own door."))

EXTRAS_PATH = os.path.join(os.path.dirname(__file__), "c3_extras.json")
V3_TYPES = ("poison", "lava", "fan", "conveyor", "glass", "door", "portal", "blackhole", "magnet", "mixer")
STARS_PATH = os.path.join(os.path.dirname(__file__), "stars.json")


# =====================================================================
# v1.2: Chapter 4 (Volcano) and Chapter 5 (Space), rules version 3.
# Level definitions live in tools/levels_v12.py.
# =====================================================================
def _area(id, type, cx, cy, w, h, rot=0, **kw):
    o = {"id": id, "type": type, "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": rot}
    o.update(kw)
    return o

def poison(id, cx, cy, w, h, rot=0): return _area(id, "poison", cx, cy, w, h, rot)
def lava(id, cx, cy, w, h, rot=0): return _area(id, "lava", cx, cy, w, h, rot)
def fan(id, cx, cy, w, h, push): return _area(id, "fan", cx, cy, w, h, 0, push=push)
def conveyor(id, cx, cy, w, h=18, speed=200, rot=0): return _area(id, "conveyor", cx, cy, w, h, rot, speed=speed)
def glass(id, cx, cy, w, h, hits=3, rot=0): return _area(id, "glass", cx, cy, w, h, rot, hits=hits)
def door(id, cx, cy, w, h, period=2.0, open=1.0, phase=0.0): return _area(id, "door", cx, cy, w, h, 0, period=period, open=open, phase=phase)
def mixer(id, cx, cy, w, h, color, rot=0): return _area(id, "mixer", cx, cy, w, h, rot, color=color)
def portal(id, a, b, r=20):
    return {"id": id, "type": "portal", "shape": "regular", "center": a, "radius": r, "sides": 16, "rotation": 0, "to": b}
def blackhole(id, c, r=14, reach=110, strength=900):
    return {"id": id, "type": "blackhole", "shape": "regular", "center": c, "radius": r, "sides": 16, "rotation": 0, "reach": reach, "strength": strength}
def magnet(id, c, color, reach=130, strength=900):
    return {"id": id, "type": "magnet", "shape": "regular", "center": c, "radius": 12, "sides": 16, "rotation": 0, "reach": reach, "strength": strength, "color": color}
def nodraw(x, y, w, h): return {"rect": [x, y, w, h]}

C4 = lambda *a, **kw: level_c2(*a, chapter=4, **kw)
C5 = lambda *a, **kw: level_c2(*a, chapter=5, **kw)
_v12 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "levels_v12.py")
if os.path.exists(_v12):
    exec(compile(open(_v12, encoding="utf-8").read(), _v12, "exec"))


def main():
    os.makedirs(os.path.join(ROOT, "solutions"), exist_ok=True)
    # v1.1 map stars, placed by tools/place_stars.gd (proven collectible).
    stars = {}
    if os.path.exists(STARS_PATH):
        with open(STARS_PATH) as f:
            stars = json.load(f)
    # v1.2 Chapter 3 rework: goal cups and poison from tools/harden_c3.gd.
    extras = {}
    if os.path.exists(EXTRAS_PATH) and os.environ.get("BUILD_NO_EXTRAS") != "1":
        with open(EXTRAS_PATH) as f:
            extras = json.load(f)
    names = []
    for lid, data, sol in LEVELS:
        if extras.get(lid):
            data["obstacles"] = data["obstacles"] + extras[lid]
        if lid.startswith("c3_") and os.environ.get("BUILD_NO_EXTRAS") != "1":
            # Reworked in v1.2: new revision (old saved drawings no longer fit).
            data["revision"] = 2
            sol["revision"] = 2
        # Levels using v1.2 pieces run on rules version 3.
        if any(o.get("type") in V3_TYPES for o in data["obstacles"]) or \
                any(c["targetColor"] in ("orange", "purple") for c in data["collectors"]):
            data["rulesVersion"] = 3
            sol["rulesVersion"] = 3
        if lid in stars:
            data["star"] = {"pos": stars[lid]}
        if lid.startswith("s2_"):
            for stale in (os.path.join(ROOT, lid + ".json"), os.path.join(ROOT, "solutions", lid + ".json")):
                if os.path.exists(stale):
                    os.remove(stale)
            continue
        with open(os.path.join(ROOT, lid + ".json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        with open(os.path.join(ROOT, "solutions", lid + ".json"), "w", encoding="utf-8") as f:
            json.dump(sol, f)
        names.append(lid + ".json")
    with open(os.path.join(ROOT, "index.json"), "w") as f:
        json.dump({"levels": names}, f, indent=1)
    with open(CTRL_PATH, "w") as f:
        f.write("{\n" + ",\n".join('"%s": %s' % (k, json.dumps(CTRL[k])) for k in sorted(CTRL)) + "\n}\n")
    print("wrote", len(names), "levels")


if __name__ == "__main__":
    main()
