extends SceneTree
## Headless: fases do W1, telegraph só arma hitbox depois, 4 cenas novas,
## KINDS de chefe no WaveDirector. Sem ondas w2–w5 (frente mundos).
##   godot --headless --path . -s res://scripts/qa/smoke_boss_phases.gd

const W1_BOSS := "res://scenes/characters/enemies/oni_boss.tscn"
const NEW_BOSSES: PackedStringArray = [
	"res://scenes/characters/enemies/oni_boss_fire.tscn",
	"res://scenes/characters/enemies/oni_boss_dual.tscn",
	"res://scenes/characters/enemies/oni_boss_castle.tscn",
	"res://scenes/characters/enemies/oni_boss_final.tscn",
]
const REQUIRED_KINDS: PackedStringArray = [
	"boss", "boss_fire", "boss_dual", "boss_castle", "boss_final",
]
const WAVE_SCRIPT := "res://scripts/battle/wave_director.gd"
const COMMON_SCRIPT := "res://scripts/characters/enemies/boss_common.gd"
const BANNED_IP: PackedStringArray = ["Muzan", "Kokushibo", "Akaza", "Doma", "Hantengu"]

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== smoke_boss_phases ===")
	_check_common()
	_check_kinds()
	await _check_w1_phases_and_telegraph()
	await _check_new_scenes()
	await _check_castle_teleport_anchors()
	if _failed > 0:
		print("=== BOSS PHASES FAIL === falhas=%d" % _failed)
		quit(1)
		return
	print("=== BOSS PHASES PASS ===")
	quit(0)


func _fail(msg: String) -> void:
	_failed += 1
	push_error("[boss-phases] %s" % msg)
	print("  FAIL %s" % msg)


func _check_common() -> void:
	var bc: GDScript = load(COMMON_SCRIPT) as GDScript
	if bc == null:
		_fail("não carregou %s" % COMMON_SCRIPT)
		return
	if int(bc.phase_from_ratio(1.0)) != 0:
		_fail("phase_from_ratio(1.0) deveria ser P1")
	if int(bc.phase_from_ratio(0.6)) != 1:
		_fail("phase_from_ratio(0.6) deveria ser P2")
	if int(bc.phase_from_ratio(0.61)) != 0:
		_fail("phase_from_ratio(0.61) deveria ser P1")
	if int(bc.phase_from_ratio(0.25)) != 2:
		_fail("phase_from_ratio(0.25) deveria ser P3")
	if int(bc.next_phase(0, 180, 300)) != 1:
		_fail("next_phase 180/300 deveria avançar pra P2")
	if int(bc.next_phase(1, 300, 300)) != 1:
		_fail("next_phase não deve recuar")
	if bc.did_advance(0, 0):
		_fail("did_advance(0,0) falso")
	if not bc.did_advance(0, 1):
		_fail("did_advance(0,1) verdadeiro")
	if not is_equal_approx(float(bc.hp_ratio(0, 0)), 0.0):
		_fail("hp_ratio max 0 = 0")
	if not is_equal_approx(float(bc.telegraph_duration(1.0, 2)), 0.72):
		_fail("telegraph_duration P3 = 0.72")
	if not is_equal_approx(float(bc.recovery_duration(1.0, 2)), 0.75):
		_fail("recovery_duration P3 = 0.75")
	if not bc.is_boss_kind("boss") or not bc.is_boss_kind("boss_fire"):
		_fail("is_boss_kind boss/boss_fire")
	if bc.is_boss_kind("weak") or bc.is_boss_kind("bossy"):
		_fail("is_boss_kind não pode aceitar weak/bossy")
	if int(bc.alive_count([])) != 0:
		_fail("alive_count vazio")
	print("  OK BossCommon fases/telegraph/kinds")


func _check_kinds() -> void:
	var script: GDScript = load(WAVE_SCRIPT) as GDScript
	if script == null:
		_fail("não carregou %s" % WAVE_SCRIPT)
		return
	var consts: Dictionary = script.get_script_constant_map()
	var kinds: PackedStringArray = consts.get("KINDS", PackedStringArray())
	for k: String in REQUIRED_KINDS:
		if not kinds.has(k):
			_fail("KINDS sem '%s'" % k)
	var wd := Node.new()
	wd.set_script(script)
	var w2: Array = wd.call("_waves_for_stage", "w2_01")
	print("  OK _waves_for_stage w2_01 size=%d" % w2.size())
	for k: String in REQUIRED_KINDS:
		var packed: PackedScene = wd.call("_scene_for_kind", k) as PackedScene
		if packed == null:
			_fail("_scene_for_kind('%s') null" % k)
			continue
		var path: String = packed.resource_path
		if k != "boss" and not path.contains("oni_boss_"):
			_fail("_scene_for_kind('%s') caiu em %s" % [k, path])
		else:
			print("  OK kind %s -> %s" % [k, path])
	wd.free()


