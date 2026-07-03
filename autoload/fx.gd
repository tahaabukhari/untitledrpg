extends Node2D
## Fx — scene-safe VFX / damage-number manager (autoload).
## Transient effects (particles, arcs, slashes, damage numbers, beams) are
## parented HERE instead of the current scene, so a scene change mid-effect
## never orphans them. Every tween callback is guarded with is_instance_valid().

# ─── Colors ──────────────────────────────────────────────────────────────────
const HIT_PARTICLE_COLOR := Color(1.0, 0.95, 0.6, 1.0)
const DAMAGE_COLOR := Color(1.0, 0.3, 0.3, 1.0)
const PLAYER_DAMAGE_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const SWING_ARC_COLOR := Color(1.0, 1.0, 0.8, 0.95)
const SLASH_COLOR := Color(1.0, 1.0, 1.0, 0.9)


var _last_scene: Node = null


func _process(_delta: float) -> void:
	# Clear leftover effects whenever the scene changes so nothing lingers
	# visually across levels (nodes here are already crash-safe regardless).
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == _last_scene:
		return
	_last_scene = scene
	for child in get_children():
		child.queue_free()


# ─── Hit particles ───────────────────────────────────────────────────────────

func hit_particles(pos: Vector2, color: Color = HIT_PARTICLE_COLOR) -> void:
	for i in range(5):
		var p := ColorRect.new()
		p.size = Vector2(2, 2)
		p.color = color
		p.z_index = 100
		add_child(p)
		p.global_position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position:y", p.global_position.y - randf_range(8, 16), 0.25)
		tw.tween_property(p, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ─── Damage numbers ──────────────────────────────────────────────────────────

func damage_number(pos: Vector2, amount: int, color: Color = DAMAGE_COLOR) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.z_index = 100
	add_child(label)
	label.global_position = pos + Vector2(randf_range(-8, 8), -20)

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 30, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free())


# ─── Swing arc (light weapon swoosh) ─────────────────────────────────────────

func swing_arc(origin: Vector2, dir: float) -> void:
	var arc := Line2D.new()
	arc.width = 4.0
	arc.default_color = SWING_ARC_COLOR
	arc.z_index = 100
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND

	var arc_radius := 20.0
	for i in range(9):
		var t: float = float(i) / 8.0
		var angle: float = lerpf(-PI * 0.4, PI * 0.4, t)
		var pt := Vector2(cos(angle) * arc_radius * dir, sin(angle) * arc_radius)
		pt += Vector2(dir * 14, 0)
		arc.add_point(pt)

	add_child(arc)
	arc.global_position = origin

	var tw := arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(arc, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(arc):
			arc.queue_free())

	for i in range(5):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(1.0, 0.9, 0.5, 0.9)
		p.z_index = 100
		add_child(p)
		p.global_position = origin + Vector2(dir * randf_range(10, 28), randf_range(-12, 12))
		var tw2 := p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + Vector2(dir * randf_range(6, 16), randf_range(-8, 8)), 0.22)
		tw2.tween_property(p, "modulate:a", 0.0, 0.22)
		tw2.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ─── Beam (mage laser) ───────────────────────────────────────────────────────

