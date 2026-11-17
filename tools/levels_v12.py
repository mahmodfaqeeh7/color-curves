# v1.2 levels: Chapter 4 "Volcano" and Chapter 5 "Space" (rules version 3).
# Executed by build_levels.py (uses its helpers). Text is written inline in
# English and Arabic. Solutions are first guesses; tools/tune_solution.py
# refines them into tools/solution_ctrl.json.
TT = lambda en, ar: {"en": en, "ar": ar}
G = lambda id, c, col: collector(id, c, col, 34)
LAVA_FLOOR = lambda id="LV0", x0=0, x1=960: lava(id, (x0 + x1) / 2, 520, x1 - x0, 40)

# ===================================================================== Chapter 4: Volcano
# 1 Lava Lake: lava destroys balls.
C4(1, TT("Lava Lake", "بحيرة الحمم"), "intro",
   [L("L1", [75, 100], [240, 0], ["blue"], 8)],
   [LAVA_FLOOR()],
   [G("C1", [850, 300], "blue")],
   [[[140, 180], [470, 245], [805, 298]]],
   tip=TT("Lava destroys every ball that touches it.", "الحمم تُتلف كل كرة تلمسها."),
   hint=TT("One long ramp, high above the lava.", "منحدر واحد طويل، عاليًا فوق الحمم."))

# 2 Burnt Bridge: lines near lava burn away.
C4(2, TT("Burnt Bridge", "الجسر المحترق"), "intro",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [lava("LV1", 470, 250, 140, 220), LAVA_FLOOR()],
   [G("C1", [860, 430], "red")],
   [[[225, 390], [520, 425], [812, 440]]],
   tip=TT("Lines drawn in or next to lava burn away after a moment.", "الخطوط المرسومة داخل الحمم أو بجانبها تحترق بعد لحظة."),
   hint=TT("Pass under the hanging lava, not through it.", "مرّ من تحت الحمم المعلّقة، لا من خلالها."))

# 3 Updraft: a fan lifts balls over a wall.
C4(3, TT("Updraft", "تيار صاعد"), "easy",
   [L("L1", [75, 100], [240, 0], ["green"], 8)],
   [fan("F1", 380, 290, 160, 440, [0, -1000]), rect("W1", 480, 390, 24, 300), LAVA_FLOOR("LV0", 0, 468)],
   [G("C1", [820, 440], "green")],
   [[[130, 170], [220, 205], [295, 225]], [[640, 400], [720, 430], [775, 442]]],
   tip=TT("A fan blows balls in the direction of its arrow.", "المروحة تدفع الكرات باتجاه سهمها."),
   hint=TT("Feed the fan gently, then catch the balls on the far side.", "أدخل الكرات إلى المروحة بهدوء، ثم التقطها في الجهة الأخرى."))

# 4 Uphill Belt: a conveyor carries balls up a slope.
C4(4, TT("Uphill Belt", "السير الصاعد"), "easy",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [conveyor("B1", 590, 300, 360, 18, 230, -10), LAVA_FLOOR()],
   [G("C1", [880, 320], "yellow")],
   [[[130, 170], [290, 290], [400, 318]]],
   tip=TT("A conveyor belt carries balls along its arrows, even uphill.", "السير المتحرك يحمل الكرات باتجاه أسهمه، حتى صعودًا."),
   hint=TT("Deliver the balls to the low end of the belt.", "أوصل الكرات إلى الطرف المنخفض من السير."))

# 5 Glass Lid: three hits open the well.
C4(5, TT("Glass Lid", "غطاء زجاجي"), "easy",
   [L("L1", [75, 100], [240, 0], ["blue"], 9)],
   [rect("W1", 630, 440, 20, 200), rect("W2", 770, 440, 20, 200), glass("GL1", 700, 347, 120, 14, 3),
    LAVA_FLOOR("LV0", 0, 620), LAVA_FLOOR("LV1", 780, 960)],
   [G("C1", [700, 475], "blue")],
   [[[130, 170], [400, 265], [655, 322]]],
   tip=TT("Glass breaks after the number of hits written on it.", "الزجاج ينكسر بعد عدد الضربات المكتوب عليه."),
   hint=TT("Drop the balls on the lid. The third one breaks it.", "أسقط الكرات على الغطاء، والثالثة تكسره."))

