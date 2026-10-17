extends Node
## Game time. One simulation tick is one game minute. At 1x, 4 game minutes pass per real second.

const MINUTES_PER_DAY := 1440
const BASE_MINUTES_PER_SECOND := 4.0
const SPEEDS: Array[int] = [0, 1, 2, 4]

var day: int = 0
var minute: int = 6 * 60
var speed: int = 0
var _accum: float = 0.0


func set_speed(s: int) -> void:
	if s in SPEEDS:
		speed = s
		EventBus.speed_changed.emit(speed)


func _process(delta: float) -> void:
	if speed == 0:
		return
	_accum += delta * BASE_MINUTES_PER_SECOND * float(speed)
	while _accum >= 1.0:
		_accum -= 1.0
		advance_minute()


func advance_minute() -> void:
	minute += 1
	if minute >= MINUTES_PER_DAY:
		minute = 0
		day += 1
	EventBus.time_changed.emit(day, minute)


## "Sat 14 June 1952 · 10:40 pm" style label. Day 0 is Monday 2 June 1952.
func label() -> String:
	return "%s · %s" % [date_label(day), time_label(minute)]


static func time_label(m: int) -> String:
	var h := m / 60
	var mm := m % 60
	var suffix := "am" if h < 12 else "pm"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, suffix]


static func date_label(d: int) -> String:
	const WEEKDAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	const MONTHS: Array[String] = ["January", "February", "March", "April", "May", "June", "July",
		"August", "September", "October", "November", "December"]
	const MONTH_DAYS: Array[int] = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]  # 1952 is a leap year
	var month := 5  # June
	var dom := 2 + d
	var year := 1952
	while dom > MONTH_DAYS[month]:
		dom -= MONTH_DAYS[month]
		month += 1
		if month == 12:
			month = 0
			year += 1
	return "%s %d %s %d" % [WEEKDAYS[d % 7], dom, MONTHS[month], year]


func to_dict() -> Dictionary:
	return {"day": day, "minute": minute}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	minute = int(d.get("minute", 360))
