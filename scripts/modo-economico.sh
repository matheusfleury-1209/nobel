#!/usr/bin/env bash
# Modo econômico do time (rodar na VPS, dentro da pasta time-ia):
#   1. Rafa mais barato: modelo Haiku 5.5 + Guia do Rafa (arquivo curto) + conversas novas
#   2. Todos os agentes pensam no nível "low" (a Vera, que revisa, fica em "medium")
#   3. Desliga as rotinas da madrugada que ainda não têm dados para trabalhar
#   4. A Gabi confere os anúncios 3x por dia (10h, 14h, 18h) em vez de a cada 3 horas
#
# Uso:  bash scripts/modo-economico.sh
#       RAFA_MODELO=anthropic/claude-sonnet-5-5 bash scripts/modo-economico.sh   # mantém o Rafa no Sonnet
# Para desfazer uma rotina:  openclaw automations list --all  e  openclaw automations enable <id>
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMPRESA_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}/empresa"
RAFA_MODELO="${RAFA_MODELO:-anthropic/claude-haiku-5-5}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }

echo "== 1/4 Rafa mais barato =="
if [[ -f "$REPO_DIR/privado/GUIA-DO-RAFA.md" ]]; then
  mkdir -p "$EMPRESA_DIR/vendas"
  cp "$REPO_DIR/privado/GUIA-DO-RAFA.md" "$EMPRESA_DIR/vendas/GUIA-DO-RAFA.md"
  ok "Guia do Rafa copiado"
else
  aviso "privado/GUIA-DO-RAFA.md não encontrado: libere os arquivos da empresa antes (openssl ... | tar xz)"
fi
openclaw config set agents.entries.vendedor.model "$RAFA_MODELO"
ok "Rafa usando $RAFA_MODELO"

echo; echo "== 2/4 Nível de raciocínio =="
openclaw config set agents.defaults.thinkingDefault low
openclaw config set agents.entries.revisor.thinkingDefault medium
ok "todos em low; Vera em medium"

echo; echo "== 3/4 Rotinas =="
DESLIGAR=(
  "[time] Garimpo noturno"
  "[time] Checagem técnica noturna"
  "[time] Produção noturna"
  "[time] Revisão noturna"
  "[time] Posts do dia para aprovação"
  "[time] Pesquisa de mercado"
  "[time] Agenda do dia"
  "[time] Leads da madrugada"
  "[time] Checagem dos anúncios"
)
LISTA_JSON="$(openclaw automations list --all --json 2>/dev/null || true)"
IDS="$(printf '%s' "$LISTA_JSON" | python3 -c '
import json, sys
alvos = set(sys.argv[1:])
try:
    dados = json.load(sys.stdin)
except Exception:
    sys.exit(0)
def andar(x):
    if isinstance(x, dict):
        nome, jid = x.get("name"), x.get("id") or x.get("jobId")
        if isinstance(nome, str) and nome in alvos and jid:
            print(f"{jid}\t{nome}")
        for v in x.values(): andar(v)
    elif isinstance(x, list):
        for v in x: andar(v)
andar(dados)
' "${DESLIGAR[@]}")"
if [[ -z "$IDS" ]]; then
  aviso "Não consegui ler a lista de rotinas automaticamente."
  aviso "Desligue pelo painel ou com: openclaw automations list  e  openclaw automations disable <id>"
else
  while IFS=$'\t' read -r jid nome; do
    openclaw automations disable "$jid" >/dev/null && ok "desligada: $nome" || aviso "não consegui desligar: $nome"
  done <<<"$IDS"
fi
NOVA="[time] Checagem dos anúncios 3x"
if ! openclaw automations list --all 2>/dev/null | grep -qF -- "$NOVA"; then
  openclaw automations create "0 10,14,18 * * *" \
    "Confira gasto, conversas e custo por conversa desde a última checagem. Se um anúncio tiver erro ou estiver gastando sem trazer conversa (regras do plano), PAUSE e avise a diretora. Nunca aumente verba." \
    --name "$NOVA" --tz America/Sao_Paulo --session isolated --agent trafego >/dev/null
  ok "Gabi confere os anúncios às 10h, 14h e 18h"
fi

echo; echo "== 4/4 Aplicando =="
openclaw gateway restart
sleep 10
for k in $(openclaw sessions --agent vendedor 2>/dev/null | grep -oE 'agent:vendedor:[^ "]+' | sort -u); do
  openclaw sessions archive "$k" --agent vendedor >/dev/null 2>&1 || true
done
ok "conversas de teste do Rafa arquivadas (as próximas já usam o modo econômico)"

cat <<FIM

✅ Modo econômico ligado.
  • Teste o Rafa de outro celular com as mesmas perguntas de antes.
  • Se as respostas piorarem, volte o Rafa para o Sonnet (continua econômico, só um pouco mais caro):
      RAFA_MODELO=anthropic/claude-sonnet-5-5 bash scripts/modo-economico.sh
  • Acompanhe o "Custo diário" no console da Anthropic nos próximos 2 dias.
FIM