# 6 Rhythm Door: wait for the beat.
C4(6, TT("Rhythm Door", "باب الإيقاع"), "easy",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [rect("S1", 660, 446, 500, 16, 6), door("D1", 620, 380, 18, 124, 3.0, 1.3), rect("W1", 620, 159, 18, 318),
    LAVA_FLOOR("LV0", 0, 400)],
   [G("C1", [860, 440], "red")],
   [[[130, 170], [300, 330], [425, 405]]],
   tip=TT("A timed door opens and closes. The ring shows the time left.", "الباب المؤقّت يُفتح ويُغلق، والدائرة تُظهر الوقت المتبقي."),
   hint=TT("Bring the balls to the slab. The door lets them through in turns.", "أوصل الكرات إلى اللوح، والباب يمرّرها على دفعات."))

# 7 Wind Bridge: a side fan carries balls across the gap.
C4(7, TT("Wind Bridge", "جسر الرياح"), "medium",
   [L("L1", [75, 100], [240, 0], ["green"], 8)],
   [fan("F1", 520, 250, 260, 200, [950, -950]), rect("P2", 760, 330, 240, 16), LAVA_FLOOR()],
   [G("C1", [850, 300], "green")],
   [[[130, 170], [280, 255], [395, 300]]],
   tip=TT("Wind can carry a ball across a gap.", "الرياح تحمل الكرة فوق الفجوة."),
   hint=TT("End your ramp where the wind begins.", "أنهِ منحدرك حيث تبدأ الرياح."))

# 8 Belt Relay: the second belt runs the wrong way.
C4(8, TT("Belt Relay", "تتابع السيور"), "medium",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [conveyor("B1", 300, 250, 300, 18, 200), conveyor("B2", 520, 400, 300, 18, -200),
    rect("P1", 660, 300, 110, 18, 10, color="red"), LAVA_FLOOR()],
   [G("C1", [850, 455], "red")],
   [[[460, 256], [530, 266], [598, 274]], [[730, 430], [770, 455], [800, 466]]],
   tip=TT("The lower belt runs the wrong way.", "السير السفلي يتحرك في الاتجاه الخاطئ."),
   hint=TT("Bridge the gap to the red slab before the balls drop.", "اصنع جسرًا إلى اللوح الأحمر قبل أن تسقط الكرات."))

# 9 Break Through: glass wall on a slope.
C4(9, TT("Break Through", "اختراق"), "medium",
   [L("L1", [75, 100], [240, 0], ["blue"], 10)],
   [rect("S1", 640, 384, 620, 16, 8), glass("GL1", 620, 318, 14, 120, 3), rect("W1", 620, 129, 14, 258),
    LAVA_FLOOR("LV0", 0, 320)],
   [G("C1", [870, 395], "blue")],
   [[[130, 170], [250, 290], [345, 332]]],
   tip=TT("Some balls must be spent to break the glass.", "لا بد من التضحية ببعض الكرات لكسر الزجاج."),
   hint=TT("Keep the balls coming. The glass gives way on the third hit.", "استمر بإرسال الكرات، فالزجاج ينكسر عند الضربة الثالثة."))

# 10 Ember Path: under one lava column, over the next.
C4(10, TT("Ember Path", "درب الجمر"), "hard",
   [L("L1", [75, 100], [240, 0], ["red"], 9)],
   [lava("LV1", 400, 135, 50, 270), lava("LV2", 640, 420, 50, 240), booster("U1", 525, 330, 100, 60, [150, -2700]),
    LAVA_FLOOR("LV0", 0, 600)],
   [G("C1", [840, 440], "red")],
   [[[130, 170], [300, 300], [468, 345]], [[700, 380], [760, 430], [795, 448]]],
   tip=TT("Under the first column, over the second.", "من تحت العمود الأول، ومن فوق الثاني."),
   hint=TT("Roll into the booster, then catch the balls after their jump.", "ادخل لوحة الدفع، ثم التقط الكرات بعد قفزتها."))

