<#
.SYNOPSIS
  Reserva de DEV: sobe a sala da estrela neste PC.

.DESCRIPTION
  O APK do sobrinho já aponta para a sala da estrela. Este script é só
  para editor / duas instâncias no mesmo computador.
  Sem Firebase, sem Play Games.
  Desligou esta janela: o jogo ainda abre; Criar/Entrar avisa em português.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/ligar_computador_da_sala.ps1
#>
[CmdletBinding()]
param(
    [string]$Bind = "0.0.0.0",
    [int]$Port = 17779,
    [int]$HttpPort = 8080
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script = Join-Path $root "tools\sala_meio.py"
if (-not (Test-Path -LiteralPath $script)) {
    Write-Error "sala_meio.py nao encontrado em $script"
    exit 2
}

$py = $null
foreach ($cand in @("python", "py")) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) {
        $py = $cmd.Source
        break
    }
}
if (-not $py) {
    Write-Host "Python nao encontrado. Instale Python 3 ou rode: py -3 tools/sala_meio.py"
    exit 2
}

Write-Host "=== Sala da estrela (reserva de DEV) ==="
Write-Host "O celular do sobrinho NAO usa este PC. Host baked: hashira/sala_host"
Write-Host "UDP/TCP ${Port}  HTTP ${HttpPort}  relay $($Port + 1)"
Write-Host ""

$pyArgs = @()
if ((Split-Path -Leaf $py) -eq "py.exe") {
    $pyArgs += "-3"
}
$pyArgs += @($script, "--bind", $Bind, "--port", "$Port", "--http-port", "$HttpPort")
& $py @pyArgs
exit $LASTEXITCODE
