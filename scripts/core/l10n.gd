class_name L10n
extends RefCounted
## Every player-facing string for Roadside Empire: Idle Tycoon (Persian + English).

const FALLBACK := "en"
const LANGUAGES: Array[String] = ["fa", "en"]

const STRINGS := {
	# --- Brand & Menu --------------------------------------------------------
	"app.title": {"fa": "امپراتوری بین‌راهی", "en": "Roadside Empire"},
	"app.subtitle": {
		"fa": "شبیه‌ساز تایکون پمپ‌بنزین و مجتمع رفاهی",
		"en": "Idle Gas Station Tycoon",
	},
	"menu.new_game": {"fa": "شروع امپراتوری جدید", "en": "Start New Empire"},
	"menu.continue": {"fa": "ادامهٔ بازی", "en": "Continue Empire"},
	"menu.language_target": {"fa": "English", "en": "فارسی"},
	"menu.quit": {"fa": "خروج", "en": "Quit"},
	"menu.record": {"fa": "بهترین اعتبار: {0}", "en": "Best Prestige: {0}"},
	"menu.hint": {
		"fa": "سلام رئیس! یک جایگاه متروکه در دل کویر را بازسازی کن، کارواش و رستوران بساز و امپراتوری بین‌راهی بساز!",
		"en": "Hello, Boss! Rebuild an abandoned desert gas station, unlock car washes & diners, and grow your empire!",
	},
	"menu.controls": {
		"fa": "کشیدن: جابه‌جایی دوربین • دو انگشت: زوم • لمس ساختمان: ارتقا و جمع‌آوری گاوصندوق",
		"en": "Drag: pan • Pinch: zoom • Tap station: collect safe & upgrade",
	},

	# --- Story Mode Territories ---------------------------------------------
	"town.desert": {"fa": "درهٔ شنی آریزونا", "en": "Dusty Canyon, AZ"},
	"town.mojave": {"fa": "واحهٔ صخرهٔ سرخ", "en": "Red Rock Oasis, CA"},
	"town.forest": {"fa": "گذرگاه جنگلی اورگن", "en": "Timberland Pass, OR"},
	"town.swamp": {"fa": "مرداب خروشان لوئیزیانا", "en": "Swamp & Furious, LA"},
	"town.star_city": {"fa": "بزرگراه استار سیتی", "en": "Star City Route, NV"},
	"town.vegas": {"fa": "بلوار طلایی وگاس", "en": "Golden Strip, Vegas"},

	# --- 8 Roadside Empire Facilities ---------------------------------------
	"business.gas_station.name": {"fa": "پمپ‌بنزین", "en": "Gas Station"},
	"business.gas_station.desc": {
		"fa": "تلمبه‌های سوخت، مخزن گاز و قلب درآمد ایستگاه",
		"en": "Fuel pumps, canopy bays and steady highway cash",
	},
	"business.car_wash.name": {"fa": "کارواش", "en": "Car Wash"},
	"business.car_wash.desc": {
		"fa": "تونل کف‌پاش و برس‌های چرخان برای شست‌وشوی سریع",
		"en": "Foam jets and spinning brushes for dusty travellers",
	},
	"business.auto_service.name": {"fa": "تعمیرگاه و لاستیک", "en": "Auto Service"},
	"business.auto_service.desc": {
		"fa": "جک هیدرولیک، تعویض لاستیک و تیونینگ خودرو",
		"en": "Hydraulic lifts, tire shop and heavy tuning",
	},
	"business.toilets.name": {"fa": "سرویس بهداشتی و دوش", "en": "Toilets & Showers"},
	"business.toilets.desc": {
		"fa": "استراحتگاه تمیز و سریع با رضایت بالای مسافرها",
		"en": "Clean restrooms and hot showers with fast turnover",
	},
	"business.diner.name": {"fa": "برگر و استیک باربیکیو", "en": "Burgers & BBQ"},
	"business.diner.desc": {
		"fa": "همبرگر زغالی، هات‌داگ و استیک داغ کنار جاده",
		"en": "Flame-grilled burgers, hot dogs and smokehouse steak",
	},
	"business.electric_charger.name": {"fa": "شارژر برقی سریع", "en": "EV Charging"},
	"business.electric_charger.desc": {
		"fa": "ایستگاه سوپرشارژ خورشیدی برای خودروهای مدرن",
		"en": "Solar supercharger bays for high-tech vehicles",
	},
	"business.motel.name": {"fa": "هتل بین‌راهی", "en": "Roadside Hotel"},
	"business.motel.desc": {
		"fa": "اتاق‌های راحت، استخر و اقامت شبانهٔ پرسود",
		"en": "Cozy rooms, neon sign and high-ticket overnight stays",
	},
	"business.drive_in.name": {"fa": "سینما خودرو و آرکید", "en": "Drive-In & Arcade"},
	"business.drive_in.desc": {
		"fa": "پردهٔ بزرگ سینما در فضای باز و دستگاه‌های آرکید",
		"en": "Giant outdoor cinema screen, pawn shop and arcade",
	},

	# --- Equipment Branches & Manager Ranks ---------------------------------
	"branch.capacity": {"fa": "جایگاه سرویس", "en": "Service Bays"},
	"branch.speed": {"fa": "شتاب‌دهنده", "en": "Speed Tech"},
	"branch.quality": {"fa": "تجهیزات مدرن", "en": "Value Tech"},
	"manager.rank.0": {"fa": "بدون مدیر (دستی)", "en": "No Manager (Manual)"},
	"manager.rank.1": {"fa": "مدیر سطح ۱", "en": "Manager Lv 1"},
	"manager.rank.2": {"fa": "مدیر سطح ۲", "en": "Manager Lv 2"},
	"manager.rank.3": {"fa": "مدیر سطح ۳", "en": "Manager Lv 3"},
	"manager.rank.4": {"fa": "مدیر سطح ۴", "en": "Manager Lv 4"},
	"manager.rank.5": {"fa": "مدیر سطح ۵", "en": "Manager Lv 5"},
	"manager.rank.6": {"fa": "مدیر سطح ۶", "en": "Manager Lv 6"},
	"manager.rank.7": {"fa": "مدیر سطح ۷", "en": "Manager Lv 7"},
	"manager.rank.8": {"fa": "مدیر سطح ۸", "en": "Manager Lv 8"},
	"manager.rank.9": {"fa": "مدیر سطح ۹", "en": "Manager Lv 9"},
	"manager.rank.10": {"fa": "مدیر ارشد سطح ۱۰", "en": "Master Manager Lv 10"},

	# --- Named Managers & Rarities ------------------------------------------
	"mgr.buck_novak": {"fa": "باک نواک", "en": "Buck Novak"},
	"mgr.rico_suds": {"fa": "ریکو رامیرز", "en": "Rico Suds"},
	"mgr.daisy_torque": {"fa": "دیزی تورک", "en": "Daisy Torque"},
	"mgr.sunny_clean": {"fa": "سانی لو", "en": "Sunny Lou"},
	"mgr.big_tex": {"fa": "شف بیگ تکس", "en": "Chef Big Tex"},
	"mgr.volt_vera": {"fa": "دکتر ورا ولت", "en": "Dr. Vera Volt"},
	"mgr.velvet_monroe": {"fa": "ولوت مونرو", "en": "Velvet Monroe"},
	"mgr.shregg_boudreaux": {"fa": "شرگ بودرو", "en": "Shregg Boudreaux"},
	"rarity.common": {"fa": "معمولی", "en": "Common"},
	"rarity.rare": {"fa": "کمیاب", "en": "Rare"},
	"rarity.epic": {"fa": "حماسی", "en": "Epic"},
	"rarity.legendary": {"fa": "افسانه‌ای", "en": "Legendary"},

	# --- HUD & Top/Bottom Bars ----------------------------------------------
	"hud.cash": {"fa": "پول", "en": "Cash"},
	"hud.gems": {"fa": "الماس", "en": "Gems"},
	"hud.bourbon": {"fa": "نوشیدنی مدیر", "en": "Bourbon"},
	"hud.reputation": {"fa": "اعتبار", "en": "Prestige"},
	"hud.star_lvl": {"fa": "سطح {0}", "en": "{0} lvl"},
	"hud.chapter": {"fa": "فصل {0} · {1}/{2}", "en": "Chapter {0} · {1}/{2}"},
	"hud.claim_reward": {"fa": "✓ دریافت جایزه!", "en": "✓ CLAIM REWARD!"},
	"hud.level": {"fa": "سطح {0}", "en": "Level {0}"},
	"hud.town_level": {"fa": "ستاره {0}", "en": "Star Lv {0}"},
	"hud.income": {"fa": "درآمد در دقیقه", "en": "Income / min"},
	"hud.income_value": {"fa": "{0} در دقیقه", "en": "{0}/min"},
	"hud.customers": {"fa": "خودرو در دقیقه", "en": "Vehicles / min"},
	"hud.capacity": {"fa": "جایگاه فعال", "en": "Active Bays"},
	"hud.capacity_value": {"fa": "{0} جایگاه", "en": "{0} bays"},
	"hud.upkeep": {"fa": "نگهداری", "en": "Upkeep"},
	"hud.upkeep_value": {"fa": "{0}/دقیقه", "en": "{0}/min"},
	"hud.efficiency": {"fa": "ضریب سود ×{0}", "en": "Profit Mult x{0}"},
	"hud.menu": {"fa": "منو", "en": "Menu"},
	"hud.save": {"fa": "ذخیره", "en": "Save"},
	"hud.saved": {"fa": "بازی ذخیره شد", "en": "Progress saved"},
	"hud.close": {"fa": "بستن", "en": "Close"},
	"hud.upgrade": {"fa": "ارتقا · 💵 {0}", "en": "UPGRADE · 💵 {0}"},
	"hud.max_level": {"fa": "حداکثر سطح (۱۰۰)", "en": "MAX LEVEL (100)"},
	"hud.branch": {"fa": "{0} · {1}/{2}", "en": "{0} · {1}/{2}"},
	"hud.branch_state": {"fa": "سطح {0} · 💵 {1}", "en": "Lv {0} · 💵 {1}"},
	"hud.hire_manager": {"fa": "استخدام ({0})", "en": "Unlock ({0})"},
	"hud.promote_manager": {"fa": "ارتقای مدیر ({0})", "en": "Level Up ({0})"},
	"hud.manager_max": {"fa": "حداکثر سطح مدیر", "en": "MAX MANAGER"},
	"hud.unlock": {"fa": "ساخت · 💵 {0}", "en": "BUILD · 💵 {0}"},
	"hud.locked": {"fa": "نیازمند ⭐ سطح {0}", "en": "Star Lv {0} required"},
	"hud.automated": {"fa": "✅ خودکار (جمع‌آوری اتوماتیک)", "en": "✅ AUTOMATED (Auto-Collect)"},
	"hud.manual_need": {
		"fa": "⚠️ دستی — نیازمند مدیر سطح {0}",
		"en": "⚠️ Manual — Needs Manager Lv {0}",
	},
	"hud.renovation_warn": {
		"fa": "نوسازی بعدی در سطح {0} (سود ×۲ + ⭐۱ · نیاز خودکار: مدیر سطح {1})",
		"en": "Next renovation at Lv {0} (x2 Profit + ⭐1 · Auto req: Mgr Lv {1})",
	},
	"hud.vault_collect": {"fa": "جمع‌آوری گاوصندوق: +{0}", "en": "Collect Safe: +{0}"},
	"hud.x2_idle": {"fa": "×۲ درآمد", "en": "x2 Income"},
	"hud.x2_active": {"fa": "⏱ {0} · ×۲ فعال", "en": "⏱ {0} · x2 Active"},
	"hud.nav_map": {"fa": "نقشه", "en": "Map"},
	"hud.nav_cases": {"fa": "صندوق", "en": "Cases"},
	"hud.nav_managers": {"fa": "مدیران", "en": "Managers"},
	"hud.nav_build": {"fa": "ساخت‌وساز", "en": "Upgrades"},
	"hud.offline_title": {"fa": "درآمد آفلاین ایستگاه!", "en": "Offline Empire Earnings!"},
	"hud.offline_body": {
		"fa": "در مدت {0} ساعت و {1} دقیقه نبودنت، مدیرانت 💵 {2} جمع کردند!",
		"en": "In {0}h {1}m away, your station managers collected 💵 {2}!",
	},
	"hud.offline_claim": {"fa": "دریافت پول!", "en": "COLLECT!"},
	"hud.manager_none": {"fa": "بدون مدیر", "en": "Unassigned"},
	"hud.completion": {"fa": "تکمیل ایستگاه {0}٪", "en": "Station {0}%"},
	"hud.completion_done": {"fa": "ایستگاه ۱۰۰٪ کامل!", "en": "Station 100% Complete!"},
	"hud.town_complete": {
		"fa": "تبریک رئیس! این ایستگاه ۱۰۰٪ تکمیل شد!",
		"en": "Boss! This roadside hub is 100% complete!",
	},
	"hud.complete_title": {"fa": "ایستگاه کامل شد!", "en": "Station Mastered!"},
	"hud.complete_body": {
		"fa": "تمام بخش‌ها ساخته و نوسازی شدند! ۳۵ الماس جایزه گرفتی و ایالت بعدی منتظر توست.",
		"en": "Every facility is built and maxed out! +35 Gems awarded — expand to the next state!",
	},
	"hud.complete_continue": {"fa": "ادامه بده!", "en": "Awesome!"},
	"hud.hint": {
		"fa": "سلام رئیس! روی ساختمان‌ها بزن تا پول گاوصندوق را جمع کنی و ایستگاه را ارتقا بدهی!",
		"en": "Hello Boss! Tap stations to collect safe cash, upgrade pumps & claim quests!",
	},
	"hud.map": {"fa": "نقشه و رقابت‌ها", "en": "Map & Modes"},
	"hud.settings": {"fa": "تنظیمات", "en": "Settings"},
	"hud.boost": {"fa": "⚡ {0} الماس", "en": "⚡ {0} Gems"},
	"hud.next_goal": {
		"fa": "قدم بعدی: ساخت {0} با 💵 {1}",
		"en": "Next build: {0} for 💵 {1}",
	},

	# --- 3 Parallel Chapter Quest Cards -------------------------------------
	"quest.unlock": {"fa": "باز کردن {0}", "en": "Unlock {0}"},
	"quest.level": {"fa": "ارتقای {0} به سطح {1}", "en": "Upgrade {0} to lvl {1}"},
	"quest.earn": {"fa": "کسب {0} پول", "en": "Earn {0} money"},
	"quest.manager": {"fa": "استخدام یا ارتقای مدیر", "en": "Unlock or upgrade Manager"},
	"quest.equip": {"fa": "ارتقای جایگاه یا تجهیزات", "en": "Buy 1 Bay or Tech upgrade"},
	"quest.serve": {"fa": "سرویس به {0} خودرو", "en": "Serve {0} customers"},

	# --- Cases, Cards & Managers Modal --------------------------------------
	"cases.title": {"fa": "صندوق‌های کارت و تدارکات", "en": "Supply Cases & Bourbon"},
	"cases.subtitle": {
		"fa": "کارت‌های مدیران و نوشیدنی 🥃 جمع کن تا ایستگاه‌ها کاملاً خودکار شوند!",
		"en": "Open cases for Manager Cards & Bourbon 🥃 to automate every station!",
	},
	"cases.free": {"fa": "جعبهٔ رایگان تدارکات", "en": "Free Supply Crate"},
	"cases.free_btn": {"fa": "باز کردن رایگان!", "en": "OPEN FREE!"},
	"cases.free_wait": {"fa": "آماده تا {0} ثانیه", "en": "Ready in {0}s"},
	"cases.common": {"fa": "صندوق استاندارد (۳ کارت)", "en": "Standard Case (3 Cards)"},
	"cases.rare": {"fa": "صندوق کمیاب (۵ کارت)", "en": "Rare Case (5 Cards)"},
	"cases.epic": {"fa": "صندوق حماسی (۸ کارت + افسانه‌ای)", "en": "Epic Case (8 Cards)"},
	"cases.open_gems": {"fa": "💎 {0} الماس", "en": "💎 {0} Gems"},
	"cases.bourbon_pack": {"fa": "بستهٔ ۶۰ نوشیدنی مدیر 🥃", "en": "60 Bourbon Barrel 🥃"},
	"cases.reward_toast": {
		"fa": "🎁 دریافت شد: +{0} پول · +{1} 🥃 · +{2} کارت مدیر!",
		"en": "🎁 Case opened: +{0} Cash · +{1} 🥃 · +{2} Cards!",
	},
	"managers.title": {"fa": "مدیران ایستگاه و کارت‌ها", "en": "Station Managers & Cards"},
	"managers.subtitle": {
		"fa": "نوشیدنی شما: 🥃 {0} — مدیرها پول را خودکار جمع می‌کنند و سود را چندبرابر می‌کنند",
		"en": "Your Bourbon: 🥃 {0} — Managers auto-collect safes & multiply station income",
	},
	"managers.cards": {"fa": "کارت‌ها: {0}/{1} · نیاز: 🥃 {2}", "en": "Cards: {0}/{1} · Cost: 🥃 {2}"},
	"managers.upgrade_cards": {"fa": "ارتقا با کارت + 🥃 {0}", "en": "Upgrade (Cards + 🥃 {0})"},
	"managers.upgrade_cash": {"fa": "استخدام فوری · 💵 {0}", "en": "Hire Now · 💵 {0}"},
	"build.title": {"fa": "ساخت‌وساز و نوسازی مجتمع", "en": "Build & Renovate Empire"},

	# --- World Map & Expeditions (Monster Hills, Iron Bones, Special Orders) -
	"map.title": {"fa": "نقشهٔ ایالت‌ها و حالت‌های ویژه", "en": "Territory Map & Expeditions"},
	"map.tab_story": {"fa": "🧭 بخش داستانی (ایالت‌ها)", "en": "🧭 Story Maps"},
	"map.tab_expeditions": {"fa": "🦖 رقابت‌ها و سفارش ویژه", "en": "🦖 Expeditions"},
	"map.subtitle": {
		"fa": "سطح ستارهٔ امپراتوری: ⭐ {0} · درآمد کل: 💵 {1}/دقیقه",
		"en": "Empire Star Level: ⭐ {0} · Total Income: 💵 {1}/min",
	},
	"map.summary": {
		"fa": "ایستگاه‌های فعال: {0} · کل سود: {1}/دقیقه",
		"en": "Active Hubs: {0} · {1}/min total",
	},
	"map.rates": {"fa": "ضریب سود ×{0} · ترافیک ×{1}", "en": "Profit x{0} · Traffic x{1}"},
	"map.progress": {"fa": "پیشرفت {0}٪ · ستاره {1}", "en": "{0}% Built · Star {1}"},
	"map.unvisited": {"fa": "آمادهٔ افتتاح!", "en": "Ready to Open!"},
	"map.here": {"fa": "📍 ایستگاه فعلی", "en": "📍 Current Hub"},
	"map.travel": {"fa": "سفر به ایالت", "en": "Open Hub"},
	"map.locked": {"fa": "قفل · نیازمند ⭐ سطح {0}", "en": "Locked · Needs ⭐ Lv {0}"},
	"exp.monster_title": {"fa": "🦖 تپه‌های مانستر (Monster Hills)", "en": "🦖 Monster Hills Expedition"},
	"exp.monster_desc": {
		"fa": "کامیون‌های غول‌پیکر مانستر وارد ایستگاه می‌شوند! سود ×۲.۵ به مدت ۹۰ ثانیه!",
		"en": "Giant Monster Trucks storm your station! x2.5 Income & heavy traffic for 90s!",
	},
	"exp.monster_btn": {"fa": "شروع رالی مانستر!", "en": "Launch Monster Hills!"},
	"exp.order_title": {"fa": "🚚 سفارش ویژه (کاروان VIP)", "en": "🚚 Special Orders (VIP Convoy)"},
	"exp.order_desc": {
		"fa": "در ۶۵ ثانیه به کاروان خودروها سرویس بده و پاداش فوری پول + ۲۸ 🥃 + کارت بگیر!",
		"en": "Serve a VIP vehicle convoy in 65s for instant Cash + 28 🥃 + Manager Card!",
	},
	"exp.order_btn": {"fa": "پذیرش قرارداد کاروان!", "en": "Accept Convoy Order!"},
	"exp.order_running": {"fa": "کاروان فعال: {0}/{1} ({2} ثانیه)", "en": "Convoy: {0}/{1} ({2}s)"},
	"exp.iron_title": {"fa": "🔩 اوراق‌فروشی آیرون بونز (Iron Bones)", "en": "🔩 Iron Bones Junkyard"},
	"exp.iron_desc": {
		"fa": "خودروهای فرسودهٔ اوراق‌فروشی را کاوش کن و نوشیدنی 🥃، الماس 💎 و کارت بیرون بکش!",
		"en": "Salvage rusted junkyard cars to extract Bourbon 🥃, Gems 💎 & Manager Cards!",
	},
	"exp.iron_btn": {"fa": "کاوش لاشه ({0}/۳ رایگان)", "en": "Salvage Car ({0}/3 Free)"},
	"exp.iron_gem": {"fa": "کاوش فوری (💎 ۵)", "en": "Salvage (💎 5)"},

	# --- Missions (Legacy & Guided) -----------------------------------------
	"mission.title": {"fa": "مأموریت", "en": "Mission"},
	"mission.claim": {"fa": "دریافت", "en": "Claim"},
	"mission.progress": {"fa": "{0} از {1}", "en": "{0} of {1}"},
	"mission.reward_coins": {"fa": "{0} دلار", "en": "${0}"},
	"mission.reward_gems": {"fa": "{0} الماس", "en": "{0} Gems"},
	"mission.reward": {"fa": "پاداش: {0}", "en": "Reward: {0}"},
	"msg.mission_claimed": {"fa": "پاداش دریافت شد: {0}", "en": "Quest claimed: {0}"},
	"mission.first_upgrade.title": {"fa": "شروع بازسازی", "en": "First Upgrades"},
	"mission.first_upgrade.desc": {"fa": "پمپ‌بنزین را ۳ سطح ارتقا بده.", "en": "Upgrade Gas Station 3 times."},
	"mission.open_car_wash.title": {"fa": "راه‌اندازی کارواش", "en": "Open Car Wash"},
	"mission.open_car_wash.desc": {"fa": "کارواش را از وضعیت مخروبه خارج کن.", "en": "Rebuild the derelict Car Wash."},
	"mission.reach_level_ten.title": {"fa": "اولین نوسازی", "en": "First Renovation"},
	"mission.reach_level_ten.desc": {"fa": "یک بخش را به سطح ۱۰ برسان.", "en": "Reach level 10 on any station."},
	"mission.hire_manager.title": {"fa": "اولین مدیر", "en": "First Manager"},
	"mission.hire_manager.desc": {"fa": "یک مدیر استخدام کن تا خودکار شود.", "en": "Assign a manager to automate."},
	"mission.open_auto_service.title": {"fa": "تعمیرگاه جاده", "en": "Open Auto Service"},
	"mission.open_auto_service.desc": {"fa": "تعمیرگاه و لاستیک‌فروشی را باز کن.", "en": "Open the Auto Service garage."},
	"mission.buy_branch.title": {"fa": "افزودن جایگاه", "en": "Expand Bays"},
	"mission.buy_branch.desc": {"fa": "۲ جایگاه یا تجهیزات جدید بخر.", "en": "Buy 2 bay or tech upgrades."},
	"mission.serve_customers.title": {"fa": "جادهٔ پررونق", "en": "Busy Highway"},
	"mission.serve_customers.desc": {"fa": "به ۱۲۰ خودرو سرویس بده.", "en": "Serve 120 vehicles."},
	"mission.open_all.title": {"fa": "شهر کامل بین‌راهی", "en": "Full Roadside City"},
	"mission.open_all.desc": {"fa": "هر ۸ ساختمان مجتمع را بساز.", "en": "Unlock all 8 facilities."},
	"mission.complete_town.title": {"fa": "امپراتور جاده", "en": "Roadside Emperor"},
	"mission.complete_town.desc": {"fa": "ایستگاه را ۱۰۰٪ کامل کن.", "en": "Reach 100% completion."},

	# --- Events -------------------------------------------------------------
	"event.title": {"fa": "رویداد", "en": "Event"},
	"event.started": {"fa": "رویداد فعال: {0}", "en": "Live Event: {0}"},
	"event.ended": {"fa": "پایان رویداد {0}", "en": "{0} finished"},
	"event.remaining": {"fa": "{0} ثانیه", "en": "{0}s"},
	"event.monster_hills": {"fa": "🦖 رالی کامیون‌های مانستر!", "en": "🦖 Monster Hills Rally!"},
	"event.holiday": {"fa": "🎉 کاروان تعطیلات (سود ×۲)", "en": "🎉 Holiday Convoy (x2)"},
	"event.rush_hour": {"fa": "🚗 ساعت شلوغی بزرگراه", "en": "🚗 Highway Rush Hour"},
	"event.bbq_fest": {"fa": "🥩 جشنوارهٔ باربیکیو", "en": "🥩 Roadside BBQ Fest"},
	"event.burning_fest": {"fa": "🔥 فستیوال برنینگ کویر", "en": "🔥 Desert Burning Fest"},
	"event.sandstorm": {"fa": "🌪️ طوفان شن کویر", "en": "🌪️ Desert Sandstorm"},

	# --- Settings & Toast Messages ------------------------------------------
	"settings.title": {"fa": "تنظیمات بازی", "en": "Game Settings"},
	"settings.music": {"fa": "موسیقی", "en": "Music"},
	"settings.sfx": {"fa": "جلوه‌های صوتی", "en": "Sound Effects"},
	"settings.haptics": {"fa": "لرزش لمسی", "en": "Haptics"},
	"settings.quality": {"fa": "کیفیت گرافیک", "en": "Graphics"},
	"settings.quality.low": {"fa": "سبک (ذخیره باتری)", "en": "Low (Battery)"},
	"settings.quality.medium": {"fa": "متوسط", "en": "Medium"},
	"settings.quality.high": {"fa": "بالا", "en": "High"},
	"settings.on": {"fa": "روشن", "en": "On"},
	"settings.off": {"fa": "خاموش", "en": "Off"},
	"settings.lang": {"fa": "زبان / Language", "en": "Language / زبان"},
	"settings.reset": {"fa": "شروع مجدد از صفر", "en": "Reset Progress"},
	"msg.no_cash": {"fa": "پول کافی نیست!", "en": "Not enough cash!"},
	"msg.no_gems": {"fa": "الماس کافی نیست!", "en": "Not enough gems!"},
	"msg.upgraded": {"fa": "{0} به سطح {1} ارتقا یافت!", "en": "{0} upgraded to Lv {1}!"},
	"msg.unlocked": {"fa": "🎉 {0} ساخته و راه‌اندازی شد!", "en": "🎉 {0} rebuilt & opened!"},
	"msg.manager_hired": {"fa": "✨ {0}: {1}", "en": "✨ {0}: {1}"},
	"msg.branch_upgraded": {"fa": "{0}: {1} سطح {2}", "en": "{0}: {1} Lv {2}"},
	"msg.save_ok": {"fa": "پیشرفت امپراتوری ذخیره شد", "en": "Empire progress saved"},
	"msg.auto_level": {"fa": "مدیر خودکار: {0} ← سطح {1}", "en": "Auto-Manager: {0} -> Lv {1}"},
	"msg.auto_branch": {"fa": "مدیر خودکار: {0} · {1} {2}", "en": "Auto-Manager: {0} · {1} {2}"},
	"msg.auto_rank": {"fa": "ارتقای خودکار مدیر: {0} · {1}", "en": "Auto-Promote: {0} · {1}"},
	"msg.boost": {"fa": "⚡ ضریب ×۲ درآمد برای ۵ دقیقه فعال شد!", "en": "⚡ x2 Income Boost active for 5 min!"},
	"msg.night": {"fa": "غروب کویر — نئون‌های ایستگاه روشن شدند", "en": "Desert dusk — station neons lit!"},
	"msg.morning": {"fa": "طلوع خورشید — روز پرتردد جدید!", "en": "Sunrise — new highway rush!"},
	"msg.daily": {
		"fa": "🎁 پاداش روزانه: +{0} پول · روز {1} (×{2})",
		"en": "🎁 Daily Login: +${0} · Day {1} (x{2})",
	},
	"msg.daily_gems": {"fa": "+{0} الماس", "en": "+{0} Gems"},
	"msg.tip": {"fa": "+{0} 💵", "en": "+${0} 💵"},
	"msg.travel": {"fa": "به {0} خوش آمدی رئیس!", "en": "Welcome to {0}, Boss!"},
	"msg.travel_locked": {"fa": "نیازمند ⭐ سطح {0} است!", "en": "Requires Star Level {0}!"},
	"msg.streak_lost": {"fa": "زنجیرهٔ روزانه از نو شروع شد", "en": "Daily streak restarted"},
}


static func translate(language: String, key: String, args: Array = []) -> String:
	var entry: Variant = STRINGS.get(key)
	if entry == null:
		push_warning("L10n: missing key '%s'" % key)
		return key
	var text := str(entry.get(language, entry.get(FALLBACK, key)))
	for i in args.size():
		text = text.replace("{%d}" % i, str(args[i]))
	return text


static func keys() -> Array:
	return STRINGS.keys()


static func has_language(language: String) -> bool:
	return LANGUAGES.has(language)


static func is_complete() -> bool:
	for key in STRINGS:
		var entry: Dictionary = STRINGS[key]
		for language in LANGUAGES:
			if not entry.has(language) or str(entry[language]).strip_edges().is_empty():
				return false
	return true
