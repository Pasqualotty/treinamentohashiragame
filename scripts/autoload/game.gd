extends Node
## Estado global leve (progress├úo, moedas banked, upgrades, personagem atual).
## N├úo colocar l├│gica de combate aqui.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const UPGRADE_CATALOG_PATH := "res://resources/upgrades/catalog.json"
const DEFAULT_PLAYER_STATS := "res://resources/player/player_stats.tres"
const DASH_COOLDOWN_FLOOR := 0.35
## Ripple do upgrade Dano: mesmo nível global sobe skills/ult (não só o básico).
const ATTACK_SKILL_1_RIPPLE := 4
const ATTACK_SKILL_2_RIPPLE := 3
const ATTACK_ULTIMATE_RIPPLE := 6
## Limite do nome de cacador. Fonte unica: a tela de nome usa isto no LineEdit.
const MAX_PLAYER_NAME_LEN := 24

## Emite o total banked (hub) OU o valor da run dependendo do caller.
## Hub ignora o payload e rel├¬ `coins_banked`. HUD de combate usa `run_coins_changed`.
signal coins_changed(total: int)
## Moedas da run atual (fase). Preferir este sinal no combate.
signal run_coins_changed(run_total: int)
signal breath_changed(value: float, max_value: float)
signal upgrades_changed
## Nome de cacador escolhido pelo jogador (onboarding ou renomeacao no hub).
signal player_name_changed(new_name: String)
## Personagem atual (elenco). Hub e select escutam para atualizar o showcase.
signal character_changed(character_id: String)
## Lista local de amigos (LAN). Sem IP.
signal friends_changed
## Convites de amigo (entrada / saída) mudaram.
signal friend_invites_changed
## Vitórias em sala (1v1 / mapa). Local, no save.
signal trophies_changed(total: int)

const FRIENDS_CAP := 16
const PENDING_CAP := 16

var coins_banked: int = 0
## Vazio = jogador ainda nao passou pelo onboarding de nome.
var player_name: String = ""
var current_character_id: String = "tanjiro"
## Persistido. Save legado sem a chave começa só com o starter (Tanjiro).
var unlocked_characters: Array[String] = ["tanjiro"]
var stages_cleared: Array[String] = []
var upgrades: Dictionary = {}  # id -> level

# Run / fase atual (n├úo grava at├® bank)
var coins_run: int = 0
var breath: float = 0.0
var breath_max: float = 100.0

var audio_volume_master: float = 1.0
var mp_trophies: int = 0
var audio_volume_bgm: float = 0.32  # era 0.75 — alto demais no device
var audio_volume_sfx: float = 0.45  # era 1.0  — alto demais no device
## Stage id opcional (mapa / debug) antes de trocar de cena.
var pending_stage_id: String = "w1_01"
## Mundo visível no mapa. Persistido; o mapa clampa se ainda estiver trancado.
var current_world_id: String = "w1"
## Amigos LAN: `{name, friend_id, added_unix}`. Save legado sem a chave = [].
var friends: Array[Dictionary] = []
## Código de amigo persistente (8). Gerado na primeira vez.
var friend_code: String = ""
## Convites recebidos: `{friend_id, name}`.
var pending_in: Array[Dictionary] = []
## Convites enviados: `{friend_id, name}`.
var pending_out: Array[Dictionary] = []

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


func ensure_friend_code() -> String:
	if FriendCode.is_valid(friend_code):
		return FriendCode.normalize(friend_code)
	friend_code = FriendCode.generate()
	return friend_code


## Upsert pelo nome sanitizado. Recusa invisível. Cap 16. Sem IP.
func add_friend(raw_name: String, raw_id: String = "") -> bool:
	var clean := sanitize_player_name(raw_name)
	if clean.is_empty():
		return false
	var fid := FriendCode.normalize(raw_id) if FriendCode.is_valid(raw_id) else ""
	for i in friends.size():
		var have_id := str(friends[i].get("friend_id", ""))
		var same_id: bool = not fid.is_empty() and have_id == fid
		var same_name: bool = str(friends[i].get("name", "")) == clean
		var attach_id: bool = not fid.is_empty() and same_name and have_id.is_empty()
		if same_id or attach_id or (fid.is_empty() and same_name):
			friends[i]["name"] = clean
			if not fid.is_empty():
				friends[i]["friend_id"] = fid
			friends_changed.emit()
			save_game()
			return true
	if friends.size() >= FRIENDS_CAP:
		return false
	var rec: Dictionary = {"name": clean, "added_unix": int(Time.get_unix_time_from_system())}
	if not fid.is_empty():
		rec["friend_id"] = fid
	friends.append(rec)
	_drop_pending(fid)
	friends_changed.emit()
	save_game()
	return true


