<#
.SYNOPSIS
  Liga o computador da sala (saída 3a) no PC do Matheus.

.DESCRIPTION
  Sobe tools/sala_meio.py: achar código de 6 e, se o NAT bloquear, carregar o ENet.
  Sem Firebase, sem Play Games, sem Hostinger.
  Desligou esta janela: o jogo ainda abre; Criar/Entrar avisa em português.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/ligar_computador_da_sala.ps1
#>
[CmdletBinding()]
param(
    [string]$Bind = "0.0.0.0",
    [int]$Port = 17779
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

Write-Host "=== Computador da sala ==="
Write-Host "Cole no celular (Amigos): IP_DESTE_PC:${Port}"
Write-Host "Beacon Wi-Fi da onda 2 continua. Este PC so entra se o Wi-Fi nao achar."
Write-Host ""

$pyArgs = @()
if ((Split-Path -Leaf $py) -eq "py.exe") {
    $pyArgs += "-3"
}
$pyArgs += @($script, "--bind", $Bind, "--port", "$Port")
& $py @pyArgs
exit $LASTEXITCODE
