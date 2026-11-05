extends Node
# ============================================================
#  NineLens V1.0  —  Nine-Ball Roulette aim assistant
#  瞄准线 / 瞄准判定 / 推荐线路 / 一键出杆（带方向校正）
#  by.Ysmeral
# ============================================================
var DIR := "D:/deepseeek/nbr_cheat/"
const BALL_R := 0.25
const HALF_X := 5.16
const HALF_Z := 10.16
const TABLE_Y := 8.446
const REACH := 2.0 * BALL_R
const POCKET_R := 0.55
const WARMUP_FRAMES := 150

const SHOT_MODES := ["shooter_normal", "shooter_far", "shooter_close", "shooter_lifted", "shooter_lifted_far", "shooter_85"]
const SRC_NAMES := ["杆身轴", "CueRotater", "射手朝向", "杆容器", "镜头前方"]

# ---------------- config
var show_aim := true
var show_hud := true
var show_best := true
var auto_power := 0.0
var power_scale := 1.0

# ---------------- state
var _layer: CanvasLayer
var _canvas: Control
var _pockets: Array = []
var _balls: Array = []
var _cue := Vector2.ZERO
var _cue_ok := false
var _aim := Vector2(0.0, -1.0)
var _best: Dictionary = {}
var _best_loose := false
var _legal: Array = []
var _tgt := -1
var _tgt_pocket := -1
var _msg := "NineLens V1.0 已加载  F5 面板"
var _prev_key := {}
var _stat_t := 0.0
var _ready_done := false

# 瞄准源识别
var _src_idx := 0
var _src_dirs: Array = []
var _src_move: Array = []
var _src_pick_t := 0.0

# 出杆
var _fire_phase := 0
var _fire_t := 0.0
var _fire_power := 8.0
var _fire_dir := Vector2.ZERO
var _fire_result := ""
var _force_left := 0

# 校准
var _aim_s := Vector2(0.0, -1.0)
var _aim_s_ok := false
var _aim_hit: Dictionary = {}
var _judge: Dictionary = {}
var _judge_t := 0.0
var _rail_x := HALF_X
var _rail_z := HALF_Z
var _rails_ok := false
var _rail_t := 0.0
var _rail_tries := 0
var _rail_fail := 0

func _ready() -> void:
	DIR = _pick_dir()
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	_layer.add_child(_canvas)
	_src_dirs = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	_src_move = [0.0, 0.0, 0.0, 0.0, 0.0]
	_ready_done = true
	print("NINELENS V1.0 ready by.Ysmeral")

# ---------------------------------------------------------------- safe access
func _pick_dir() -> String:
	# 日志目录：优先作者的固定目录，其次写入系统用户数据目录（发给别人也能用）
	var cand: Array = ["D:/deepseeek/nbr_cheat/", "C:/nbr_cheat/"]
	for c in cand:
		var s: String = c
		if DirAccess.make_dir_recursive_absolute(s) == OK:
			return s
	var u := ProjectSettings.globalize_path("user://nbr_cheat/")
	if DirAccess.make_dir_recursive_absolute(u) == OK:
		return u
	return ProjectSettings.globalize_path("user://")

func _ok(o) -> bool:
	if o == null:
		return false
	if o is Object:
		return is_instance_valid(o)
	return true

func _global() -> Node:
	var g := get_node_or_null("/root/Global")
	if _ok(g):
		return g
	return null

func _gp(prop: String):
	var g := _global()
	if g == null:
		return null
	return g.get(prop)

func _mainnode() -> Node:
	var m = _gp("main")
	if _ok(m):
		return m
	return null

func _say(s: String) -> void:
	_msg = s

func _dbg(s: String) -> void:
	var p := DIR + "debug.log"
	var mode := FileAccess.READ_WRITE
	if not FileAccess.file_exists(p):
		mode = FileAccess.WRITE
	var f := FileAccess.open(p, mode)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s %s" % [Time.get_time_string_from_system(), s])
	f.close()

func _trace(s: String) -> void:
	var p := DIR + "aim_trace.log"
	var lines: Array = []
	if FileAccess.file_exists(p):
		var r := FileAccess.open(p, FileAccess.READ)
		if r != null:
			while not r.eof_reached():
				lines.append(r.get_line())
			r.close()
	if lines.size() > 120:
		lines = lines.slice(lines.size() - 120)
	lines.append(s)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	for l in lines:
		f.store_line(str(l))
	f.close()

# ---------------------------------------------------------------- keys
func _key(k: int) -> bool:
	var now := Input.is_physical_key_pressed(k)
	var was := bool(_prev_key.get(k, false))
	_prev_key[k] = now
	return now and not was

func _input_keys() -> void:
	if _key(KEY_F5):
		show_hud = not show_hud
		show_aim = show_hud
		_say("面板 " + ("开" if show_hud else "关"))
	if _key(KEY_F6):
		show_aim = not show_aim
		_say("瞄准线 " + ("开" if show_aim else "关"))
	if _key(KEY_F7):
		_do_aim()
	if _key(KEY_F8):
		_do_shoot()
	if _key(KEY_T):
		_cycle_target(1)
	if _key(KEY_G):
		show_best = not show_best
		_say("推荐线 " + ("开" if show_best else "关"))
	if _key(KEY_B):
		_cycle_pocket(1)
	if _key(KEY_BRACKETLEFT):
		auto_power = maxf(2.0, (auto_power if auto_power > 0.0 else 7.5) - 0.5)
		_say("力度 " + str(auto_power))
	if _key(KEY_BRACKETRIGHT):
		auto_power = minf(14.0, (auto_power if auto_power > 0.0 else 7.5) + 0.5)
		_say("力度 " + str(auto_power))
	if _key(KEY_BACKSLASH):
		auto_power = 0.0
		_say("力度 自动")

