<#
.SYNOPSIS
  Exporta APK debug do Treinamento Hashira (preset "Android Debug").

.DESCRIPTION
  Usa Godot 4.7 CLI headless. Requer:
  - export_presets.cfg no projeto
  - Export templates 4.7.1 em %APPDATA%\Godot\export_templates\4.7.1.stable\
  - Editor Settings Android (Java + SDK + debug keystore) j├í configurados

  Paths de refer├¬ncia: docs/android-paths.txt

.PARAMETER GodotExe
  Caminho do Godot_v4.7.1-stable_win64.exe. Se omitido, tenta achar via WinGet / PATH.

.PARAMETER ProjectDir
  Pasta com project.godot (default: raiz do repo = pai de scripts/).

.PARAMETER OutputApk
  Caminho relativo ou absoluto do APK (default: export/TreinamentoHashira-debug.apk).
#>
[CmdletBinding()]
param(
    [string]$GodotExe = "",
    [string]$ProjectDir = "",
    [string]$OutputApk = "export/TreinamentoHashira-debug.apk",
    [string]$PresetName = "Android Debug"
)

$ErrorActionPreference = "Stop"

function Resolve-GodotExe {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path -LiteralPath $Explicit)) { return (Resolve-Path $Explicit).Path }

    $winget = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe"
    if (Test-Path -LiteralPath $winget) { return $winget }

    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $found = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages") -Filter "Godot_v4*.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($found) { return $found }

    return $null
}

if (-not $ProjectDir) {
    $ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectDir = (Resolve-Path $ProjectDir).Path
}

$projectFile = Join-Path $ProjectDir "project.godot"
$presetsFile = Join-Path $ProjectDir "export_presets.cfg"
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "project.godot n├úo encontrado em: $ProjectDir"
}
if (-not (Test-Path -LiteralPath $presetsFile)) {
    throw "export_presets.cfg ausente. Crie o preset Android no Editor ou restaure do git."
}

$godot = Resolve-GodotExe -Explicit $GodotExe
if (-not $godot) {
    Write-Host @"
Godot CLI n├úo encontrado.

Instale Godot 4.7.x (Standard) ou passe -GodotExe.

Caminho t├¡pico (winget):
  $env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe

Comando manual:
  & <Godot.exe> --headless --path `"$ProjectDir`" --export-debug `"$PresetName`" `"$OutputApk`"
"@
    exit 2
}

$tplDir = Join-Path $env:APPDATA "Godot\export_templates\4.7.1.stable"
$tplApk = Join-Path $tplDir "android_debug.apk"
if (-not (Test-Path -LiteralPath $tplApk)) {
    Write-Host @"
Export templates 4.7.1 n├úo encontrados em:
  $tplDir

No Editor: Editor ÔåÆ Manage Export Templates ÔåÆ Download and Install (4.7.1).
Ou baixe o .tpz e extraia para a pasta acima:
  https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz

Sem templates o export headless falha.
"@
    exit 3
}

$outDir = Split-Path -Parent (Join-Path $ProjectDir $OutputApk)
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

Write-Host "Godot:  $godot"
Write-Host "Project: $ProjectDir"
Write-Host "Preset:  $PresetName"
Write-Host "Output:  $OutputApk"
Write-Host "Export templates: OK ($tplDir)"

Push-Location $ProjectDir
try {
    & $godot --headless --path $ProjectDir --export-debug $PresetName $OutputApk
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

$absOut = if ([System.IO.Path]::IsPathRooted($OutputApk)) { $OutputApk } else { Join-Path $ProjectDir $OutputApk }
if ((Test-Path -LiteralPath $absOut) -and ((Get-Item -LiteralPath $absOut).Length -gt 0)) {
    Write-Host "OK APK: $absOut ($([math]::Round((Get-Item $absOut).Length / 1MB, 2)) MB)"
    exit 0
}

Write-Host "Export terminou sem APK v├ílido (exit=$code). Veja o log do Godot acima."
if ($null -eq $code) { exit 1 }
exit $code