func friend_id_of(raw_name: String) -> String:
	var clean := sanitize_player_name(raw_name)
	if clean.is_empty():
		return ""
	for d in friends:
		if str(d.get("name", "")) == clean:
			var fid := str(d.get("friend_id", ""))
			return FriendCode.normalize(fid) if FriendCode.is_valid(fid) else ""
	return ""


func has_friend_id(raw_id: String) -> bool:
	if not FriendCode.is_valid(raw_id):
		return false
	var fid := FriendCode.normalize(raw_id)
	for d in friends:
		if str(d.get("friend_id", "")) == fid:
			return true
	return false


func has_friend_named(raw_name: String) -> bool:
	var clean := sanitize_player_name(raw_name)
	if clean.is_empty():
		return false
	for d in friends:
		if str(d.get("name", "")) == clean:
			return true
	return false


func remember_outgoing_invite(raw_id: String, raw_name: String) -> bool:
	var fid := FriendCode.normalize(raw_id) if FriendCode.is_valid(raw_id) else ""
	var clean := sanitize_player_name(raw_name)
	if clean.is_empty() and fid.is_empty():
		return false
	if clean.is_empty():
		clean = "Caçador"
	for i in pending_out.size():
		var same_id: bool = not fid.is_empty() and str(pending_out[i].get("friend_id", "")) == fid
		var same_name: bool = str(pending_out[i].get("name", "")) == clean
		if same_id or same_name:
			pending_out[i]["name"] = clean
			if not fid.is_empty():
				pending_out[i]["friend_id"] = fid
			friend_invites_changed.emit()
			save_game()
			return true
	if pending_out.size() >= PENDING_CAP:
		return false
	var rec: Dictionary = {"name": clean}
	if not fid.is_empty():
		rec["friend_id"] = fid
	pending_out.append(rec)
	friend_invites_changed.emit()
	save_game()
	return true


func add_incoming_invite(raw_id: String, raw_name: String) -> bool:
	if not FriendCode.is_valid(raw_id):
		return false
	var fid := FriendCode.normalize(raw_id)
	if has_friend_id(fid) or fid == ensure_friend_code():
		return false
	var clean := sanitize_player_name(raw_name)
	if clean.is_empty():
		clean = "Caçador"
	for i in pending_in.size():
		if str(pending_in[i].get("friend_id", "")) == fid:
			if str(pending_in[i].get("name", "")) != clean:
				pending_in[i]["name"] = clean
				friend_invites_changed.emit()
				save_game()
			return false
	if pending_in.size() >= PENDING_CAP:
		return false
	pending_in.append({"friend_id": fid, "name": clean})
	friend_invites_changed.emit()
	save_game()
	return true


func _drop_pending(fid: String) -> void:
	if fid.is_empty():
		return
	var pin: Array[Dictionary] = []
	for d in pending_in:
		if str(d.get("friend_id", "")) != fid:
			pin.append(d)
	var pout: Array[Dictionary] = []
	for d in pending_out:
		if str(d.get("friend_id", "")) != fid:
			pout.append(d)
	pending_in = pin
	pending_out = pout
	friend_invites_changed.emit()


func remove_incoming_invite(raw_id: String) -> bool:
	if not FriendCode.is_valid(raw_id):
		return false
	var fid := FriendCode.normalize(raw_id)
	var before: int = pending_in.size()
	var kept: Array[Dictionary] = []
	for d in pending_in:
		if str(d.get("friend_id", "")) != fid:
			kept.append(d)
	pending_in = kept
	if pending_in.size() == before:
		return false
	friend_invites_changed.emit()
	save_game()
	return true


func remove_friend(raw_name: String) -> bool:
	var clean := sanitize_player_name(raw_name)
	if clean.is_empty():
		return false
	var kept: Array[Dictionary] = []
	var removed := false
	for d in friends:
		if str(d.get("name", "")) == clean:
			removed = true
			continue
		kept.append(d)
	if not removed:
		return false
	friends = kept
	friends_changed.emit()
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
		_sync_character_unlocks()
		save_game()


func is_character_unlocked(character_id: String) -> bool:
	_sync_character_unlocks()
	return character_id in unlocked_characters


## Seleciona quem entra na fase. Recusa id locked ou fora do catálogo.
func select_character(character_id: String) -> bool:
	_sync_character_unlocks()
	if character_id not in unlocked_characters:
		return false
	if CharacterCatalog.find(character_id) == null:
		return false
	if current_character_id == character_id:
		return true
	current_character_id = character_id
	character_changed.emit(current_character_id)
	save_game()
	return true