# ---------------------------------------------------------------- nodes / sources
func _active_shooter() -> Node:
	var m := _mainnode()
	if m == null:
		return null
	for n in SHOT_MODES:
		var s = m.get(n)
		if _ok(s) and (s as Node3D).visible:
			return s
	return null

func _shooter() -> Node:
	var s := _active_shooter()
	if s != null:
		return s
	var m := _mainnode()
	if m == null:
		return null
	var fb = m.get("shooter_normal")
	if _ok(fb):
		return fb
	return null

func _cue_node(s: Node) -> Node3D:
	if not _ok(s):
		return null
	var c = s.get("cue")
	if _ok(c) and c is Node3D:
		return c
	return null

func _dir_of_basis(n: Node3D) -> Vector2:
	var b := n.global_transform.basis
	var d := Vector2(b.y.x, b.y.z)
	if d.length() < 0.2:
		d = Vector2(b.z.x, b.z.z)
	if d.length() < 0.001:
		return Vector2.ZERO
	return d.normalized()

func _yaw_dir(n: Node3D) -> Vector2:
	return Vector2(-sin(n.global_rotation.y), -cos(n.global_rotation.y))

func _sample_sources() -> void:
	var s := _shooter()
	var d0 := Vector2.ZERO
	var d1 := Vector2.ZERO
	var d2 := Vector2.ZERO
	var d3 := Vector2.ZERO
	var d4 := Vector2.ZERO
	if _ok(s):
		var cue := _cue_node(s)
		if cue != null:
			d0 = _dir_of_basis(cue)
		var cr = s.get("cue_rotater")
		if _ok(cr) and cr is Node3D:
			var n1: Node3D = cr
			d1 = Vector2(-sin(n1.rotation.y), -cos(n1.rotation.y))
		if s is Node3D:
			d2 = _yaw_dir(s as Node3D)
			var par: Node = s.get_parent()
			if _ok(par) and par is Node3D:
				d3 = _yaw_dir(par as Node3D)
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_3d()
		if _ok(cam) and cam is Node3D:
			var b: Basis = (cam as Node3D).global_transform.basis
			var cd := Vector2(-b.z.x, -b.z.z)
			if cd.length() > 0.2:
				d4 = cd.normalized()
	var dirs: Array = [d0, d1, d2, d3, d4]
	for i in 5:
		var nd: Vector2 = dirs[i]
		if nd != Vector2.ZERO:
			_src_move[i] = float(_src_move[i]) * 0.92 + absf(nd.angle_to(_src_dirs[i])) * 30.0
			_src_dirs[i] = nd
		else:
			_src_move[i] = float(_src_move[i]) * 0.9

func _pick_source() -> void:
	# 杆身轴优先：它是真实瞄准方向；镜头前方在侧视角会偏几度
	if float(_src_move[0]) > 0.12 and _src_dirs[0] != Vector2.ZERO:
		_src_idx = 0
		return
	var best := -1
	var bv := 0.05
	for i in 5:
		if float(_src_move[i]) > bv and _src_dirs[i] != Vector2.ZERO:
			bv = float(_src_move[i])
			best = i
	if best >= 0:
		_src_idx = best

func _read_dir() -> Vector2:
	var nd: Vector2 = _src_dirs[_src_idx]
	if nd == Vector2.ZERO:
		return _aim
	return nd

func _read_theta() -> float:
	var d := _read_dir()
	return atan2(-d.x, -d.y)

func _diag(tag: String) -> void:
	var s := _shooter()
	var line := "[%s] src=%s aim=%.1f err=%.1f move=" % [tag, SRC_NAMES[_src_idx], rad_to_deg(atan2(_read_dir().x, _read_dir().y)), _err_deg()]
	line += "[%.2f,%.2f,%.2f,%.2f,%.2f]" % [_src_move[0], _src_move[1], _src_move[2], _src_move[3], _src_move[4]]
	if _ok(s) and s is Node3D:
		line += " vis=" + str((s as Node3D).visible)
		var cue := _cue_node(s)
		if cue != null:
			var cd := _dir_of_basis(cue)
			line += " cueY=%.1f" % rad_to_deg(atan2(cd.x, cd.y))
		var cr = s.get("cue_rotater")
		if _ok(cr) and cr is Node3D:
			line += " rotY=%.1f" % rad_to_deg((cr as Node3D).rotation.y)
	_trace(line)

# ---------------------------------------------------------------- data
func _find_child_by_name(n: Node, target: String) -> Node:
	if not _ok(n):
		return null
	if n.name == target:
		return n
	for c in n.get_children():
		var r := _find_child_by_name(c, target)
		if r != null:
			return r
	return null

