class_name SkyCycle
extends Node
## Owns the WorldEnvironment and sun; drives sky, fog, light and cloud colors from the hour.
## Supports per-level presets (fixed time, storm), a day/night toggle, lightning flashes,
## and the quality presets from Settings.

var hour := 17.0
var day_length := 1200.0  # real seconds per 24h
var paused := false
var allow_skip := true
var storm := 0.0  # 0 clear .. 1 full storm
var cloud_amount := 0.38
var fog_mul := 1.0
var flash := 0.0
var aurora := 0.0
var tint := Color(1, 1, 1)  # biome tint applied to sky/fog (e.g. warm desert haze)

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var cloud_mats: Array[ShaderMaterial] = []
var _hour_tween: Tween

# Keyed by sun height (sin of elevation).
const ZENITH := [[-0.3, Color(0.01, 0.015, 0.04)], [-0.05, Color(0.1, 0.12, 0.28)],
	[0.1, Color(0.24, 0.34, 0.62)], [0.45, Color(0.2, 0.42, 0.82)]]
const HORIZON := [[-0.3, Color(0.03, 0.04, 0.08)], [-0.05, Color(0.6, 0.34, 0.36)],
	[0.06, Color(1.0, 0.6, 0.38)], [0.22, Color(0.98, 0.8, 0.62)], [0.5, Color(0.72, 0.84, 0.96)]]
const SUN := [[-0.05, Color(1.0, 0.35, 0.15)], [0.08, Color(1.0, 0.62, 0.36)],
	[0.25, Color(1.0, 0.86, 0.7)], [0.6, Color(1.0, 0.97, 0.92)]]
const STORM_ZEN := Color(0.22, 0.24, 0.3)
const STORM_HOR := Color(0.46, 0.48, 0.54)
const STORM_SUN := Color(0.55, 0.6, 0.75)


func configure(preset: Dictionary) -> void:
	hour = preset.get("hour", hour)
	day_length = preset.get("day_length", day_length)
	paused = preset.get("paused", false)
	allow_skip = preset.get("allow_skip", true)
	storm = preset.get("storm", 0.0)
	cloud_amount = preset.get("clouds", cloud_amount)
	fog_mul = preset.get("fog", 1.0)
	aurora = preset.get("aurora", 0.0)
	tint = preset.get("tint", Color(1, 1, 1))


func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.0
	env.fog_height = -45.0
	env.fog_height_density = 0.012
	env.fog_sun_scatter = 0.25
	env.volumetric_fog_density = 0.003
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 120.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.6
	sun.shadow_blur = 1.2
	add_child(sun)
	sky_mat.set_shader_parameter("cloud_amount", lerp(cloud_amount, 0.75, storm))
	_apply_quality()
	Settings.changed.connect(_apply_quality)
	_apply()


func _apply_quality() -> void:
	var q := Settings.quality()
	env.ssao_enabled = q >= 1
	env.ssil_enabled = q >= 3
	env.volumetric_fog_enabled = q >= 2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [80.0, 120.0, 160.0, 220.0][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][q], true)


## 0 at night .. 1 in full day (storm darkens it a little).
func daylight() -> float:
	var theta := (hour - 6.0) / 12.0 * PI
	return smoothstep(-0.12, 0.06, sin(theta) * 0.9) * (1.0 - storm * 0.35)


func is_night() -> bool:
	var theta := (hour - 6.0) / 12.0 * PI
	return sin(theta) < -0.02


func toggle_day_night(duration := 3.0) -> void:
	var target := 12.5 if is_night() else 22.5
	if _hour_tween:
		_hour_tween.kill()
	var from := hour
	var to := target if target > from else target + 24.0
	_hour_tween = create_tween()
	_hour_tween.tween_method(func(h): hour = fmod(h, 24.0), from, to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func lightning() -> void:
	flash = 1.0


func _process(dt: float) -> void:
	flash = move_toward(flash, 0.0, dt * 2.5)
	if not paused and (_hour_tween == null or not _hour_tween.is_running()):
		var speed := 40.0 if allow_skip and Input.is_action_pressed("time_skip") else 1.0
		hour = fmod(hour + dt * 24.0 / day_length * speed, 24.0)
	_apply()


static func _grad(keys: Array, x: float) -> Color:
	if x <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if x <= keys[i][0]:
			var t: float = (x - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0])
			return (keys[i - 1][1] as Color).lerp(keys[i][1], t)
	return keys[-1][1]


