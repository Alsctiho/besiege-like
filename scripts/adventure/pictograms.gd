class_name JourneyPictograms
extends RefCounted

const INK := "#675344"
const PATHS := {
	"core": '<path d="M30 28L64 12 99 29V80L65 100 30 80Z M30 28L65 46 99 29 M65 46V100"/><path d="M37 44L58 55V72L37 62Z" fill="#675344"/><path d="M41 51L46 53 M50 55L55 58" stroke="#efe6cd"/><circle cx="85" cy="62" r="7"/>',
	"wheel": '<path d="M24 32H96V72H24Z M35 32V24H85V32"/><circle cx="33" cy="86" r="14"/><circle cx="86" cy="86" r="14"/><circle cx="33" cy="86" r="5"/><circle cx="86" cy="86" r="5"/><path d="M45 86H73"/>',
	"drill": '<path d="M17 45H47V81H17Z M47 45L108 63 47 81Z M58 48L54 78 M72 52L68 74 M86 56L82 70 M17 56H8V70H17"/>',
	"rotor": '<circle cx="64" cy="61" r="10"/><path d="M58 51L39 14 57 10 68 49 M75 60L115 63 111 81 72 70 M58 70L33 103 19 90 49 61 M60 74V108H69V74"/>',
	"fireball": '<path d="M13 49H58V78H13Z M58 49L73 55V71L58 78 M23 78V95H48V78"/><path d="M89 78C70 63 93 52 87 31 113 48 123 66 104 80Z"/><path d="M89 58L100 48 105 70"/>',
	"blower": '<circle cx="43" cy="62" r="28"/><circle cx="43" cy="62" r="7"/><path d="M42 55L28 44 31 62 M50 62L58 45 42 55 M42 69L58 79 50 62 M35 63L28 78 42 69 M82 43H116 M82 62H109 M82 81H116"/>',
	"rod": '<path d="M12 47H34V79H12Z M34 53H60V73H34 M60 57H90V69H60 M90 62H115 M110 53V78 M20 79V94H28V79"/>',
	"booster": '<path d="M25 37H68L87 49V76L68 89H25Z M17 47H25V79H17 M40 38V88 M70 48V77 M90 51L117 44 107 62 119 81 90 75"/>',
	"rock": '<path d="M12 93L26 36 51 23 79 33 111 92Z M51 23L62 54 49 64 66 95 M79 33L72 59 94 71"/>',
	"lamp": '<path d="M20 69H106L93 83H34Z M49 83V106H79V83"/><path d="M64 68C32 51 68 35 56 12 89 32 94 57 64 68Z"/>',
	"gate": '<path d="M20 109V21H106V109 M35 109V38H91V109 M20 21H106 M57 57L75 70 57 83"/>',
	"flight": '<path d="M24 105H105 M35 89L72 52 M72 52H57 M72 52V68 M47 62L22 35 41 29 64 49 M43 65V92"/>',
	"hand": '<path d="M37 110L25 64Q27 53 36 62L44 74V28Q44 15 54 27V58 18Q64 6 69 20V60 32Q80 20 85 34V64 45Q96 36 99 49V82L86 110Z"/>',
	"move": '<path d="M64 10V113 M12 63H116 M64 10L49 27 M64 10L79 27 M64 113L49 96 M64 113L79 96 M12 63L29 48 M12 63L29 78 M116 63L99 48 M116 63L99 78"/>',
	"turn": '<path d="M30 36Q76 9 101 50V73 M101 73L83 56 M101 73L116 51 M98 91Q51 120 26 78V55 M26 55L9 76 M26 55L44 72"/>',
	"check": '<path d="M24 62L52 88 104 29"/>',
	"close": '<path d="M30 29L97 96 M97 29L30 96"/>',
	"remove": '<path d="M21 27H104 M37 27V14H88V27 M30 27L37 109H89L97 27 M52 44V93 M75 44V93"/>',
	"empty": '<rect x="27" y="27" width="74" height="74" rx="11" stroke-dasharray="7 8"/><path d="M64 44V84 M44 64H84"/>',
	"forward": '<path d="M64 107V24 M64 24L38 54 M64 24L90 54"/>',
}
static var _cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if not _cache.has(kind):
		_cache[kind] = from_svg('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g stroke="%s" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" fill="none">%s</g></svg>' % [INK, PATHS.get(kind, PATHS.empty)])
	return _cache[kind]

