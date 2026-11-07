class_name PersianText
extends RefCounted
## Persian text helpers, ported from client/Assets/Core/Text/PersianText.cs.
##
## One difference is deliberate and it is the whole reason the port is worth doing: Unity's TMP
## cannot shape Arabic script, so the C# side reorders and joins glyphs by hand. Godot's TextServer
## runs HarfBuzz (shaping) and ICU (bidi) natively, so the port must NOT reorder anything — a string
## that arrives here is the logical string an author wrote, and the renderer shapes it.
##
## What is still needed on this side is the other half of the C# contract: digits are Persian, and
## numbers are grouped and formatted the same way «۱۲٬۳۴۵» was. Those two things are pure text
## transforms and are safe to unit test without an engine.

const PERSIAN_DIGITS := "۰۱۲۳۴۵۶۷۸۹"
const ARABIC_DIGITS := "٠١٢٣٤٥٦٧٨٩"
const THOUSANDS_SEPARATOR := "٬"
const DECIMAL_SEPARATOR := "٫"
const FROM_WORD := "از"

## ۱۲۳۴ → ۱۲٬۳۴۵. Grouping is every three digits from the right, like the C# Number().
static func number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = THOUSANDS_SEPARATOR + grouped
	var text := to_persian_digits(grouped)
	return ("-" if negative else "") + text

static func decimal(value: float, places: int = 1) -> String:
	var text := String.num(value, places)
	return to_persian_digits(text).replace(".", DECIMAL_SEPARATOR)

## 95 → «۱:۳۵», 3 725 → «۱:۰۲:۰۵». The counter under the lives pill uses the short form.
static func time(total_seconds: int) -> String:
	var remaining := maxi(total_seconds, 0)
	var hours := remaining / 3600
	var minutes := (remaining % 3600) / 60
	var seconds := remaining % 60
	if hours > 0:
		return to_persian_digits("%d:%02d:%02d" % [hours, minutes, seconds])
	return to_persian_digits("%d:%02d" % [minutes, seconds])

## «۳ از ۵» — the shape of every counter in the HUD.
static func fraction(current: int, total: int) -> String:
	return number(current) + " " + FROM_WORD + " " + number(total)

## «مرحله ۳» is authored with an ASCII digit in some content files; this makes it Persian without
## the author having to think about it.
static func localize(text: String) -> String:
	return to_persian_digits(text)

static func to_persian_digits(text: String) -> String:
	var out := ""
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 48 and code <= 57:
			out += PERSIAN_DIGITS[code - 48]
		elif code >= 0x0660 and code <= 0x0669:
			out += PERSIAN_DIGITS[code - 0x0660]
		else:
			out += text[index]
	return out

## The digits only, for a label that is already Persian but may carry ASCII numerals.
static func to_ascii_digits(text: String) -> String:
	var out := ""
	for index in range(text.length()):
		var found := PERSIAN_DIGITS.find(text[index])
		if found >= 0:
			out += str(found)
		elif ARABIC_DIGITS.find(text[index]) >= 0:
			out += str(ARABIC_DIGITS.find(text[index]))
		else:
			out += text[index]
	return out

## True when a string carries at least one Persian/Arabic letter, used by the boot self-check.
static func contains_persian(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x0600 and code <= 0x06FF:
			return true
	return false