func beam(start: Vector2, end: Vector2, width: float,
		core_color: Color = Color(0.75, 0.9, 1.0, 1.0),
		glow_color: Color = Color(0.35, 0.55, 1.0, 0.55),
		helix: bool = false, stacks: int = 0) -> void:
	## Bright core + soft glow hitscan beam, persists briefly then collapses.
	## `helix` (overdrive) wraps two counter-phased strands around the core and
	## sheds drifting motes along the line; `stacks` thickens the strands.
	if helix:
		_beam_helix(start, end, width, core_color, stacks)
	var glow := Line2D.new()
	glow.width = width * 3.2
	glow.default_color = glow_color
	glow.z_index = 108
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.add_point(Vector2.ZERO)
	glow.add_point(end - start)
	add_child(glow)
	glow.global_position = start

	var core := Line2D.new()
	core.width = width
	core.default_color = core_color
	core.z_index = 109
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.add_point(Vector2.ZERO)
	core.add_point(end - start)
	# Dynamic gradient along the beam: hot white core at the muzzle bleeding
	# into the tinted glow color toward the impact point.
	var cg := Gradient.new()
	cg.set_color(0, Color(1, 1, 1, core_color.a))
	cg.add_point(0.5, core_color)
	cg.set_color(cg.get_point_count() - 1, Color(glow_color.r, glow_color.g, glow_color.b, core_color.a))
	core.gradient = cg
	add_child(core)
	core.global_position = start

	# Muzzle flash ring at the origin
	var flash := Line2D.new()
	flash.width = 3.0
	flash.default_color = Color(core_color, 0.9)
	flash.z_index = 110
	flash.closed = true
	for i in range(13):
		var t := TAU * float(i) / 12.0
		flash.add_point(Vector2(cos(t), sin(t)) * width * 0.9)
	add_child(flash)
	flash.global_position = start

	# Impact sparks at the end point
	var dir := (end - start).normalized()
	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = core_color
		p.z_index = 110
		add_child(p)
		p.global_position = end + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var burst := (-dir).rotated(randf_range(-0.9, 0.9)) * randf_range(20, 55)
		var twp := p.create_tween()
		twp.set_parallel(true)
		twp.tween_property(p, "global_position", p.global_position + burst, 0.25)
		twp.tween_property(p, "modulate:a", 0.0, 0.25)
		twp.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())

	# Beam holds ~0.12s, then collapses/fades
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		if is_instance_valid(core):
			var tc := core.create_tween()
			tc.set_parallel(true)
			tc.tween_property(core, "width", 0.0, 0.12)
			tc.tween_property(core, "modulate:a", 0.0, 0.14)
			tc.chain().tween_callback(func() -> void:
				if is_instance_valid(core):
					core.queue_free())
		if is_instance_valid(glow):
			var tg := glow.create_tween()
			tg.set_parallel(true)
			tg.tween_property(glow, "width", 0.0, 0.16)
			tg.tween_property(glow, "modulate:a", 0.0, 0.18)
			tg.chain().tween_callback(func() -> void:
				if is_instance_valid(glow):
					glow.queue_free())
		if is_instance_valid(flash):
			var tf := flash.create_tween()
			tf.set_parallel(true)
			tf.tween_property(flash, "scale", Vector2(2.2, 2.2), 0.15)
			tf.tween_property(flash, "modulate:a", 0.0, 0.15)
			tf.chain().tween_callback(func() -> void:
				if is_instance_valid(flash):
					flash.queue_free()))


func _beam_helix(start: Vector2, end: Vector2, width: float,
		core_color: Color, stacks: int) -> void:
	## Two sine strands spiraling around the beam axis + drifting energy motes.
	var axis := end - start
	var length := axis.length()
	if length < 8.0:
		return
	var dir := axis / length
	var perp := Vector2(-dir.y, dir.x)
	var strand_width := 2.5 + 0.5 * stacks
	var amplitude := width * 1.4
	var turns := maxf(length / 90.0, 2.0)  # helix frequency scales with length
	var samples := int(clampf(length / 14.0, 16, 64))

	# White helix strand gradient (bright white core → cool white edges)
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 0.0))
	sg.add_point(0.5, Color(1, 1, 1, 0.95))
	sg.set_color(sg.get_point_count() - 1, Color(0.85, 0.92, 1.0, 0.0))

	for phase in [0.0, PI]:
		var strand := Line2D.new()
		strand.width = strand_width
		strand.default_color = Color(1, 1, 1, 0.9)
		strand.gradient = sg
		strand.z_index = 110
		strand.begin_cap_mode = Line2D.LINE_CAP_ROUND
		strand.end_cap_mode = Line2D.LINE_CAP_ROUND
		for i in range(samples + 1):
			var t := float(i) / float(samples)
			var swing := sin(t * TAU * turns + phase) * amplitude
			# Taper the helix at both ends so it converges on muzzle/impact
			var taper := sin(t * PI)
			strand.add_point(dir * (t * length) + perp * swing * taper)
		add_child(strand)
		strand.global_position = start
		var tw := strand.create_tween()
		tw.set_parallel(true)
		tw.tween_property(strand, "width", 0.0, 0.28).set_ease(Tween.EASE_IN)
		tw.tween_property(strand, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(strand):
				strand.queue_free())

	# Drifting energy motes shed along the beam (denser, white, mixed sizes)
	var mote_count := 16 + stacks * 4
	for i in range(mote_count):
		var m := ColorRect.new()
		var sz := randf_range(1.5, 3.5)
		m.size = Vector2(sz, sz)
		m.color = Color(1, 1, 1, randf_range(0.7, 1.0))
		m.z_index = 111
		add_child(m)
		var t := randf()
		# Bias motes onto the helix strands so they read as shed energy
		var strand_swing := sin(t * TAU * turns) * amplitude * sin(t * PI)
		m.global_position = start + dir * (t * length) + perp * (strand_swing + randf_range(-amplitude * 0.4, amplitude * 0.4))
		var drift := perp * randf_range(-30.0, 30.0) + dir * randf_range(-10.0, 10.0)
		var twm := m.create_tween()
		twm.set_parallel(true)
		twm.tween_property(m, "global_position", m.global_position + drift, 0.45)
		twm.tween_property(m, "modulate:a", 0.0, 0.45)
		twm.tween_property(m, "scale", Vector2(0.2, 0.2), 0.45)
		twm.chain().tween_callback(func() -> void:
			if is_instance_valid(m):
				m.queue_free())