func _check_w1_phases_and_telegraph() -> void:
	var packed: PackedScene = load(W1_BOSS) as PackedScene
	if packed == null:
		_fail("load falhou: %s" % W1_BOSS)
		return
	var boss: Node = packed.instantiate()
	if boss == null:
		_fail("instantiate falhou: %s" % W1_BOSS)
		return
	boss.set("skip_intro", true)
	root.add_child(boss)
	await process_frame
	await process_frame

	_assert_hud(boss, "W1")
	_assert_no_ip_name(str(boss.get("boss_display_name")))

	if int(boss.get("phase")) != 0:
		_fail("W1 nasceu fora de P1")

	boss.set("hp", 180)
	boss.call("_check_phase_transition")
	if int(boss.get("phase")) != 1:
		_fail("W1 hp=180 não entrou em P2 (phase=%s)" % str(boss.get("phase")))
	else:
		print("  OK W1 P2 em 60% HP")

	boss.set("hp", 75)
	boss.call("_check_phase_transition")
	if int(boss.get("phase")) != 2:
		_fail("W1 hp=75 não entrou em P3 (phase=%s)" % str(boss.get("phase")))
	else:
		print("  OK W1 P3 em 25% HP")

	var hb: Hitbox = boss.get_node_or_null("Hitbox") as Hitbox
	if hb == null:
		_fail("W1 sem Hitbox")
	else:
		if hb.is_active():
			_fail("W1 hitbox ativa antes do telegraph")
		# State.TELEGRAPH = 3, AttackKind.CHARGE = 0
		boss.set("state", 3)
		boss.set("_pending_attack", 0)
		boss.set("_phase_timer", 0.0)
		if hb.is_active():
			_fail("W1 hitbox ligada no início do telegraph")
		var dur: float = float(boss.call("_telegraph_duration_for", 0))
		boss.call("_ai_telegraph", dur + 0.05)
		if not hb.is_active():
			_fail("W1 hitbox deveria ligar só depois do telegraph (dur=%s)" % dur)
		else:
			print("  OK telegraph CHARGE arma hitbox depois (dur=%.2f)" % dur)
		hb.disable()

	var died_before: bool = bool(boss.get("_died"))
	if died_before:
		_fail("W1 _died cedo demais")
	var data: HitData = HitData.new()
	data.damage = 9999
	data.knockback = Vector2.ZERO
	boss.call("_on_hurt", data)
	if not bool(boss.get("_died")):
		_fail("W1 não marcou _died após HP 0 (portal espera isto)")
	else:
		print("  OK W1 defeated/_died (WaveDirector só então libera portal)")

	boss.queue_free()
	await process_frame


func _check_new_scenes() -> void:
	for path: String in NEW_BOSSES:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			_fail("load falhou: %s" % path)
			continue
		var n: Node = packed.instantiate()
		if n == null:
			_fail("instantiate falhou: %s" % path)
			continue
		n.set("skip_intro", true)
		root.add_child(n)
		await process_frame
		if int(n.get("hp")) <= 0:
			_fail("%s hp inválido" % path)
		_assert_hud(n, path)
		_assert_no_ip_name(str(n.get("boss_display_name")))
		if n.get_node_or_null("Sprite") == null:
			_fail("%s sem Sprite" % path)
		print("  OK load %s name=%s hp=%s" % [path, n.get("boss_display_name"), n.get("hp")])
		n.queue_free()
		await process_frame


func _check_castle_teleport_anchors() -> void:
	## WaveDirector faz add_child (dispara _ready com x da cena ~0) e SÓ DEPOIS
	## seta global_position em boss_spawn_x (~760). Âncoras TELEPORT assadas no
	## _ready ficam em -200/0/200 — fora do chão. Este smoke reproduz essa ordem.
	const CASTLE := "res://scenes/characters/enemies/oni_boss_castle.tscn"
	const SPAWN_X := 760.0
	const ROOM_SPAN := 200.0
	const NEAR_ORIGIN := 100.0
	var packed: PackedScene = load(CASTLE) as PackedScene
	if packed == null:
		_fail("load falhou: %s" % CASTLE)
		return
	var boss: Node2D = packed.instantiate() as Node2D
	if boss == null:
		_fail("instantiate falhou: %s" % CASTLE)
		return
	boss.set("skip_intro", true)
	root.add_child(boss)
	await process_frame
	boss.global_position.x = SPAWN_X
	await process_frame
	boss.call("_do_teleport")
	var rooms: PackedFloat32Array = boss.get("_rooms") as PackedFloat32Array
	if rooms.size() != 3:
		_fail("castle TELEPORT _rooms size=%d (esperava 3)" % rooms.size())
	else:
		for i in range(3):
			var expected: float = SPAWN_X + float(i - 1) * ROOM_SPAN
			var got: float = rooms[i]
			if absf(got) < NEAR_ORIGIN:
				_fail("castle TELEPORT âncora[%d]=%.1f perto de x=0 com spawn %.0f" % [i, got, SPAWN_X])
			elif absf(got - expected) > 1.0:
				_fail("castle TELEPORT âncora[%d]=%.1f deveria ser ~%.1f" % [i, got, expected])
		print("  OK castle rooms=[%.0f, %.0f, %.0f] em torno do spawn %.0f" % [rooms[0], rooms[1], rooms[2], SPAWN_X])
	var px: float = boss.global_position.x
	if absf(px) < NEAR_ORIGIN:
		_fail("castle TELEPORT caiu em x=%.1f (perto de 0) com spawn %.0f" % [px, SPAWN_X])
	elif absf(px - SPAWN_X) > ROOM_SPAN + 1.0:
		_fail("castle TELEPORT x=%.1f fora das salas do spawn %.0f" % [px, SPAWN_X])
	else:
		print("  OK castle TELEPORT x=%.0f (não origin)" % px)
	boss.queue_free()
	await process_frame


func _assert_hud(n: Node, tag: String) -> void:
	if n.get_node_or_null("BossHpLayer") == null:
		_fail("%s sem barra de HP (BossHpLayer)" % tag)
	if n.get_node_or_null("BossBannerLayer") == null:
		_fail("%s sem banner (BossBannerLayer)" % tag)


func _assert_no_ip_name(display: String) -> void:
	for banned: String in BANNED_IP:
		if display.findn(banned) >= 0:
			_fail("nome de chefe usa IP oficial: '%s'" % display)
