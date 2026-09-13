# 12 — Coop 2P: LAN **ou** casa↔casa no celular

Fan game sideload. **Sem Firebase, sem Play Games, sem conta Google.**  
2 jogadores no **2 vs oni** (cap 1 amigo). A sala ENet abre no teto **3** para poder trocar de modo sem fechar. Host escolhe a fase no **mapa** (botão **Começar** na sala ou JOGAR). JOGAR solo **não** muda.

O sobrinho joga no **telefone**. PC é reserva de dev, não o caminho dele.

## Portas

| O quê | Porta | Proto |
|-------|-------|--------|
| Jogo (ENet) | **17777** | UDP |
| Beacon (achar o host no Wi-Fi) | **17778** | UDP broadcast |
| Sala da estrela (pedido) | **17779** | UDP JSON + TCP JSON |
| Sala da estrela (HTTP) | **8080** | HTTP POST `/sala`, GET `/ping` |
| Sala da estrela (relay ENet) | **17780** | UDP (porta do pedido + 1) |

`proto = 1`. Handshake também manda `version_code`.

## Ordem de join (não inverter)

1. **Beacon Wi-Fi** (~2,5 s). Se achar, conecta no IP do pacote. LAN da onda 2 **não some**.
2. Se não achar: pergunta à **sala da estrela** (host baked em `hashira/sala_host`). Os dois abrem uma **ponte UDP local** e só saem pro relay (`host:porta+1`). O VPS encaminha pelo endereço NAT real — não manda mais em `:17777` da casa.
3. Se a sala estiver desligada: o jogo **já abriu**; MULTIPLAYER / ENTRAR avisam em PT (“A sala da estrela está desligada”). Boot **nunca** “Conectando-se…”.
4. Reserva de dev: `LanSession.join_by_ip` no editor. **Não** aparece na gaveta.

Sem campo de IP na UI. MULTIPLAYER no hub cria a sala. ENTRAR na linha do amigo (se `friends_status` trouxe o código) ou código 6.

## Sala da estrela

Serviço no host do APK (`tools/sala_meio.py`, Docker `hashira-sala`):

```powershell
python tools/sala_meio.py --self-test
# reserva local:
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ligar_computador_da_sala.ps1
```

- Acha o código de 6 → IP/porta do host (o IP vem do datagrama, **não** do JSON do celular).
- 4G: UDP primeiro; senão HTTP 8080 / TCP 17779.
- Se o NAT da operadora bloquear o caminho direto, o **mesmo** host relaya o UDP do ENet **com os dois saindo** (bind/join no 17780). Pacote ENet até 4096.
- Convite de amigo pelo **nome do perfil** (presence na sala da estrela) + aceite. **+** na lista manda convite de sala (com code). Poll de `calls` antigo **não** leva code. O id interno de 8 continua só no save/servidor — não aparece na gaveta.
- `friends_status` (friend_id do pedinte) devolve amigos online `{name, friend_id, code}`. O cliente polla junto com o inbox. Sem essa op no VPS, a lista continua e o **ENTRAR** some.
- Nick + código da sala na presence. Sem e-mail, telefone, Google.
- Sala caiu: casa↔casa para; o Wi-Fi da sala continua.
- Nome até 24 caracteres (`MAX_PLAYER_NAME_LEN` / `NICK_MAX`). Sanitize só no confirmar — o espaço no meio não some ao digitar.

## Código de 6 e chamar

Charset `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sem 0/O/I/1). Zap ainda vale.

Toque no **+** (não o **x**): se a sala já existe e o amigo está no hub, ele entra. Sem sala criada: “Cria a sala primeiro”. Offline: “O amigo não está aí agora”. Sem sala no APK: “Mande o código da sala”. **ENTRAR** na linha chama `join_room` com o código da presence.

Na lobby (tela cheia depois do MULTIPLAYER / entrar), os caçadores ficam **grandes lado a lado**; cada celular escolhe o caçador na faixa de retratos. `LanSession.pick_character` atualiza o roster. 1v1 / mapa de batalha com sessão usam o roster — Inosuke/Nezuko default só no F6 sem sala.

Fim do 1v1 / mapa com sala: **De novo** (os dois aceitam) ou **Lobby** (volta à mesma sala, sem fechar nem convidar de novo). `keep_room_after_stage` / `vote_rematch` — não chama `close_session`. Nome do jogador fica em cima do corpo. Vitória soma troféu no save local.

## Save

`friends` = `{name, friend_id, added_unix}` + `friend_code` (8). **Sem IP**. O endereço da sala vive no ProjectSettings / autoload, não no `user://save.json`.

## Quem simula

Host no celular é a verdade (ondas, hitbox, clear, morte). Guest manda `InputFrame`. A sala da estrela **não** simula combate — só apresenta e, se preciso, carrega pacotes.

Desconexão: host cai → guest hub. Guest cai → host segue solo.

## Permissões Android

Já tinha `INTERNET` (OTA). Continua:

- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`

**Não** location / contacts / bluetooth.

## Duas instâncias no PC (QA)

1. Ligar `tools/ligar_computador_da_sala.ps1` (reserva).
2. Duas cópias Play. Host: **MULTIPLAYER**. Guest: **ENTRAR** no amigo ou código (beacon de loopback costuma falhar; a sala cobre se `hashira/sala_host` apontar para 127.0.0.1).
3. Host **Começar** no 2 vs oni → mapa → fase.

## Atualizar a sala no VPS

Esta sessão **não** publica o VPS. Quando o host tiver o compose em `/opt/hashira-sala`:

```sh
./tools/docker/hashira-sala/deploy-remote.sh
```

Ou, no servidor:

```sh
cd /opt/hashira-sala
docker compose -f tools/docker/hashira-sala/docker-compose.yml up -d --build
```

Sem o `friends_status` no host, o jogo degrada: lista de amigos intacta, sem botão ENTRAR.

## Autoload

`LanSession` (`scripts/autoload/lan_session.gd`) + `SalaMeioClient` (`scripts/net/sala_meio_client.gd`).  
Combate **não** mora no `Game`. `hub.gd` **não** lotar — lista e sala ficam no `FriendsPanel`.

`close_session` no fechar a janela, sair da sala, e ao voltar splash. **Não** apaga o host baked (ProjectSettings).

## JOGAR / mapa

Solo intocado. No **2 vs oni** / **4 vs oni**, **Começar** na lobby leva o host ao mapa. Guest no hub: “O anfitrião escolhe a fase”. Trocar o modo com amigo já dentro **não** fecha a sala.
