extends Node
## Estado global leve (progress├úo, moedas banked, upgrades, personagem atual).
## N├úo colocar l├│gica de combate aqui.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const UPGRADE_CATALOG_PATH := "res://resources/upgrades/catalog.json"
const DEFAULT_PLAYER_STATS := "res://resources/player/player_stats.tres"
const DASH_COOLDOWN_FLOOR := 0.35
## Limite do nome de cacador. Fonte unica: a tela de nome usa isto no LineEdit.
const MAX_PLAYER_NAME_LEN := 14

## Emite o total banked (hub) OU o valor da run dependendo do caller.
## Hub ignora o payload e rel├¬ `coins_banked`. HUD de combate usa `run_coins_changed`.
signal coins_changed(total: int)
## Moedas da run atual (fase). Preferir este sinal no combate.
signal run_coins_changed(run_total: int)
signal breath_changed(value: float, max_value: float)
signal upgrades_changed
## Nome de cacador escolhido pelo jogador (onboarding ou renomeacao no hub).
signal player_name_changed(new_name: String)

var coins_banked: int = 0
## Vazio = jogador ainda nao passou pelo onboarding de nome.
var player_name: String = ""
var current_character_id: String = "tanjiro"
var stages_cleared: Array[String] = []
var upgrades: Dictionary = {}  # id -> level

# Run / fase atual (n├úo grava at├® bank)
var coins_run: int = 0
var breath: float = 0.0
var breath_max: float = 100.0

var audio_volume_master: float = 1.0
var audio_volume_bgm: float = 0.75
var audio_volume_sfx: float = 1.0
## Stage id opcional (mapa / debug) antes de trocar de cena.
var pending_stage_id: String = "w1_01"

var _catalog: Array[UpgradeDef] = []
var _catalog_loaded: bool = false
## Caminho efetivo do save. Em producao e sempre SAVE_PATH; smokes headless
## apontam para um arquivo temporario (ver `set_save_path`) para nunca encostar
## no save real do jogador — antes um smoke podia deixar o save do dev sujo.
var _save_path: String = SAVE_PATH


func _ready() -> void:
	_ensure_catalog()
	load_game()
	call_deferred("_sync_audio_volumes")


# --- Nome do jogador ---

## Espacos que o `split(" ")` nao enxerga: NBSP (U+00A0), OGHAM (U+1680), a faixa
## tipografica U+2000-U+200A, NNBSP, MMSP e o ideografico. Viram espaco comum.
static func _is_space_like(code: int) -> bool:
	if code == 0x00A0 or code == 0x1680 or code == 0x202F or code == 0x205F or code == 0x3000:
		return true
	return code >= 0x2000 and code <= 0x200A


## Formatadores de largura zero (categoria Unicode Cf): soft hyphen, ZWSP/ZWNJ/ZWJ,
## marcas e overrides bidi, isolates bidi, word joiner e BOM. Nao renderizam nada —
## passavam pelo filtro antigo (`>= 32`) e deixavam um nome invisivel burlar o gate
## do onboarding (badge do hub em branco, `has_player_name()` mentindo true).
static func _is_invisible_format(code: int) -> bool:
	if code == 0x00AD or code == 0xFEFF:
		return true
	if code >= 0x200B and code <= 0x200F:
		return true
	if code >= 0x202A and code <= 0x202E:
		return true
	if code >= 0x2060 and code <= 0x2064:
		return true
	return code >= 0x2066 and code <= 0x2069


## "Blank letters": codepoints que NAO sao Cc/C1/Cf/Zs — logo escapavam de todos
## os filtros acima — mas desenham exatamente nada. E o bypass classico de nome
## invisivel em jogo online: U+3164 (HANGUL FILLER) e o mais usado, seguido do
## meio-largura U+FFA0 e do BRAILLE BLANK U+2800.
## Os seletores de variacao (U+FE00-FE0F) entram aqui pelo mesmo motivo: sozinhos
## nao desenham nada. Grudados num emoji so mudam a apresentacao, entao nome com
## emoji continua valido — ver o caso de emoji em `_test_sanitize`.
static func _is_blank_letter(code: int) -> bool:
	if code == 0x115F or code == 0x1160 or code == 0x2800 or code == 0x3164 or code == 0xFFA0:
		return true
	if code >= 0x17B4 and code <= 0x17B5:
		return true
	if code >= 0x180B and code <= 0x180E:
		return true
	return code >= 0xFE00 and code <= 0xFE0F


