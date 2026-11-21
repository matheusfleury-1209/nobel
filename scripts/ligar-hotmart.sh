#!/usr/bin/env bash
# Liga o time às vendas da Hotmart (SOMENTE LEITURA).
#
# Uso, na VPS, dentro da pasta do projeto:
#   bash scripts/ligar-hotmart.sh            # primeira vez: pede os 3 códigos
#   TROCAR=1 bash scripts/ligar-hotmart.sh   # para trocar os códigos
#
# O que faz:
#   1. Pede o Client ID, o Client Secret e o Basic da Hotmart e guarda em ~/.config/nobel/hotmart.env
#      (só o root lê; fora do Git e fora das pastas dos agentes)
#   2. Testa a conexão
#   3. Puxa as vendas e cria empresa/vendas/hotmart/ (vendas.csv, pendentes.csv, resumo.md)
#   4. Agenda a atualização a cada 10 minutos (cron do sistema, sem gastar IA)
#   5. Atualiza as instruções dos agentes (Rafa, Bia, Nina, Otávio e regras gerais)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
SEG_DIR="$HOME/.config/nobel"
ENV_FILE="$SEG_DIR/hotmart.env"
LOG_FILE="$SEG_DIR/hotmart.log"

say()   { printf '%s\n' "$*"; }
aviso() { printf '⚠️  %s\n' "$*"; }
erro()  { printf '❌ %s\n' "$*" >&2; exit 1; }

PY="$(command -v python3 || true)"
[[ -n "$PY" ]] || erro "python3 não encontrado. Rode: apt-get install -y python3"

limpar() {  # tira espaços, Enter do Windows e marcas de colagem do terminal
  local v="$1"
  v="${v//$'\r'/}"
  v="${v//$'\e[200~'/}"
  v="${v//$'\e[201~'/}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

perguntar() {  # $1 = nome que aparece para a pessoa
  local valor="" tentativas=0
  while [[ -z "$valor" ]]; do
    tentativas=$((tentativas + 1))
    (( tentativas <= 5 )) || erro "Não recebi o $1."
    read -r -p "Cole o $1 e aperte Enter: " valor || true
    valor="$(limpar "$valor")"
    [[ -n "$valor" ]] || say "   (veio vazio, tente de novo)" >&2
  done
  printf '%s' "$valor"
}

say ""
say "== 1/5 Códigos da Hotmart"
mkdir -p "$SEG_DIR"
chmod 700 "$SEG_DIR"
if [[ -f "$ENV_FILE" && "${TROCAR:-0}" != "1" ]]; then
  say "   Já existem códigos salvos. Vou usar os mesmos (para trocar: TROCAR=1 bash scripts/ligar-hotmart.sh)"
else
  say "   Na Hotmart: Ferramentas → Credenciais Developers → Criar credencial (deixe 'sandbox' DESMARCADO)."
  say "   Ela mostra 3 códigos. Cole um de cada vez aqui:"
  CID="$(perguntar "Client ID")"
  CSEC="$(perguntar "Client Secret")"
  BASIC="$(perguntar "Basic")"
  BASIC="${BASIC#Basic }"
  BASIC="${BASIC#basic }"
  ( umask 077
    printf 'HOTMART_CLIENT_ID=%s\nHOTMART_CLIENT_SECRET=%s\nHOTMART_BASIC=%s\n' "$CID" "$CSEC" "$BASIC" > "$ENV_FILE" )
  rm -f "$SEG_DIR/hotmart-token.json"
  unset CID CSEC BASIC
  printf '\033c'  # limpa a tela para os códigos não ficarem à mostra
  say "== 1/5 Códigos salvos em $ENV_FILE (só o root lê)"
fi

say ""
say "== 2/5 Testando a conexão"
if ! "$PY" "$REPO_DIR/scripts/hotmart.py" testar; then
  erro "Não conectou. Confira os 3 códigos na Hotmart e rode: TROCAR=1 bash scripts/ligar-hotmart.sh"
fi

say ""
say "== 3/5 Puxando as vendas (pode levar 1 minuto)"
mkdir -p "$EMPRESA_DIR/vendas/hotmart"
"$PY" "$REPO_DIR/scripts/hotmart.py" sincronizar || erro "Falhou ao puxar as vendas (veja a mensagem acima)"

say ""
say "== 4/5 Atualização automática a cada 10 minutos"
if ! command -v crontab >/dev/null 2>&1; then
  say "   Instalando o cron…"
  apt-get install -y cron >/dev/null
fi
systemctl enable --now cron >/dev/null 2>&1 || true
LINHA="*/10 * * * * cd $REPO_DIR && $PY scripts/hotmart.py sincronizar --quieto >> $LOG_FILE 2>&1 # nobel-hotmart"
( crontab -l 2>/dev/null | grep -v '# nobel-hotmart' || true; echo "$LINHA" ) | crontab -
say "   ✅ Agendado. Erros, se houver, ficam em $LOG_FILE"

say ""
say "== 5/5 Atualizando as instruções do time"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "✅ HOTMART LIGADA"
say "   • Resumo de vendas: $EMPRESA_DIR/vendas/hotmart/resumo.md"
say "   • O Rafa confere sozinho quem diz que pagou (pelo e-mail da compra)"
say "   • A Bia recebe a fila de Pix/boleto/cartão que não virou venda"
say "   • A Nina vê as alunas novas e o Otávio fecha o faturamento"
say "   Teste: mande para a Helena \"Quantas vendas tivemos hoje na Hotmart?\""
