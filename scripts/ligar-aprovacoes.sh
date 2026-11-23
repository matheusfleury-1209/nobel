#!/usr/bin/env bash
# Pacote de aprovação diário: a Helena manda às 8h05, todo dia, o briefing com a lista numerada
# do que espera a sua decisão. Você responde "aprova 1 e 3", "não 2" ou "aprova tudo".
#
# Uso, na VPS, dentro da pasta do projeto:
#   bash scripts/ligar-aprovacoes.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTA="${AVISO_CONTA:-comercial}"
say()   { printf '%s\n' "$*"; }
aviso() { printf '⚠️  %s\n' "$*"; }
erro()  { printf '❌ %s\n' "$*" >&2; exit 1; }

command -v openclaw >/dev/null 2>&1 || erro "openclaw não encontrado"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

say ""
say "== 1/3 Atualizando as instruções da Helena"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "== 2/3 Descobrindo o seu número (o mesmo do briefing de hoje)"
LISTA="$(openclaw automations list --all --json 2>/dev/null || true)"
DESTINO="${AVISO_PARA:-}"
if [[ -z "$DESTINO" ]]; then
  DESTINO="$(printf '%s' "$LISTA" | python3 -c '
import json, sys
try:
    dados = json.load(sys.stdin)
except Exception:
    sys.exit(0)
achou = []
def procurar_to(x):
    if isinstance(x, dict):
        for k, v in x.items():
            if k in ("to", "target", "peer") and isinstance(v, str) and v.startswith("+"):
                achou.append(v)
            procurar_to(v)
    elif isinstance(x, list):
        for v in x: procurar_to(v)
def andar(x):
    if isinstance(x, dict):
        if isinstance(x.get("name"), str) and x["name"].startswith("[time] Briefing"):
            procurar_to(x)
        for v in x.values(): andar(v)
    elif isinstance(x, list):
        for v in x: andar(v)
andar(dados)
print(achou[0] if achou else "")
' || true)"
fi
if [[ -z "$DESTINO" ]]; then
  read -r -p "→ Digite o SEU WhatsApp (o que fala com a Helena), com DDD, ex.: 62 99999-9999: " NUM || true
  dig="$(tr -cd '0-9' <<<"$NUM")"
  [[ ${#dig} -ge 10 ]] || erro "Número inválido"
  [[ "$dig" == 55* ]] || dig="55$dig"
  DESTINO="+$dig"
fi
say "   Mensagens vão para: $DESTINO (pelo WhatsApp da conta '$CONTA')"

say ""
say "== 3/3 Rotina das 8h05"
IDS="$(printf '%s' "$LISTA" | python3 -c '
import json, sys
alvos = {"[time] Briefing diário"}
try:
    dados = json.load(sys.stdin)
except Exception:
    sys.exit(0)
def andar(x):
    if isinstance(x, dict):
        nome, jid = x.get("name"), x.get("id") or x.get("jobId")
        if isinstance(nome, str) and nome in alvos and jid:
            print(jid)
        for v in x.values(): andar(v)
    elif isinstance(x, list):
        for v in x: andar(v)
andar(dados)
' || true)"
while read -r jid; do
  [[ -n "$jid" ]] && openclaw automations disable "$jid" >/dev/null 2>&1 && say "   desligado o briefing antigo (só seg–sex)"
done <<<"$IDS"

NOVA="[time] Briefing e aprovações"
if openclaw automations list --all 2>/dev/null | grep -qF -- "$NOVA"; then
  say "   ↷ já existe: $NOVA"
else
  openclaw automations create "5 8 * * *" \
    "Use a skill briefing-diario e me mande o resumo de hoje, com o pacote numerado de aprovações (skill pacote-aprovacao) no fim." \
    --name "$NOVA" --tz America/Sao_Paulo --session isolated --agent diretor \
    --announce --channel whatsapp --to "$DESTINO" --account "$CONTA" >/dev/null \
    || erro "Não consegui criar a rotina. Me mande o print."
  say "   ✅ Todo dia às 8h05 a Helena te manda o briefing com as aprovações"
fi

say ""
say "✅ APROVAÇÕES LIGADAS"
say "   Para testar agora, mande para a Helena: \"me manda o pacote de aprovação\""