# ─── Prayer sparkle (healer hand-rub feedback) ───────────────────────────────

func prayer_sparkle(pos: Vector2) -> void:
	## Soft golden motes drifting up from clasped hands — every prayer gets
	## this; the lightning is the 1-in-7 jackpot on top.
	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(2, 2)
		p.color = Color(1.0, 0.95, 0.6, randf_range(0.6, 0.95))
		p.z_index = 105
		add_child(p)
		p.global_position = pos + Vector2(randf_range(-7, 7), randf_range(-4, 4))
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position:y", p.global_position.y - randf_range(14, 26), 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ─── Lightning strike (healer prayer answered) ──────────────────────────────

func lightning_strike(pos: Vector2, aoe_radius: float = 90.0) -> void:
	## Divine bolt from above: jagged white core + glow crashing onto `pos`,
	## sky flash, expanding explosion ring, radial sparks, and lingering
	## BURNING embers. Flashy and strong — it should feel like a jackpot.
	var top := pos + Vector2(randf_range(-30, 30), -420.0)

	# Jagged bolt path (main) — segments jitter sideways on the way down
	var points := PackedVector2Array()
	var seg_count := 7
	for i in range(seg_count + 1):
		var t := float(i) / float(seg_count)
		var p := top.lerp(pos, t)
		if i > 0 and i < seg_count:
			p.x += randf_range(-26.0, 26.0) * (1.0 - t * 0.5)
		points.append(p - pos)  # local to the strike point

	for pass_data in [[10.0, Color(0.75, 0.85, 1.0, 0.45), 106], [4.0, Color(1, 1, 1, 1.0), 107]]:
		var bolt := Line2D.new()
		bolt.width = pass_data[0]
		bolt.default_color = pass_data[1]
		bolt.z_index = pass_data[2]
		bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
		bolt.points = points
		add_child(bolt)
		bolt.global_position = pos
		var twb := bolt.create_tween()
		twb.set_parallel(true)
		twb.tween_property(bolt, "width", 0.0, 0.22).set_ease(Tween.EASE_IN)
		twb.tween_property(bolt, "modulate:a", 0.0, 0.25)
		twb.chain().tween_callback(func() -> void:
			if is_instance_valid(bolt):
				bolt.queue_free())

	# Thin secondary fork for extra crackle
	var fork := Line2D.new()
	fork.width = 2.0
	fork.default_color = Color(0.9, 0.95, 1.0, 0.9)
	fork.z_index = 107
	var fork_start: Vector2 = points[3]
	var fork_dir := signf(randf_range(-1, 1))
	fork.add_point(fork_start)
	fork.add_point(fork_start + Vector2(fork_dir * 22, 26))
	fork.add_point(fork_start + Vector2(fork_dir * 34, 55))
	add_child(fork)
	fork.global_position = pos
	var twf := fork.create_tween()
	twf.set_parallel(true)
	twf.tween_property(fork, "width", 0.0, 0.16)
	twf.tween_property(fork, "modulate:a", 0.0, 0.18)
	twf.chain().tween_callback(func() -> void:
		if is_instance_valid(fork):
			fork.queue_free())

	# Sky flash above the impact — brief bright wash so the bolt reads as huge
	var flash := ColorRect.new()
	flash.size = Vector2(220, 460)
	flash.color = Color(0.85, 0.9, 1.0, 0.22)
	flash.z_index = 104
	add_child(flash)
	flash.global_position = pos - Vector2(flash.size.x / 2.0, flash.size.y - 20)
	var twfl := flash.create_tween()
	twfl.tween_property(flash, "modulate:a", 0.0, 0.15)
	twfl.tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free())

	# Explosion: expanding shockwave ring sized to the AoE + hot inner ring
	for ring_data in [[aoe_radius, Color(1.0, 0.85, 0.4, 0.9), 0.3], [aoe_radius * 0.55, Color(1, 1, 1, 0.95), 0.22]]:
		var ring := Line2D.new()
		ring.width = 4.0
		ring.default_color = ring_data[1]
		ring.z_index = 106
		ring.closed = true
		for i in range(21):
			var t := TAU * float(i) / 20.0
			ring.add_point(Vector2(cos(t), sin(t)) * 10.0)
		add_child(ring)
		ring.global_position = pos
		var target_scale: float = ring_data[0] / 10.0
		var twr := ring.create_tween()
		twr.set_parallel(true)
		twr.tween_property(ring, "scale", Vector2(target_scale, target_scale), ring_data[2]).set_ease(Tween.EASE_OUT)
		twr.tween_property(ring, "width", 0.0, ring_data[2])
		twr.tween_property(ring, "modulate:a", 0.0, ring_data[2] + 0.05)
		twr.chain().tween_callback(func() -> void:
			if is_instance_valid(ring):
				ring.queue_free())

	# Radial explosion sparks
	for i in range(10):
		var ang := TAU * float(i) / 10.0 + randf_range(-0.2, 0.2)
		var s := ColorRect.new()
		s.size = Vector2(6, 2)
		s.color = Color(1.0, 0.9, 0.5, 0.95)
		s.rotation = ang
		s.z_index = 107
		add_child(s)
		s.global_position = pos
		var fly := Vector2(cos(ang), sin(ang)) * randf_range(40.0, aoe_radius)
		var tws := s.create_tween()
		tws.set_parallel(true)
		tws.tween_property(s, "global_position", pos + fly, 0.28).set_ease(Tween.EASE_OUT)
		tws.tween_property(s, "modulate:a", 0.0, 0.3)
		tws.chain().tween_callback(func() -> void:
			if is_instance_valid(s):
				s.queue_free())

	# BURNING embers: flickering fire particles lingering at the scorch point
	for i in range(14):
		var e := ColorRect.new()
		var sz := randf_range(2.0, 4.0)
		e.size = Vector2(sz, sz)
		e.color = [Color(1.0, 0.55, 0.15, 0.95), Color(1.0, 0.35, 0.1, 0.9), Color(1.0, 0.8, 0.3, 0.9)][i % 3]
		e.z_index = 106
		add_child(e)
		e.global_position = pos + Vector2(randf_range(-aoe_radius * 0.6, aoe_radius * 0.6), randf_range(-6, 8))
		var rise := randf_range(24.0, 55.0)
		var life := randf_range(0.5, 1.1)
		var twe := e.create_tween()
		twe.set_parallel(true)
		twe.tween_property(e, "global_position", e.global_position + Vector2(randf_range(-10, 10), -rise), life)
		twe.tween_property(e, "scale", Vector2(0.15, 0.15), life).set_ease(Tween.EASE_IN)
		twe.tween_property(e, "modulate:a", 0.0, life).set_delay(life * 0.35)
		twe.chain().tween_callback(func() -> void:
			if is_instance_valid(e):
				e.queue_free())


