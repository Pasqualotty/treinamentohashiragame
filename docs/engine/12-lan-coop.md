# 12 — LAN coop (2 jogadores, mesmo Wi-Fi)

Fan game sideload. **Sem nuvem, Firebase, Play Games, relay ou NAT pela internet.**

## Portas

| O quê | Porta | Proto |
|-------|-------|--------|
| Jogo (ENet) | **17777** | UDP |
| Beacon (achar o host) | **17778** | UDP broadcast |

`max_clients = 1` (host + 1 guest). `proto = 1`.

## Como o amigo acha o host

1. Host: `ENet.create_server(17777, max=1)` e gera código de **6** no charset `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sem 0/O/I/1).
2. Enquanto a sala está aberta: beacon ~2 Hz, JSON ASCII < 512 B:

```
magic=HASHIRA, proto=1, code, port=17777, name (≤14, sanitizado), version_code
```

3. Guest escuta 17778, filtra pelo código, conecta ENet no IP **do pacote** (o código **não** é o IPv4).
4. Handshake: `proto` + `version_code` (`AutoUpdater.get_local_version_code()`). APK diferente → texto em PT, volta ao hub.

**Fallback IP:** se ~2,5 s sem beacon, o painel mostra “IP do anfitrião”. `127.0.0.1` é o caminho de **QA no PC** (broadcast de loopback costuma falhar).

**Não persistir IP** no `user://save.json` (fica velho no DHCP + PII). Lista `friends` = `{name, added_unix}` só.

## Quem simula

Host é a verdade: ondas, hitbox, clear, morte. Guest manda `InputFrame` (~20 Hz: axis + bitmask). Host devolve `PlayerSnap` ×2. Onis: só o host roda AI; spawn via RPC; guest instancia sem AI.

Desconexão: host cai → guest hub. Guest cai → host segue solo (o corpo do amigo some; onis não caçam fantasma).

## Permissões Android

Já tinha `INTERNET` (OTA). Esta frente liga:

- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`

**Não** location / contacts / bluetooth.

Se o Wi-Fi tiver “isolamento de estação”, o beacon não chega. Texto na UI: mesmo Wi-Fi, sem convidado isolado.

## Duas instâncias no PC

1. Abra duas cópias do editor **ou** duas janelas Play (projetos / `--path` distintos se precisar).
2. Host: Criar sala.
3. Guest: Entrar + IP `127.0.0.1` (o beacon em loopback quase nunca funciona).
4. Host JOGAR → mapa → fase. Os dois devem aparecer em `w1_01`.

## Autoload

`LanSession` (`scripts/autoload/lan_session.gd`). Solo: `multiplayer_peer` nulo depois de `close_session()`. `close_session` no fechar a janela, sair da sala, e ao voltar splash.

Combate **não** mora no `Game`. Save `SAVE_VERSION` continua **1**; chave `friends` é aditiva.

## JOGAR / mapa

Solo intocado. Com 2 na sala: só o host navega o mapa. Guest no hub: “O anfitrião escolhe a fase”. `rpc_load_stage` **depois** o host também entra na cena.
