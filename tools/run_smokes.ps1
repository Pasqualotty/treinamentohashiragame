<#
.SYNOPSIS
  Roda a suite headless de smokes do Treinamento Hashira e falha (exit != 0) se algum quebrar.

.DESCRIPTION
  Resolve Godot 4.7 CLI (console preferido), executa scripts de QA com --headless.
  Exit code = 0 so se TODOS os smokes passarem.

.PARAMETER GodotExe
  Caminho explicito do Godot. Se vazio, tenta winget console, winget gui, PATH.

.PARAMETER ProjectDir
  Pasta com project.godot (default: pai de tools/).

.PARAMETER TimeoutSec
  Timeout por smoke em segundos (default 120).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_smokes.ps1
#>
[CmdletBinding()]
param(
    [string]$GodotExe = "",
    [string]$ProjectDir = "",
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = "Stop"

function Resolve-GodotExe {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path -LiteralPath $Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    if ($env:GODOT_EXE -and (Test-Path -LiteralPath $env:GODOT_EXE)) {
        return (Resolve-Path -LiteralPath $env:GODOT_EXE).Path
    }

    $pkg = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    $console = Join-Path $pkg "Godot_v4.7.1-stable_win64_console.exe"
    if (Test-Path -LiteralPath $console) { return $console }
    $gui = Join-Path $pkg "Godot_v4.7.1-stable_win64.exe"
    if (Test-Path -LiteralPath $gui) { return $gui }

    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $found = Get-ChildItem -Path $wingetRoot -Filter "Godot_v4*console*.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($found) { return $found }

    $found2 = Get-ChildItem -Path $wingetRoot -Filter "Godot_v4*.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($found2) { return $found2 }

    return $null
}

function Convert-ResPathToFs {
    param([string]$ResPath, [string]$Root)
    $rel = $ResPath
    if ($rel.StartsWith("res://")) {
        $rel = $rel.Substring(6)
    }
    $rel = $rel.Replace("/", [string][IO.Path]::DirectorySeparatorChar)
    return (Join-Path $Root $rel)
}

if (-not $ProjectDir) {
    $ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
}

$projectFile = Join-Path $ProjectDir "project.godot"
if (-not (Test-Path -LiteralPath $projectFile)) {
    Write-Error "project.godot nao encontrado em: $ProjectDir"
    exit 2
}

$godot = Resolve-GodotExe -Explicit $GodotExe
if (-not $godot) {
    Write-Host "Godot CLI nao encontrado."
    Write-Host "Instale Godot 4.7.x ou passe -GodotExe / env GODOT_EXE."
    exit 2
}

# Worktree fresco: sem .godot os class_name e .import quebram smokes.
$godotCache = Join-Path $ProjectDir ".godot"
$importedDir = Join-Path $godotCache "imported"
if (-not (Test-Path -LiteralPath $importedDir)) {
    Write-Host "Cache .godot/imported ausente - rodando import headless..."
    $importArgs = "--headless --path `"$ProjectDir`" --import"
    $importProc = Start-Process -FilePath $godot -ArgumentList $importArgs `
        -WorkingDirectory $ProjectDir -PassThru -NoNewWindow -Wait
    if (-not (Test-Path -LiteralPath $importedDir)) {
        Write-Host "AVISO: import nao gerou .godot/imported (exit $($importProc.ExitCode)). Smokes podem falhar."
        Write-Host "Abra o projeto uma vez no Editor ou copie .godot de um checkout que ja importou."
    } else {
        Write-Host "Import OK."
    }
    Write-Host ""
}

# Suite canonica do gate playtest.
# PassMarker: Godot headless muitas vezes sai com code!=0 por ObjectDB leak / ERROR de engine
# mesmo apos quit(0) do script. O veredito do smoke vem do marcador no stdout.
$smokeList = @(
    [pscustomobject]@{
        Name = "smoke_load_stages"
        Script = "res://scripts/qa/smoke_load_stages.gd"
        PassMarker = "[smoke] ALL PASSED"
        FailMarker = "[smoke] FAILED"
    },
    [pscustomobject]@{
        Name = "smoke_playable_w1"
        Script = "res://scripts/qa/smoke_playable_w1.gd"
        PassMarker = "=== SMOKE PASS ==="
        FailMarker = "=== SMOKE FAIL ==="
    },
    [pscustomobject]@{
        Name = "smoke_combat_e2e"
        Script = "res://scripts/qa/smoke_combat_e2e.gd"
        PassMarker = "=== E2E PASS ==="
        FailMarker = "=== E2E FAIL ==="
    },
    [pscustomobject]@{
        Name = "smoke_facing_ground"
        Script = "res://scripts/qa/smoke_facing_ground.gd"
        PassMarker = "=== FACING/GROUND PASS ==="
        FailMarker = "=== FACING/GROUND FAIL ==="
    },
    [pscustomobject]@{
        Name = "smoke_meta_loja_mapa"
        Script = "res://scripts/ui/smoke_meta_loja_mapa.gd"
        PassMarker = "RESULT: PASS"
        FailMarker = "RESULT: FAIL"
    },
    [pscustomobject]@{
        Name = "smoke_player_test"
        Script = "res://scripts/combat/smoke_player_test.gd"
        PassMarker = "SMOKE_PLAYER_TEST PASS"
        FailMarker = "SMOKE_PLAYER_TEST FAIL"
    }
)

Write-Host "=== Treinamento Hashira - run_smokes ==="
Write-Host "Godot:  $godot"
Write-Host "Project: $ProjectDir"
Write-Host "Timeout/smoke: ${TimeoutSec}s"
Write-Host ""

$failed = 0
$results = New-Object System.Collections.Generic.List[object]

foreach ($s in $smokeList) {
    $name = $s.Name
    $script = $s.Script
    $passMarker = [string]$s.PassMarker
    $failMarker = [string]$s.FailMarker
    $fsPath = Convert-ResPathToFs -ResPath $script -Root $ProjectDir

    if (-not (Test-Path -LiteralPath $fsPath)) {
        Write-Host "[SKIP] $name - script ausente: $script"
        $results.Add([pscustomobject]@{ Name = $name; Status = "SKIP"; ExitCode = -1 }) | Out-Null
        continue
    }

    Write-Host ">>> RUN $name ($script)"
    # PS 5.1: ArgumentList com array quebra paths com espaço. Cmdline = string unica.
    $argString = "--headless --path `"$ProjectDir`" -s `"$script`""

    $stdoutLog = Join-Path $env:TEMP ("hashira-smoke-{0}-out.txt" -f $name)
    $stderrLog = Join-Path $env:TEMP ("hashira-smoke-{0}-err.txt" -f $name)
    if (Test-Path -LiteralPath $stdoutLog) { Remove-Item -LiteralPath $stdoutLog -Force }
    if (Test-Path -LiteralPath $stderrLog) { Remove-Item -LiteralPath $stderrLog -Force }

    $proc = Start-Process -FilePath $godot -ArgumentList $argString `
        -WorkingDirectory $ProjectDir `
        -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog

    $finished = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $finished) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Write-Host ("[FAIL] {0} - TIMEOUT {1}s" -f $name, $TimeoutSec)
        $failed++
        $results.Add([pscustomobject]@{ Name = $name; Status = "TIMEOUT"; ExitCode = 124 }) | Out-Null
        if (Test-Path -LiteralPath $stdoutLog) {
            Get-Content -LiteralPath $stdoutLog -Tail 40 | ForEach-Object { Write-Host $_ }
        }
        Write-Host ""
        continue
    }

    $code = $proc.ExitCode
    if ($null -eq $code) { $code = 1 }

    $outText = ""
    if (Test-Path -LiteralPath $stdoutLog) {
        $outLines = Get-Content -LiteralPath $stdoutLog
        $outLines | ForEach-Object { Write-Host $_ }
        $outText = ($outLines -join "`n")
    }
    if (Test-Path -LiteralPath $stderrLog) {
        $errLines = Get-Content -LiteralPath $stderrLog -ErrorAction SilentlyContinue
        if ($errLines -and $errLines.Count -gt 0) {
            Write-Host "--- stderr (engine; nao decide sozinho) ---"
            $errLines | Select-Object -Last 12 | ForEach-Object { Write-Host $_ }
        }
    }

    $hasFail = ($failMarker.Length -gt 0) -and ($outText.Contains($failMarker))
    $hasPass = ($passMarker.Length -gt 0) -and ($outText.Contains($passMarker))

    # Prioridade: marcador do script > exit code do Godot (leaks viram exit 1).
    $status = "FAIL"
    if ($hasFail) {
        $status = "FAIL"
    } elseif ($hasPass) {
        $status = "PASS"
    } elseif ($code -eq 0) {
        $status = "PASS"
    } else {
        $status = "FAIL"
    }

    if ($status -eq "PASS") {
        if ($code -ne 0) {
            Write-Host ("[PASS] {0} (marker OK; godot exit={1} ignored - leaks/engine noise)" -f $name, $code)
        } else {
            Write-Host ("[PASS] {0} (exit 0)" -f $name)
        }
        $results.Add([pscustomobject]@{ Name = $name; Status = "PASS"; ExitCode = $code }) | Out-Null
    } else {
        Write-Host ("[FAIL] {0} (exit {1}; passMarker={2} failMarker={3})" -f $name, $code, $hasPass, $hasFail)
        $failed++
        $results.Add([pscustomobject]@{ Name = $name; Status = "FAIL"; ExitCode = $code }) | Out-Null
    }
    Write-Host ""
}

Write-Host "=== SUMMARY ==="
foreach ($r in $results) {
    Write-Host ("  {0,-24} {1} (exit {2})" -f $r.Name, $r.Status, $r.ExitCode)
}

$ran = @($results | Where-Object { $_.Status -ne "SKIP" }).Count
$passed = @($results | Where-Object { $_.Status -eq "PASS" }).Count
Write-Host ""
Write-Host ("Passed {0} / {1} (failed={2})" -f $passed, $ran, $failed)

if ($failed -gt 0) {
    Write-Host "SUITE FAIL"
    exit 1
}
if ($ran -eq 0) {
    Write-Host "SUITE FAIL - nenhum smoke rodou"
    exit 1
}
Write-Host "SUITE PASS"
exit 0