# ─── Bomb explosion (bombug detonation) ──────────────────────────────────────

func bomb_explosion(pos: Vector2, radius: float = 95.0) -> void:
	## Bombug blast: black-purple charge shell snapping into a white-hot core,
	## twin shockwaves, jagged shrapnel sparks, embers, and thick smoke.
	var shell := Polygon2D.new()
	var shell_pts := PackedVector2Array()
	for i in range(18):
		var t := TAU * float(i) / 18.0
		var r := 10.0 + sin(t * 3.0) * 1.8
		shell_pts.append(Vector2(cos(t), sin(t)) * r)
	shell.polygon = shell_pts
	shell.color = Color(0.38, 0.18, 0.54, 0.85)
	shell.z_index = 106
	add_child(shell)
	shell.global_position = pos
	var tw_shell := shell.create_tween()
	tw_shell.set_parallel(true)
	tw_shell.tween_property(shell, "scale", Vector2(radius / 20.0, radius / 20.0), 0.12).set_ease(Tween.EASE_OUT)
	tw_shell.tween_property(shell, "modulate:a", 0.0, 0.16)
	tw_shell.chain().tween_callback(func() -> void:
		if is_instance_valid(shell):
			shell.queue_free())

	var core := Polygon2D.new()
	var core_pts := PackedVector2Array()
	for i in range(16):
		var t := TAU * float(i) / 16.0
		core_pts.append(Vector2(cos(t), sin(t)) * 10.0)
	core.polygon = core_pts
	core.color = Color(1.0, 1.0, 0.96, 0.98)
	core.z_index = 107
	add_child(core)
	core.global_position = pos
	var twc := core.create_tween()
	twc.set_parallel(true)
	twc.tween_property(core, "scale", Vector2(radius / 18.0, radius / 18.0), 0.18).set_ease(Tween.EASE_OUT)
	twc.tween_property(core, "color", Color(1.0, 0.45, 0.12, 0.0), 0.24)
	twc.chain().tween_callback(func() -> void:
		if is_instance_valid(core):
			core.queue_free())

	for ring_data in [
		[radius, Color(1.0, 0.72, 0.3, 0.92), 0.28, 4.5],
		[radius * 0.72, Color(1.0, 0.98, 0.92, 0.95), 0.2, 3.0],
		[radius * 1.08, Color(0.62, 0.38, 0.82, 0.45), 0.34, 2.0]
	]:
		var ring := Line2D.new()
		ring.width = ring_data[3]
		ring.default_color = ring_data[1]
		ring.z_index = 106
		ring.closed = true
		for i in range(25):
			var t := TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(t), sin(t)) * 10.0)
		add_child(ring)
		ring.global_position = pos
		var target_scale: float = ring_data[0] / 10.0
		var twr := ring.create_tween()
		twr.set_parallel(true)
		twr.tween_property(ring, "scale", Vector2(target_scale, target_scale), ring_data[2]).set_ease(Tween.EASE_OUT)
		twr.tween_property(ring, "width", 0.0, ring_data[2])
		twr.tween_property(ring, "modulate:a", 0.0, ring_data[2] + 0.06)
		twr.chain().tween_callback(func() -> void:
			if is_instance_valid(ring):
				ring.queue_free())

	for i in range(14):
		var ang := TAU * float(i) / 14.0 + randf_range(-0.22, 0.22)
		var spark := ColorRect.new()
		spark.size = Vector2(randf_range(7.0, 11.0), 2)
		spark.color = [Color(1.0, 0.78, 0.32, 0.95), Color(1.0, 0.98, 0.9, 0.92), Color(0.78, 0.55, 1.0, 0.85)][i % 3]
		spark.rotation = ang
		spark.z_index = 107
		add_child(spark)
		spark.global_position = pos
		var fly := Vector2(cos(ang), sin(ang)) * randf_range(radius * 0.45, radius * 1.2)
		var tws := spark.create_tween()
		tws.set_parallel(true)
		tws.tween_property(spark, "global_position", pos + fly, 0.3).set_ease(Tween.EASE_OUT)
		tws.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.3)
		tws.tween_property(spark, "modulate:a", 0.0, 0.32)
		tws.chain().tween_callback(func() -> void:
			if is_instance_valid(spark):
				spark.queue_free())

	for i in range(10):
		var puff := Polygon2D.new()
		var puff_pts := PackedVector2Array()
		var pr := randf_range(7.0, 13.0)
		for j in range(12):
			var t := TAU * float(j) / 12.0
			puff_pts.append(Vector2(cos(t), sin(t)) * pr * randf_range(0.85, 1.15))
		puff.polygon = puff_pts
		var shade := randf_range(0.2, 0.34)
		puff.color = Color(shade, shade, shade + 0.04, randf_range(0.4, 0.62))
		puff.z_index = 105
		add_child(puff)
		puff.global_position = pos + Vector2(randf_range(-radius * 0.42, radius * 0.42), randf_range(-radius * 0.22, radius * 0.16))
		var life := randf_range(0.85, 1.45)
		var twp := puff.create_tween()
		twp.set_parallel(true)
		twp.tween_property(puff, "scale", Vector2(2.4, 2.4), life).set_ease(Tween.EASE_OUT)
		twp.tween_property(puff, "global_position",
			puff.global_position + Vector2(randf_range(-16, 16), -randf_range(26, 58)), life)
		twp.tween_property(puff, "modulate:a", 0.0, life).set_delay(life * 0.25)
		twp.chain().tween_callback(func() -> void:
			if is_instance_valid(puff):
				puff.queue_free())

	for i in range(8):
		var ember := ColorRect.new()
		var sz := randf_range(2.0, 3.8)
		ember.size = Vector2(sz, sz)
		ember.color = [Color(1.0, 0.5, 0.15, 0.92), Color(1.0, 0.3, 0.1, 0.88), Color(0.8, 0.55, 1.0, 0.72)][i % 3]
		ember.z_index = 106
		add_child(ember)
		ember.global_position = pos + Vector2(randf_range(-radius * 0.4, radius * 0.4), randf_range(-8, 8))
		var life2 := randf_range(0.5, 0.95)
		var twe := ember.create_tween()
		twe.set_parallel(true)
		twe.tween_property(ember, "global_position", ember.global_position + Vector2(randf_range(-12, 12), -randf_range(20, 46)), life2)
		twe.tween_property(ember, "modulate:a", 0.0, life2).set_delay(life2 * 0.25)
		twe.chain().tween_callback(func() -> void:
			if is_instance_valid(ember):
				ember.queue_free())


