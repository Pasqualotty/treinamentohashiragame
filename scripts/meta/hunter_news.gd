class_name HunterNews
extends RefCounted
## Notícias estáticas no APK. Não é feed da internet.


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()


static func articles() -> Array[Dictionary]:
	var ver: String = game_version()
	if ver.is_empty():
		ver = "sem número"
	var out: Array[Dictionary] = []
	out.append({
		"id": "fan",
		"title": "Fan game de uso pessoal",
		"body": "Treinamento Hashira é um fan game da Pasqualotti Studio. Serve para a família jogar no celular. Não é produto oficial e não usa a marca para vender.",
	})
	out.append({
		"id": "how",
		"title": "Como jogar",
		"body": "No hub, toque em JOGAR e escolha a fase no mapa. Na luta, o stick fica à esquerda e os golpes à direita. Moedas da fase entram na loja só quando você limpa a fase.",
	})
	out.append({
		"id": "ver",
		"title": "Versão neste aparelho",
		"body": "Você está na versão %s. Clube, notícias, eventos e missões ficam só neste celular. Sem ranking online e sem campo de IP." % ver,
	})
	return out


static func find_article(article_id: String) -> Dictionary:
	for a: Dictionary in articles():
		if str(a.get("id", "")) == article_id:
			return a
	return {}
