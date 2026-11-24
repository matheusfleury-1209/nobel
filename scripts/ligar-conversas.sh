#!/usr/bin/env bash
# Liga o registro automático das conversas do Rafa (sem IA) e o alarme de cliente sem resposta.
#   cd ~/time-ia && bash scripts/ligar-conversas.sh
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEG_DIR="$HOME/.config/nobel"
say() { printf '%s\n' "$*"; }
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$SEG_DIR"; chmod 700 "$SEG_DIR"

say ""
say "== 1/3 Números internos (você e a Hanielly ficam fora da lista de clientes)"
openclaw config get bindings --json 2>/dev/null | python3 -c '
import json, sys
try:
    b = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for r in b if isinstance(b, list) else []:
    peer = ((r.get("match") or {}).get("peer") or {}).get("id")
    if peer and r.get("agentId") != "vendedor":
        print(peer)
' > "$SEG_DIR/internos.txt" || true
say "   $(grep -c . "$SEG_DIR/internos.txt" 2>/dev/null || echo 0) número(s) interno(s) salvos"

say ""
say "== 2/3 Lendo as conversas do Rafa"
python3 "$REPO_DIR/scripts/conversas.py" --diagnostico | sed 's/^/   /'
cat "$HOME/.openclaw/empresa/vendas/conversas-resumo.md" 2>/dev/null | sed -n '/^- /p' | sed 's/^/   /'

say ""
say "== 3/3 Instruções do time (a Helena e a Bia passam a usar a lista)"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "✅ CONVERSAS LIGADAS"
say "   A lista atualiza a cada 5 minutos (junto com o alarme) e você recebe 'Cliente sem resposta' no ntfy"
say "   se alguém esperar mais de 15 minutos."
