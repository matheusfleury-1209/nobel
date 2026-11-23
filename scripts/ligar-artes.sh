#!/usr/bin/env bash
# Instala a fábrica de artes na VPS (Playwright + Chromium) e gera uma arte de teste.
#   cd ~/time-ia && bash scripts/ligar-artes.sh
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
say() { printf '%s\n' "$*"; }
erro() { printf '❌ %s\n' "$*" >&2; exit 1; }
command -v node >/dev/null 2>&1 || erro "node não encontrado"
command -v npm >/dev/null 2>&1 || erro "npm não encontrado"

say ""
say "== 1/3 Instalando o gerador (pode levar 2 a 4 minutos)"
cd "$REPO_DIR"
npm install --no-save --no-package-lock --no-audit --no-fund playwright@1.63.0 >/dev/null
npx --yes playwright@1.63.0 install --with-deps chromium >/dev/null
say "   ✅ Playwright e Chromium instalados"

say ""
say "== 2/3 Gerando uma arte de teste"
DEST="$EMPRESA_DIR/marketing/criativos/artes/teste"
mkdir -p "$DEST"
python3 - "$REPO_DIR/artes/exemplos/asb-black-oferta.json" "$DEST/asb-black-oferta.json" "$DEST/asb-black-oferta" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); d["saida"] = sys.argv[3]
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
node "$REPO_DIR/artes/gerar.mjs" "$DEST/asb-black-oferta.json" || erro "A arte de teste não foi gerada (veja a mensagem acima)"

say ""
say "== 3/3 Ensinando a Duda"
bash "$REPO_DIR/scripts/atualizar-instrucoes.sh"

say ""
say "✅ FÁBRICA DE ARTES LIGADA"
say "   Teste: $DEST/asb-black-oferta-feed.png"
say "   Peça para a Helena: \"pede pra Duda uma arte de ASB no modelo pergunta para quem quer mudar de profissão\""