func bomb_defuse(pos: Vector2, radius: float = 30.0) -> void:
	## A harmless collapse of unstable energy when an armed bombug is killed.
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.95, 0.72, 1.0, 0.85)
	ring.z_index = 107
	ring.closed = true
	for i in range(17):
		var t := TAU * float(i) / 16.0
		ring.add_point(Vector2(cos(t), sin(t)) * 7.0)
	add_child(ring)
	ring.global_position = pos
	var twr := ring.create_tween()
	twr.set_parallel(true)
	twr.tween_property(ring, "scale", Vector2(radius / 7.0, radius / 7.0), 0.22).set_ease(Tween.EASE_OUT)
	twr.tween_property(ring, "modulate:a", 0.0, 0.24)
	twr.chain().tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free())

	for i in range(8):
		var mote := ColorRect.new()
		mote.size = Vector2(3, 3)
		mote.color = [Color(1.0, 0.9, 0.98, 0.92), Color(0.85, 0.65, 1.0, 0.85)][i % 2]
		mote.z_index = 108
		add_child(mote)
		mote.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var drift := Vector2(randf_range(-radius, radius), -randf_range(10.0, radius + 8.0))
		var twm := mote.create_tween()
		twm.set_parallel(true)
		twm.tween_property(mote, "global_position", mote.global_position + drift, 0.35).set_ease(Tween.EASE_OUT)
		twm.tween_property(mote, "scale", Vector2(0.2, 0.2), 0.35)
		twm.tween_property(mote, "modulate:a", 0.0, 0.35)
		twm.chain().tween_callback(func() -> void:
			if is_instance_valid(mote):
				mote.queue_free())