static func from_svg(svg: String) -> Texture2D:
	var image := Image.new()
	var error := image.load_svg_from_string(svg)
	if error != OK:
		push_error("JourneyPictograms: invalid SVG")
		return null
	return ImageTexture.create_from_image(image)

static func paper() -> Texture2D:
	if not _cache.has("paper"):
		var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
		for y in 128:
			for x in 128:
				var grain := float((x * 73 + y * 131 + x * y * 17) % 29) / 29.0
				image.set_pixel(x, y, Color(0.88 + grain * 0.06, 0.83 + grain * 0.06, 0.71 + grain * 0.06))
		_cache.paper = ImageTexture.create_from_image(image)
	return _cache.paper

static func symbol_markup(kind: String, x: float, y: float, scale_value: float) -> String:
	return '<g transform="translate(%s %s) scale(%s)" stroke="%s" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" fill="none">%s</g>' % [x, y, scale_value, INK, PATHS.get(kind, PATHS.empty)]

static func lesson(kind: String) -> Texture2D:
	var cache_key := "lesson_" + kind
	if _cache.has(cache_key): return _cache[cache_key]
	var target := {"drill": "rock", "fireball": "lamp", "blower": "fireball", "rod": "hand", "rotor": "flight", "booster": "move", "wheel": "move"}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="280" viewBox="0 0 640 280">'
	svg += symbol_markup(kind, 22, 44, 0.72)
	svg += '<path d="M143 84V126 M122 105H164" stroke="%s" stroke-width="5"/>' % INK
	svg += symbol_markup("core", 180, 40, 1.05)
	svg += '<path d="M331 109H405 M395 97L409 109 395 121" fill="none" stroke="%s" stroke-width="4"/>' % INK
	svg += symbol_markup(target.get(kind, "gate"), 451, 33, 1.15)
	svg += '<path d="M215 221Q325 265 476 196 M457 196H476V215" fill="none" stroke="%s" stroke-width="4"/>' % INK
	svg += symbol_markup(kind, 379, 146, 0.48)
	svg += '</svg>'
	_cache[cache_key] = from_svg(svg)
	return _cache[cache_key]

static func flight_recipe() -> Texture2D:
	if _cache.has("flight_recipe"): return _cache.flight_recipe
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="280" viewBox="0 0 640 280">'
	svg += symbol_markup("rotor", 20, 28, 0.78)
	svg += symbol_markup("booster", 20, 145, 0.78)
	svg += '<path d="M143 90V190 M122 140H164" stroke="%s" stroke-width="5"/>' % INK
	svg += symbol_markup("core", 180, 56, 1.05)
	svg += '<path d="M330 122H407 M395 110L409 122 395 134" fill="none" stroke="%s" stroke-width="4"/>' % INK
	svg += symbol_markup("flight", 447, 55, 1.12)
	svg += '</svg>'
	_cache.flight_recipe = from_svg(svg)
	return _cache.flight_recipe

static func ground_controls() -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512" viewBox="0 0 1024 512">'
	var keys := ["WASD", "F", "Tab", "Q / E", "Z / X", "↑ / ↓"]
	var symbols := ["move", "hand", "core", "core", "core", "core"]
	for i in 6:
		var x := 26 + (i % 3) * 330
		var y := 28 + int(floorf(float(i) / 3.0)) * 237
		svg += '<rect x="%s" y="%s" width="112" height="53" rx="19" fill="%s"/>' % [x, y + 22, INK]
		svg += '<text x="%s" y="%s" text-anchor="middle" font-family="sans-serif" font-size="26" font-weight="bold" fill="#e8d8b5">%s</text>' % [x + 56, y + 57, keys[i]]
		svg += symbol_markup(symbols[i], x + 141, y, 0.9)
	svg += '</svg>'
	return from_svg(svg)
