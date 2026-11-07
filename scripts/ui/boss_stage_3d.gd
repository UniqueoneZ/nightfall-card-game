class_name BossStage3D
extends Control
## 3D Boss 舞台：SubViewport 里搭一个真正的 3D 场景（网格 + PBR + 轮廓光），
## 渲染成透明底纹理叠在战斗界面中。待机漂浮、符文环旋转、受击闪光。

var viewport: SubViewport
var world_root: Node3D
var pivot: Node3D
var shard_pivot: Node3D
var ring_pivot: Node3D
var core_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var key_light: DirectionalLight3D
var rim_light: OmniLight3D

var tint := Color("#8A6FB0")
var _t := 0.0
var _flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO:
		size = Vector2(520, 520)

	viewport = SubViewport.new()
	viewport.size = Vector2i(560, 560)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	_build_scene()

	var rect := TextureRect.new()
	rect.texture = viewport.get_texture()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	set_process(true)

func _build_scene() -> void:
	world_root = Node3D.new()
	viewport.add_child(world_root)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.38, 0.55)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world_root.add_child(env)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.55, 6.4)
	cam.fov = 40.0
	world_root.add_child(cam)
	cam.look_at(Vector3(0, 0.05, 0))

	key_light = DirectionalLight3D.new()
	key_light.position = Vector3(2.4, 3.2, 3.0)
	key_light.light_energy = 1.35
	key_light.light_color = Color(1.0, 0.95, 0.88)
	world_root.add_child(key_light)
	key_light.look_at(Vector3.ZERO)

	rim_light = OmniLight3D.new()
	rim_light.position = Vector3(-2.2, -0.6, -1.8)
	rim_light.light_energy = 3.2
	rim_light.omni_range = 6.0
	rim_light.light_color = Color(0.75, 0.55, 1.0)
	world_root.add_child(rim_light)

	pivot = Node3D.new()
	pivot.scale = Vector3(0.92, 0.92, 0.92)
	world_root.add_child(pivot)

	# ---- 核心球体 ----
	core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.06, 0.06, 0.09)
	core_mat.metallic = 0.75
	core_mat.roughness = 0.28
	core_mat.emission_enabled = true
	core_mat.emission = tint
	core_mat.emission_energy_multiplier = 0.35
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.92
	sphere.height = 1.84
	sphere.radial_segments = 48
	sphere.rings = 24
	core.mesh = sphere
	core.material_override = core_mat
	pivot.add_child(core)

	# ---- 外层晶壳（低面数，半透明） ----
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.emission_enabled = true
	shell_mat.emission = tint
	shell_mat.emission_energy_multiplier = 0.6
	shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell := MeshInstance3D.new()
	var ico := SphereMesh.new()
	ico.radius = 1.22
	ico.height = 2.44
	ico.radial_segments = 9
	ico.rings = 5
	shell.mesh = ico
	shell.material_override = shell_mat
	pivot.add_child(shell)

	# ---- 瞳孔 ----
	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 1, 1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 1, 1)
	eye_mat.emission_energy_multiplier = 2.2
	var eye := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.15
	es.height = 0.3
	es.radial_segments = 24
	es.rings = 12
	eye.mesh = es
	eye.material_override = eye_mat
	eye.position = Vector3(0, 0.02, 0.86)
	pivot.add_child(eye)

	# ---- 符文环 ----
	ring_pivot = Node3D.new()
	pivot.add_child(ring_pivot)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.9, 0.8, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = tint
	ring_mat.emission_energy_multiplier = 1.6
	ring_mat.metallic = 0.6
	ring_mat.roughness = 0.3
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.16
	torus.outer_radius = 1.21
	torus.rings = 64
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = ring_mat
	ring_pivot.add_child(ring)

	# ---- 环绕碎片 ----
	shard_pivot = Node3D.new()
	pivot.add_child(shard_pivot)
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.12, 0.10, 0.16)
	shard_mat.metallic = 0.8
	shard_mat.roughness = 0.2
	shard_mat.emission_enabled = true
	shard_mat.emission = tint
	shard_mat.emission_energy_multiplier = 1.1
	for i in 7:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.10, 0.34, 0.10)
		shard.mesh = box
		shard.material_override = shard_mat
		var a := TAU * float(i) / 7.0
		var r := 1.42 + 0.09 * float(i % 3)
		shard.position = Vector3(cos(a) * r, sin(a * 1.7) * 0.45, sin(a) * r)
		shard.rotation = Vector3(a * 1.3, a, a * 0.7)
		shard_pivot.add_child(shard)

func _process(delta: float) -> void:
	_t += delta
	if pivot != null:
		pivot.position.y = sin(_t * 0.9) * 0.09
		pivot.rotation.y = sin(_t * 0.35) * 0.38
	if ring_pivot != null:
		ring_pivot.rotation.y = _t * 0.42
		ring_pivot.rotation.x = 0.38 + sin(_t * 0.5) * 0.08
	if shard_pivot != null:
		shard_pivot.rotation.y = -_t * 0.24

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.2)
	if core_mat != null:
		var pulse := 0.32 + 0.10 * sin(_t * 2.1)
		core_mat.emission_energy_multiplier = pulse + _flash * 1.2
	if rim_light != null:
		rim_light.light_energy = 3.2 + _flash * 4.0
	if eye_mat != null:
		eye_mat.emission_energy_multiplier = 2.0 + 0.6 * sin(_t * 3.0) + _flash * 2.0

func flash() -> void:
	_flash = 1.0