# 11 Twin Wells: each colour has its own lid.
C4(11, TT("Twin Wells", "البئران"), "medium",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 14, 0.5)],
   [rect("W1", 390, 450, 20, 180), rect("W2", 530, 450, 20, 180), gate("GA", 460, 358, 120, 14, "red"),
    rect("S1", 615, 372, 150, 14, 6),
    rect("W3", 690, 462, 20, 156), rect("W4", 830, 462, 20, 156), gate("GB", 760, 386, 120, 14, "blue"),
    LAVA_FLOOR("LV0", 0, 380), LAVA_FLOOR("LV1", 540, 680), LAVA_FLOOR("LV2", 840, 960)],
   [G("C1", [460, 478], "red"), G("C2", [760, 482], "blue")],
   [[[130, 170], [280, 290], [392, 340]]],
   tip=TT("A colored lid lets only its own color fall through.", "الغطاء الملوّن يسمح للونه فقط بالسقوط."),
   hint=TT("One ramp to the first lid. Blue balls roll on to the second.", "منحدر واحد إلى الغطاء الأول، والكرات الزرقاء تكمل إلى الثاني."))

# 12 Belt and Door.
C4(12, TT("Belt and Door", "السير والباب"), "medium",
   [L("L1", [75, 100], [120, 0], ["green"], 10)],
   [conveyor("B1", 420, 330, 380, 18, 220, -8), door("D1", 626, 248, 16, 112, 3.0, 1.3), rect("W1", 626, 96, 16, 192),
    LAVA_FLOOR()],
   [G("C1", [880, 330], "green")],
   [[[125, 165], [182, 292], [228, 332]], [[642, 314], [760, 332], [838, 344]]],
   tip=TT("The belt keeps pushing while the door is closed.", "السير يواصل الدفع والباب مغلق."),
   hint=TT("Feed the belt, then build a path from the door to the circle.", "أوصل الكرات إلى السير، ثم ابنِ مسارًا من الباب إلى الدائرة."))

# 13 Fragile: a glass plank that only survives gentle balls.
C4(13, TT("Fragile", "قابل للكسر"), "medium",
   [L("L1", [75, 100], [240, 0], ["yellow"], 10)],
   [glass("GL1", 480, 330, 300, 14, 12, 4), LAVA_FLOOR()],
   [G("C1", [765, 388], "yellow")],
   [[[130, 170], [250, 275], [330, 308]]],
   tip=TT("Every bounce on glass counts as a hit.", "كل ارتداد على الزجاج يُحسب ضربة."),
   hint=TT("Lay the balls onto the plank smoothly, without a drop.", "ضع الكرات على اللوح الزجاجي بسلاسة، دون سقوط."))

# 14 Hot Air: two walls, two fans.
C4(14, TT("Hot Air", "هواء ساخن"), "hard",
   [L("L1", [75, 100], [240, 0], ["green"], 9)],
   [fan("F1", 275, 300, 90, 400, [0, -820]), rect("W1", 335, 420, 20, 240),
    fan("F2", 560, 330, 100, 400, [0, -1000]), rect("W2", 622, 420, 20, 240), LAVA_FLOOR()],
   [G("C1", [850, 430], "green")],
   [[[130, 170], [180, 200], [225, 215]], [[380, 330], [450, 350], [505, 356]], [[700, 400], [760, 428], [795, 438]]],
   tip=TT("Two walls, two fans.", "جداران ومروحتان."),
   hint=TT("Feed each fan gently and catch the balls after each hop.", "أدخل الكرات إلى كل مروحة بهدوء، والتقطها بعد كل قفزة."))

# 15 Airlock: two doors that are never open together.
C4(15, TT("Airlock", "غرفة العزل"), "hard",
   [L("L1", [75, 100], [240, 0], ["blue"], 8)],
   [rect("S1", 640, 430, 560, 16, 5), door("D1", 520, 362, 16, 118, 3.0, 1.5, 0.0), rect("W1", 520, 152, 16, 304),
    door("D2", 700, 378, 16, 118, 3.0, 1.5, 1.5), rect("W2", 700, 160, 16, 320), LAVA_FLOOR("LV0", 0, 350)],
   [G("C1", [880, 425], "blue")],
   [[[130, 170], [250, 330], [368, 392]]],
   tip=TT("When one door opens, the other closes.", "عندما يُفتح باب يُغلق الآخر."),
   hint=TT("Just bring the balls to the slab. They pass one door at a time.", "أوصل الكرات إلى اللوح فقط، وهي تعبر بابًا تلو الآخر."))