## Libera quem cumpriu `unlock_requires` com o `stages_cleared` atual.
## Não grava sozinho — o caller persiste (load não deve sujar disco).
func _sync_character_unlocks() -> void:
	if CharacterCatalog.STARTER_ID not in unlocked_characters:
		unlocked_characters.insert(0, CharacterCatalog.STARTER_ID)
	for def: CharacterDef in CharacterCatalog.load_all():
		if def.is_unlocked(stages_cleared) and def.id not in unlocked_characters:
			unlocked_characters.append(def.id)
	_sanitize_current_character()


func _sanitize_current_character() -> void:
	if current_character_id in unlocked_characters and CharacterCatalog.find(current_character_id) != null:
		return
	current_character_id = CharacterCatalog.STARTER_ID
	if current_character_id not in unlocked_characters:
		unlocked_characters.insert(0, current_character_id)


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
				s.skill_1_damage = maxi(1, s.skill_1_damage + ATTACK_SKILL_1_RIPPLE * level)
				s.skill_2_damage = maxi(1, s.skill_2_damage + ATTACK_SKILL_2_RIPPLE * level)
				s.ultimate_damage = maxi(1, s.ultimate_damage + ATTACK_ULTIMATE_RIPPLE * level)
			"move_speed":
				s.move_speed = maxf(40.0, s.move_speed + delta)
			"dash_cooldown":
				s.dash_cooldown = maxf(DASH_COOLDOWN_FLOOR, s.dash_cooldown + delta)
			_:
				push_warning("Game: stat_key desconhecido no upgrade %s: %s" % [def.id, def.stat_key])
	return s


func build_player_stats() -> PlayerStats:
	var def: CharacterDef = CharacterCatalog.find(current_character_id)
	if def == null:
		def = CharacterCatalog.starter()
	var base: PlayerStats
	if def != null:
		base = def.build_stats()
	else:
		base = load(DEFAULT_PLAYER_STATS) as PlayerStats
	return apply_upgrades_to_stats(base)


# --- Save ---

## Caminho de save em uso agora. Preferir isto a `SAVE_PATH` em testes.
func get_save_path() -> String:
	return _save_path


## Redireciona o save para outro arquivo (uso exclusivo dos smokes headless).
## Passar "" volta para o caminho padrao do jogador.
func set_save_path(path: String) -> void:
	_save_path = SAVE_PATH if path.is_empty() else path


func get_mp_trophies() -> int:
	return mp_trophies


func add_mp_trophy() -> void:
	mp_trophies += 1
	trophies_changed.emit(mp_trophies)
	save_game()


func save_game() -> void:
	if not AtomicJson.write_dict(_save_path, _save_payload()):
		push_error("Save failed: %s" % FileAccess.get_open_error())


func load_game() -> void:
	var parsed: Variant = AtomicJson.read_dict(_save_path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply_save_data(parsed as Dictionary)


func _save_payload() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins_banked": coins_banked,
		"player_name": player_name,
		"current_character_id": current_character_id,
		"current_world_id": current_world_id,
		"unlocked_characters": unlocked_characters,
		"stages_cleared": stages_cleared,
		"upgrades": upgrades,
		"friends": _friends_payload(),
		"friend_code": ensure_friend_code(),
		"friend_pending_in": _pending_payload(pending_in),
		"friend_pending_out": _pending_payload(pending_out),
		"mp_trophies": mp_trophies,
	}


func _friends_payload() -> Array:
	var out: Array = []
	for d in friends:
		var name := sanitize_player_name(str(d.get("name", "")))
		if name.is_empty():
			continue
		var rec: Dictionary = {
			"name": name,
			"added_unix": int(d.get("added_unix", 0)),
		}
		var fid := str(d.get("friend_id", ""))
		if FriendCode.is_valid(fid):
			rec["friend_id"] = FriendCode.normalize(fid)
		out.append(rec)
	return out


func _pending_payload(src: Array[Dictionary]) -> Array:
	var out: Array = []
	for d in src:
		var name := sanitize_player_name(str(d.get("name", "")))
		if name.is_empty():
			continue
		var rec: Dictionary = {"name": name}
		var fid := str(d.get("friend_id", ""))
		if FriendCode.is_valid(fid):
			rec["friend_id"] = FriendCode.normalize(fid)
		out.append(rec)
	return out


