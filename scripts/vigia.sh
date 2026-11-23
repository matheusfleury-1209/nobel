#!/usr/bin/env bash
# Vigia do time (roda a cada 5 minutos pelo cron, sem IA e sem WhatsApp).
# Avisa no celular pelo ntfy quando algo para e avisa de novo quando volta:
#   - WhatsApp do Rafa/Helena desconectado
#   - sistema dos agentes (gateway) fora do ar
#   - créditos da Anthropic acabando ou bloqueados
#   - vendas da Hotmart ou números da Meta sem atualizar
#   - recebedor de avisos da Hotmart parado
#   - disco quase cheio
# Configuração: ~/.config/nobel/alarme.env (NTFY_TOPICO=...), criada por scripts/ligar-alarme.sh
set -uo pipefail

SEG_DIR="$HOME/.config/nobel"
CFG="$SEG_DIR/alarme.env"
ESTADO="$SEG_DIR/alarme-estado"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
REPETIR_MIN=120   # enquanto continuar com problema, lembra a cada 2 horas
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

[[ -f "$CFG" ]] || { echo "sem $CFG"; exit 0; }
# shellcheck disable=SC1090
source "$CFG"
[[ -n "${NTFY_TOPICO:-}" ]] || exit 0
mkdir -p "$ESTADO"

avisar() {  # $1 prioridade (1-5)  $2 título  $3 texto
  python3 - "$NTFY_TOPICO" "$1" "$2" "$3" <<'PY' | curl -s -m 20 -o /dev/null -H 'Content-Type: application/json' -d @- https://ntfy.sh/ || true
import json, sys
topico, prio, titulo, texto = sys.argv[1:5]
print(json.dumps({"topic": topico, "priority": int(prio), "title": titulo, "message": texto,
                  "tags": ["rotating_light"] if int(prio) >= 4 else ["white_check_mark"]}))
PY
}

# $1 chave  $2 ok|falha  $3 prioridade  $4 título  $5 texto do problema  $6 texto de volta
checar() {
  local chave="$1" estado="$2" prio="$3" titulo="$4" texto="$5" volta="$6"
  local arq="$ESTADO/$chave" anterior="ok" ultimo=0 agora
  agora="$(date +%s)"
  if [[ -f "$arq" ]]; then read -r anterior ultimo < "$arq" || true; fi
  if [[ "$estado" == "falha" ]]; then
    if [[ "$anterior" != "falha" ]] || (( agora - ${ultimo:-0} >= REPETIR_MIN * 60 )); then
      avisar "$prio" "$titulo" "$texto"
      echo "falha $agora" > "$arq"
    fi
  else
    if [[ "$anterior" == "falha" ]]; then
      avisar 3 "Voltou ao normal" "$volta"
    fi
    echo "ok $agora" > "$arq"
  fi
}

idade_min() {  # minutos desde a última modificação do arquivo (vazio se não existe)
  [[ -f "$1" ]] || return 0
  echo $(( ( $(date +%s) - $(stat -c %Y "$1") ) / 60 ))
}

# 1) Gateway dos agentes
if curl -s -m 10 -o /dev/null http://127.0.0.1:18789; then GW=ok; else GW=falha; fi
checar gateway "$GW" 5 "Agentes fora do ar" \
  "O sistema dos agentes (gateway) não responde na VPS. Ninguém está atendendo. Rode na VPS: openclaw gateway restart" \
  "O sistema dos agentes voltou a responder."

# 2) WhatsApp comercial (Rafa e Helena)
if [[ "$GW" == ok ]] && command -v openclaw >/dev/null 2>&1; then
  LINHA="$(timeout 60 openclaw channels status 2>&1 | grep -i 'whatsapp comercial:' | head -n 1)"
  if [[ -z "$LINHA" ]] || grep -qiE 'not linked|logged-out|stopped|error|disconnect' <<<"$LINHA"; then WA=falha; else WA=ok; fi
  checar whatsapp "$WA" 5 "WhatsApp do Rafa caiu" \
    "O WhatsApp do Rafa está desconectado da VPS: clientes e a Helena ficam sem resposta. Reconecte: openclaw channels logout --channel whatsapp --account comercial; openclaw channels login --channel whatsapp --account comercial (e leia o QR no celular do Rafa)." \
    "O WhatsApp do Rafa está conectado de novo."

  # 3) Créditos da Anthropic (erros nos últimos 15 minutos)
  CRED="$(timeout 60 openclaw logs --limit 400 --plain --no-color 2>/dev/null | python3 -c '
import sys, re
from datetime import datetime, timezone, timedelta
limite = datetime.now(timezone.utc) - timedelta(minutes=15)
padrao = re.compile(r"credit balance|insufficient[_ ]credit|quota exceeded", re.I)
achou = 0
for linha in sys.stdin:
    m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)", linha)
    if not m or not padrao.search(linha):
        continue
    quando = datetime.fromisoformat(m.group(1)).replace(tzinfo=timezone.utc)
    if quando >= limite:
        achou += 1
print("falha" if achou else "ok")
' 2>/dev/null || echo ok)"
  checar creditos "${CRED:-ok}" 5 "Créditos da Anthropic" \
    "Os agentes estão recebendo erro de créditos/cobrança da Anthropic e podem parar de responder. Confira em console.anthropic.com → Billing." \
    "Os erros de crédito da Anthropic pararam."
fi

# 4) Vendas da Hotmart atualizando (sincroniza a cada 10 min)
if [[ -f "$SEG_DIR/hotmart.env" ]]; then
  I="$(idade_min "$EMPRESA_DIR/vendas/hotmart/resumo.md")"
  if [[ -z "$I" || "$I" -gt 40 ]]; then HM=falha; else HM=ok; fi
  checar hotmart "$HM" 4 "Vendas da Hotmart paradas" \
    "As vendas da Hotmart não atualizam há mais de 40 minutos. Veja o erro: tail -n 5 ~/.config/nobel/hotmart.log" \
    "As vendas da Hotmart voltaram a atualizar."
fi

# 5) Números da Meta atualizando (sincroniza a cada hora)
if [[ -f "$SEG_DIR/meta.env" ]]; then
  I="$(idade_min "$EMPRESA_DIR/marketing/trafego/meta/resumo.md")"
  if [[ -z "$I" || "$I" -gt 180 ]]; then MT=falha; else MT=ok; fi
  checar meta "$MT" 3 "Números da Meta parados" \
    "Os números dos anúncios não atualizam há mais de 3 horas. Veja o erro: tail -n 5 ~/.config/nobel/meta.log" \
    "Os números da Meta voltaram a atualizar."
fi

# 6) Recebedor de avisos da Hotmart
if [[ -f /etc/systemd/system/nobel-hotmart-webhook.service ]]; then
  if systemctl is-active --quiet nobel-hotmart-webhook; then WH=ok; else WH=falha; fi
  checar webhook "$WH" 4 "Avisos da Hotmart parados" \
    "O recebedor de avisos da Hotmart (abandono de checkout e pagamentos) parou. Rode: systemctl restart nobel-hotmart-webhook" \
    "O recebedor de avisos da Hotmart voltou."
fi

# 7) Disco
LIVRE="$(df -P / | awk 'NR==2 {print 100 - $5}' | tr -d '%')"
if [[ -n "$LIVRE" && "$LIVRE" -lt 10 ]]; then DK=falha; else DK=ok; fi
checar disco "$DK" 4 "Disco da VPS quase cheio" \
  "Restam só ${LIVRE:-?}% de espaço no disco da VPS. Se encher, o time para." \
  "O disco da VPS voltou a ter espaço."

exit 0