# 16 Lava Slalom: one line between fire above and fire below.
C4(16, TT("Lava Slalom", "تعرّج الحمم"), "expert",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [lava("LV1", 300, 105, 40, 210), lava("LV2", 520, 145, 40, 290), lava("LV3", 740, 105, 40, 210),
    lava("LV4", 410, 440, 40, 200), lava("LV5", 630, 470, 40, 140), LAVA_FLOOR("LV0", 0, 760)],
   [G("C1", [860, 440], "red")],
   [[[130, 170], [300, 258], [410, 290], [520, 340], [630, 362], [805, 430]]],
   tip=TT("Keep your line away from the heat on both sides.", "أبعد خطك عن الحرارة من الجهتين."),
   hint=TT("One long line: under, over, under, over.", "خط واحد طويل: من تحت، من فوق، من تحت، من فوق."))

# 17 Belt Maze: the middle belt leads to the lava.
C4(17, TT("Wrong Way", "الاتجاه الخاطئ"), "hard",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [conveyor("B1", 300, 200, 360, 18, 200), conveyor("B2", 710, 330, 300, 18, 200),
    conveyor("B3", 275, 430, 410, 18, 200), rect("W1", 62, 375, 16, 110), LAVA_FLOOR("LV0", 0, 480), LAVA_FLOOR("LV1", 650, 960)],
   [G("C1", [562, 472], "yellow")],
   [[[625, 250], [560, 305], [470, 350], [385, 385]]],
   tip=TT("The middle belt carries balls straight into the lava.", "السير الأوسط يحمل الكرات مباشرة إلى الحمم."),
   hint=TT("Catch the balls before the middle belt and turn them back to the lowest one.", "التقط الكرات قبل السير الأوسط وأعدها إلى السير السفلي."))

# 18 Pressure Cooker: the fan hammers balls against a glass ceiling.
C4(18, TT("Pressure Cooker", "طنجرة الضغط"), "hard",
   [L("L1", [75, 100], [240, 0], ["blue"], 9)],
   [fan("F1", 480, 345, 140, 390, [0, -1300]), rect("W1", 400, 175, 16, 350), rect("W2", 560, 270, 16, 540),
    glass("GL1", 480, 160, 144, 14, 3), LAVA_FLOOR("LV0", 0, 552)],
   [G("C1", [480, 82], "blue")],
   [[[130, 170], [300, 330], [404, 382]]],
   tip=TT("The circle waits above the glass.", "الدائرة تنتظر فوق الزجاج."),
   hint=TT("Roll the balls into the chimney from below. The fan does the rest.", "أدخل الكرات إلى المدخنة من الأسفل، والمروحة تكمل الباقي."))

# 19 Sorter Belt.
C4(19, TT("Sorter Belt", "سير الفرز"), "hard",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 14, 0.5)],
   [conveyor("B1", 425, 300, 190, 18, 200), rect("W1", 615, 455, 16, 170), rect("W2", 755, 455, 16, 170),
    gate("GA", 685, 372, 130, 14, "red"), LAVA_FLOOR("LV0", 0, 607), LAVA_FLOOR("LV1", 763, 960)],
   [G("C1", [685, 480], "red"), G("C2", [895, 445], "blue")],
   [[[130, 170], [250, 255], [328, 283]], [[772, 395], [815, 428], [850, 442]]],
   tip=TT("Red balls drop through the red lid. Blue balls bounce on.", "الكرات الحمراء تسقط من الغطاء الأحمر، والزرقاء تواصل طريقها."),
   hint=TT("Feed the belt, then catch the blue balls after the lid.", "أوصل الكرات إلى السير، ثم التقط الزرقاء بعد الغطاء."))

