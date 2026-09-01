<#
.SYNOPSIS
  Prepara um update OTA do Treinamento Hashira (version bump + latest.json).

.DESCRIPTION
  Nao commita, nao faz push, nao sobe token. So edita versoes no repo e
  monta updates/latest.json pra ir no GitHub Release.

  Fluxo tipico:
    1. .\scripts\publish-update.ps1 -VersionName 0.0.2 -Changelog "Pulo mais facil"
    2. Exportar APK (Editor ou .\scripts\export-android-debug.ps1)
    3. .\scripts\publish-update.ps1 -FillFromApk
    4. Criar o release (comando impresso, ou -CreateGithubRelease)

.PARAMETER VersionName
  Nome visivel (0.0.2). Obrigatorio no bump; no -FillFromApk sozinho reusa o atual.

.PARAMETER VersionCode
  Inteiro do Android. 0 = incrementa o que esta em updates/app_version.json.

.PARAMETER Changelog
  Texto curto em portugues pro aviso do sobrinho.

.PARAMETER ApkPath
  APK ja exportado (default: export/TreinamentoHashira-debug.apk).

.PARAMETER FillFromApk
  Recalcula size_bytes e sha256 no latest.json a partir do APK.

.PARAMETER CreateGithubRelease
  Roda `gh release create` com latest.json + APK. Exige gh autenticado.
  Nao commita codigo.
#>
[CmdletBinding()]
param(
    [string]$VersionName = "",
    [int]$VersionCode = 0,
    [string]$Changelog = "Melhorias no treino.",
    [string]$ApkPath = "export/TreinamentoHashira-debug.apk",
    [string]$Repo = "Pasqualotty/treinamentohashiragame",
    [switch]$FillFromApk,
    [switch]$CreateGithubRelease
)

$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$AppVersionPath = Join-Path $ProjectDir "updates\app_version.json"
$LatestPath = Join-Path $ProjectDir "updates\latest.json"
$ProjectGodot = Join-Path $ProjectDir "project.godot"
$Presets = Join-Path $ProjectDir "export_presets.cfg"

function Read-AppVersion {
    if (-not (Test-Path -LiteralPath $AppVersionPath)) {
        throw "Falta updates/app_version.json"
    }
    return (Get-Content -LiteralPath $AppVersionPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Write-AppVersion([int]$Code, [string]$Name, [string]$ManifestUrl) {
    $json = @"
{
	"version_code": $Code,
	"version_name": "$Name",
	"manifest_url": "$ManifestUrl"
}
"@
    Write-Utf8NoBom $AppVersionPath $json
}

function Write-Latest {
    param(
        [int]$Code,
        [string]$Name,
        [string]$ApkUrl,
        [string]$Notes,
        [int64]$SizeBytes,
        [string]$Sha
    )
    $notesEsc = $Notes.Replace("\", "\\").Replace('"', '\"')
    $json = @"
{
	"version_code": $Code,
	"version_name": "$Name",
	"apk_url": "$ApkUrl",
	"changelog": "$notesEsc",
	"size_bytes": $SizeBytes,
	"sha256": "$Sha"
}
"@
    Write-Utf8NoBom $LatestPath $json
}

function Set-ProjectVersion([string]$Name) {
    $text = Get-Content -LiteralPath $ProjectGodot -Raw -Encoding UTF8
    $updated = [regex]::Replace($text, 'config/version="[^"]*"', "config/version=`"$Name`"")
    if ($updated -eq $text -and $text -notmatch 'config/version=') {
        throw "project.godot sem config/version"
    }
    Write-Utf8NoBom $ProjectGodot $updated
}

function Set-PresetVersion([int]$Code, [string]$Name) {
    $text = Get-Content -LiteralPath $Presets -Raw -Encoding UTF8
    $text = [regex]::Replace($text, 'version/code=\d+', "version/code=$Code")
    $text = [regex]::Replace($text, 'version/name="[^"]*"', "version/name=`"$Name`"")
    Write-Utf8NoBom $Presets $text
}

$current = Read-AppVersion
$manifestUrl = [string]$current.manifest_url
if (-not $manifestUrl) {
    $manifestUrl = "https://github.com/$Repo/releases/latest/download/latest.json"
}

$code = [int]$current.version_code
$name = [string]$current.version_name

if ($VersionName) {
    $name = $VersionName
    if ($VersionCode -gt 0) {
        $code = $VersionCode
    } else {
        $code = $code + 1
    }
    Set-ProjectVersion $name
    Set-PresetVersion $code $name
    Write-AppVersion $code $name $manifestUrl
    Write-Host "Versao bump: $name (version_code=$code)"
} elseif (-not $FillFromApk) {
    Write-Host "Passe -VersionName 0.0.2 (bump) e/ou -FillFromApk (hash do APK)."
    Write-Host "Atual no repo: $name / code $code"
    exit 2
}

$apkUrl = "https://github.com/$Repo/releases/download/v$name/TreinamentoHashira.apk"
$size = [int64]0
$sha = ""

$apkAbs = $ApkPath
if (-not [System.IO.Path]::IsPathRooted($apkAbs)) {
    $apkAbs = Join-Path $ProjectDir $ApkPath
}

if ($FillFromApk) {
    if (-not (Test-Path -LiteralPath $apkAbs)) {
        throw "APK nao encontrado: $apkAbs - exporte antes e rode -FillFromApk de novo."
    }
    $item = Get-Item -LiteralPath $apkAbs
    $size = [int64]$item.Length
    $sha = (Get-FileHash -LiteralPath $apkAbs -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host ("APK: {0} ({1:N1} MB)" -f $apkAbs, ($size / 1MB))
    Write-Host "SHA256: $sha"
}

if ($VersionName -or $FillFromApk) {
    $notes = $Changelog
    if (-not $VersionName -and (Test-Path -LiteralPath $LatestPath)) {
        $prev = Get-Content -LiteralPath $LatestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $Changelog -or $Changelog -eq "Melhorias no treino.") {
            $notes = [string]$prev.changelog
        }
        if (-not $VersionName) {
            $name = [string]$prev.version_name
            $code = [int]$prev.version_code
            $apkUrl = [string]$prev.apk_url
        }
    }
    Write-Latest -Code $code -Name $name -ApkUrl $apkUrl -Notes $notes -SizeBytes $size -Sha $sha
    Write-Host "Escrito: updates/latest.json"
}

Write-Host ""
Write-Host "Proximo passo - GitHub Release (APK publico, sem token no jogo):"
Write-Host "  gh release create `"v$name`" `"$apkAbs`" `"$LatestPath`" --repo $Repo --title `"Treino $name`" --notes `"$Changelog`""
Write-Host ""
Write-Host "O sobrinho so precisa abrir o jogo. Manifesto:"
Write-Host "  $manifestUrl"

if ($CreateGithubRelease) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "gh nao encontrado. Instale GitHub CLI ou rode o comando acima na mao."
    }
    if (-not (Test-Path -LiteralPath $apkAbs)) {
        throw "Sem APK em $apkAbs - exporte antes de -CreateGithubRelease."
    }
    if ($size -le 0 -or -not $sha) {
        throw "Rode -FillFromApk antes de criar o release (latest.json sem hash)."
    }
    & gh release create "v$name" $apkAbs $LatestPath --repo $Repo --title "Treino $name" --notes $Changelog
    if ($LASTEXITCODE -ne 0) {
        throw "gh release create falhou (exit $LASTEXITCODE)"
    }
    Write-Host "Release v$name publicado."
}
