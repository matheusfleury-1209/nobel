#!/usr/bin/env bash
# Instala o time de 16 agentes no OpenClaw.
#
# O que faz:
#   1. Copia a pasta empresa/ (planilhas e PERFIL) para ~/.openclaw/empresa (nunca sobrescreve dados existentes)
#   2. Cria os agentes no OpenClaw (openclaw agents add) com o modelo de cada um
#   3. Copia a personalidade, o cargo, a identidade e as skills de cada agente para o workspace dele
#   4. Liga a pasta compartilhada empresa/ dentro de cada workspace
#   5. Configura delegação (Diretora → time), conversa entre agentes e restrições de quem fala com clientes
#
# Pode rodar de novo para atualizar: arquivos alterados viram backup *.bak-<data> antes de serem trocados.
#
# Uso:
#   ./scripts/instalar-time.sh
#   MODELO_FORTE=anthropic/claude-sonnet-5-5 MODELO_RAPIDO=anthropic/claude-haiku-5-5 ./scripts/instalar-time.sh
#   SO_ARQUIVOS=1 ./scripts/instalar-time.sh     # só copia arquivos (não mexe na config do OpenClaw)
#   DRY_RUN=1 ./scripts/instalar-time.sh         # mostra o que faria, sem alterar nada
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCLAW_HOME="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
EMPRESA_DIR="${EMPRESA_DIR:-$OPENCLAW_HOME/empresa}"
MODELO_FORTE="${MODELO_FORTE:-anthropic/claude-sonnet-5-5}"
MODELO_RAPIDO="${MODELO_RAPIDO:-anthropic/claude-haiku-5-5}"
DRY_RUN="${DRY_RUN:-0}"
SO_ARQUIVOS="${SO_ARQUIVOS:-0}"
CARIMBO="$(date +%Y%m%d-%H%M%S)"

AGENTES=(diretor financeiro trafego social criativos vendedor atendimento prospector administrativo inteligencia revisor otimizador programador recuperacao sucesso parcerias)
FORTES=" diretor financeiro trafego vendedor revisor otimizador programador recuperacao "          # o resto usa MODELO_RAPIDO
FALAM_COM_CLIENTES=(vendedor atendimento)                # recebem ferramentas restritas

say()  { printf '%s\n' "$*"; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf '[dry-run]'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }
modelo_de() { [[ "$FORTES" == *" $1 "* ]] && echo "$MODELO_FORTE" || echo "$MODELO_RAPIDO"; }

# Instala um arquivo; se já existir com conteúdo diferente, guarda backup.
instalar_arquivo() {
  local origem="$1" destino="$2"
  if [[ -f "$destino" ]] && ! cmp -s "$origem" "$destino"; then
    run cp "$destino" "$destino.bak-$CARIMBO"
  fi
  run cp "$origem" "$destino"
}

USA_OPENCLAW=1
if [[ "$SO_ARQUIVOS" == "1" ]]; then
  USA_OPENCLAW=0
elif ! command -v openclaw >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == "1" ]]; then
    say "ℹ️  'openclaw' não encontrado — no dry-run os comandos dele só serão mostrados."
  else
    say "⚠️  'openclaw' não encontrado. Vou só copiar os arquivos. Instale o OpenClaw (docs/02-instalacao.md) e rode de novo."
    USA_OPENCLAW=0
  fi
fi

say "== 1/5 Pasta compartilhada: $EMPRESA_DIR"
run mkdir -p "$EMPRESA_DIR"
# -n = no-clobber: nunca sobrescreve planilhas/perfil que você já preencheu
run cp -Rn "$REPO_DIR/empresa/." "$EMPRESA_DIR/"

AGENTES_EXISTENTES=""
if [[ "$USA_OPENCLAW" == "1" && "$DRY_RUN" != "1" ]]; then
  AGENTES_EXISTENTES="$(openclaw agents list --json 2>/dev/null || openclaw agents list 2>/dev/null || true)"
fi

