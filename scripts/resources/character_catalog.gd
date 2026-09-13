class_name CharacterCatalog
extends RefCounted
## Catálogo do elenco jogável — fonte única de verdade para select, save e player.
##
## COMO ADICIONAR UM PERSONAGEM
##   1. Criar `resources/characters/<id>.tres` (CharacterDef) + kit de stats.
##   2. Acrescentar o caminho em `PATHS` (ordem da tela PERSONAGENS).
##   3. Ligar `hub_frames_dir` / `portrait_path` / `combat_frames_dir` se houver pack.
##   4. O smoke `smoke_character_select` exige os 15 ids (Nezuko após Tanjiro).
##
## Autoload `Game` NÃO é lido aqui na compilação — smokes `godot -s` quebram se
## um `class_name` tocar o identificador global `Game` no parse.

const STARTER_ID: String = "tanjiro"

const PATHS: PackedStringArray = [
	"res://resources/characters/tanjiro.tres",
	"res://resources/characters/nezuko.tres",
	"res://resources/characters/zenitsu.tres",
	"res://resources/characters/inosuke.tres",
	"res://resources/characters/kanao.tres",
	"res://resources/characters/shinobu.tres",
	"res://resources/characters/uzui.tres",
	"res://resources/characters/rengoku.tres",
	"res://resources/characters/tomioka.tres",
	"res://resources/characters/obanai.tres",
	"res://resources/characters/tokito.tres",
	"res://resources/characters/sanemi.tres",
	"res://resources/characters/gyomei.tres",
	"res://resources/characters/yoriichi.tres",
	"res://resources/characters/muzan.tres",
]

const EXPECTED_IDS: PackedStringArray = [
	"tanjiro",
	"nezuko",
	"zenitsu",
	"inosuke",
	"kanao",
	"shinobu",
	"uzui",
	"rengoku",
	"tomioka",
	"obanai",
	"tokito",
	"sanemi",
	"gyomei",
	"yoriichi",
	"muzan",
]


static func load_all() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for path: String in PATHS:
		var res: Resource = load(path)
		var def := res as CharacterDef
		if def == null:
			push_error("CharacterCatalog: CharacterDef inválido em %s" % path)
			continue
		if def.id == "":
			push_error("CharacterCatalog: CharacterDef sem id em %s" % path)
			continue
		out.append(def)
	return out


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for def: CharacterDef in load_all():
		out.append(def.id)
	return out


static func find(character_id: String) -> CharacterDef:
	for def: CharacterDef in load_all():
		if def.id == character_id:
			return def
	return null


static func display_name_of(character_id: String) -> String:
	var def: CharacterDef = find(character_id)
	if def != null and def.display_name != "":
		return def.display_name
	if character_id.is_empty():
		return "Caçador"
	return character_id.capitalize()


static func starter() -> CharacterDef:
	var def: CharacterDef = find(STARTER_ID)
	if def != null:
		return def
	var all: Array[CharacterDef] = load_all()
	return all[0] if not all.is_empty() else null