func _refresh_pockets() -> void:
	if not _pockets.is_empty():
		return
	var t = _gp("table")
	if not _ok(t):
		return
	var pa := _find_child_by_name(t, "PocketArea")
	if not _ok(pa):
		return
	for c in pa.get_children():
		if not _ok(c) or not (c is Node3D):
			continue
		var n3: Node3D = c
		var r := POCKET_R
		if c is CollisionShape3D:
			var cs: CollisionShape3D = c
			if cs.shape is CylinderShape3D:
				r = (cs.shape as CylinderShape3D).radius
		_pockets.append({"p": Vector2(n3.global_position.x, n3.global_position.z), "r": r, "i": _pockets.size()})

func _refresh() -> void:
	_refresh_pockets()
	_balls.clear()
	var bsr = _gp("ball_spawn_root")
	if _ok(bsr):
		for c in bsr.get_children():
			if not _ok(c) or not (c is Node3D):
				continue
			if not bool(c.get("on_table")):
				continue
			var pos: Vector3 = (c as Node3D).global_position
			if absf(pos.y - TABLE_Y) > 0.8:
				continue
			_balls.append({"n": c, "i": int(c.get("ball_index")), "p": Vector2(pos.x, pos.z)})
	_cue_ok = false
	var cb = _gp("cue_ball")
	if _ok(cb) and cb is Node3D:
		var cp: Vector3 = (cb as Node3D).global_position
		if absf(cp.y - TABLE_Y) < 0.8 and absf(cp.x) < 6.2 and absf(cp.z) < 11.8:
			_cue = Vector2(cp.x, cp.z)
			_cue_ok = true
	_aim = _read_dir()
	if not _aim_s_ok:
		_aim_s = _aim
		_aim_s_ok = true
	else:
		var sm := _aim_s.lerp(_aim, 0.45)
		if sm.length() > 0.01:
			_aim_s = sm.normalized()

# ---------------------------------------------------------------- geometry
func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _blocked(a: Vector2, b: Vector2, ignore: Array) -> bool:
	for bl in _balls:
		if ignore.has(bl["i"]):
			continue
		if _seg_dist(bl["p"], a, b) < REACH + 0.02:
			return true
	return false

func _allowed() -> Array:
	var out: Array = []
	var sup := int(_gp("supposed_to_hit"))
	if sup >= 0:
		out.append(sup)
	var arr = _gp("display_supposed_to_hit_array")
	if arr is Array and (arr as Array).size() > 0:
		for v in arr:
			var iv := int(v)
			if iv >= 0 and not out.has(iv):
				out.append(iv)
	return out

func _cand_core(bl: Dictionary, pk: Dictionary, relaxed: bool) -> Dictionary:
	var idx: int = bl["i"]
	var tp: Vector2 = bl["p"]
	var pp: Vector2 = pk["p"]
	var pr: float = pk["r"]
	if tp.distance_to(pp) < 0.05:
		return {}
	var to_pocket := pp - tp
	var dir_op := to_pocket.normalized()
	var ghost: Vector2 = tp - dir_op * REACH
	if ghost.distance_to(_cue) < 0.08:
		return {}
	var dir_cue: Vector2 = (ghost - _cue).normalized()
	var cut := absf(dir_cue.angle_to(dir_op))
	if cut > (1.52 if relaxed else 1.34):
		return {}
	# 幽灵球位置就是母球球心该停的地方，必须在台面内（贴库球的这条经常跑到库外，属于打不到）
	var gx := absf(ghost.x)
	var gz := absf(ghost.y)
	if gx > _rail_x - BALL_R + 0.02 or gz > _rail_z - BALL_R + 0.02:
		return {}
	var b1 := _blocked(_cue, ghost, [idx, 0])
	var b2 := _blocked(tp, tp + dir_op * (to_pocket.length() - pr * 0.8), [idx, 0])
	if (b1 or b2) and not relaxed:
		return {}
	var score := 3.0 - cut * 2.2 - tp.distance_to(pp) * 0.05 - _cue.distance_to(ghost) * 0.03
	if b1 or b2:
		score -= 6.0
	return {"idx": idx, "target": tp, "pocket": pp, "ghost": ghost, "cut": cut, "score": score,
		"dir": dir_cue, "pocket_idx": int(pk["i"]), "blocked": (b1 or b2)}

func _cmp_score(a, b) -> bool:
	return float(a["score"]) > float(b["score"])

