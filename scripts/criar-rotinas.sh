#!/usr/bin/env bash
# Cria as rotinas automáticas (automações/cron) de cada agente no OpenClaw.
# Pode rodar mais de uma vez: rotinas que já existem (mesmo nome) são puladas.
#
# Uso:
#   ./scripts/criar-rotinas.sh
#   AVISO_CANAL=telegram AVISO_PARA=123456789 ./scripts/criar-rotinas.sh   # manda o briefing no seu Telegram
#   DRY_RUN=1 ./scripts/criar-rotinas.sh                                  # só mostra os comandos
set -euo pipefail

TZ_EMPRESA="${TZ_EMPRESA:-America/Sao_Paulo}"
AVISO_CANAL="${AVISO_CANAL:-}"     # canal onde VOCÊ recebe os resumos da Diretora (ex.: telegram, whatsapp)
AVISO_PARA="${AVISO_PARA:-}"       # seu id/número nesse canal
DRY_RUN="${DRY_RUN:-0}"

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

if [[ "$DRY_RUN" != "1" ]] && ! command -v openclaw >/dev/null 2>&1; then
  echo "❌ Comando 'openclaw' não encontrado. Instale o OpenClaw primeiro (docs/02-instalacao.md)." >&2
  exit 1
fi

EXISTENTES=""
if [[ "$DRY_RUN" != "1" ]]; then
  EXISTENTES="$(openclaw automations list --all 2>/dev/null || true)"
fi

# rotina <agente> "<cron>" "<nome>" "<instrução>" [avisar_dono=0|1]
rotina() {
  local agente="$1" cron="$2" nome="[time] $3" prompt="$4" avisar="${5:-0}"
  if [[ -n "$EXISTENTES" ]] && grep -qF -- "$nome" <<<"$EXISTENTES"; then
    echo "↷ já existe: $nome"
    return
  fi
  local extra=()
  if [[ "$avisar" == "1" && -n "$AVISO_CANAL" && -n "$AVISO_PARA" ]]; then
    extra=(--announce --channel "$AVISO_CANAL" --to "$AVISO_PARA")
  fi
  run openclaw automations create "$cron" "$prompt" \
    --name "$nome" --tz "$TZ_EMPRESA" --session isolated --agent "$agente" \
    ${extra[@]+"${extra[@]}"}
  echo "✓ $nome ($agente, $cron)"
}

# ── Diretora ───────────────────────────────────────────────────────────────
rotina diretor "0 8 * * 1-5"  "Briefing diário"   "Use a skill briefing-diario e me mande o resumo de hoje." 1
rotina diretor "0 17 * * 5"   "Revisão semanal"   "Use a skill revisao-semanal e me mande o resumo da semana e o plano da próxima." 1

# ── Financeiro ─────────────────────────────────────────────────────────────
rotina financeiro "30 7 * * 1-5" "Caixa do dia"      "Use a skill fluxo-de-caixa. Se houver alerta (saldo negativo previsto, conta vencendo sem saldo, atraso > 15 dias), avise a diretora com sessions_send."
rotina financeiro "0 10 * * 1-5" "Cobranças"         "Use a skill cobranca e gere os rascunhos do dia. Peça aprovação para enviar."
rotina financeiro "0 9 1 * *"    "Fechamento do mês" "Use a skill fechamento-mensal para o mês anterior e mande o resumo à diretora."

# ── Tráfego ────────────────────────────────────────────────────────────────
rotina trafego "0 9 * * 1-5" "Relatório de anúncios" "Use a skill relatorio-campanhas para ontem. Se houver campanha queimando dinheiro, peça aprovação URGENTE para pausar."
rotina trafego "0 10 * * 1"  "Otimização semanal"    "Use a skill otimizacao-campanhas com os últimos 7 dias e registre as propostas em aprovações."

# ── Social media ───────────────────────────────────────────────────────────
rotina social "0 9 * * 1"    "Calendário da semana"  "Use a skill calendario-editorial para esta semana."
rotina social "0 14 * * 1-5" "Posts de amanhã"       "Use a skill conteudo-redes para deixar prontos os posts de amanhã do calendário."

# ── Criativos ──────────────────────────────────────────────────────────────
rotina criativos "0 15 * * 1-5" "Fila de criativos"  "Processe os pedidos pendentes em empresa/marketing/criativos/fila.md (skills copy-anuncio e briefing-criativo) e avise quem pediu."

# ── Vendas ─────────────────────────────────────────────────────────────────
rotina vendedor "0 9,15 * * 1-5" "Follow-ups"        "Use a skill follow-up para os leads com próximo passo vencido."

# ── Atendimento ────────────────────────────────────────────────────────────
rotina atendimento "0 11 * * 1-5" "Tickets abertos"  "Revise empresa/atendimento/tickets.csv: cobre respostas internas, feche o que foi resolvido e avise a diretora sobre urgentes."

# ── Prospecção ─────────────────────────────────────────────────────────────
rotina prospector "0 10 * * 2,4" "Nova lista de prospecção" "Use a skill prospeccao-leads e gere 20 novos alvos."
rotina prospector "0 10 1 * *"   "Concorrentes do mês"      "Use a skill analise-concorrentes e mande as oportunidades para a diretora."

# ── Administrativo ─────────────────────────────────────────────────────────
rotina administrativo "0 8 * * 1" "Obrigações da semana" "Use a skill agenda-obrigacoes."

echo
echo "Pronto. Veja as rotinas com:  openclaw automations list"
[[ -z "$AVISO_CANAL" ]] && echo "Dica: rode de novo com AVISO_CANAL e AVISO_PARA para receber os resumos da Diretora no seu celular (apague antes as rotinas da Diretora com 'openclaw automations remove <id>')."
exit 0
