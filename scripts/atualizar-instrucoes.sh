#!/usr/bin/env bash
# Copia para a VPS as instruções mais recentes do time (AGENTS.md + regras gerais, skills e o guia do Rafa).
# Não mexe em planilhas, memória, conversas nem configurações. Usado pelos scripts ligar-*.sh.
#   bash scripts/atualizar-instrucoes.sh
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
CARIMBO="$(date +%Y%m%d-%H%M%S)"

instalar_arquivo() {
  local origem="$1" destino="$2"
  if [[ -f "$destino" ]] && ! cmp -s "$origem" "$destino"; then
    cp "$destino" "$destino.bak-$CARIMBO"
  fi
  cp "$origem" "$destino"
}

n=0
for src in "$REPO_DIR"/time/*/; do
  id="$(basename "$src")"
  [[ "$id" == _* ]] && continue
  ws="$OPENCLAW_HOME/workspace-$id"
  [[ -d "$ws" ]] || continue
  tmp="$(mktemp)"
  cat "$src/AGENTS.md" "$REPO_DIR/time/_comum/REGRAS-GERAIS.md" > "$tmp"
  chmod 644 "$tmp"
  instalar_arquivo "$tmp" "$ws/AGENTS.md"
  rm -f "$tmp"
  for skill_dir in "$src"/skills/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    nome="$(basename "$skill_dir")"
    mkdir -p "$ws/skills/$nome"
    instalar_arquivo "$skill_dir/SKILL.md" "$ws/skills/$nome/SKILL.md"
  done
  n=$((n + 1))
done
echo "   ✅ Instruções atualizadas em $n agentes"

# Pastas e LEIA-ME novos de empresa/ (nunca sobrescreve planilhas já preenchidas)
cp -Rn "$REPO_DIR/empresa/." "$EMPRESA_DIR/" 2>/dev/null || true
for leia in "$REPO_DIR"/empresa/*/*/LEIA-ME.md "$REPO_DIR"/empresa/*/*/*/LEIA-ME.md; do
  [[ -f "$leia" ]] || continue
  rel="${leia#"$REPO_DIR/empresa/"}"
  mkdir -p "$EMPRESA_DIR/$(dirname "$rel")"
  cp "$leia" "$EMPRESA_DIR/$rel"
done

if [[ -d "$REPO_DIR/privado/estagio" ]]; then
  mkdir -p "$EMPRESA_DIR/alunas/estagio/documentos"
  cp "$REPO_DIR"/privado/estagio/* "$EMPRESA_DIR/alunas/estagio/documentos/"
  echo "   ✅ Kit de estágio no lugar ($(ls "$EMPRESA_DIR/alunas/estagio/documentos" | wc -l) arquivos)"
fi

if [[ -f "$REPO_DIR/privado/GUIA-DO-RAFA.md" ]]; then
  cp "$REPO_DIR/privado/GUIA-DO-RAFA.md" "$EMPRESA_DIR/vendas/GUIA-DO-RAFA.md"
  echo "   ✅ Guia do Rafa atualizado"
else
  echo "⚠️  privado/GUIA-DO-RAFA.md não encontrado: o guia do Rafa ficou na versão anterior"
fi

if command -v openclaw >/dev/null 2>&1; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  openclaw gateway restart >/dev/null 2>&1 || echo "⚠️  Reinicie o gateway: openclaw gateway restart"
fi
