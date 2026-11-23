#!/usr/bin/env bash
# Liga o alarme do time: notificação no seu celular (app ntfy) quando o WhatsApp do Rafa cair,
# os agentes pararem, os créditos da Anthropic acabarem ou as vendas/anúncios pararem de atualizar.
# Não usa IA nem WhatsApp, então funciona justamente quando eles caem.
#   bash scripts/ligar-alarme.sh
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEG_DIR="$HOME/.config/nobel"
CFG="$SEG_DIR/alarme.env"
say() { printf '%s\n' "$*"; }
erro() { printf '❌ %s\n' "$*" >&2; exit 1; }

mkdir -p "$SEG_DIR"; chmod 700 "$SEG_DIR"
if [[ -f "$CFG" ]]; then
  source "$CFG"
else
  NTFY_TOPICO="nobel-$(python3 -c 'import secrets; print(secrets.token_hex(6))')"
  ( umask 077; printf 'NTFY_TOPICO=%s\n' "$NTFY_TOPICO" > "$CFG" )
fi

say ""
say "== 1/3 No seu celular"
say "   1. Instale o aplicativo  ntfy  (Play Store ou App Store, ícone verde)"
say "   2. Abra, toque no  +  (Assinar tópico / Subscribe to topic)"
say "   3. Digite exatamente este tópico (deixe o servidor padrão ntfy.sh):"
say ""
say "        $NTFY_TOPICO"
say ""
say "   4. Toque em Assinar. Se o celular perguntar, permita as notificações."
say "   (Não divulgue esse nome: quem souber pode ler os alertas.)"
read -r -p "   Quando terminar, aperte Enter aqui... " _ || true

say ""
say "== 2/3 Mandando um teste"
python3 - "$NTFY_TOPICO" <<'PY' | curl -s -m 20 -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -d @- https://ntfy.sh/ > /tmp/ntfy-teste.code || true
import json, sys
print(json.dumps({"topic": sys.argv[1], "priority": 4, "title": "Alarme do time ligado",
                  "message": "Teste: se você está vendo isto, o alarme do Instituto Nobel está funcionando ✅",
                  "tags": ["white_check_mark"]}))
PY
[[ "$(cat /tmp/ntfy-teste.code 2>/dev/null)" == "200" ]] && say "   ✅ Teste enviado: deve chegar uma notificação no celular" \
  || say "   ⚠️  Não consegui enviar o teste (a VPS chegou no ntfy.sh?). Me mande o print."
rm -f /tmp/ntfy-teste.code

say ""
say "== 3/3 Vigia a cada 5 minutos"
command -v crontab >/dev/null 2>&1 || apt-get install -y cron >/dev/null
systemctl enable --now cron >/dev/null 2>&1 || true
LINHA="*/5 * * * * PATH='$PATH' HOME='$HOME' bash $REPO_DIR/scripts/vigia.sh >> $SEG_DIR/vigia.log 2>&1 # nobel-vigia"
( crontab -l 2>/dev/null | grep -v '# nobel-vigia' || true; echo "$LINHA" ) | crontab -
bash "$REPO_DIR/scripts/vigia.sh" || true
say "   Situação agora:"
for f in "$SEG_DIR"/alarme-estado/*; do
  [[ -f "$f" ]] || continue
  read -r st _ < "$f"
  printf '     %-10s %s\n' "$(basename "$f")" "$([[ $st == ok ]] && echo '✅ ok' || echo '🚨 PROBLEMA (alerta enviado)')"
done

say ""
say "✅ ALARME LIGADO"
say "   Você recebe notificação quando algo parar e outra quando voltar ao normal."