## Normaliza o que veio da UI: tira espacos das pontas, colapsa espacos internos,
## remove caracteres de controle e invisiveis, e corta no limite.
## Retorna "" se nao sobrar nada VISIVEL — a checagem de vazio e sempre a ultima
## etapa: validar antes de limpar era o furo que deixava ZWSP/NBSP passar.
static func sanitize_player_name(raw: String) -> String:
	var printable := ""
	for c in raw:
		var code: int = c.unicode_at(0)
		# C0 (tab, quebra de linha, NUL de paste), DEL (U+007F) e o bloco C1.
		if code < 32 or (code >= 0x7F and code <= 0x9F):
			continue
		# Invisiveis Cf: descarta antes de qualquer contagem de "tem conteudo".
		if _is_invisible_format(code):
			continue
		# Blank letters (Lo/Mn que nao desenham nada): mesmo bypass, outra categoria.
		if _is_blank_letter(code):
			continue
		# NBSP e afins viram espaco comum para o colapso abaixo enxergar.
		if _is_space_like(code):
			printable += " "
			continue
		printable += c
	var words: PackedStringArray = printable.split(" ", false)
	var clean := " ".join(words).strip_edges()
	if clean.length() > MAX_PLAYER_NAME_LEN:
		clean = clean.substr(0, MAX_PLAYER_NAME_LEN).strip_edges()
	# Recheca no fim, depois de TODA a limpeza (inclusive o corte pelo limite).
	if clean.is_empty():
		return ""
	return clean


func has_player_name() -> bool:
	return not player_name.is_empty()


## Define o nome (ja sanitizado internamente) e persiste. Retorna false se o nome
## for invalido — a UI usa isso para manter o botao de confirmar desabilitado.
func set_player_name(raw: String) -> bool:
	var clean := sanitize_player_name(raw)
	if clean.is_empty():
		return false
	if clean == player_name:
		return true
	player_name = clean
	player_name_changed.emit(player_name)
	save_game()
	return true


func add_run_coins(amount: int) -> void:
	coins_run += amount
	run_coins_changed.emit(coins_run)
	# Mant├®m API legada; hub rel├¬ banked no handler e n├úo quebra.
	coins_changed.emit(coins_run)


func bank_run_coins() -> void:
	coins_banked += coins_run
	coins_run = 0
	run_coins_changed.emit(coins_run)
	coins_changed.emit(coins_banked)
	save_game()


func lose_run_coins() -> void:
	coins_run = 0
	run_coins_changed.emit(coins_run)
	coins_changed.emit(coins_run)


func add_breath_from_hit(amount: float = 10.0) -> void:
	var was_ready: bool = is_ultimate_ready()
	breath = minf(breath + amount, breath_max)
	breath_changed.emit(breath, breath_max)
	# SFX only on the edge into full breath (not every hit while already full).
	if not was_ready and is_ultimate_ready():
		var audio := get_node_or_null("/root/Audio")
		if audio != null and audio.has_method("play_sfx"):
			audio.call("play_sfx", "breath_full")


func is_ultimate_ready() -> bool:
	return breath >= breath_max


func consume_ultimate() -> void:
	breath = 0.0
	breath_changed.emit(breath, breath_max)


func is_stage_cleared(stage_id: String) -> bool:
	return stage_id in stages_cleared


func mark_stage_cleared(stage_id: String) -> void:
	if stage_id not in stages_cleared:
		stages_cleared.append(stage_id)
		save_game()


# --- Upgrades / loja ---

func get_upgrade_catalog() -> Array[UpgradeDef]:
	_ensure_catalog()
	return _catalog


func get_upgrade_def(upgrade_id: String) -> UpgradeDef:
	_ensure_catalog()
	for def in _catalog:
		if def.id == upgrade_id:
			return def
	return null


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func get_upgrade_next_cost(upgrade_id: String) -> int:
	var def: UpgradeDef = get_upgrade_def(upgrade_id)
	if def == null:
		return -1
	return def.cost_for_next_level(get_upgrade_level(upgrade_id))


func can_buy_upgrade(upgrade_id: String) -> bool:
	var def: UpgradeDef = get_upgrade_def(upgrade_id)
	if def == null:
		return false
	var level: int = get_upgrade_level(upgrade_id)
	if def.is_maxed(level):
		return false
	var cost: int = def.cost_for_next_level(level)
	return cost > 0 and coins_banked >= cost


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy_upgrade(upgrade_id):
		return false
	var def: UpgradeDef = get_upgrade_def(upgrade_id)
	var level: int = get_upgrade_level(upgrade_id)
	var cost: int = def.cost_for_next_level(level)
	coins_banked -= cost
	upgrades[upgrade_id] = level + 1
	coins_changed.emit(coins_banked)
	upgrades_changed.emit()
	save_game()
	return true


