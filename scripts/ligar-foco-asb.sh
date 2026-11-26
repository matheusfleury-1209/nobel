#!/usr/bin/env bash
# Deixa o time focado só no projeto ASB online: filtra os dados da Meta e da Hotmart e atualiza as instruções.
#   cd ~/time-ia && git pull && bash scripts/ligar-foco-asb.sh
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
say() { printf '%s\n' "$*"; }
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

say ""
say "== 1/3 Hotmart: quais produtos contam para o projeto"
if [[ -f "$HOME/.config/nobel/hotmart.env" ]]; then
  python3 "$REPO_DIR/scripts/hotmart.py" sincronizar --produtos
else
  say "   (Hotmart não ligada)"
fi

say ""
say "== 2/3 Meta: só as campanhas do projeto"
if [[ -f "$HOME/.config/nobel/meta.env" ]]; then
  python3 "$REPO_DIR/scripts/meta.py" sincronizar
  grep -E '^\| ' "$HOME/.openclaw/empresa/marketing/trafego/meta/resumo.md" | sed -n '/Campanha/,/^$/p' | head -6 | sed 's/^/   /'
else
  say "   (Meta não ligada)"
fi

say ""
say "== 3/3 Instruções: o time inteiro focado no ASB online"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "✅ FOCO NO ASB LIGADO"
say "   Confira acima: em Hotmart, o curso de ASB online tem que aparecer como '✅ conta'."
say "   Teste: pergunte à Helena \"Como estão as campanhas?\" — ela deve falar só da campanha ASB | ONLINE."
