class_name Rain
extends Node3D
## Rain near the camera: falling streaks, wet ground that darkens and shines, and it dries afterwards.

var particles: CPUParticles3D
var target := 0.0     ## 0 dry, 1 raining
var intensity := 0.0  ## eased towards target
var wetness := 0.0    ## ground wetness, slower than intensity


func _ready() -> void:
	particles = CPUParticles3D.new()
	particles.amount = 1400
	particles.lifetime = 1.1
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(22, 0.5, 22)
	particles.direction = Vector3(0.08, -1, 0.04)
	particles.spread = 2.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.initial_velocity_min = 14.0
	particles.initial_velocity_max = 17.0
	particles.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.42)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.85, 0.9, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	quad.material = mat
	particles.mesh = quad
	particles.emitting = false
	particles.position = Vector3(0, 16, 0)
	add_child(particles)


func set_amount(n: int) -> void:
	particles.amount = n


func step(delta: float, focus: Vector3) -> void:
	intensity = move_toward(intensity, target, delta * 0.25)
	var dry_rate := 0.02 if target < 0.5 else 0.08
	wetness = move_toward(wetness, target, delta * dry_rate)
	particles.emitting = intensity > 0.05
	global_position = focus
