extends Node
## Minimal English/Arabic UI strings. The board itself is never mirrored.

signal language_changed

const STRINGS := {
	"title": {"en": "Color Curves", "ar": "منحنيات الألوان"},
	"tagline": {"en": "Draw a path. Change the color. Fill the circle.", "ar": "ارسم مسارًا. غيّر اللون. املأ الدائرة."},
	"credit": {"en": "A game by Rawan Studio", "ar": "لعبة من روان ستوديو"},
	"a_game_by": {"en": "A game by", "ar": "لعبة من"},
	"studio_tagline": {"en": "A little heart in every game.", "ar": "لمسة حب في كل لعبة."},
	"play": {"en": "Play", "ar": "العب"},
	"settings": {"en": "Settings", "ar": "الإعدادات"},
	"levels": {"en": "Levels", "ar": "المراحل"},
	"back": {"en": "Back", "ar": "عودة"},
	"level_n": {"en": "Level %d", "ar": "المرحلة %d"},
	"chapter_n": {"en": "Chapter %d", "ar": "الفصل %d"},
	"remove_ads": {"en": "Remove ads", "ar": "إزالة الإعلانات"},
	"ads_removed": {"en": "Ads removed. Thank you!", "ar": "أُزيلت الإعلانات. شكرًا لك!"},
	"restore_purchases": {"en": "Restore purchases", "ar": "استعادة المشتريات"},
	"privacy_options": {"en": "Privacy options", "ar": "خيارات الخصوصية"},
	"theme_studio": {"en": "Studio", "ar": "المرسم"},
	"theme_garden": {"en": "Garden", "ar": "الحديقة"},
	"theme_lab": {"en": "Lab", "ar": "المختبر"},
	"theme_volcano": {"en": "Volcano", "ar": "البركان"},
	"theme_space": {"en": "Space", "ar": "الفضاء"},
	"undo": {"en": "Undo", "ar": "تراجع"},
	"redo": {"en": "Redo", "ar": "أعِد"},
	"delete": {"en": "Delete", "ar": "احذف"},
	"clear": {"en": "Clear", "ar": "امسح"},
	"launch": {"en": "Launch", "ar": "أطلق"},
	"stop_edit": {"en": "Stop & Edit", "ar": "أوقف وعدّل"},
	"pause": {"en": "Pause", "ar": "إيقاف"},
	"paused": {"en": "Paused", "ar": "اللعبة متوقفة"},
	"resume": {"en": "Resume", "ar": "تابِع"},
	"retry": {"en": "Retry", "ar": "أعد المحاولة"},
	"edit_path": {"en": "Edit Path", "ar": "عدّل المسار"},
	"next": {"en": "Next Level", "ar": "المرحلة التالية"},
	"replay": {"en": "Replay", "ar": "العب مجددًا"},
	"hint": {"en": "Hint", "ar": "تلميح"},
	"close": {"en": "Got it", "ar": "فهمت"},
	"hint_first": {"en": "Show first line", "ar": "أظهر الخط الأول"},
	"hint_all": {"en": "Show solution", "ar": "أظهر الحل"},
	"hint_trace": {"en": "Trace the dotted line", "ar": "ارسم فوق الخط المنقّط"},
	"guide_first": {"en": "Draw along the dotted line, then press Launch.", "ar": "ارسم على الخط المنقّط، ثم اضغط أطلق."},
	"new_piece": {"en": "New!", "ar": "جديد!"},
	"piece_poison": {"en": "Poison", "ar": "سُمّ"},
	"piece_poison_d": {"en": "Any ball that touches the poison is lost.", "ar": "أي كرة تلمس السم تُفقد."},
	"piece_lava": {"en": "Lava", "ar": "حِمَم"},
	"piece_lava_d": {"en": "Lava destroys balls, and your lines inside it burn away after a moment.", "ar": "الحمم تُتلف الكرات، والخطوط المرسومة داخلها تحترق بعد لحظة."},
	"piece_fan": {"en": "Fan", "ar": "مروحة"},
	"piece_fan_d": {"en": "Blows every ball that passes through in its direction.", "ar": "تدفع كل كرة تمر بها في اتجاهها."},
	"piece_conveyor": {"en": "Conveyor belt", "ar": "سير متحرك"},
	"piece_conveyor_d": {"en": "Carries balls along in the direction of its arrows.", "ar": "يحمل الكرات باتجاه أسهمه."},
	"piece_glass": {"en": "Glass", "ar": "زجاج"},
	"piece_glass_d": {"en": "Cracks with every hit and breaks after the number shown.", "ar": "يتشقق مع كل ضربة وينكسر بعد العدد المكتوب."},
	"piece_door": {"en": "Timed door", "ar": "باب مؤقّت"},
	"piece_door_d": {"en": "Opens and closes on a rhythm. The ring shows the time left.", "ar": "يُفتح ويُغلق بإيقاع ثابت، والدائرة تُظهر الوقت المتبقي."},
	"piece_portal": {"en": "Portals", "ar": "بوابات"},
	"piece_portal_d": {"en": "A ball that enters one ring comes out of the other, just as fast.", "ar": "الكرة التي تدخل حلقة تخرج من الأخرى بالسرعة نفسها."},
	"piece_blackhole": {"en": "Black hole", "ar": "ثقب أسود"},
	"piece_blackhole_d": {"en": "Pulls balls in and swallows any that reach its centre.", "ar": "يجذب الكرات ويبتلع كل كرة تصل إلى مركزه."},
	"piece_magnet": {"en": "Magnet", "ar": "مغناطيس"},
	"piece_magnet_d": {"en": "Pulls only balls of its own color.", "ar": "يجذب الكرات التي بلونه فقط."},
	"piece_mixer": {"en": "Color mixer", "ar": "خلّاط الألوان"},
	"piece_mixer_d": {"en": "Mixes colors: red + yellow = orange, red + blue = purple, blue + yellow = green.", "ar": "يمزج الألوان: أحمر + أصفر = برتقالي، أحمر + أزرق = بنفسجي، أزرق + أصفر = أخضر."},
	"no_hearts": {"en": "Out of hearts", "ar": "انتهت القلوب"},
	"no_hearts_body": {"en": "Watch a short video to get 3 hearts and keep your lines, or start over with a clean board.", "ar": "شاهد فيديو قصيرًا لتحصل على 3 قلوب وتحتفظ بخطوطك، أو ابدأ من جديد بلوحة فارغة."},
	"keep_lines": {"en": "Keep my lines", "ar": "احتفظ بخطوطي"},
	"start_over": {"en": "Start over", "ar": "ابدأ من جديد"},
	"piece_hearts": {"en": "Hearts", "ar": "القلوب"},
	"piece_hearts_d": {"en": "You have 3 hearts per level. A launch that fails costs one. Drawing and editing are always free.", "ar": "لديك 3 قلوب في كل مرحلة. كل إطلاق فاشل يكلّف قلبًا، أما الرسم والتعديل فمجانيان دائمًا."},
	"piece_star": {"en": "Bonus star", "ar": "نجمة إضافية"},
	"piece_star_d": {"en": "Roll any ball through the star to earn an extra star.", "ar": "مرّر أي كرة عبر النجمة لتكسب نجمة إضافية."},
	"piece_gate": {"en": "Color door", "ar": "باب ملوّن"},
	"piece_gate_d": {"en": "Only balls of the door's color can pass. Others bounce off.", "ar": "تعبر فقط الكرات التي بلون الباب، والباقي يرتد."},
	"piece_switch": {"en": "Switch wall", "ar": "جدار منزلق"},
	"piece_switch_d": {"en": "A ball of the wall's color slides it open for everyone.", "ar": "كرة بلون الجدار تفتحه للجميع."},
	"piece_splitter": {"en": "Prism", "ar": "منشور"},
	"piece_splitter_d": {"en": "Every ball that enters comes out as two.", "ar": "كل كرة تدخله تخرج كرتين."},
	"piece_bumper": {"en": "Bumper", "ar": "مصدّ"},
	"piece_bumper_d": {"en": "Bounces balls back harder than they hit it.", "ar": "يردّ الكرات بقوة أكبر من ضربتها."},
	"piece_flip": {"en": "Flip pad", "ar": "لوحة قلب"},
	"piece_flip_d": {"en": "Touching it flips that ball's gravity: it falls up.", "ar": "لمسها يقلب جاذبية الكرة فتسقط للأعلى."},
	"piece_booster": {"en": "Booster pad", "ar": "لوحة دفع"},
	"piece_booster_d": {"en": "Pushes balls hard in the direction of its arrows.", "ar": "تدفع الكرات بقوة باتجاه أسهمها."},
	"piece_zone": {"en": "Gravity zone", "ar": "منطقة جاذبية"},
	"piece_zone_d": {"en": "Inside the tinted area, gravity points another way.", "ar": "داخل المنطقة الملوّنة تتجه الجاذبية باتجاه آخر."},
	"piece_float": {"en": "Zero gravity", "ar": "انعدام الجاذبية"},
	"piece_float_d": {"en": "Balls fly in straight lines. Rails turn them like mirrors.", "ar": "تطير الكرات بخط مستقيم، والخطوط تديرها كالمرايا."},
	"piece_rock": {"en": "Rock", "ar": "صخر"},
	"piece_rock_d": {"en": "Solid ground: balls roll on it, but you can't draw on it.", "ar": "أرض صلبة: تتدحرج عليها الكرات، لكن لا يمكنك الرسم عليها."},
	"piece_power": {"en": "Power launcher", "ar": "مدفع قوي"},
	"piece_power_d": {"en": "Fires fast, long shots. Catch them softly.", "ar": "يطلق كرات سريعة وبعيدة. التقطها بلطف."},
	"piece_locked": {"en": "Locked goal", "ar": "هدف مقفل"},
	"piece_locked_d": {"en": "Opens only after the goal before it is full.", "ar": "يُفتح فقط بعد امتلاء الهدف الذي قبله."},
	"piece_ink": {"en": "Ink", "ar": "الحبر"},
	"piece_ink_d": {"en": "Your pen holds limited ink. The bar shows what's left; undo a line to get it back.", "ar": "قلمك يحمل حبرًا محدودًا. الشريط يُظهر ما تبقى، والتراجع عن خط يعيد حبره."},
	"piece_sideways": {"en": "Sideways gravity", "ar": "جاذبية جانبية"},
	"piece_sideways_d": {"en": "Here, balls fall to the side instead of down.", "ar": "هنا تسقط الكرات إلى الجانب بدل الأسفل."},
	"cancel": {"en": "Cancel", "ar": "إلغاء"},
	"strokes": {"en": "Strokes", "ar": "خطوط"},
	"ink": {"en": "Ink", "ar": "حبر"},
	"balls": {"en": "Balls", "ar": "كرات"},
	"level_complete": {"en": "Nice work!", "ar": "أحسنت!"},
	"new_best": {"en": "New personal best", "ar": "أفضل نتيجة لك حتى الآن"},
	"attempt_failed": {"en": "Give it another try", "ar": "جرّب مرة ثانية"},
	"star1": {"en": "Fill every circle", "ar": "املأ كل الدوائر"},
	"star2": {"en": "Use %s or fewer", "ar": "استخدم %s أو أقل"},
	"star3": {"en": "Collect the star", "ar": "اجمع النجمة"},
	"star2_ink": {"en": "Use %s m of ink or less", "ar": "استخدم %s م من الحبر أو أقل"},
	"ink_dry": {"en": "Out of ink: your line stopped here. Undo a line to get ink back.", "ar": "نفد الحبر: توقف خطك هنا. تراجع عن خط لاستعادة الحبر."},
	"ink_m": {"en": "Ink %s m", "ar": "حبر %s م"},
	"fail_short_one": {"en": "%d of 5 %s balls arrived. Adjust a curve and try again.", "ar": "وصلت %d من 5 كرات %s. عدّل المسار وجرّب مرة ثانية."},
	"fail_none": {"en": "No %s balls reached the circle yet. Adjust a curve and try again.", "ar": "لم تصل أي كرة %s إلى الدائرة بعد. عدّل المسار وجرّب مرة ثانية."},
	"fail_short_multi": {"en": "Some circles aren't full yet. Adjust a curve and try again.", "ar": "بعض الدوائر لم تمتلئ بعد. عدّل المسار وجرّب مرة ثانية."},
	"fail_no_balls": {"en": "Out of balls. Adjust a curve and try again.", "ar": "نفدت الكرات. عدّل المسار وجرّب مرة ثانية."},
	"fail_timeout": {"en": "Time's up — some balls kept bouncing.", "ar": "انتهى الوقت وبعض الكرات ما زالت تتحرك."},
	"reason_too_short": {"en": "", "ar": ""},
	"reason_outside": {"en": "Keep your line inside the board", "ar": "أبقِ الخط داخل اللوحة"},
	"reason_obstacle": {"en": "Draw around shapes, not through them", "ar": "ارسم حول الأشكال، لا عبرها"},
	"reason_protected": {"en": "Leave space around launchers and circles", "ar": "اترك مسافة حول المدفع والدوائر"},
	"reason_no_draw": {"en": "Drawing isn't allowed in the striped area", "ar": "الرسم غير متاح في المنطقة المخططة"},
	"reason_too_complex": {"en": "That line is too long. Split it in two.", "ar": "الخط طويل جدًا. قسّمه إلى خطين."},
	"reason_no_strokes": {"en": "No strokes left. Undo or delete a line.", "ar": "انتهت الخطوط. تراجع أو احذف خطًا."},
	"reason_no_ink": {"en": "Not enough ink. Try a shorter line.", "ar": "الحبر لا يكفي. جرّب خطًا أقصر."},
	"reason_geometry_cap": {"en": "Drawing limit reached. Delete a line first.", "ar": "وصلت لحد الرسم. احذف خطًا أولًا."},
	"sound": {"en": "Sound", "ar": "الصوت"},
	"haptics": {"en": "Vibration", "ar": "الاهتزاز"},
	"music_vol": {"en": "Music", "ar": "الموسيقى"},
	"sfx_vol": {"en": "Sound effects", "ar": "المؤثرات الصوتية"},
	"trails": {"en": "Ball trails", "ar": "أثر الكرات"},
	"ghost": {"en": "Last-attempt trace", "ar": "أثر المحاولة السابقة"},
	"preview": {"en": "Launch preview", "ar": "معاينة الإطلاق"},
	"reduced_motion": {"en": "Reduced motion", "ar": "تقليل الحركة"},
	"language": {"en": "Language", "ar": "اللغة"},
	"reset_progress": {"en": "Reset progress", "ar": "إعادة ضبط التقدّم"},
	"reset": {"en": "Reset", "ar": "أعِد الضبط"},
	"confirm_reset": {"en": "Erase all stars and saved drawings?", "ar": "مسح كل النجوم والرسومات المحفوظة؟"},
	"confirm_reset_body": {"en": "This can't be undone.", "ar": "لا يمكن التراجع عن ذلك."},
	"confirm_clear": {"en": "Clear the whole drawing?", "ar": "مسح الرسم بالكامل؟"},
	"confirm_clear_body": {"en": "You can still bring it back with Undo.", "ar": "يمكنك استعادته بزر التراجع."},
	"blue": {"en": "blue", "ar": "زرقاء"},
	"red": {"en": "red", "ar": "حمراء"},
	"green": {"en": "green", "ar": "خضراء"},
	"yellow": {"en": "yellow", "ar": "صفراء"},
	"diff_intro": {"en": "Intro", "ar": "تمهيدي"},
	"diff_easy": {"en": "Easy", "ar": "سهل"},
	"diff_medium": {"en": "Medium", "ar": "متوسط"},
	"diff_hard": {"en": "Hard", "ar": "صعب"},
	"diff_expert": {"en": "Expert", "ar": "خبير"},
	"all_done": {"en": "You finished every level!", "ar": "أنهيت كل المراحل!"},
}

var lang := "en"


func _ready() -> void:
	lang = str(Save.get_setting("lang"))


func t(key: String) -> String:
	var e: Dictionary = STRINGS.get(key, {})
	return str(e.get(lang, e.get("en", key)))


## "1 stroke" / "2 strokes"; Arabic: خطًا واحدًا / خطين / 3 خطوط / 11 خطًا.
func strokes_phrase(n: int) -> String:
	if lang == "ar":
		if n == 1:
			return "خطًا واحدًا"
		if n == 2:
			return "خطين"
		if n >= 3 and n <= 10:
			return "%d خطوط" % n
		return "%d خطًا" % n
	return "1 stroke" if n == 1 else "%d strokes" % n


func is_rtl() -> bool:
	return lang == "ar"


func set_lang(l: String) -> void:
	lang = l
	Save.set_setting("lang", l)
	language_changed.emit()