func _scan() -> void:
	_legal.clear()
	_best = {}
	_best_loose = false
	if not _cue_ok or _balls.is_empty() or _pockets.is_empty():
		return
	var allowed := _allowed()
	var per_ball: Array = []
	var per_loose: Array = []
	for bl in _balls:
		var idx: int = bl["i"]
		var legal := allowed.is_empty() or allowed.has(idx)
		var strict := {}
		for pk in _pockets:
			var c := _cand_core(bl, pk, false)
			if c.is_empty():
				continue
			if strict.is_empty() or float(c["score"]) > float(strict["score"]):
				strict = c
		if not strict.is_empty():
			if legal:
				per_ball.append(strict)
			continue
		var loose := {}
		for pk in _pockets:
			var r := _cand_core(bl, pk, true)
			if r.is_empty():
				continue
			if loose.is_empty() or float(r["score"]) > float(loose["score"]):
				loose = r
		if not loose.is_empty():
			if legal:
				per_loose.append(loose)
	if per_ball.is_empty():
		# 全都不严格可达时，用宽松线路兜底（边库球常常落在这一档）
		if per_loose.is_empty():
			return
		per_ball = per_loose
		_best_loose = true
	else:
		_best_loose = false
	per_ball.sort_custom(_cmp_score)
	_legal = per_ball
	if _tgt >= 0:
		for c in per_ball:
			if int(c["idx"]) == _tgt:
				_best = c
				return
		_tgt = -1
	if _tgt_pocket >= 0:
		var first: Dictionary = per_ball[0]
		var bl2 := {}
		for b in _balls:
			if int(b["i"]) == int(first["idx"]):
				bl2 = b
				break
		if not bl2.is_empty():
			for pk in _pockets:
				if int(pk["i"]) != _tgt_pocket:
					continue
				var c2 := _cand_core(bl2, pk, false)
				if not c2.is_empty():
					_best = c2
					return
		_tgt_pocket = -1
	_best = per_ball[0]

func _cycle_target(dir: int) -> void:
	_scan()
	var idxs: Array = []
	for c in _legal:
		if not idxs.has(int(c["idx"])):
			idxs.append(int(c["idx"]))
	if idxs.is_empty():
		_say("没有可打的线路")
		return
	idxs.sort()
	var cur := idxs.find(_tgt)
	if cur < 0:
		var bcur := -1
		if not _best.is_empty():
			bcur = idxs.find(int(_best["idx"]))
		cur = bcur if bcur >= 0 else 0
	cur = int((cur + dir + idxs.size()) % idxs.size())
	_tgt = int(idxs[cur])
	_tgt_pocket = -1
	_scan()
	_say("目标 %d 号" % _tgt)

func _cycle_pocket(dir: int) -> void:
	_scan()
	if _best.is_empty():
		_say("没有可打的线路")
		return
	var idx: int = int(_best["idx"])
	var tb := {}
	for b in _balls:
		if int(b["i"]) == idx:
			tb = b
			break
	if tb.is_empty():
		return
	var opts: Array = []
	for pk in _pockets:
		var c := _cand_core(tb, pk, false)
		if not c.is_empty():
			opts.append(c)
	if opts.size() < 2:
		_say("只有一个袋可选")
		return
	var cur := 0
	for i in opts.size():
		if int(opts[i]["pocket_idx"]) == int(_best.get("pocket_idx", -1)):
			cur = i
	cur = int((cur + dir + opts.size()) % opts.size())
	_tgt = idx
	_tgt_pocket = int(opts[cur]["pocket_idx"])
	_scan()
	_say("袋口切换")

# ---------------------------------------------------------------- aim / fire
func _err_deg() -> float:
	if _best.is_empty():
		return 999.0
	var d: Vector2 = _best["dir"]
	var th := atan2(-d.x, -d.y)
	return rad_to_deg(absf(wrapf(th - _read_theta(), -PI, PI)))

func _can_shoot() -> bool:
	var g := _global()
	if g == null:
		return false
	return bool(g.call("can_shoot"))

func _apply_aim(dir: Vector2) -> void:
	var th := atan2(-dir.x, -dir.y)
	var m := _mainnode()
	if m != null:
		for nm in SHOT_MODES:
			var sh = m.get(nm)
			if not _ok(sh):
				continue
			var cr = sh.get("cue_rotater")
			if _ok(cr) and cr is Node3D:
				(cr as Node3D).rotation.y = th
			if _ok(sh) and sh is Node3D and (sh as Node3D).visible:
				(sh as Node3D).rotation.y = th

func _do_aim() -> void:
	_refresh()
	if not _cue_ok:
		_say("母球还没落位")
		return
	_scan()
	if _best.is_empty():
		_say("没有能进的球（按 T 换目标球）")
		return
	_apply_aim(_best["dir"])
	_say("对齐 %d 号 → %s  %.1f°" % [int(_best["idx"]), str(_best["pocket"]), rad_to_deg(float(_best["cut"]))])

func _cue_body() -> CharacterBody3D:
	var cb = _gp("cue_ball")
	if _ok(cb) and cb is CharacterBody3D:
		return cb
	return null

func _cue_speed() -> float:
	var b := _cue_body()
	if b == null:
		return 0.0
	return b.velocity.length()

func _power_for(dist: float) -> float:
	return clampf((2.7 * sqrt(maxf(dist, 0.5)) + 1.2) * power_scale, 2.0, 14.0)

func _do_shoot() -> void:
	var g := _global()
	if g == null:
		return
	_refresh()
	if not _cue_ok:
		_say("母球还没落位")
		return
	_scan()
	if _best.is_empty():
		_say("没有能进的球")
		return
	_fire_dir = _best["dir"]
	_apply_aim(_fire_dir)
	var tp: Vector2 = _best["target"]
	var pp: Vector2 = _best["pocket"]
	var dist: float = _cue.distance_to(_best["ghost"]) + tp.distance_to(pp) + 1.5
	_fire_power = auto_power if auto_power > 0.0 else _power_for(dist)
	_dbg("fire idx=%d dir=%s pow=%.2f can=%s" % [int(_best["idx"]), str(_fire_dir), _fire_power, str(g.call("can_shoot"))])
	_fire_phase = 1
	_fire_t = 0.0
	_fire_result = ""
	g.call("shoot", _fire_power)