func _apply_save_data(data: Dictionary) -> void:
	coins_banked = int(data.get("coins_banked", 0))
	# Save antigo (sem a chave) cai em "" e manda o jogador pro onboarding de nome.
	player_name = sanitize_player_name(str(data.get("player_name", "")))
	current_character_id = str(data.get("current_character_id", "tanjiro"))
	var loaded_world: String = str(data.get("current_world_id", "w1"))
	current_world_id = loaded_world if loaded_world != "" else "w1"
	var raw_upgrades: Variant = data.get("upgrades", {})
	upgrades = {}
	if typeof(raw_upgrades) == TYPE_DICTIONARY:
		for k in raw_upgrades:
			upgrades[str(k)] = int(raw_upgrades[k])
	var cleared: Array = data.get("stages_cleared", [])
	stages_cleared.clear()
	for s in cleared:
		stages_cleared.append(str(s))
	unlocked_characters.clear()
	if data.has("unlocked_characters"):
		var raw_chars: Variant = data.get("unlocked_characters", [])
		if raw_chars is Array:
			for cid in raw_chars:
				var sid := str(cid)
				if sid != "" and sid not in unlocked_characters:
					unlocked_characters.append(sid)
	if unlocked_characters.is_empty():
		unlocked_characters.append("tanjiro")
	_load_friends(data)
	_load_friend_code(data)
	_load_pending(data)
	mp_trophies = maxi(0, int(data.get("mp_trophies", 0)))
	_sync_character_unlocks()


func _load_friends(data: Dictionary) -> void:
	friends.clear()
	if not data.has("friends"):
		return
	var raw: Variant = data.get("friends", [])
	if not raw is Array:
		return
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var name := sanitize_player_name(str(d.get("name", "")))
		if name.is_empty():
			continue
		if friends.size() >= FRIENDS_CAP:
			break
		var exists := false
		for e in friends:
			if str(e.get("name", "")) == name:
				exists = true
				break
		if exists:
			continue
		var rec: Dictionary = {
			"name": name,
			"added_unix": int(d.get("added_unix", 0)),
		}
		var fid := str(d.get("friend_id", ""))
		if FriendCode.is_valid(fid):
			rec["friend_id"] = FriendCode.normalize(fid)
		friends.append(rec)


func _load_friend_code(data: Dictionary) -> void:
	var raw := str(data.get("friend_code", ""))
	if FriendCode.is_valid(raw):
		friend_code = FriendCode.normalize(raw)
	else:
		friend_code = FriendCode.generate()


func _load_pending(data: Dictionary) -> void:
	pending_in = _parse_pending(data.get("friend_pending_in", []))
	pending_out = _parse_pending(data.get("friend_pending_out", []))


func _parse_pending(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var fid := str(d.get("friend_id", ""))
		var name := sanitize_player_name(str(d.get("name", "")))
		if name.is_empty() and not FriendCode.is_valid(fid):
			continue
		if name.is_empty():
			name = "Caçador"
		var exists := false
		for e in out:
			var same_id: bool = FriendCode.is_valid(fid) and str(e.get("friend_id", "")) == FriendCode.normalize(fid)
			var same_name: bool = str(e.get("name", "")) == name
			if same_id or (not FriendCode.is_valid(fid) and same_name):
				exists = true
				break
		if exists:
			continue
		if out.size() >= PENDING_CAP:
			break
		var rec: Dictionary = {"name": name}
		if FriendCode.is_valid(fid):
			rec["friend_id"] = FriendCode.normalize(fid)
		out.append(rec)
	return out


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
		var costs_raw: Array = d.get("costs", [50, 200, 420])
		for c in costs_raw:
			def.costs.append(int(c))
		if def.id != "":
			_catalog.append(def)
	if _catalog.is_empty():
		_load_fallback_catalog()


func _load_fallback_catalog() -> void:
	var defs: Array[Dictionary] = [
		{"id": "max_hp", "display_name": "Vida Maxima", "description": "+15 de HP maximo por nivel.", "stat_key": "max_hp", "value_per_level": 15.0},
		{"id": "attack", "display_name": "Dano", "description": "+3 no basico; skills e ultimate tambem sobem.", "stat_key": "attack_damage", "value_per_level": 3.0},
		{"id": "speed", "display_name": "Velocidade", "description": "+20 de velocidade de movimento por nivel.", "stat_key": "move_speed", "value_per_level": 20.0},
		{"id": "dash_cd", "display_name": "Dash Rapido", "description": "-0,12 s no cooldown do dash por nivel.", "stat_key": "dash_cooldown", "value_per_level": -0.12},
	]
	for d in defs:
		var def := UpgradeDef.new()
		def.id = str(d["id"])
		def.display_name = str(d["display_name"])
		def.description = str(d["description"])
		def.max_level = 3
		def.costs = [50, 200, 420]
		def.stat_key = str(d["stat_key"])
		def.value_per_level = float(d["value_per_level"])
		_catalog.append(def)




func _sync_audio_volumes() -> void:
	var a = get_node_or_null("/root/Audio")
	if a != null and a.has_method("apply_volumes"):
		a.call("apply_volumes", audio_volume_master, audio_volume_bgm, audio_volume_sfx, false)


