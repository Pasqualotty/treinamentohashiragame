class_name AndroidApkInstaller
extends RefCounted
## Instala APK sideload no Android via FileProvider + Intent (Godot 4.7).
## Desktop: todas as funções devolvem erro/false e nunca tocam JNI.

const MIME_APK := "application/vnd.android.package-archive"
const FLAG_GRANT_READ := 1
const FLAG_ACTIVITY_NEW_TASK := 268435456
const ACTION_VIEW := "android.intent.action.VIEW"
const ACTION_UNKNOWN_SOURCES := "android.settings.MANAGE_UNKNOWN_APP_SOURCES"
const FILEPROVIDER_SUFFIX := ".fileprovider"
const GODOT_FILEPROVIDER := "org.godotengine.godot.io.file.FileProvider"
const ANDROIDX_FILEPROVIDER := "androidx.core.content.FileProvider"


static func is_android() -> bool:
	return OS.get_name() == "Android"


static func can_request_installs() -> bool:
	if not is_android():
		return false
	if not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return false
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return false
	var pm: Variant = activity.getPackageManager()
	if pm == null:
		return false
	return bool(pm.canRequestPackageInstalls())


static func open_unknown_sources_settings() -> String:
	if not is_android():
		return "desktop"
	if not Engine.has_singleton("AndroidRuntime"):
		return "sem AndroidRuntime"
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return "sem activity"
	var Intent := JavaClassWrapper.wrap("android.content.Intent")
	var Uri := JavaClassWrapper.wrap("android.net.Uri")
	if Intent == null or Uri == null:
		return "jni"
	var pkg: String = str(activity.getPackageName())
	var intent: Variant = Intent.Intent(ACTION_UNKNOWN_SOURCES)
	intent.setData(Uri.parse("package:" + pkg))
	intent.addFlags(FLAG_ACTIVITY_NEW_TASK)
	_start_on_ui_thread(runtime, activity, intent)
	var ex: Variant = _jni_exception()
	if ex != null:
		return str(ex)
	return ""


## Dispara o instalador do sistema. "" = ok; senão mensagem curta.
static func start_install(abs_path: String) -> String:
	if not is_android():
		return "desktop"
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return "arquivo"
	if not Engine.has_singleton("AndroidRuntime"):
		return "sem AndroidRuntime"
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return "sem activity"
	var File := JavaClassWrapper.wrap("java.io.File")
	var Intent := JavaClassWrapper.wrap("android.content.Intent")
	if File == null or Intent == null:
		return "jni"
	var file: Variant = File.File(abs_path)
	if file == null or not bool(file.exists()):
		return "arquivo"
	var authority: String = str(activity.getPackageName()) + FILEPROVIDER_SUFFIX
	var uri: Variant = _uri_for_file(activity, authority, file)
	if uri == null:
		return "fileprovider"
	var intent: Variant = Intent.Intent()
	intent.setAction(ACTION_VIEW)
	intent.setDataAndType(uri, MIME_APK)
	intent.addFlags(FLAG_GRANT_READ)
	intent.addFlags(FLAG_ACTIVITY_NEW_TASK)
	_start_on_ui_thread(runtime, activity, intent)
	var ex: Variant = _jni_exception()
	if ex != null:
		return str(ex)
	return ""


static func read_package_version_code() -> int:
	if not is_android():
		return 0
	if not Engine.has_singleton("AndroidRuntime"):
		return 0
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return 0
	var pm: Variant = activity.getPackageManager()
	if pm == null:
		return 0
	var pkg: String = str(activity.getPackageName())
	var info: Variant = pm.getPackageInfo(pkg, 0)
	if info == null:
		return 0
	return int(info.versionCode)


static func _uri_for_file(activity: Variant, authority: String, file: Variant) -> Variant:
	for class_name_java in [GODOT_FILEPROVIDER, ANDROIDX_FILEPROVIDER]:
		var Provider := JavaClassWrapper.wrap(class_name_java)
		if Provider == null:
			continue
		var uri: Variant = Provider.getUriForFile(activity, authority, file)
		var ex: Variant = _jni_exception()
		if ex != null:
			push_warning("AutoUpdater FileProvider %s: %s" % [class_name_java, str(ex)])
			continue
		if uri != null:
			return uri
	return null


static func _start_on_ui_thread(runtime: Object, activity: Variant, intent: Variant) -> void:
	if runtime.has_method("createRunnableFromGodotCallable"):
		var starter := func() -> void:
			activity.startActivity(intent)
		activity.runOnUiThread(runtime.createRunnableFromGodotCallable(starter))
		return
	activity.startActivity(intent)


static func _jni_exception() -> Variant:
	if not ClassDB.class_exists("JavaClassWrapper"):
		return null
	if not JavaClassWrapper.has_method("get_exception"):
		return null
	return JavaClassWrapper.get_exception()
