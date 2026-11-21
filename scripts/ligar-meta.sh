#!/usr/bin/env bash
# Liga a Gabi (tráfego) e o time aos números dos anúncios da Meta (SOMENTE LEITURA, token com ads_read).
#
# Uso, na VPS, dentro da pasta do projeto:
#   bash scripts/ligar-meta.sh            # primeira vez: pede o token e escolhe a conta
#   TROCAR=1 bash scripts/ligar-meta.sh   # para trocar o token ou a conta
#
# O que faz:
#   1. Pede o token do usuário do sistema e guarda em ~/.config/nobel/meta.env (só o root lê)
#   2. Escolhe a conta de anúncios e testa
#   3. Puxa os números e cria empresa/marketing/trafego/meta/ (diario.csv, ativos.csv, resumo.md)
#   4. Agenda a atualização a cada hora (cron do sistema, sem gastar IA)
#   5. Troca a rotina de checagem da Gabi para usar esses números e atualiza as instruções do time
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
SEG_DIR="$HOME/.config/nobel"
ENV_FILE="$SEG_DIR/meta.env"
LOG_FILE="$SEG_DIR/meta.log"

say()   { printf '%s\n' "$*"; }
aviso() { printf '⚠️  %s\n' "$*"; }
erro()  { printf '❌ %s\n' "$*" >&2; exit 1; }

PY="$(command -v python3 || true)"
[[ -n "$PY" ]] || erro "python3 não encontrado. Rode: apt-get install -y python3"

