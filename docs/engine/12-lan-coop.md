# 12 — Coop 2P: LAN **ou** casa↔casa

Fan game sideload. **Sem Firebase, sem Play Games, sem Hostinger, sem conta Google.**  
2 jogadores. `max_clients = 1`. Host escolhe a fase no **mapa**. JOGAR solo **não** muda.

## Portas

| O quê | Porta | Proto |
|-------|-------|--------|
| Jogo (ENet) | **17777** | UDP |
| Beacon (achar o host no Wi-Fi) | **17778** | UDP broadcast |
| Computador da sala (pedido) | **17779** | UDP JSON |
| Computador da sala (relay ENet) | **17780** | UDP (porta do pedido + 1) |

`proto = 1`. Handshake também manda `version_code`.

## Ordem de join (não inverter)

1. **Beacon Wi-Fi** (~2,5 s). Se achar, conecta no IP do pacote. LAN da onda 2 **não some**.
2. Se não achar e o campo **Computador da sala** estiver preenchido: pergunta ao PC (código de 6 → caminho). O guest entra no **relay** do PC (`host:porta+1`); o PC carrega o ENet até o celular anfitrião.
3. Se o PC estiver desligado: o jogo **já abriu**; Criar/Entrar avisa em PT (“O computador da sala está desligado”). Boot **nunca** “Conectando-se…”.
4. Fallback QA: “IP do anfitrião” (`127.0.0.1` no PC).

Campo vazio = **só LAN**. Playtest: colar `IP_DO_PC:17779` (ou hostname).

## Computador da sala (saída 3a)

Serviço fino no **PC do Matheus**, ligado na hora do playtest:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ligar_computador_da_sala.ps1
```

- Acha o código de 6 → IP/porta do host (o IP vem do datagrama, **não** do JSON do celular).
- Se o NAT da operadora bloquear o caminho direto, o **mesmo** PC relaya o UDP do ENet.
- Nick + “está numa sala / não está”. Sem e-mail, telefone, Google.
- Desligou o PC: casa↔casa para; o Wi-Fi da sala continua.

Não é nuvem de produto. Não abre porta no roteador da família como caminho principal (só desespero, fora desta frente).

## Código de 6 e chamar

Charset `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sem 0/O/I/1). Zap ainda vale.

Toque no **nome** da lista (não o **x**): se o PC vir o nick online, manda o chamado. Offline: “O amigo não está aí agora”. Sem o PC: “Cole o computador da sala para chamar. Ou mande o código.”

## Save

`friends` = `{name, added_unix}` só. **Sem IP** (nem o do computador da sala). O endereço do PC vive no autoload da sessão, não no `user://save.json`.

## Quem simula

Host no celular é a verdade (ondas, hitbox, clear, morte). Guest manda `InputFrame`. O PC do meio **não** simula combate — só apresenta e, se preciso, carrega pacotes.

Desconexão: host cai → guest hub. Guest cai → host segue solo.

## Permissões Android

Já tinha `INTERNET` (OTA). Continua:

- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`

**Não** location / contacts / bluetooth.

## Duas instâncias no PC (QA)

1. Ligar `tools/ligar_computador_da_sala.ps1`.
2. Duas cópias Play. Host: Criar sala. Guest: campo `127.0.0.1:17779` + código (beacon de loopback costuma falhar; o PC cobre).
3. Host JOGAR → mapa → fase.

## Autoload

`LanSession` (`scripts/autoload/lan_session.gd`) + `SalaMeioClient` (`scripts/net/sala_meio_client.gd`).  
Combate **não** mora no `Game`. `hub.gd` **não** lotar — o campo e o toque no nome ficam no `FriendsPanel`.

`close_session` no fechar a janela, sair da sala, e ao voltar splash. **Não** apaga o texto do computador da sala (autoload).

## JOGAR / mapa

Solo intocado. Com 2 na sala: só o host navega o mapa. Guest no hub: “O anfitrião escolhe a fase”.