# 20 Eruption: belt, door, fan and glass in one run.
C4(20, TT("Eruption", "الثوران"), "expert",
   [L("L1", [75, 100], [120, 0], ["red"], 11)],
   [conveyor("B1", 300, 340, 260, 18, 220, -8), door("D1", 446, 264, 16, 112, 3.0, 1.4), rect("W0", 446, 104, 16, 208),
    fan("F1", 512, 330, 100, 360, [0, -1000]), rect("W1", 574, 410, 20, 260), rect("W4", 530, 142, 160, 16, 8),
    rect("W2", 750, 470, 16, 140), rect("W3", 890, 470, 16, 140), glass("GL1", 820, 393, 124, 14, 3),
    LAVA_FLOOR("LV0", 0, 742), LAVA_FLOOR("LV1", 898, 960)],
   [G("C1", [820, 482], "red")],
   [[[125, 165], [150, 280], [166, 338]], [[620, 300], [700, 350], [745, 372]]],
   tip=TT("Everything the volcano taught you, in one run.", "كل ما علّمك إياه البركان، في جولة واحدة."),
   hint=TT("Feed the belt. After the fan, guide the balls onto the glass lid.", "أوصل الكرات إلى السير، وبعد المروحة وجّهها إلى الغطاء الزجاجي."))


# ===================================================================== Chapter 5: Space
def ND(*rects):
    """No-draw zones for the level just defined."""
    LEVELS[-1][1]["drawingRules"]["forbiddenZones"] = [nodraw(*r) for r in rects]

ZERO_G = lambda id, cx, cy, w, h: zone(id, cx, cy, w, h, [0, 0])

# 1 Wormhole: in one ring, out of the other.
C5(1, TT("Wormhole", "ثقب دودي"), "intro",
   [L("L1", [75, 100], [240, 0], ["blue"], 8)],
   [portal("T1", [500, 430], [700, 120], 24)],
   [G("C1", [890, 300], "blue")],
   [[[230, 330], [380, 410], [470, 428]]],
   tip=TT("A ball that enters one ring leaves the other, just as fast.", "الكرة التي تدخل حلقة تخرج من الأخرى بالسرعة نفسها."),
   hint=TT("Ramp the balls into the lower ring.", "وجّه الكرات إلى الحلقة السفلية."))

# 2 Orbit: keep away from the black hole.
C5(2, TT("Dark Star", "النجم المظلم"), "intro",
   [L("L1", [75, 100], [240, 0], ["green"], 8)],
   [blackhole("H1", [480, 280], 14, 150, 900)],
   [G("C1", [860, 440], "green")],
   [[[130, 170], [300, 340], [480, 425], [805, 445]]],
   tip=TT("A black hole pulls balls in and swallows them.", "الثقب الأسود يجذب الكرات ويبتلعها."),
   hint=TT("Pass well below the ring of the black hole.", "مرّ بعيدًا من تحت حلقة الثقب الأسود."))

# 3 Attraction: the magnet lifts its own colour.
C5(3, TT("Attraction", "تجاذب"), "easy",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 14, 0.5)],
   [magnet("M1", [480, 180], "red", 190, 2200)],
   [G("C1", [480, 215], "red"), G("C2", [850, 440], "blue")],
   [[[130, 170], [320, 270], [480, 300], [800, 432]]],
   tip=TT("A magnet pulls only balls of its own color.", "المغناطيس يجذب الكرات التي بلونه فقط."),
   hint=TT("Pass close under the magnet: red balls lift off, blue ones roll on.", "مرّ قريبًا من تحت المغناطيس: الحمراء ترتفع والزرقاء تكمل."))

# 4 Mix It: red + yellow = orange.
C5(4, TT("Mix It", "امزجها"), "easy",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [mixer("X1", 520, 330, 130, 18, "yellow", 8)],
   [G("C1", [850, 440], "orange")],
   [[[130, 170], [330, 270], [455, 310]], [[600, 370], [720, 420], [805, 438]]],
   tip=TT("A mixer blends colors: red + yellow = orange.", "الخلّاط يمزج الألوان: أحمر + أصفر = برتقالي."),
   hint=TT("Roll the red balls over the yellow mixer.", "مرّر الكرات الحمراء فوق الخلّاط الأصفر."))

# 5 No-Fly Zone: you cannot draw where the balls float.
C5(5, TT("Quiet Zone", "المنطقة الصامتة"), "easy",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [ZERO_G("Z1", 480, 270, 200, 540)],
   [G("C1", [850, 440], "yellow")],
   [[[130, 170], [280, 240], [372, 262]], [[590, 300], [720, 400], [805, 432]]],
   tip=TT("You cannot draw inside the striped zone. Balls float straight through it.", "لا يمكنك الرسم داخل المنطقة المخططة، والكرات تطفو عبرها بخط مستقيم."),
   hint=TT("Aim the balls across, then catch them on the other side.", "صوّب الكرات لتعبر، ثم التقطها في الجهة الأخرى."))
