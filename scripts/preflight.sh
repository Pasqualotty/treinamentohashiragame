#!/usr/bin/env bash
#
# scripts/preflight.sh — rede de seguranca pre-build/deploy do Treinamento Hashira.
#
# Roda, nesta ordem:
#   1) Import headless do Godot (garante .godot/imported atualizado)
#   2) Suite completa de smokes (tools/run_smokes.ps1)
# So cria a sentinela de preflight ("/tmp/.claude-preflight-passed-<HEAD>") se
# TUDO passar (exit 0 em cada etapa). Falha rapido em qualquer quebra.
#
# Uso:
#   bash scripts/preflight.sh
#
# Override opcional do binario do Godot (se a auto-deteccao nao achar):
#   GODOT_EXE=/c/path/para/Godot_v4.7.1-stable_win64_console.exe bash scripts/preflight.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Treinamento Hashira - preflight ==="
echo "Project: $PROJECT_DIR"
echo ""

if [ ! -f "$PROJECT_DIR/project.godot" ]; then
    echo "ERRO: project.godot nao encontrado em: $PROJECT_DIR" >&2
    exit 1
fi

# --- Resolucao do binario do Godot -----------------------------------------
# Mesma estrategia de tools/run_smokes.ps1 (Resolve-GodotExe):
#   1. GODOT_EXE explicito (env var)
#   2. Pacote winget console (preferido - sem janela de console propria)
#   3. Pacote winget GUI
#   4. `godot` no PATH
#   5. Busca recursiva por Godot_v4*console*.exe / Godot_v4*.exe em WinGet/Packages
resolve_localappdata() {
    local raw="${LOCALAPPDATA:-}"
    if [ -z "$raw" ]; then
        raw="$HOME/AppData/Local"
    fi
    # Normaliza backslashes (LOCALAPPDATA costuma vir em formato Windows).
    printf '%s\n' "${raw//\\//}"
}

resolve_godot() {
    if [ -n "${GODOT_EXE:-}" ] && [ -f "${GODOT_EXE}" ]; then
        printf '%s\n' "${GODOT_EXE}"
        return 0
    fi

    local local_appdata pkg_dir console gui found
    local_appdata="$(resolve_localappdata)"
    pkg_dir="${local_appdata}/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    console="${pkg_dir}/Godot_v4.7.1-stable_win64_console.exe"
    gui="${pkg_dir}/Godot_v4.7.1-stable_win64.exe"

    if [ -f "$console" ]; then
        printf '%s\n' "$console"
        return 0
    fi
    if [ -f "$gui" ]; then
        printf '%s\n' "$gui"
        return 0
    fi

    found="$(command -v godot 2>/dev/null || true)"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi

    local winget_root="${local_appdata}/Microsoft/WinGet/Packages"
    if [ -d "$winget_root" ]; then
        found="$(find "$winget_root" -iname 'Godot_v4*console*.exe' 2>/dev/null | head -n1 || true)"
        if [ -n "$found" ]; then
            printf '%s\n' "$found"
            return 0
        fi
        found="$(find "$winget_root" -iname 'Godot_v4*.exe' 2>/dev/null | head -n1 || true)"
        if [ -n "$found" ]; then
            printf '%s\n' "$found"
            return 0
        fi
    fi

    return 1
}

echo "[1/3] Resolvendo binario do Godot..."
if ! GODOT_BIN="$(resolve_godot)"; then
    echo "" >&2
    echo "ERRO: Godot CLI nao encontrado." >&2
    echo "Instale Godot 4.7.x (winget install GodotEngine.GodotEngine) ou defina" >&2
    echo "GODOT_EXE apontando para o executavel antes de rodar este script." >&2
    exit 2
fi
echo "Godot: $GODOT_BIN"
echo ""

# --- Import headless ---------------------------------------------------------
echo "[2/3] Import headless (godot --headless --path . --import)..."
if ! "$GODOT_BIN" --headless --path "$PROJECT_DIR" --import; then
    echo "" >&2
    echo "ERRO: import headless do Godot falhou (exit != 0)." >&2
    exit 3
fi
echo "Import OK."
echo ""

# --- Suite de smokes ---------------------------------------------------------
echo "[3/3] Rodando suite de smokes (tools/run_smokes.ps1)..."
if ! powershell -NoProfile -ExecutionPolicy Bypass -File "$PROJECT_DIR/tools/run_smokes.ps1" -GodotExe "$GODOT_BIN" -ProjectDir "$PROJECT_DIR"; then
    echo "" >&2
    echo "ERRO: suite de smokes falhou. Veja o output acima para identificar o smoke quebrado." >&2
    exit 4
fi
echo ""

# --- Sentinela ----------------------------------------------------------------
HEAD=$(git rev-parse HEAD)
touch "/tmp/.claude-preflight-passed-${HEAD}"
echo "PREFLIGHT PASS ${HEAD}"
