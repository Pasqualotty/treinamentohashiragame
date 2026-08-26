class_name UpdateManifest
extends RefCounted
## Manifest remoto de OTA (JSON) + versão local em res://updates/app_version.json.
## Parse e comparação são puros — o smoke testa isto sem HTTP e sem Android.

const LOCAL_VERSION_PATH := "res://updates/app_version.json"
const MAX_CHANGELOG_LEN := 160
const MAX_APK_BYTES := 400 * 1024 * 1024

var version_code: int = 0
var version_name: String = ""
var apk_url: String = ""
var changelog: String = ""
var size_bytes: int = 0
var sha256: String = ""
var parse_error: String = ""


func is_valid() -> bool:
	return parse_error.is_empty() and version_code > 0 and not apk_url.is_empty()


func is_newer_than(local_code: int) -> bool:
	return is_valid() and version_code > local_code


static func parse(text: String) -> UpdateManifest:
	var m := UpdateManifest.new()
	if text.is_empty():
		m.parse_error = "vazio"
		return m
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		m.parse_error = "json"
		return m
	return from_dict(parsed)


static func from_dict(data: Dictionary) -> UpdateManifest:
	var m := UpdateManifest.new()
	m.version_code = int(data.get("version_code", 0))
	m.version_name = str(data.get("version_name", "")).strip_edges()
	m.apk_url = str(data.get("apk_url", "")).strip_edges()
	m.changelog = str(data.get("changelog", "")).strip_edges()
	m.size_bytes = int(data.get("size_bytes", 0))
	m.sha256 = str(data.get("sha256", "")).strip_edges().to_lower()
	if m.changelog.length() > MAX_CHANGELOG_LEN:
		m.changelog = m.changelog.substr(0, MAX_CHANGELOG_LEN).strip_edges()
	if m.version_code <= 0:
		m.parse_error = "version_code"
		return m
	if m.version_name.is_empty():
		m.parse_error = "version_name"
		return m
	if not m.apk_url.begins_with("https://"):
		m.parse_error = "apk_url"
		return m
	if m.size_bytes < 0 or m.size_bytes > MAX_APK_BYTES:
		m.parse_error = "size_bytes"
		return m
	if not m.sha256.is_empty() and m.sha256.length() != 64:
		m.parse_error = "sha256"
		return m
	return m


static func load_local() -> Dictionary:
	var out := {
		"version_code": 1,
		"version_name": "0.0.1",
		"manifest_url": "",
	}
	if not FileAccess.file_exists(LOCAL_VERSION_PATH):
		return out
	var f := FileAccess.open(LOCAL_VERSION_PATH, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var data: Dictionary = parsed
	out["version_code"] = int(data.get("version_code", 1))
	var name_s := str(data.get("version_name", "")).strip_edges()
	if name_s.is_empty():
		name_s = str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	out["version_name"] = name_s
	out["manifest_url"] = str(data.get("manifest_url", "")).strip_edges()
	return out


static func format_size(bytes: int) -> String:
	if bytes <= 0:
		return ""
	if bytes < 1024 * 1024:
		return "menos de 1 MB"
	return "uns %d MB" % int(round(float(bytes) / 1048576.0))


static func looks_like_apk(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var magic: PackedByteArray = f.get_buffer(2)
	return magic.size() == 2 and magic[0] == 0x50 and magic[1] == 0x4B


static func sha256_matches(path: String, expected_hex: String) -> bool:
	if expected_hex.is_empty():
		return true
	if not FileAccess.file_exists(path):
		return false
	return FileAccess.get_sha256(path).to_lower() == expected_hex.to_lower()