func _correct_direction() -> bool:
	var b := _cue_body()
	if b == null:
		return false
	var v := b.velocity
	if v.length() < 0.5:
		return false
	var d2 := Vector2(v.x, v.z).normalized()
	if d2.dot(_fire_dir) > 0.985:
		return false
	b.velocity = Vector3(_fire_dir.x, 0.0, _fire_dir.y) * v.length()
	return true

func _fire_tick(delta: float) -> void:
	_fire_t += delta
	match _fire_phase:
		1:
			if _cue_speed() > 0.5:
				_fire_result = "游戏接口+校正" if _correct_direction() else "游戏接口"
				_say("出杆 %s 力度 %.1f" % [_fire_result, _fire_power])
				_fire_phase = 0
				return
			if _fire_t > 0.15:
				_fire_phase = 2
				_fire_t = 0.0
				var m := _mainnode()
				if m != null and m.has_method("shoot"):
					m.call("shoot", _fire_power)
		2:
			if _cue_speed() > 0.5:
				_fire_result = "Main3D+校正" if _correct_direction() else "Main3D"
				_say("出杆 %s" % _fire_result)
				_fire_phase = 0
				return
			if _fire_t > 0.15:
				_fire_phase = 3
				_fire_t = 0.0
				var vp := get_viewport()
				var mp := vp.get_mouse_position() if vp != null else Vector2.ZERO
				for press in [true, false]:
					var ev := InputEventMouseButton.new()
					ev.button_index = MOUSE_BUTTON_LEFT
					ev.pressed = press
					ev.position = mp
					ev.global_position = mp
					Input.parse_input_event(ev)
		3:
			if _cue_speed() > 0.5:
				_fire_result = "输入模拟"
				_say("出杆 %s" % _fire_result)
				_fire_phase = 0
				return
			if _fire_t > 0.15:
				_fire_phase = 4
				_fire_t = 0.0
				_force_left = 30
		4:
			var b := _cue_body()
			if b != null:
				b.velocity = Vector3(_fire_dir.x, 0.0, _fire_dir.y) * (2.0 * _fire_power)
				_force_left -= 1
			if _cue_speed() > 0.5 and _force_left < 26:
				_fire_result = "强物理"
				_say("出杆 %s 力度 %.1f" % [_fire_result, _fire_power])
				_fire_phase = 0
				return
			if _force_left <= 0:
				_fire_result = "失败"
				_say("出杆失败")
				_fire_phase = 0

# ---------------------------------------------------------------- draw
func _wp(v: Vector2) -> Vector3:
	return Vector3(v.x, TABLE_Y, v.y)

func _on_draw() -> void:
	if not _ready_done:
		return
	var vp := _canvas.get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if not _ok(cam):
		return
	_canvas.size = vp.get_visible_rect().size
	if show_aim and _cue_ok and not _balls.is_empty():
		_draw_pockets(cam)
		_draw_rings(cam)
		_draw_path(cam)
		_draw_best(cam)
		if not _judge.is_empty() and _judge.get("pocket") != null and bool(_judge.get("ok", false)):
			# 只点一个小点提示“这个袋能进”，不再画大圈挡视野
			_canvas.draw_circle(_px(cam, _judge["pocket"]), 5.0, Color(0.35, 1.0, 0.55, 0.6))
	if show_hud:
		_draw_hud()

func _px(cam: Camera3D, p: Vector2) -> Vector2:
	return cam.unproject_position(_wp(p))

func _visible(cam: Camera3D, p: Vector2) -> bool:
	return not cam.is_position_behind(_wp(p))

