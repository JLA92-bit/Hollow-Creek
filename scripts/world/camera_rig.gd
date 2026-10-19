class_name CameraRig
extends Node3D
## Perspective camera with a narrow field of view that orbits, pans, zooms and tilts around a focus
## point. Mouse, keyboard and touch (docs/HOUSE_BUILDING.md controls). Smoothly eased.

signal view_changed(forward: Vector3)

@export var fov := 35.0
@export var min_distance := 6.0
@export var max_distance := 220.0
@export var min_pitch := 12.0
@export var max_pitch := 82.0

var camera: Camera3D
var focus := Vector3.ZERO
var yaw := 35.0      ## degrees; 0 looks north (towards -z)
var pitch := 38.0    ## degrees above the horizon
var distance := 40.0
var bounds := Rect2(0, 0, 144, 96)
var height_fn: Callable
## In build mode one finger draws, so only two fingers move the camera.
var one_finger_pan := true

var _t_focus := Vector3.ZERO
var _t_yaw := 35.0
var _t_pitch := 38.0
var _t_distance := 40.0
var _touches: Dictionary = {}
var _drag_orbit := false
var _drag_pan := false
var _last_forward := Vector3.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	snap()


func set_view(p_focus: Vector3, p_yaw: float, p_pitch: float, p_distance: float, instant: bool = true) -> void:
	_t_focus = p_focus
	_t_yaw = p_yaw
	_t_pitch = clampf(p_pitch, min_pitch, max_pitch)
	_t_distance = clampf(p_distance, min_distance, max_distance)
	if instant:
		snap()


func snap() -> void:
	focus = _t_focus
	yaw = _t_yaw
	pitch = _t_pitch
	distance = _t_distance
	_update_camera()


func orbit_step(deg: float) -> void:
	_t_yaw += deg


func forward_xz() -> Vector3:
	var f := -camera.global_basis.z
	f.y = 0.0
	return f.normalized()


func _process(delta: float) -> void:
	var k := 1.0 if bool(Settings.get_value("reduce_motion")) else 1.0 - exp(-delta * 10.0)  # no easing when motion is reduced
	var move := Vector2(
		Input.get_axis(&"ui_left", &"ui_right") + (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0),
		Input.get_axis(&"ui_up", &"ui_down") + (1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0))
	if move != Vector2.ZERO and not Input.is_key_pressed(KEY_CTRL):
		_pan(move.normalized() * delta * distance * 0.9)
	if Input.is_key_pressed(KEY_Q):
		_t_yaw -= 70.0 * delta
	if Input.is_key_pressed(KEY_E):
		_t_yaw += 70.0 * delta
	focus = focus.lerp(_t_focus, k)
	yaw = lerpf(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	distance = lerpf(distance, _t_distance, k)
	_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	var ry := deg_to_rad(yaw)
	var rp := deg_to_rad(pitch)
	var offset := Vector3(-sin(ry) * cos(rp), sin(rp), cos(ry) * cos(rp)) * distance
	var pos := focus + offset
	if height_fn.is_valid():
		pos.y = maxf(pos.y, float(height_fn.call(pos.x, pos.z)) + 1.2)
	camera.global_transform = Transform3D(Basis(), pos).looking_at(focus, Vector3.UP)
	var f := forward_xz()
	if f.distance_to(_last_forward) > 0.05:
		_last_forward = f
		view_changed.emit(f)


## Glides the focus towards a point (following a resident), keeping the angle and distance.
func follow_point(p: Vector3) -> void:
	_t_focus = p


func _pan(screen_delta: Vector2) -> void:
	var ry := deg_to_rad(yaw)
	var right := Vector3(cos(ry), 0, sin(ry))
	var fwd := Vector3(sin(ry), 0, -cos(ry))
	_t_focus += right * screen_delta.x - fwd * screen_delta.y
	_t_focus.x = clampf(_t_focus.x, bounds.position.x, bounds.end.x)
	_t_focus.z = clampf(_t_focus.z, bounds.position.y, bounds.end.y)
	if height_fn.is_valid():
		_t_focus.y = float(height_fn.call(_t_focus.x, _t_focus.z))


func _zoom(factor: float) -> void:
	_t_distance = clampf(_t_distance * factor, min_distance, max_distance)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var dirn := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if mb.shift_pressed:
				_t_pitch = clampf(_t_pitch + dirn * 3.0, min_pitch, max_pitch)
			else:
				_zoom(1.0 + 0.12 * dirn)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag_orbit = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_pan = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_orbit:
			_t_yaw += mm.relative.x * 0.3
			_t_pitch = clampf(_t_pitch + mm.relative.y * 0.2, min_pitch, max_pitch)
		elif _drag_pan:
			_pan(-mm.relative * distance * 0.0016)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			_touches[sd.index] = sd.position
		var prev: Dictionary = _touches.duplicate()
		_touches[sd.index] = sd.position
		if _touches.size() == 1 and one_finger_pan:
			_pan(-sd.relative * distance * 0.0018)
		elif _touches.size() == 2:
			_two_finger(prev, _touches)
			var mid_prev := ((prev.values()[0] as Vector2) + (prev.values()[1] as Vector2)) * 0.5
			var mid_now := ((_touches.values()[0] as Vector2) + (_touches.values()[1] as Vector2)) * 0.5
			if not one_finger_pan:
				_pan(-(mid_now - mid_prev) * distance * 0.0018)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		_pan((event as InputEventPanGesture).delta * distance * 0.01)


## Pinch to zoom, twist to orbit, and a two-finger vertical drag to tilt.
func _two_finger(before: Dictionary, after: Dictionary) -> void:
	var ids := after.keys()
	var a0: Vector2 = before[ids[0]]
	var b0: Vector2 = before[ids[1]]
	var a1: Vector2 = after[ids[0]]
	var b1: Vector2 = after[ids[1]]
	var d0 := a0.distance_to(b0)
	var d1 := a1.distance_to(b1)
	if d0 > 1.0 and d1 > 1.0:
		_zoom(d0 / d1)
	var twist := (b1 - a1).angle() - (b0 - a0).angle()
	_t_yaw += rad_to_deg(wrapf(twist, -PI, PI))
	var mid_dy := ((a1 + b1) - (a0 + b0)).y * 0.5
	_t_pitch = clampf(_t_pitch + mid_dy * 0.15, min_pitch, max_pitch)
