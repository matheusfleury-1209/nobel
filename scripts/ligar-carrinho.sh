#!/usr/bin/env bash
# Liga os avisos da Hotmart (webhook): abandono de checkout para a Bia e pagamento confirmado na hora para o Rafa.
#
# Uso, na VPS, dentro da pasta do projeto (precisa da Hotmart já ligada: scripts/ligar-hotmart.sh):
#   bash scripts/ligar-carrinho.sh
#
# O que faz:
#   1. Cria um endereço secreto e guarda em ~/.config/nobel/hotmart-webhook.env (com o Hottok, se você tiver)
#   2. Liga o recebedor de avisos (serviço nobel-hotmart-webhook, só em 127.0.0.1)
#   3. Publica SÓ esse recebedor na internet pelo Tailscale Funnel (porta 8443, HTTPS).
#      O escritório 3D e o resto da VPS continuam fechados.
#   4. Testa e mostra o endereço para colar na Hotmart
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEG_DIR="$HOME/.config/nobel"
CFG="$SEG_DIR/hotmart-webhook.env"
PORTA=8787
SERVICO=nobel-hotmart-webhook

say()   { printf '%s\n' "$*"; }
aviso() { printf '⚠️  %s\n' "$*"; }
erro()  { printf '❌ %s\n' "$*" >&2; exit 1; }

PY="$(command -v python3 || true)"
[[ -n "$PY" ]] || erro "python3 não encontrado"
[[ -f "$SEG_DIR/hotmart.env" ]] || erro "Ligue a Hotmart antes: bash scripts/ligar-hotmart.sh"
command -v tailscale >/dev/null 2>&1 || erro "Tailscale não encontrado nesta VPS"
command -v openssl >/dev/null 2>&1 || erro "openssl não encontrado"

limpar() {
  local v="$1"
  v="${v//$'\r'/}"; v="${v//$'\e[200~'/}"; v="${v//$'\e[201~'/}"
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

say ""
say "== 1/4 Endereço secreto e Hottok"
mkdir -p "$SEG_DIR"; chmod 700 "$SEG_DIR"
if [[ -f "$CFG" ]]; then
  say "   Já existe configuração. Vou usar o mesmo endereço."
else
  CAMINHO="/hotmart-$(openssl rand -hex 16)"
  say "   Na Hotmart, o Hottok aparece na tela de Webhook (Ferramentas → Webhook)."
  HOTTOK=""
  read -r -p "   Se já tiver o Hottok, cole aqui. Se não achar, só aperte Enter: " HOTTOK || true
  HOTTOK="$(limpar "$HOTTOK")"
  ( umask 077; printf 'CAMINHO=%s\nPORTA=%s\nHOTTOK=%s\n' "$CAMINHO" "$PORTA" "$HOTTOK" > "$CFG" )
  [[ -n "$HOTTOK" ]] && say "   ✅ Hottok salvo" || say "   ℹ️  Sem Hottok: ele é aprendido no primeiro aviso da Hotmart e passa a ser exigido."
fi
CAMINHO="$(grep -E '^CAMINHO=' "$CFG" | cut -d= -f2-)"
HOTTOK_SALVO="$(grep -E '^HOTTOK=' "$CFG" | cut -d= -f2- || true)"
CAB=()
[[ -n "$HOTTOK_SALVO" ]] && CAB=(-H "X-HOTMART-HOTTOK: $HOTTOK_SALVO")

say ""
say "== 2/4 Recebedor de avisos (serviço $SERVICO)"
cat > "/etc/systemd/system/$SERVICO.service" <<EOF
[Unit]
Description=Instituto Nobel - recebe avisos da Hotmart
After=network-online.target

[Service]
ExecStart=$PY $REPO_DIR/scripts/hotmart_webhook.py
Environment=HOME=$HOME
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICO" >/dev/null 2>&1
systemctl restart "$SERVICO"
sleep 2
CORPO='{"id":"teste-local","event":"NOBEL_TESTE","data":{}}'
CODIGO="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  "${CAB[@]}" -d "$CORPO" "http://127.0.0.1:$PORTA$CAMINHO" || true)"
[[ "$CODIGO" == "200" || "$CODIGO" == "401" ]] || erro "O recebedor não respondeu (código $CODIGO). Veja: journalctl -u $SERVICO -n 30"
say "   ✅ Recebedor ligado"

say ""
say "== 3/4 Publicando o recebedor pelo Tailscale Funnel (porta 8443)"
say "   Se aparecer um link dizendo que o Funnel não está ativado, abra o link no computador,"
say "   entre no Tailscale e clique para ativar. O comando continua sozinho depois."
timeout 600 tailscale funnel --bg --https=8443 "http://127.0.0.1:$PORTA" \
  || erro "Não consegui ligar o Funnel. Me mande o print desta tela."
HOST="$(tailscale status --json | "$PY" -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"
URL="https://$HOST:8443$CAMINHO"

say ""
say "== 4/4 Testando pela internet"
sleep 3
CODIGO="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST -H 'Content-Type: application/json' \
  "${CAB[@]}" -d "$CORPO" "$URL" || true)"
if [[ "$CODIGO" == "200" || "$CODIGO" == "401" ]]; then
  say "   ✅ O endereço responde"
else
  aviso "Não consegui testar daqui (código $CODIGO). Pode ser normal; confira com o botão de teste da Hotmart."
fi

say ""
say "== Atualizando as instruções da Bia e do time"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "✅ RECEBEDOR PRONTO. Agora, na Hotmart:"
say "   1. Ferramentas → Webhook → Cadastrar (ou Configurar) Webhook"
say "   2. Nome: Time Nobel  ·  Versão: 2.0.0  ·  Produto: todos (ou o curso de ASB)"
say "   3. URL de destino (copie a linha inteira de baixo):"
say ""
say "      $URL"
say ""
say "   4. Eventos: marque 'Abandono de carrinho' e todos os eventos de compra"
say "      (aprovada, completa, aguardando pagamento/boleto, cancelada, expirada, atrasada, reembolso, chargeback, protesto)"
say "   5. Salve e clique em 'Testar'/'Enviar teste'"
say ""
say "   Para ver se os avisos chegam: tail -n 20 ~/.openclaw/empresa/vendas/hotmart/avisos.log"
