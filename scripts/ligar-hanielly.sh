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
bash "$REPO_DIR/scripts/backup-empresa.sh" || true
H9="$H9" HS="$HS" python3 - "$EMPRESA_DIR/vendas/leads.csv" <<'PY'
import csv, io, os, shutil, sys, time
arq = sys.argv[1]
if not os.path.isfile(arq):
    print("   (sem leads.csv)"); sys.exit(0)
alvos = {"".join(c for c in os.environ[k] if c.isdigit()) for k in ("H9", "HS")}
with open(arq, encoding="utf-8", newline="") as f:
    linhas = f.read().splitlines(keepends=True)
cab = next(csv.reader([linhas[0]]))
idx = {c: i for i, c in enumerate(cab)}
n = 0
for k in range(1, len(linhas)):
    try:
        campos = next(csv.reader([linhas[k]]))
    except StopIteration:
        continue
    if "telefone" not in idx or len(campos) <= idx["telefone"]:
        continue
    tel = "".join(c for c in campos[idx["telefone"]] if c.isdigit())
    if not tel or not (tel in alvos or ("55" + tel) in alvos):
        continue
    for campo, valor in (("etapa", "perdido"), ("proximo_passo", ""), ("data_proximo_passo", ""),
                         ("responsavel", "equipe"), ("observacoes", "NÃO É LEAD: Hanielly, da equipe comercial")):
        if campo in idx and idx[campo] < len(campos):
            campos[idx[campo]] = valor
    buf = io.StringIO(); csv.writer(buf, lineterminator="\n").writerow(campos)
    linhas[k] = buf.getvalue()  # só esta linha muda; as outras ficam exatamente como estavam
    n += 1
if n:
    shutil.copy2(arq, f"{arq}.bak-{time.strftime('%Y%m%d-%H%M%S')}")
    tmp = arq + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        f.writelines(linhas)
    os.replace(tmp, arq)
print(f"   ✅ {n} linha(s) da Hanielly marcadas como 'não é lead' (o Rafa não faz follow-up)")
PY

say ""
say "== 4/4 Instruções da Bia e do Rafa (reinicia o sistema por alguns segundos)"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"
sleep 20
openclaw channels status 2>&1 | grep -i 'whatsapp comercial' || true

say ""
say "== Cópia de segurança diária das planilhas (3h15, guarda 14 dias em ~/backups)"
LINHA="15 3 * * * bash $REPO_DIR/scripts/backup-empresa.sh # nobel-backup"
( crontab -l 2>/dev/null | grep -v '# nobel-backup' || true; echo "$LINHA" ) | crontab -
bash "$REPO_DIR/scripts/backup-empresa.sh" && say "   ✅ Primeira cópia feita em ~/backups"

say ""
say "✅ HANIELLY LIGADA À BIA"
say "   Peça para a Hanielly mandar no número do Rafa: \"Oi Bia, me manda minha lista de hoje\""