func _solid(cam: Camera3D, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	if not _visible(cam, a) or not _visible(cam, b):
		return
	_canvas.draw_line(_px(cam, a), _px(cam, b), col, w, true)

func _ring(cam: Camera3D, p: Vector2, radius_world: float, col: Color, w: float) -> void:
	if not _visible(cam, p):
		return
	var c := _px(cam, p)
	var e := _px(cam, p + Vector2(radius_world, 0.0))
	var r := c.distance_to(e)
	if r < 2.0:
		return
	_canvas.draw_arc(c, r, 0.0, TAU, 48, col, w, true)

func _draw_pockets(cam: Camera3D) -> void:
	for pk in _pockets:
		_ring(cam, pk["p"], 0.32, Color(0.2, 1.0, 0.7, 0.07), 1.0)

func _draw_path(cam: Camera3D) -> void:
	# 只画一条实线：白球 → 第一撞点；撞球后接一条实线表示被撞球去向
	var d := _aim_s
	var p := _cue
	var hit := _ray_to_cushion(p, d)
	var ball := _ray_to_ball(p, hit["p"], d)
	_aim_hit = ball
	if not ball.is_empty():
		var bp: Vector2 = ball["p"]
		# 用射线求交得到的真实撞点（薄球时撞点靠边，不能用「球心距-2R」）
		var t: float = ball["t"]
		var contact: Vector2 = p + d * t
		# 贴死球（两球几乎相贴）时黄线本来就极短，画出来像一坨，这里直接不画
		if t > 0.08:
			_solid(cam, p, contact, Color(1.0, 0.85, 0.25, 0.20), 5.0)
			_solid(cam, p, contact, Color(1.0, 0.92, 0.40, 0.95), 2.0)
		_ring(cam, bp, 0.27, Color(1.0, 0.45, 0.45, 0.85), 1.8)
		# 被撞球去向 = 撞点指向球心的连心线（大角度时与瞄准方向差别很大，这才是对的）
		var od := bp - contact
		if od.length() > 0.0001:
			var odn := od.normalized()
			var h := _ray_to_cushion(bp, odn)
			# 贴库球：出球方向直接顶进库边（走不动）就不画线，避免画出库外的假线
			var len_out: float = (h["p"] - bp).length()
			if len_out > 0.10:
				_solid(cam, bp, h["p"], Color(0.3, 1.0, 0.55, 0.20), 5.0)
				_solid(cam, bp, h["p"], Color(0.35, 1.0, 0.60, 0.95), 2.0)
				if h["pocket"] != null:
					_ring(cam, h["p"], 0.30, Color(1.0, 1.0, 0.40, 0.55), 1.2)
			else:
				_ring(cam, bp, 0.30, Color(1.0, 0.75, 0.35, 0.85), 1.6)
		return
	_solid(cam, p, hit["p"], Color(1.0, 0.85, 0.25, 0.20), 5.0)
	_solid(cam, p, hit["p"], Color(1.0, 0.92, 0.40, 0.95), 2.0)
	if hit["pocket"] != null:
		_ring(cam, hit["p"], 0.30, Color(1.0, 1.0, 0.40, 0.55), 1.2)

func _measure_rails() -> void:
	# 用物理射线实测四条库边的内壁位置（撞库线路的误差主要来自这里）
	_rail_tries += 1
	if _rail_tries > 12:
		_rails_ok = true
		return
	var vp := get_viewport()
	if vp == null:
		return
	var w: World3D = vp.world_3d
	if w == null:
		return
	var space: PhysicsDirectSpaceState3D = w.direct_space_state
	if space == null:
		return
	var origin := Vector3(0.0, TABLE_Y, 0.0)
	var dirs: Array = [Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0)]
	var vals: Array = []
	for d in dirs:
		var dv: Vector3 = d
		var best := 0.0
		var got := false
		for off in [0.0, -1.4, 1.4, -2.8, 2.8]:
			var side := Vector3(dv.z, 0.0, dv.x)
			var from: Vector3 = origin + side * float(off)
			var to: Vector3 = from + dv * 40.0
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var hp: Vector3 = hit["position"]
			var dist: float = absf(Vector2(hp.x, hp.z).dot(Vector2(dv.x, dv.z)))
			if dist < 0.5:
				continue
			if not got or dist < best:
				best = dist
				got = true
		if got:
			vals.append(best)
	if vals.size() == 4:
		var nx: float = (float(vals[0]) + float(vals[1])) * 0.5
		var nz: float = (float(vals[2]) + float(vals[3])) * 0.5
		if nx > 3.0 and nx < 8.0 and nz > 8.0 and nz < 14.0:
			_rail_x = nx
			_rail_z = nz
			_rails_ok = true
			_dbg("rails x=%.3f z=%.3f" % [_rail_x, _rail_z])
			_trace("[rails] x=%.3f z=%.3f" % [_rail_x, _rail_z])
			return
	_rail_fail += 1
	if _rail_fail >= 5:
		_rails_ok = true
		_trace("[rails] giveup, use default x=%.2f z=%.2f" % [_rail_x, _rail_z])

func _ray_to_cushion(p: Vector2, d: Vector2) -> Dictionary:
	var lim_x := _rail_x - BALL_R
	var lim_z := _rail_z - BALL_R
	var best_t := 10000.0
	var normal := Vector2.ZERO
	var pocket = null
	for pk in _pockets:
		var t := _ray_circle(p, d, pk["p"], float(pk["r"]) * 0.7)
		if t > 0.0 and t < best_t:
			best_t = t
			pocket = pk["p"]
	var tx := 10000.0
	if d.x > 0.0001:
		tx = (lim_x - p.x) / d.x
	elif d.x < -0.0001:
		tx = (-lim_x - p.x) / d.x
	var tz := 10000.0
	if d.y > 0.0001:
		tz = (lim_z - p.y) / d.y
	elif d.y < -0.0001:
		tz = (-lim_z - p.y) / d.y
	if tx < tz:
		if tx < best_t and tx > 0.0:
			best_t = tx
			normal = Vector2(-signf(d.x), 0.0)
			pocket = null
	elif tz < best_t and tz > 0.0:
		best_t = tz
		normal = Vector2(0.0, -signf(d.y))
		pocket = null
	if best_t >= 9999.0:
		return {"p": p + d * 40.0, "normal": -d, "pocket": null}
	return {"p": p + d * (best_t - 0.001), "normal": normal, "pocket": pocket}

func _ray_circle(p: Vector2, d: Vector2, c: Vector2, r: float) -> float:
	var oc := p - c
	var b := oc.dot(d)
	var cc := oc.dot(oc) - r * r
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	if t < 0.01:
		t = -b + sqrt(disc)
	if t < 0.01:
		return -1.0
	return t

