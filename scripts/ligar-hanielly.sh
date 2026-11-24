#!/usr/bin/env bash
# Mensagens do WhatsApp da Hanielly (no número do Rafa) passam a ir para a Bia, não para o Rafa.
# O Rafa continua mandando os cartões de passagem para ela; ela responde e atualiza status com a Bia.
#   cd ~/time-ia && bash scripts/ligar-hanielly.sh
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
CONTA="${CONTA:-comercial}"
say() { printf '%s\n' "$*"; }
erro() { printf '❌ %s\n' "$*" >&2; exit 1; }
command -v openclaw >/dev/null 2>&1 || erro "openclaw não encontrado"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

variantes() {  # imprime "COM9 SEM9" para um número do Brasil
  local dig; dig="$(tr -cd '0-9' <<<"$1")"
  [[ "$dig" == 55* && ${#dig} -ge 12 ]] || dig="55$dig"
  [[ ${#dig} -eq 12 || ${#dig} -eq 13 ]] || return 1
  if [[ ${#dig} -eq 13 ]]; then echo "+$dig +${dig:0:4}${dig:5}"; else echo "+${dig:0:4}9${dig:4} +$dig"; fi
}

say ""
say "== 1/4 Número da Hanielly"
SUGESTAO="$(grep -oE '\+55 ?[0-9]{2} ?9?[0-9]{4}-?[0-9]{4}' "$REPO_DIR/privado/GUIA-DO-RAFA.md" 2>/dev/null | head -n 1 || true)"
NUM="${HANIELLY:-}"
if [[ -z "$NUM" ]]; then
  read -r -p "→ WhatsApp da Hanielly com DDD [${SUGESTAO:-ex.: 62 99999-9999}]: " NUM || true
  NUM="${NUM:-$SUGESTAO}"
fi
read -r H9 HS <<<"$(variantes "$NUM" || true)"
[[ -n "${H9:-}" && -n "${HS:-}" ]] || erro "Número inválido: $NUM"
say "   Hanielly: $H9 (e $HS)"

say ""
say "== 2/4 Direcionando as mensagens dela para a Bia"
ATUAL="$(openclaw config get bindings --json 2>/dev/null || openclaw config get bindings 2>/dev/null || true)"
NOVO="$(H9="$H9" HS="$HS" CONTA="$CONTA" python3 -c '
import json, os, sys
txt = sys.stdin.read().strip()
try:
    atual = json.loads(txt) if txt else []
except Exception:
    sys.exit(2)
if isinstance(atual, dict) and "bindings" in atual:
    atual = atual["bindings"]
if not isinstance(atual, list):
    sys.exit(2)
alvos = {os.environ["H9"], os.environ["HS"]}
resto = [b for b in atual if ((b.get("match") or {}).get("peer") or {}).get("id") not in alvos]
novos = [{"agentId": "recuperacao", "match": {"channel": "whatsapp", "accountId": os.environ["CONTA"],
          "peer": {"kind": "direct", "id": n}}} for n in sorted(alvos)]
geral = [b for b in resto if not (b.get("match") or {}).get("peer")]
especificos = [b for b in resto if (b.get("match") or {}).get("peer")]
print(json.dumps(novos + especificos + geral))
' <<<"$ATUAL")" || erro "Não consegui ler as regras atuais do WhatsApp. Me mande o print de: openclaw config get bindings"
grep -q '"vendedor"' <<<"$NOVO" || erro "A regra do Rafa não apareceu nas regras atuais; nada foi mudado. Me mande o print de: openclaw config get bindings"
openclaw config set bindings "$NOVO" --strict-json >/dev/null
openclaw config validate >/dev/null 2>&1 || true
say "   ✅ Regras: Hanielly → Bia · você → Helena · clientes → Rafa"

say ""
say "== 3/4 Tirando a Hanielly da lista de leads do Rafa"
H9="$H9" HS="$HS" python3 - "$EMPRESA_DIR/vendas/leads.csv" <<'PY'
import csv, os, sys
arq = sys.argv[1]
if not os.path.isfile(arq):
    print("   (sem leads.csv)"); sys.exit(0)
alvos = {"".join(c for c in os.environ[k] if c.isdigit()) for k in ("H9", "HS")}
with open(arq, encoding="utf-8", newline="") as f:
    r = csv.DictReader(f); campos = r.fieldnames; linhas = list(r)
n = 0
for l in linhas:
    tel = "".join(c for c in (l.get("telefone") or "") if c.isdigit())
    if tel and (tel in alvos or ("55" + tel) in alvos):
        l["etapa"] = "perdido"; l["proximo_passo"] = ""; l["data_proximo_passo"] = ""
        l["responsavel"] = "equipe"; l["observacoes"] = "NÃO É LEAD: Hanielly, da equipe comercial"
        n += 1
with open(arq, "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=campos); w.writeheader(); w.writerows(linhas)
print(f"   ✅ {n} linha(s) da Hanielly marcadas como 'não é lead' (o Rafa não faz follow-up)")
PY

say ""
say "== 4/4 Instruções da Bia e do Rafa (reinicia o sistema por alguns segundos)"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"
sleep 20
openclaw channels status 2>&1 | grep -i 'whatsapp comercial' || true

say ""
say "✅ HANIELLY LIGADA À BIA"
say "   Peça para a Hanielly mandar no número do Rafa: \"Oi Bia, me manda minha lista de hoje\""
