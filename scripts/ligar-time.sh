#!/usr/bin/env bash
# Liga o time para trabalhar sozinho (rodar na VPS, como root, depois do instalar-vps.sh):
#   1. Cada pessoa que chama no WhatsApp tem a sua própria conversa (sem misturar alunas)
#   2. O SEU WhatsApp pessoal fala com a Helena (Diretora), pelo mesmo número do Rafa
#   3. Mensagem de teste para o seu WhatsApp
#   4. Rotinas automáticas (com o turno de 24h), com os resumos chegando no seu WhatsApp
#
# Uso:  bash scripts/ligar-time.sh
# Pode rodar de novo: rotinas que já existem são puladas.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTA="${CONTA:-comercial}"   # conta do WhatsApp do Rafa no OpenClaw
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
command -v openclaw >/dev/null 2>&1 || { echo "openclaw não encontrado. Rode antes: bash scripts/instalar-vps.sh" >&2; exit 1; }

echo; echo "== 1/4 Uma conversa por pessoa no WhatsApp =="
openclaw config set session.dmScope per-account-channel-peer
ok "cada aluna tem a própria conversa com o Rafa"

echo; echo "== 2/4 Seu WhatsApp pessoal → Helena =="
NUMERO="${NUMERO:-}"
if [[ -z "$NUMERO" ]]; then
  read -rp "→ Digite o SEU WhatsApp pessoal com DDD (ex.: 62 99999-9999): " NUMERO
fi
dig="$(tr -cd '0-9' <<<"$NUMERO")"
if [[ ! ( "$dig" == 55* && ${#dig} -ge 12 ) ]]; then dig="55$dig"; fi
if [[ ${#dig} -ne 12 && ${#dig} -ne 13 ]]; then echo "Número inválido: $NUMERO" >&2; exit 1; fi
# O WhatsApp às vezes identifica celulares do Brasil sem o 9 da frente: cadastra as duas formas.
if [[ ${#dig} -eq 13 ]]; then COM9="+$dig"; SEM9="+${dig:0:4}${dig:5}"; else SEM9="+$dig"; COM9="+${dig:0:4}9${dig:4}"; fi
echo "Seu número: $COM9"
read -rp "→ Está certo? (s/n) " conf; [[ "$conf" =~ ^[sS] ]] || { echo "Cancelado."; exit 1; }

BINDINGS="[{\"agentId\":\"diretor\",\"match\":{\"channel\":\"whatsapp\",\"accountId\":\"$CONTA\",\"peer\":{\"kind\":\"direct\",\"id\":\"$COM9\"}}},{\"agentId\":\"diretor\",\"match\":{\"channel\":\"whatsapp\",\"accountId\":\"$CONTA\",\"peer\":{\"kind\":\"direct\",\"id\":\"$SEM9\"}}},{\"agentId\":\"vendedor\",\"match\":{\"channel\":\"whatsapp\",\"accountId\":\"$CONTA\"}}]"
openclaw config set bindings "$BINDINGS" --strict-json
openclaw gateway restart
echo "Esperando o WhatsApp reconectar..."; sleep 20
ok "mensagens do seu número vão para a Helena; as dos clientes, para o Rafa"

echo; echo "== 3/4 Mensagem de teste para o seu WhatsApp =="
DESTINO=""
for alvo in "$COM9" "$SEM9"; do
  if openclaw message send --channel whatsapp --account "$CONTA" --target "$alvo" \
       --message "✅ Teste do time Nobel: a Helena vai te mandar os resumos por aqui." >/dev/null 2>&1; then
    read -rp "→ Chegou a mensagem de teste no seu WhatsApp? (s/n) " chegou
    if [[ "$chegou" =~ ^[sS] ]]; then DESTINO="$alvo"; break; fi
  fi
done
if [[ -z "$DESTINO" ]]; then
  aviso "A mensagem de teste não chegou. Os resumos vão ficar só nos relatórios, até resolvermos."
  DESTINO="$COM9"
fi
ok "resumos vão para $DESTINO"

echo; echo "== 4/4 Rotinas automáticas =="
AVISO_CANAL=whatsapp AVISO_PARA="$DESTINO" AVISO_CONTA="$CONTA" bash "$REPO_DIR/scripts/criar-rotinas.sh"

cat <<FIM

✅ Time ligado!
  • Mande "oi" do seu WhatsApp para o número do Rafa: quem responde agora é a Helena.
  • Para testar o Rafa, use OUTRO celular (o seu agora fala com a Helena).
  • A Helena manda resumo às 8h, 12h30 e 19h, e os pedidos de aprovação.
  • Ver as rotinas:   openclaw automations list
FIM