func _ray_to_ball(p: Vector2, end: Vector2, d: Vector2) -> Dictionary:
	# 返回首个被撞球 + 命中距离 t（母球球心到撞点的距离，薄球时 t 会明显大于球心距-2R）
	# end 是估算的库边落点；库边是实测值，可能比真实库边短，所以放宽 +1.5，
	# 否则贴库球会被判成“没瞄到球”（这是之前那个 bug）
	var best_t := (end - p).length() + 1.5
	var hit := {}
	for bl in _balls:
		var bp: Vector2 = bl["p"]
		var oc := p - bp
		var b := oc.dot(d)
		var cc := oc.dot(oc) - REACH * REACH
		var disc := b * b - cc
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 0.02 and t < best_t:
			best_t = t
			hit = {"p": bp, "i": int(bl["i"]), "t": t}
	return hit

func _obj_dir_from(p: Vector2, bp: Vector2, d: Vector2) -> Vector2:
	# 母球从 p 沿 d 打在 bp 上，目标球实际飞出的方向（连心线）
	var oc := p - bp
	var b := oc.dot(d)
	var cc := oc.dot(oc) - REACH * REACH
	var disc := b * b - cc
	if disc < 0.0:
		return Vector2.ZERO
	var t := -b - sqrt(disc)
	if t < 0.0:
		return Vector2.ZERO
	var contact := p + d * t
	var od := bp - contact
	if od.length() < 0.0001:
		return Vector2.ZERO
	return od.normalized()

func _aim_judge() -> Dictionary:
	# 判定「现在这一杆，瞄着的球能不能进」
	var out := {"ok": false, "text": "", "pocket": null, "idx": -1}
	if _aim_hit.is_empty():
		out["text"] = "没瞄到球"
		return out
	var bp: Vector2 = _aim_hit["p"]
	var idx: int = int(_aim_hit["i"])
	var t: float = float(_aim_hit["t"])
	var contact: Vector2 = _cue + _aim_s * t
	var odn := _obj_dir_from(_cue, bp, _aim_s)
	if odn == Vector2.ZERO:
		out["text"] = "贴死球，打不动"
		out["idx"] = idx
		return out
	if t > REACH + 0.02 and _blocked(_cue, contact, [idx, 0]):
		out["text"] = "母球路线被挡"
		out["idx"] = idx
		return out
	var best := {}
	for pk in _pockets:
		var pc: Vector2 = pk["p"]
		var pr: float = float(pk["r"]) * 0.85
		if (pc - bp).dot(odn) <= 0.2:
			continue
		var md := _seg_dist(pc, bp, bp + odn * 40.0)
		if md > pr:
			continue
		if _blocked(bp, bp + odn * maxf(0.1, bp.distance_to(pc) - pr), [idx, 0]):
			continue
		if best.is_empty() or md < float(best["md"]):
			best = {"pk": pk, "md": md, "pr": pr}
	if not best.is_empty():
		var tol := 0.0
		for k in [0.0087, 0.0175, 0.0262, 0.0349, 0.0524, 0.0698]:
			var good := true
			for s in [1.0, -1.0]:
				var d2 := _aim_s.rotated(float(s) * float(k))
				var od2 := _obj_dir_from(_cue, bp, d2)
				if od2 == Vector2.ZERO:
					good = false
					break
				if _seg_dist(best["pk"]["p"], bp, bp + od2 * 40.0) > float(best["pr"]):
					good = false
					break
			if good:
				tol = float(k)
		out["ok"] = true
		out["idx"] = idx
		out["pocket"] = best["pk"]["p"]
		out["text"] = "可进 %d 号 → %s  容差±%.1f°" % [idx, str(best["pk"]["p"]), rad_to_deg(tol)]
		return out
	# 进不了：算出差多少度
	var near := {}
	for pk2 in _pockets:
		var pc2: Vector2 = pk2["p"]
		if (pc2 - bp).dot(odn) <= 0.2:
			continue
		var md2 := _seg_dist(pc2, bp, bp + odn * 40.0)
		if near.is_empty() or md2 < float(near["md"]):
			near = {"pk": pk2, "md": md2, "pr": float(pk2["r"]) * 0.85}
	out["idx"] = idx
	if near.is_empty():
		out["text"] = "%d 号：没有袋在出球方向上" % idx
		return out
	var dist := maxf(1.0, bp.distance_to(near["pk"]["p"]))
	var deg := rad_to_deg(atan2(float(near["md"]), dist))
	out["pocket"] = near["pk"]["p"]
	out["text"] = "%d 号 打不进：偏 %.1f°（差 %.2f）" % [idx, deg, float(near["md"])]
	return out

func _draw_rings(cam: Camera3D) -> void:
	# 所有「有袋可进」的球都套一个小圈；推荐的那颗更亮
	if not show_best:
		return
	var best_idx: int = int(_best.get("idx", -1))
	for c in _legal:
		var idx: int = int(c["idx"])
		var tp: Vector2 = c["target"]
		if idx == best_idx:
			_ring(cam, tp, 0.30, Color(0.35, 1.0, 0.55, 0.85), 1.8)
		else:
			_ring(cam, tp, 0.28, Color(0.85, 0.9, 1.0, 0.30), 1.0)