func _apply() -> void:
	var theta := (hour - 6.0) / 12.0 * PI
	var sun_vec := Vector3(cos(theta), sin(theta) * 0.9, -0.35).normalized()
	var h := sun_vec.y
	var dayf := smoothstep(-0.12, 0.06, h)
	var zen := _grad(ZENITH, h).lerp(STORM_ZEN * lerp(0.25, 1.0, dayf), storm) * tint
	var hor := _grad(HORIZON, h).lerp(STORM_HOR * lerp(0.2, 1.0, dayf), storm) * tint
	var sc := _grad(SUN, h).lerp(STORM_SUN, storm)

	var light_vec := sun_vec
	if h > -0.06:
		sun.light_color = sc
		sun.light_energy = smoothstep(-0.06, 0.12, h) * lerp(1.5, 0.85, storm)
	else:
		light_vec = -sun_vec
		sun.light_color = Color(0.55, 0.65, 1.0)
		sun.light_energy = (1.0 - smoothstep(-0.25, -0.06, h)) * 0.55
	sun.light_energy += flash * 2.5
	sun.global_basis = Basis.looking_at(-light_vec, Vector3.UP)

	sky_mat.set_shader_parameter("zenith", zen)
	sky_mat.set_shader_parameter("horizon", hor)
	sky_mat.set_shader_parameter("below", hor.lerp(zen, 0.5) * 0.85)
	sky_mat.set_shader_parameter("sun_tint", sc * (1.0 - storm * 0.8))
	sky_mat.set_shader_parameter("sun_dir", sun_vec)
	sky_mat.set_shader_parameter("day", dayf * (1.0 - storm * 0.7))
	sky_mat.set_shader_parameter("flash", flash)
	sky_mat.set_shader_parameter("aurora", aurora)
	sky_mat.set_shader_parameter("cloud_amount", lerp(cloud_amount, 0.8, storm))
	sky_mat.set_shader_parameter("cloud_lit", sc.lerp(Color.WHITE, 0.4) * lerp(0.12, 1.0, dayf) * (1.0 - storm * 0.55))
	sky_mat.set_shader_parameter("cloud_dark", zen.lerp(hor, 0.6) * lerp(0.4, 1.0, dayf) * (1.0 - storm * 0.4))

	env.ambient_light_energy = lerp(0.6, 1.0, dayf) + storm * 0.5 + flash
	env.fog_light_color = hor.lerp(zen, 0.3)
	env.fog_density = 0.0016 * fog_mul * (1.0 + storm * 2.5)
	var lc := sc.lerp(Color(0.45, 0.55, 0.85), 1.0 - dayf)  # sunlight by day, moonlight by night
	env.volumetric_fog_albedo = lc.lerp(Color.WHITE, 0.5)
	env.adjustment_saturation = lerp(1.12, 0.8, storm)
	Sound.set_music_gain(lerp(0.7, 1.0, dayf))
	var glow := (1.0 - daylight()) * 0.9
	for k in ["mask", "trim"]:
		(Mats.get_mat(k) as ShaderMaterial).set_shader_parameter("emission_amount", glow * (0.6 if k == "mask" else 0.35))
	for m in cloud_mats:
		m.set_shader_parameter("lit_color", (lc * 0.7 + hor * 0.25 + Color(0.25, 0.25, 0.25)) * lerp(0.22, 1.1, dayf) * (1.0 - storm * 0.5) + Color.WHITE * flash * 0.5)
		m.set_shader_parameter("shadow_color", zen.lerp(hor, 0.6).lerp(Color.WHITE, 0.25) * lerp(0.2, 0.8, dayf) * (1.0 - storm * 0.4))
		m.set_shader_parameter("sun_dir", light_vec)
		m.set_shader_parameter("color", hor.lerp(Color.WHITE, 0.3) * lerp(0.15, 1.0, dayf) * (1.0 - storm * 0.5))