ND((380, 0, 200, 540))

# 6 Slingshot: let the black hole bend the path.
C5(6, TT("Slingshot", "المقلاع"), "hard",
   [L("L1", [75, 100], [240, 0], ["blue"], 9)],
   [blackhole("H1", [640, 300], 14, 210, 1500)],
   [G("C1", [780, 450], "blue")],
   [[[130, 170], [330, 215], [490, 235]]],
   tip=TT("You cannot draw on the right side. Let the black hole bend the path.", "لا يمكنك الرسم في الجهة اليمنى. دع الثقب الأسود يحني المسار."),
   hint=TT("Send the balls past the black hole, not at it.", "أرسل الكرات بمحاذاة الثقب الأسود، لا نحوه."))
ND((500, 0, 460, 540))

# 7 Purple Rain: the right mixer is the high one.
C5(7, TT("Purple Rain", "مطر بنفسجي"), "medium",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [mixer("X1", 300, 400, 140, 18, "yellow", 6), mixer("X2", 520, 250, 120, 18, "blue", 8)],
   [G("C1", [850, 430], "purple")],
   [[[130, 165], [330, 212], [455, 232]], [[590, 285], [720, 400], [805, 425]]],
   tip=TT("Red + blue = purple. The yellow mixer below is a trap.", "أحمر + أزرق = بنفسجي. الخلّاط الأصفر في الأسفل فخ."),
   hint=TT("Keep the balls high, over the blue mixer.", "أبقِ الكرات عالية، فوق الخلّاط الأزرق."))

# 8 Double Portal: three rooms, two wormholes.
C5(8, TT("Three Rooms", "الغرف الثلاث"), "medium",
   [L("L1", [75, 100], [240, 0], ["green"], 8)],
   [rect("W1", 330, 270, 20, 540), rect("W2", 640, 270, 20, 540),
    portal("T1", [240, 430], [420, 110], 24), portal("T2", [560, 430], [730, 110], 24)],
   [G("C1", [880, 440], "green")],
   [[[130, 170], [180, 330], [218, 410]], [[400, 300], [480, 395], [528, 420]], [[700, 300], [790, 410], [836, 434]]],
   tip=TT("Each wormhole leads to the next room.", "كل ثقب دودي يقود إلى الغرفة التالية."),
   hint=TT("One ramp per room, each ending at a ring.", "منحدر في كل غرفة، ينتهي كل منها عند حلقة."))

# 9 Green Light: mix the key colour for the door.
C5(9, TT("Green Light", "الضوء الأخضر"), "medium",
   [L("L1", [75, 100], [240, 0], ["yellow"], 8)],
   [mixer("X1", 300, 300, 130, 18, "blue", 10), rect("W1", 520, 110, 24, 220), gate("G1", 520, 380, 24, 320, "green"),
    rect("P1", 300, 440, 140, 18, 6, color="red")],
   [G("C1", [840, 450], "green")],
   [[[130, 170], [190, 232], [226, 264]], [[372, 334], [440, 350], [498, 360]], [[545, 380], [700, 430], [795, 448]]],
   tip=TT("Yellow + blue = green, the color of the door.", "أصفر + أزرق = أخضر، لون الباب."),
   hint=TT("Mix green first, then roll through the green door.", "اصنع الأخضر أولًا، ثم اعبر الباب الأخضر."))

# 10 Between Two Holes.
C5(10, TT("Twin Holes", "الثقبان"), "medium",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [blackhole("H1", [480, 140], 14, 160, 1300), blackhole("H2", [480, 460], 14, 160, 1300)],
   [G("C1", [860, 350], "red")],
   [[[130, 170], [300, 270], [480, 300], [808, 345]]],
   tip=TT("Halfway between two black holes, their pulls cancel out.", "في منتصف المسافة بين ثقبين أسودين تتعادل قوتاهما."),
   hint=TT("Thread your line through the middle.", "مرّر خطك من المنتصف تمامًا."))