limpar() {
  local v="$1"
  v="${v//$'\r'/}"
  v="${v//$'\e[200~'/}"
  v="${v//$'\e[201~'/}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

say ""
say "== 1/5 Token da Meta"
mkdir -p "$SEG_DIR"
chmod 700 "$SEG_DIR"
if [[ -f "$ENV_FILE" && "${TROCAR:-0}" != "1" ]]; then
  say "   Já existe um token salvo. Vou usar o mesmo (para trocar: TROCAR=1 bash scripts/ligar-meta.sh)"
else
  TOKEN=""
  for tentativa in 1 2 3 4 5; do
    read -r -p "Cole o token do usuário do sistema (time-nobel) e aperte Enter: " TOKEN || true
    TOKEN="$(limpar "$TOKEN")"
    [[ -n "$TOKEN" ]] && break
    say "   (veio vazio, tente de novo)"
  done
  [[ -n "$TOKEN" ]] || erro "Não recebi o token."
  ( umask 077; printf 'META_TOKEN=%s\nMETA_CONTA=\nMETA_API_VERSION=\n' "$TOKEN" > "$ENV_FILE" )
  unset TOKEN
  printf '\033c'
  say "== 1/5 Token salvo em $ENV_FILE (só o root lê)"
fi

say ""
say "== 2/5 Conta de anúncios"
CONTA_ATUAL="$(grep -E '^META_CONTA=' "$ENV_FILE" | cut -d= -f2- || true)"
if [[ -z "$CONTA_ATUAL" || "${TROCAR:-0}" == "1" ]]; then
  LISTA="$("$PY" "$REPO_DIR/scripts/meta.py" contas --tsv)" || erro "O token não funcionou (veja a mensagem acima). Gere outro e rode: TROCAR=1 bash scripts/ligar-meta.sh"
  [[ -n "$LISTA" ]] || erro "O token não enxerga nenhuma conta de anúncios. No Gerenciador de Negócios, atribua a conta ao usuário do sistema (Ver desempenho) e rode de novo."
  mapfile -t CONTAS <<<"$LISTA"
  if (( ${#CONTAS[@]} == 1 )); then
    ESCOLHA="${CONTAS[0]}"
  else
    say "   O token enxerga estas contas:"
    for i in "${!CONTAS[@]}"; do
      printf '     %d) %s (%s)\n' "$((i + 1))" "$(cut -f2 <<<"${CONTAS[$i]}")" "$(cut -f1 <<<"${CONTAS[$i]}")"
    done
    N=""
    read -r -p "   Digite o número da conta dos anúncios do Instituto Nobel: " N || true
    N="$(limpar "$N")"
    [[ "$N" =~ ^[0-9]+$ ]] && (( N >= 1 && N <= ${#CONTAS[@]} )) || erro "Número inválido. Rode de novo: TROCAR=1 bash scripts/ligar-meta.sh"
    ESCOLHA="${CONTAS[$((N - 1))]}"
  fi
  CONTA="$(cut -f1 <<<"$ESCOLHA")"
  sed -i "s/^META_CONTA=.*/META_CONTA=$CONTA/" "$ENV_FILE"
  say "   Conta escolhida: $(cut -f2 <<<"$ESCOLHA") ($CONTA)"
fi
"$PY" "$REPO_DIR/scripts/meta.py" testar || erro "Não conectou (veja a mensagem acima)."

say ""
say "== 3/5 Puxando os números dos anúncios (pode levar 1 minuto)"
"$PY" "$REPO_DIR/scripts/meta.py" sincronizar || erro "Falhou ao puxar os números (veja a mensagem acima)"

say ""
say "== 4/5 Atualização automática a cada hora"
if ! command -v crontab >/dev/null 2>&1; then
  say "   Instalando o cron…"
  apt-get install -y cron >/dev/null
fi
systemctl enable --now cron >/dev/null 2>&1 || true
LINHA="23 * * * * cd $REPO_DIR && $PY scripts/meta.py sincronizar --quieto >> $LOG_FILE 2>&1 # nobel-meta"
( crontab -l 2>/dev/null | grep -v '# nobel-meta' || true; echo "$LINHA" ) | crontab -
say "   ✅ Agendado. Erros, se houver, ficam em $LOG_FILE"

say ""
say "== 5/5 Rotina da Gabi e instruções do time"
if command -v openclaw >/dev/null 2>&1; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  ANTIGAS=("[time] Checagem dos anúncios 3x" "[time] Checagem dos anúncios")
  IDS="$(openclaw automations list --all --json 2>/dev/null | "$PY" -c '
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
            print(jid)
        for v in x.values(): andar(v)
    elif isinstance(x, list):
        for v in x: andar(v)
andar(dados)
' "${ANTIGAS[@]}" || true)"
  while read -r jid; do
    [[ -n "$jid" ]] && openclaw automations disable "$jid" >/dev/null 2>&1 || true
  done <<<"$IDS"
  NOVA="[time] Checagem dos anúncios (Meta)"
  if ! openclaw automations list --all 2>/dev/null | grep -qF -- "$NOVA"; then
    openclaw automations create "0 10,14,18 * * *" \
      "Leia empresa/marketing/trafego/meta/resumo.md (e diario.csv/ativos.csv se precisar) e empresa/vendas/hotmart/resumo.md. Compare com a última checagem: gasto, conversas no WhatsApp, custo por conversa e vendas com origem whatsapp-rafa. Se houver anúncio reprovado, com problema ou gastando sem trazer conversa (regras do plano), mande para a Diretora como URGENTE, com o nome do anúncio, os números e a sua sugestão (pausar ou trocar). Seu acesso à Meta é só leitura: quem pausa é o Matheus. Nunca sugira aumentar verba sem os números de vendas. Se o resumo tiver mais de 2 horas, avise que a atualização parou." \
      --name "$NOVA" --tz America/Sao_Paulo --session isolated --agent trafego >/dev/null \
      && say "   ✅ A Gabi confere os anúncios às 10h, 14h e 18h com os números da Meta" \
      || aviso "Não consegui criar a rotina da Gabi. Crie pelo painel: 10h, 14h e 18h, agente trafego."
  fi
fi
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "✅ META LIGADA"
say "   • Resumo dos anúncios: $EMPRESA_DIR/marketing/trafego/meta/resumo.md"
say "   • A Gabi confere às 10h, 14h e 18h e avisa a Helena se algo estiver errado"
say "   • O acesso é só leitura: nada é criado, pausado ou alterado pela Meta"
say "   Teste: mande para a Helena \"Como estão os anúncios de ASB hoje?\""
