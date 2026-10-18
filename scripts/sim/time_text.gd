class_name TimeText
extends RefCounted
## A time of day in words ("9:05 pm"), for plain classes that can't reach the Clock autoload.


static func label(m: int) -> String:
	var h := m / 60
	var mm := m % 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, "am" if h < 12 else "pm"]