## Duplica stats base e aplica n├¡veis da loja. N├úo muta o .tres em disco.
func apply_upgrades_to_stats(base: PlayerStats) -> PlayerStats:
	var s: PlayerStats
	if base != null:
		s = base.duplicate(true) as PlayerStats
	else:
		s = load(DEFAULT_PLAYER_STATS) as PlayerStats
		if s == null:
			s = PlayerStats.new()
		else:
			s = s.duplicate(true) as PlayerStats
	_ensure_catalog()
	for def in _catalog:
		var level: int = get_upgrade_level(def.id)
		if level <= 0:
			continue
		var delta: float = def.value_per_level * float(level)
		match def.stat_key:
			"max_hp":
				s.max_hp = maxf(1.0, s.max_hp + delta)
			"attack_damage":
				s.attack_damage = maxi(1, s.attack_damage + int(round(delta)))
			"move_speed":
				s.move_speed = maxf(40.0, s.move_speed + delta)
			"dash_cooldown":
				s.dash_cooldown = maxf(DASH_COOLDOWN_FLOOR, s.dash_cooldown + delta)
			_:
				push_warning("Game: stat_key desconhecido no upgrade %s: %s" % [def.id, def.stat_key])
	return s


func build_player_stats() -> PlayerStats:
	var base: PlayerStats = load(DEFAULT_PLAYER_STATS) as PlayerStats
	return apply_upgrades_to_stats(base)


# --- Save ---

## Caminho de save em uso agora. Preferir isto a `SAVE_PATH` em testes.
func get_save_path() -> String:
	return _save_path


## Redireciona o save para outro arquivo (uso exclusivo dos smokes headless).
## Passar "" volta para o caminho padrao do jogador.
func set_save_path(path: String) -> void:
	_save_path = SAVE_PATH if path.is_empty() else path


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"coins_banked": coins_banked,
		"player_name": player_name,
		"current_character_id": current_character_id,
		"stages_cleared": stages_cleared,
		"upgrades": upgrades,
	}
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var f := FileAccess.open(_save_path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	coins_banked = int(data.get("coins_banked", 0))
	# Save antigo (sem a chave) cai em "" e manda o jogador pro onboarding de nome.
	player_name = sanitize_player_name(str(data.get("player_name", "")))
	current_character_id = str(data.get("current_character_id", "tanjiro"))
	var raw_upgrades: Variant = data.get("upgrades", {})
	upgrades = {}
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		for k in raw_upgrades:
			upgrades[str(k)] = int(raw_upgrades[k])
	var cleared: Array = data.get("stages_cleared", [])
	stages_cleared.clear()
	for s in cleared:
		stages_cleared.append(str(s))


func _ensure_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	_catalog.clear()
	if not FileAccess.file_exists(UPGRADE_CATALOG_PATH):
		push_error("Game: cat├ílogo de upgrades ausente: %s" % UPGRADE_CATALOG_PATH)
		_load_fallback_catalog()
		return
	var f := FileAccess.open(UPGRADE_CATALOG_PATH, FileAccess.READ)
	if f == null:
		_load_fallback_catalog()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_load_fallback_catalog()
		return
	var list: Array = parsed.get("upgrades", [])
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var def := UpgradeDef.new()
		def.id = str(d.get("id", ""))
		def.display_name = str(d.get("display_name", def.id))
		def.description = str(d.get("description", ""))
		def.max_level = int(d.get("max_level", 3))
		def.stat_key = str(d.get("stat_key", ""))
		def.value_per_level = float(d.get("value_per_level", 0.0))
		def.costs = []
		var costs_raw: Array = d.get("costs", [30, 60, 120])
		for c in costs_raw:
			def.costs.append(int(c))
		if def.id != "":
			_catalog.append(def)
	if _catalog.is_empty():
		_load_fallback_catalog()


func _load_fallback_catalog() -> void:
	var defs: Array[Dictionary] = [
		{"id": "max_hp", "display_name": "Vida Maxima", "description": "+10 HP por nivel.", "stat_key": "max_hp", "value_per_level": 10.0},
		{"id": "attack", "display_name": "Dano", "description": "+2 dano por nivel.", "stat_key": "attack_damage", "value_per_level": 2.0},
		{"id": "speed", "display_name": "Velocidade", "description": "+20 velocidade por nivel.", "stat_key": "move_speed", "value_per_level": 20.0},
		{"id": "dash_cd", "display_name": "Dash Rapido", "description": "-0,12 s dash CD por nivel.", "stat_key": "dash_cooldown", "value_per_level": -0.12},
	]
	for d in defs:
		var def := UpgradeDef.new()
		def.id = str(d["id"])
		def.display_name = str(d["display_name"])
		def.description = str(d["description"])
		def.max_level = 3
		def.costs = [30, 60, 120]
		def.stat_key = str(d["stat_key"])
		def.value_per_level = float(d["value_per_level"])
		_catalog.append(def)




func _sync_audio_volumes() -> void:
	var a = get_node_or_null("/root/Audio")
	if a != null and a.has_method("apply_volumes"):
		a.call("apply_volumes", audio_volume_master, audio_volume_bgm, audio_volume_sfx, false)