# ─── Mana circle break (overcharged laser fizzle) ────────────────────────────

func circle_break(pos: Vector2) -> void:
	## The held mana circle shatters: ring fragments spin away + a dull flash.
	for i in range(10):
		var ang := TAU * float(i) / 10.0 + randf_range(-0.2, 0.2)
		var frag := Line2D.new()
		frag.width = 2.0
		frag.default_color = Color(0.6, 0.85, 1.0, 0.95)
		frag.z_index = 110
		# Small arc fragment of the broken ring
		for j in range(4):
			var fa := ang + float(j) * 0.12
			frag.add_point(Vector2(cos(fa), sin(fa)) * 14.0)
		add_child(frag)
		frag.global_position = pos
		var fly := Vector2(cos(ang), sin(ang)) * randf_range(26.0, 60.0)
		var tw := frag.create_tween()
		tw.set_parallel(true)
		tw.tween_property(frag, "global_position", pos + fly, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(frag, "rotation", randf_range(-2.5, 2.5), 0.35)
		tw.tween_property(frag, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(frag):
				frag.queue_free())

	# Dull implosion flash (failure reads differently from the parry spark)
	var flash := ColorRect.new()
	flash.size = Vector2(26, 26)
	flash.color = Color(0.5, 0.6, 1.0, 0.5)
	flash.z_index = 109
	add_child(flash)
	flash.global_position = pos - flash.size / 2.0
	flash.pivot_offset = flash.size / 2.0
	var twf := flash.create_tween()
	twf.set_parallel(true)
	twf.tween_property(flash, "scale", Vector2(0.1, 0.1), 0.25).set_ease(Tween.EASE_IN)
	twf.tween_property(flash, "modulate:a", 0.0, 0.25)
	twf.chain().tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free())


