class_name AtomicJson
extends RefCounted
## Persistência JSON à prova de kill: escreve `.tmp`, dá flush, troca o destino
## via rename. O arquivo final só existe completo — um crash no meio deixa o
## JSON antigo (ou o `.bak`) intacto, nunca um `save.json` cortado no meio.

const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".bak"


static func tmp_path(path: String) -> String:
	return path + TMP_SUFFIX


static func bak_path(path: String) -> String:
	return path + BAK_SUFFIX


## Grava `data` em `path` de forma atômica. false = não abriu o tmp ou o rename falhou.
static func write_dict(path: String, data: Dictionary) -> bool:
	if path.is_empty():
		return false
	var tmp := tmp_path(path)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return commit_tmp(tmp, path)


## Troca tmp → destino. Se o destino já existe, primeiro vira `.bak` (janela de
## kill no Windows: `load` tenta destino, depois bak, depois tmp válido).
static func commit_tmp(tmp: String, dest: String) -> bool:
	var tmp_abs := ProjectSettings.globalize_path(tmp)
	var dest_abs := ProjectSettings.globalize_path(dest)
	var bak_abs := dest_abs + BAK_SUFFIX
	if FileAccess.file_exists(dest):
		if FileAccess.file_exists(bak_abs):
			DirAccess.remove_absolute(bak_abs)
		var parked: Error = DirAccess.rename_absolute(dest_abs, bak_abs)
		if parked != OK:
			DirAccess.remove_absolute(bak_abs)
			var parked2: Error = DirAccess.rename_absolute(dest_abs, bak_abs)
			if parked2 != OK:
				return false
	var err: Error = DirAccess.rename_absolute(tmp_abs, dest_abs)
	if err != OK:
		_restore_bak(bak_abs, dest_abs)
		return false
	if FileAccess.file_exists(bak_abs):
		DirAccess.remove_absolute(bak_abs)
	return true


static func _restore_bak(bak_abs: String, dest_abs: String) -> void:
	if FileAccess.file_exists(bak_abs) and not FileAccess.file_exists(dest_abs):
		DirAccess.rename_absolute(bak_abs, dest_abs)


## Primeiro JSON válido entre destino, `.bak` e `.tmp`. null = nada aproveitável.
static func read_dict(path: String) -> Variant:
	if path.is_empty():
		return null
	var parsed: Variant = parse_file(path)
	if parsed != null:
		return parsed
	parsed = parse_file(bak_path(path))
	if parsed != null:
		return parsed
	return parse_file(tmp_path(path))


static func parse_file(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


static func remove_sidecars(path: String) -> void:
	var tmp := tmp_path(path)
	var bak := bak_path(path)
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