say "== 2-4/5 Criando agentes, copiando arquivos e ligando a pasta empresa/"
for id in "${AGENTES[@]}"; do
  ws="$OPENCLAW_HOME/workspace-$id"
  src="$REPO_DIR/time/$id"
  modelo="$(modelo_de "$id")"

  if [[ "$USA_OPENCLAW" == "1" ]]; then
    if grep -qE "(^|[^a-z])$id([^a-z]|$)" <<<"$AGENTES_EXISTENTES"; then
      say "  ↷ $id já existe no OpenClaw"
    else
      say "  + criando $id ($modelo)"
      if ! run openclaw agents add "$id" --workspace "$ws" --model "$modelo" --non-interactive; then
        say "  ⚠️  não aceitou o modelo '$modelo'; criando $id com o modelo padrão"
        run openclaw agents add "$id" --workspace "$ws" --non-interactive
      fi
    fi
  fi

  run mkdir -p "$ws/skills" "$ws/memory"

  # AGENTS.md = cargo do agente + regras gerais da empresa
  tmp="$(mktemp)"
  cat "$src/AGENTS.md" "$REPO_DIR/time/_comum/REGRAS-GERAIS.md" > "$tmp"
  chmod 644 "$tmp"
  instalar_arquivo "$tmp" "$ws/AGENTS.md"
  rm -f "$tmp"

  instalar_arquivo "$src/SOUL.md"     "$ws/SOUL.md"
  instalar_arquivo "$src/IDENTITY.md" "$ws/IDENTITY.md"

  # USER.md aponta para a seção "Sobre o dono" do PERFIL (você preenche um arquivo só)
  instalar_arquivo "$REPO_DIR/time/_comum/USER.md" "$ws/USER.md"

  # Skills do cargo
  for skill_dir in "$src"/skills/*/; do
    nome="$(basename "$skill_dir")"
    run mkdir -p "$ws/skills/$nome"
    instalar_arquivo "$skill_dir/SKILL.md" "$ws/skills/$nome/SKILL.md"
  done

  # A identidade já vem pronta, então o ritual de primeiro uso não é necessário
  if [[ -f "$ws/BOOTSTRAP.md" ]]; then
    run mv "$ws/BOOTSTRAP.md" "$ws/BOOTSTRAP.md.bak-$CARIMBO"
  fi

  say "  ↳ $id: pasta empresa/ ligada no workspace"
  if [[ -e "$ws/empresa" && ! -L "$ws/empresa" ]]; then
    say "  ⚠️  $ws/empresa existe e não é atalho; deixei como está"
  else
    run ln -sfn "$EMPRESA_DIR" "$ws/empresa"
  fi

  if [[ "$USA_OPENCLAW" == "1" ]]; then
    run openclaw agents set-identity --workspace "$ws" --from-identity || say "  ⚠️  não consegui aplicar a identidade de $id (faça pelo painel)"
  fi
done

if [[ "$USA_OPENCLAW" == "1" ]]; then
  say "== 5/5 Configurando delegação e permissões"
  EQUIPE='["financeiro","trafego","social","criativos","vendedor","atendimento","prospector","administrativo","inteligencia","revisor","otimizador","programador","recuperacao","sucesso","parcerias"]'
  TODOS='["diretor","financeiro","trafego","social","criativos","vendedor","atendimento","prospector","administrativo","inteligencia","revisor","otimizador","programador","recuperacao","sucesso","parcerias"]'
  falhou=0

  run openclaw config set agents.defaults.systemAgent.agentId diretor || falhou=1
  run openclaw config set agents.entries.diretor.subagents \
      "{\"allowAgents\":$EQUIPE,\"delegationMode\":\"prefer\"}" --strict-json || falhou=1
  run openclaw config set tools.agentToAgent.allow "$TODOS" --strict-json || falhou=1
  for id in "${FALAM_COM_CLIENTES[@]}"; do
    run openclaw config set "agents.entries.$id.tools" \
      '{"deny":["exec","apply_patch","browser","canvas","nodes","cron"]}' --strict-json || falhou=1
  done

  run openclaw config validate || falhou=1
  if [[ "$falhou" == "1" ]]; then
    say ""
    say "⚠️  Alguma configuração não foi aceita pela sua versão do OpenClaw."
    say "    Abra ~/.openclaw/openclaw.json e confira com o modelo em openclaw/time.json5."
    say "    Depois rode: openclaw doctor --fix && openclaw gateway restart"
  else
    run openclaw gateway restart || say "⚠️  Reinicie o gateway manualmente: openclaw gateway restart"
  fi
fi

cat <<EOF

✅ Time instalado.

Próximos passos:
  1. Preencha  $EMPRESA_DIR/PERFIL-DA-EMPRESA.md   (e $EMPRESA_DIR/atendimento/faq.md)
  2. Confira:  openclaw agents list --bindings
  3. Teste:    abra http://127.0.0.1:18789/ e converse com a Diretora
  4. Rotinas:  ./scripts/criar-rotinas.sh
  5. Canais (Telegram/WhatsApp): docs/02-instalacao.md, passo 6
  6. Escritório 3D (Claw3D):     docs/02-instalacao.md, passo 8
EOF