# 11 Portal Paint: the painter can only be reached through the wormhole.
C5(11, TT("Back Door", "الباب الخلفي"), "medium",
   [L("L1", [75, 100], [240, 0], ["blue"], 8)],
   [rect("W1", 450, 150, 20, 300), portal("T1", [300, 430], [600, 90], 24),
    rect("P1", 905, 230, 18, 320, 0, color="red")],
   [G("C1", [790, 440], "red")],
   [[[130, 170], [220, 350], [272, 412]], [[690, 330], [728, 395], [742, 420]]],
   tip=TT("The wall blocks the high road. The wormhole does not care.", "الجدار يسدّ الطريق العلوي، لكن الثقب الدودي لا يهتم."),
   hint=TT("Drop into the lower ring. The balls fly out toward the red wall.", "انزل في الحلقة السفلية، فتخرج الكرات طائرة نحو الجدار الأحمر."))

# 12 Deep Space: no gravity, so balls fly straight and slide along lines.
C5(12, TT("Deep Space", "الفضاء العميق"), "hard",
   [L("L1", [75, 100], [240, 0], ["green"], 8)],
   [ZERO_G("Z1", 580, 270, 760, 540), CEIL(200, 960)],
   [G("C1", [860, 150], "green")],
   [[[280, 290], [420, 400], [640, 370], [800, 215]]],
   tip=TT("Without gravity, balls fly straight and slide along your lines.", "بلا جاذبية تطير الكرات بخط مستقيم وتنزلق على خطوطك."),
   hint=TT("Draw one long bowl that turns the balls up toward the circle.", "ارسم قوسًا طويلًا يدير الكرات صعودًا نحو الدائرة."))

# 13 Magnetic Sort: two magnets, two colours.
C5(13, TT("Two Poles", "القطبان"), "hard",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 14, 0.5)],
   [magnet("M1", [400, 170], "red", 190, 2200), magnet("M2", [690, 205], "blue", 190, 2200)],
   [G("C1", [400, 205], "red"), G("C2", [690, 240], "blue")],
   [[[130, 170], [300, 278], [540, 300], [770, 322]]],
   tip=TT("Each magnet lifts only its own color.", "كل مغناطيس يرفع لونه فقط."),
   hint=TT("One line passing close under both magnets.", "خط واحد يمرّ قريبًا من تحت المغناطيسين."))

# 14 Mixing Station: one mixer, two new colours, two lids.
C5(14, TT("Mixing Station", "محطة المزج"), "hard",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 14, 0.5)],
   [mixer("X1", 335, 322, 124, 16, "yellow", 8),
    rect("W1", 390, 450, 20, 180), rect("W2", 530, 450, 20, 180), gate("GA", 460, 358, 122, 14, "orange", 5),
    rect("S1", 615, 372, 150, 14, 6),
    rect("W3", 690, 462, 20, 156), rect("W4", 830, 462, 20, 156), gate("GB", 760, 386, 122, 14, "green", 5)],
   [G("C1", [460, 478], "orange"), G("C2", [760, 482], "green")],
   [[[130, 170], [220, 260], [272, 296]]],
   tip=TT("Red + yellow = orange. Blue + yellow = green.", "أحمر + أصفر = برتقالي. أزرق + أصفر = أخضر."),
   hint=TT("Send every ball over the yellow mixer. The lids sort them.", "مرّر كل الكرات فوق الخلّاط الأصفر، والأغطية تفرزها."))

# 15 Tractor Beam: a strong magnet lifts balls over the wall.
C5(15, TT("Tractor Beam", "شعاع الجذب"), "hard",
   [L("L1", [75, 100], [240, 0], ["green"], 9)],
   [rect("W1", 520, 420, 24, 240), magnet("M1", [520, 200], "green", 260, 2600)],
   [G("C1", [820, 440], "green")],
   [[[130, 170], [300, 330], [420, 360]], [[640, 380], [730, 425], [775, 440]]],
   tip=TT("A strong magnet can lift balls over a wall.", "المغناطيس القوي يرفع الكرات فوق الجدار."),
   hint=TT("Roll toward the wall. Catch the balls after the magnet swings them over.", "ادحرج الكرات نحو الجدار، والتقطها بعد أن يؤرجحها المغناطيس."))