func _draw_best(cam: Camera3D) -> void:
	if _best.is_empty() or not show_best:
		return
	var strong: bool = true
	var tp: Vector2 = _best["target"]
	var pp: Vector2 = _best["pocket"]
	var ghost: Vector2 = _best["ghost"]
	# 当前瞄准打的正是推荐球、且方向一致 → 推荐线和瞄准线完全重叠，只留一个袋口圈
	var same := false
	if not _aim_hit.is_empty() and int(_aim_hit.get("i", -1)) == int(_best["idx"]):
		var bd: Vector2 = _best["dir"]
		if absf(_aim_s.angle_to(bd)) < 0.22:
			same = true
	if same:
		_ring(cam, pp, 0.24, Color(1.0, 1.0, 0.40, 0.40), 1.0)
		return
	var a: float = 0.95 if strong else 0.55
	var gc := Color(0.35, 1.0, 0.55, a)
	if _best_loose:
		gc = Color(1.0, 0.72, 0.30, a)
	_solid(cam, tp, pp, Color(gc.r, gc.g, gc.b, a * 0.25), 4.0)
	_solid(cam, tp, pp, gc, 1.6)

	_ring(cam, ghost, 0.23, Color(0.45, 0.95, 1.0, a * 0.7), 1.2)

func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var g := _global()
	var can := false
	if g != null:
		can = bool(g.call("can_shoot"))
	var lines: Array = []
	lines.append("%s   F7对齐 F8出杆  源:%s" % [_msg, SRC_NAMES[_src_idx]])
	lines.append("by.Ysmeral   G推荐:%s  T换球 B换袋  源:%s" % ["开" if show_best else "关", SRC_NAMES[_src_idx]])
	var pw := "自动" if auto_power <= 0.0 else "%.1f" % auto_power
	lines.append("力度 %s 误差 %.1f° 球 %d can=%s" % [pw, _err_deg(), _balls.size(), str(can)])
	if not _best.is_empty():
		lines.append("推荐 %d 号 → %s%s" % [int(_best["idx"]), str(_best["pocket"]), "（参考线·可能被挡）" if _best_loose else ""])
	var judge_idx := -1
	if not _judge.is_empty():
		judge_idx = lines.size()
		lines.append("判定 %s" % str(_judge.get("text", "")))
	var box := Rect2(Vector2(12.0, 6.0), Vector2(640.0, 8.0 + 21.0 * lines.size()))
	_canvas.draw_rect(box, Color(0.02, 0.02, 0.04, 0.55), true)
	var y := 27.0
	for i in lines.size():
		var col := Color(0.93, 0.93, 1.0, 0.95)
		if i == 0:
			col = Color(1.0, 0.6, 0.8, 1.0)
		if i == judge_idx:
			col = Color(0.35, 1.0, 0.55, 1.0) if bool(_judge.get("ok", false)) else Color(1.0, 0.55, 0.35, 1.0)
		_canvas.draw_string(font, Vector2(20.0, y), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		y += 21.0

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if not _ready_done:
		return
	if Engine.get_process_frames() < WARMUP_FRAMES:
		return
	if _global() == null:
		return
	_input_keys()
	_sample_sources()
	_src_pick_t += delta
	if _src_pick_t > 0.5:
		_src_pick_t = 0.0
		_pick_source()
	_refresh()
	if not _rails_ok:
		_rail_t += delta
		if _rail_t > 1.0:
			_rail_t = 0.0
			_measure_rails()
	if show_hud or show_aim:
		_scan()
	if _fire_phase != 0:
		_fire_tick(delta)
	_judge_t += delta
	if _judge_t > 0.1:
		_judge_t = 0.0
		var hc := _ray_to_cushion(_cue, _aim_s)
		_aim_hit = _ray_to_ball(_cue, hc["p"], _aim_s)
		_judge = _aim_judge()
	if _canvas != null and _ok(_canvas):
		_canvas.queue_redraw()
	_stat_t += delta
	if _stat_t > 1.0:
		_stat_t = 0.0
		_write_status()
		_diag("auto")

func _write_status() -> void:
	var g := _global()
	if g == null:
		return
	var f := FileAccess.open(DIR + "nbr_status.txt", FileAccess.WRITE)
	if f == null:
		return
	f.store_line("cue=%s aim=%s src=%s balls=%d" % [str(_cue), str(_aim), SRC_NAMES[_src_idx], _balls.size()])
	f.store_line("can_shoot=%s best_empty=%s" % [str(g.call("can_shoot")), str(_best.is_empty())])
	f.store_line("move=" + str(_src_move))
	f.store_line("rails=%.3f,%.3f measured=%s" % [_rail_x, _rail_z, str(_rails_ok)])
	if _aim_hit.is_empty():
		f.store_line("aim_hit=none")
	else:
		f.store_line("aim_hit=%d t=%.3f p=%s" % [int(_aim_hit["i"]), float(_aim_hit["t"]), str(_aim_hit["p"])])
	var bs := ""
	for b in _balls:
		var bp2: Vector2 = b["p"]
		bs += "%d(%.2f,%.2f) " % [int(b["i"]), bp2.x, bp2.y]
	f.store_line("球: " + bs)
	f.store_line("judge=" + str(_judge.get("text", "")))
	f.close()