# ─── Heal burst (healer channel) ─────────────────────────────────────────────

func heal_burst(pos: Vector2) -> void:
	for i in range(8):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = Color(0.4, 1.0, 0.5, 0.95)
		p.z_index = 105
		add_child(p)
		p.global_position = pos + Vector2(randf_range(-12, 12), randf_range(-4, 10))
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position:y", p.global_position.y - randf_range(22, 40), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


# ─── Parry spark (perfect-parry deflect burst) ───────────────────────────────

func parry_spark(pos: Vector2) -> void:
	# Bright radial burst of lines + a flash circle
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + randf_range(-0.15, 0.15)
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(1.0, 0.95, 0.5, 1.0)
		line.z_index = 110
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(cos(angle), sin(angle)) * randf_range(10, 18))
		add_child(line)
		line.global_position = pos
		var tw := line.create_tween()
		tw.set_parallel(true)
		tw.tween_property(line, "scale", Vector2(1.8, 1.8), 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "modulate:a", 0.0, 0.2)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(line):
				line.queue_free())

	# Flash ring
	var flash := Line2D.new()
	flash.width = 4.0
	flash.default_color = Color(1.0, 1.0, 0.9, 0.9)
	flash.z_index = 110
	flash.closed = true
	for i in range(17):
		var t := TAU * float(i) / 16.0
		flash.add_point(Vector2(cos(t), sin(t)) * 8.0)
	add_child(flash)
	flash.global_position = pos
	var tw2 := flash.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.22).set_ease(Tween.EASE_OUT)
	tw2.tween_property(flash, "modulate:a", 0.0, 0.22)
	tw2.chain().tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free())


# ─── Slash effect (bright sword arc) ─────────────────────────────────────────
## `dir` is the horizontal facing sign (1/-1). `angle` rotates the whole slash
## plane (radians, world space) for directional attacks; 0 = horizontal slash.

func slash_effect(origin: Vector2, dir: float, downward: bool, angle: float = 0.0, arc_scale: float = 1.0) -> void:
	var arc := Line2D.new()
	arc.width = 12.0 * arc_scale
	arc.default_color = SLASH_COLOR
	arc.z_index = 105
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND

	var arc_radius := 26.0 * arc_scale

	var start_angle: float
	var end_angle: float
	if downward:
		start_angle = -PI * 0.6
		end_angle = PI * 0.4
	else:
		start_angle = PI * 0.6
		end_angle = -PI * 0.4

	for i in range(12):
		var t: float = float(i) / 11.0
		var a: float = lerpf(start_angle, end_angle, t)
		var pt := Vector2(cos(a) * arc_radius * dir, sin(a) * arc_radius)
		pt += Vector2(dir * 20 * arc_scale, -5 * arc_scale)
		pt = pt.rotated(angle)
		arc.add_point(pt)

	add_child(arc)
	arc.global_position = origin

	var tw := arc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arc, "width", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(arc):
			arc.queue_free())

	# Sharp sparks along the slash direction
	var spark_dir := Vector2(dir, 0).rotated(angle)
	for i in range(4):
		var p := ColorRect.new()
		p.size = Vector2(8, 2)
		p.color = Color(1.0, 1.0, 1.0, 0.8)
		p.z_index = 100
		add_child(p)
		p.global_position = origin + spark_dir * randf_range(15, 30) + Vector2(randf_range(-8, 8), randf_range(-15, 15))
		p.rotation = angle + deg_to_rad(randf_range(-20, 20))
		var tw2 := p.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(p, "global_position", p.global_position + spark_dir * randf_range(10, 20) + Vector2(0, randf_range(-10, 10)), 0.15)
		tw2.tween_property(p, "scale", Vector2(0.1, 0.1), 0.15)
		tw2.tween_property(p, "modulate:a", 0.0, 0.15)
		tw2.chain().tween_callback(func() -> void:
			if is_instance_valid(p):
				p.queue_free())