# 16 Zero-G Relay: aim through the quiet zone into the ring.
C5(16, TT("Ski Jump", "منصة القفز"), "hard",
   [L("L1", [75, 100], [240, 0], ["yellow"], 9)],
   [ZERO_G("Z1", 500, 270, 360, 540), portal("T1", [640, 150], [820, 110], 26)],
   [G("C1", [870, 400], "yellow")],
   [[[130, 170], [220, 330], [290, 350], [316, 335]]],
   tip=TT("In the quiet zone a ball keeps the direction you gave it.", "في المنطقة الصامتة تحافظ الكرة على الاتجاه الذي أعطيتها."),
   hint=TT("End your ramp with a lip that points at the ring.", "أنهِ منحدرك بحافة تصوّب نحو الحلقة."))
ND((320, 0, 360, 540))

# 17 Orange Key: mix the key for each wall.
C5(17, TT("Mixed Keys", "مفاتيح ممزوجة"), "hard",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [mixer("X1", 215, 215, 130, 22, "yellow", -20),
    switch("S1", 400, 200, 24, 400, "orange", [0, -360], 450), rect("W1", 400, 470, 24, 140),
    mixer("X2", 530, 400, 120, 20, "blue", 8),
    switch("S2", 690, 220, 24, 440, "blue", [0, -400], 450), rect("W2", 690, 490, 24, 100)],
   [G("C1", [850, 470], "blue")],
   [[[105, 225], [85, 290], [125, 335], [250, 335], [385, 330]], [[592, 418], [630, 425], [672, 430]], [[715, 445], [765, 453], [802, 459]]],
   tip=TT("The first wall opens for orange, the second for blue.", "الجدار الأول يُفتح للبرتقالي، والثاني للأزرق."),
   hint=TT("Mix orange for the first wall, then pass the blue mixer for the second.", "اصنع البرتقالي للجدار الأول، ثم مرّ على الخلّاط الأزرق للثاني."))

# 18 Portal Sort: only blue reaches the ring.
C5(18, TT("Customs", "نقطة العبور"), "hard",
   [L("L1", [75, 100], [240, 0], ["red", "blue"], 14, 0.5)],
   [rect("W1", 430, 122, 16, 244), gate("G1", 430, 330, 16, 170, "blue"), portal("T1", [488, 350], [730, 110], 26)],
   [G("C1", [398, 478], "red"), G("C2", [850, 430], "blue")],
   [[[130, 170], [280, 290], [376, 322]], [[790, 300], [838, 362], [846, 378]]],
   tip=TT("Only blue balls pass the blue door.", "الكرات الزرقاء فقط تعبر الباب الأزرق."),
   hint=TT("Stop your ramp before the door, so the red balls can drop.", "أوقف منحدرك قبل الباب لتسقط الكرات الحمراء."))

# 19 Falling Up: the right half of space is upside down.
C5(19, TT("Falling Up", "السقوط إلى الأعلى"), "hard",
   [L("L1", [75, 100], [240, 0], ["red"], 8)],
   [zone("Z1", 700, 270, 520, 540, [0, -630]), CEIL(440, 960), blackhole("H1", [640, 230], 14, 120, 1300)],
   [G("C1", [870, 52], "red")],
   [[[130, 170], [300, 285], [436, 322]]],
   tip=TT("On the right side, everything falls up.", "في الجهة اليمنى يسقط كل شيء إلى الأعلى."),
   hint=TT("Send the balls in low, away from the black hole.", "أدخل الكرات من الأسفل، بعيدًا عن الثقب الأسود."))

# 20 Supernova: mixer, wormhole and magnet in one run.
C5(20, TT("Supernova", "المستعر الأعظم"), "expert",
   [L("L1", [75, 100], [240, 0], ["red"], 10)],
   [mixer("X1", 520, 330, 130, 18, "yellow", 8), portal("T1", [665, 400], [740, 90], 26),
    magnet("M1", [860, 320], "orange", 210, 2400), blackhole("H1", [560, 130], 14, 110, 1300),
    rect("W1", 760, 380, 20, 320)],
   [G("C1", [860, 356], "orange")],
   [[[130, 170], [330, 270], [455, 310]]],
   tip=TT("Everything space taught you, in one run.", "كل ما علّمك إياه الفضاء، في جولة واحدة."),
   hint=TT("Mix orange, fall into the ring, and let the magnet finish the job.", "اصنع البرتقالي، اسقط في الحلقة، ودع المغناطيس يكمل المهمة."))
