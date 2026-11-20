#!/usr/bin/env bash
# Instalação completa numa VPS Ubuntu 24.04 (rodar como root):
#   1. Sistema e firewall
#   2. OpenClaw (motor dos agentes) + configuração inicial (você escolhe a IA e cola a chave)
#   3. Time de 16 agentes + perfil da empresa (se estiver em privado/)
#   4. Escritório 3D (Claw3D) rodando como serviço, só acessível pelo Tailscale (sem senha extra)
#   5. Tailscale: endereço privado para abrir o escritório no celular/computador
#
# Uso (dentro da pasta do repositório):  sudo bash scripts/instalar-vps.sh
# Pode rodar de novo: cada etapa pula o que já estiver pronto.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAW3D_DIR="${CLAW3D_DIR:-/opt/claw3d}"
CLAW3D_PORTA="${CLAW3D_PORTA:-3000}"
OPENCLAW_HOME="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

titulo() { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }
ok()     { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
aviso()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
pausa()  { read -rp "→ $* (Enter para continuar) " _; }

if [[ "$(id -u)" != "0" ]]; then
  echo "Rode como root: sudo bash scripts/instalar-vps.sh" >&2; exit 1
fi

# Sem sessão gráfica, o systemd do usuário precisa disto para o serviço do OpenClaw
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

titulo "1/5 Sistema e firewall"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl ufw ca-certificates openssl dbus-user-session
# Só SSH aberto para a internet. O painel do OpenClaw e o escritório 3D ficam fechados
# e são acessados pelo Tailscale (rede privada).
ufw allow OpenSSH >/dev/null
ufw --force enable >/dev/null
ok "firewall ativo (só SSH aberto)"

titulo "2/5 OpenClaw"
if ! command -v openclaw >/dev/null 2>&1; then
  curl -fsSL https://openclaw.ai/install.sh | bash
fi
# O instalador pode colocar o openclaw/node numa pasta que só entra no PATH num terminal novo
for d in "$HOME/.local/bin" "$HOME/.npm-global/bin" "$HOME/.openclaw/bin" /usr/local/bin; do
  [[ -d "$d" && ":$PATH:" != *":$d:"* ]] && PATH="$d:$PATH"
done
export PATH; hash -r
command -v openclaw >/dev/null 2>&1 || { aviso "openclaw não apareceu no PATH. Feche e abra o terminal e rode este script de novo."; exit 1; }
ok "OpenClaw instalado: $(openclaw --version 2>/dev/null || echo 'versão desconhecida')"

gateway_ok() { # o gateway responde na porta 18789?
  local c; c="$(curl -s -o /dev/null -m 3 -w '%{http_code}' http://127.0.0.1:18789/ 2>/dev/null || true)"
  [[ -n "$c" && "$c" != "000" ]]
}
garantir_servico() { # deixa o gateway como serviço que liga sozinho (systemd do usuário + linger)
  loginctl enable-linger "$(id -un)" >/dev/null 2>&1 || true
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -d "$XDG_RUNTIME_DIR" ]] && break; sleep 1; done
  systemctl --user start dbus.socket >/dev/null 2>&1 || true
  openclaw gateway install || openclaw gateway install --force || true
  openclaw gateway start >/dev/null 2>&1 || true
  for _ in $(seq 1 30); do gateway_ok && return 0; sleep 2; done
  return 1
}

# Configuração inicial (IA + chave) só se ainda não foi feita.
# O instalador oficial do OpenClaw às vezes já abre essa configuração sozinho.
if [[ ! -f "$OPENCLAW_HOME/openclaw.json" ]]; then
  cat <<'EOF'

Agora vem a configuração inicial do OpenClaw (é interativa):
  • Escolha "Quick start", depois "One agent".
  • Provedor de IA: Anthropic → API key → cole a sua chave (workspace ID: deixe em branco).
  • Memory embeddings: No.   • Rodar em segundo plano (background): Yes.
EOF
  pausa "Pronto para começar"
  openclaw onboard --install-daemon || true
fi

if gateway_ok; then
  ok "gateway do OpenClaw rodando"
else
  echo "Ligando o gateway do OpenClaw como serviço (para os agentes trabalharem 24h)..."
  if garantir_servico; then ok "gateway rodando como serviço"; else aviso "o gateway não respondeu. Rode depois: openclaw doctor --fix"; fi
fi
openclaw gateway status || true

titulo "3/5 Time de 16 agentes + perfil da empresa"
bash "$REPO_DIR/scripts/instalar-time.sh"
EMPRESA_DIR="$OPENCLAW_HOME/empresa"
# Perfil, FAQ, plano e roteiro vão criptografados no repositório (privado.tar.gz.enc).
if [[ ! -d "$REPO_DIR/privado" && -f "$REPO_DIR/privado.tar.gz.enc" ]]; then
  for tentativa in 1 2 3; do
    read -rsp "→ Cole a senha dos arquivos da empresa (o Claude te passou no chat): " SENHA_PRIVADO; echo
    if openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass "pass:$SENHA_PRIVADO" \
         -in "$REPO_DIR/privado.tar.gz.enc" 2>/dev/null | tar xz -C "$REPO_DIR" 2>/dev/null; then
      chmod -R go-rwx "$REPO_DIR/privado"; ok "arquivos da empresa liberados"; break
    fi
    aviso "senha incorreta, tente de novo"
  done
  unset SENHA_PRIVADO
fi
if [[ -f "$REPO_DIR/privado/PERFIL-DA-EMPRESA.md" ]]; then
  cp "$REPO_DIR/privado/PERFIL-DA-EMPRESA.md" "$EMPRESA_DIR/PERFIL-DA-EMPRESA.md"
  [[ -f "$REPO_DIR/privado/atendimento/faq.md" ]] && cp "$REPO_DIR/privado/atendimento/faq.md" "$EMPRESA_DIR/atendimento/faq.md"
  [[ -f "$REPO_DIR/privado/GUIA-DO-RAFA.md" ]] && mkdir -p "$EMPRESA_DIR/vendas" && cp "$REPO_DIR/privado/GUIA-DO-RAFA.md" "$EMPRESA_DIR/vendas/GUIA-DO-RAFA.md"
  for f in PLANO-30-DIAS-ASB.md ROTEIRO-WHATSAPP-E-ANUNCIOS-ASB.md; do
    [[ -f "$REPO_DIR/privado/$f" ]] && cp "$REPO_DIR/privado/$f" "$EMPRESA_DIR/relatorios/$f"
  done
  ok "perfil da empresa, FAQ, plano e roteiro copiados para $EMPRESA_DIR"
else
  aviso "privado/PERFIL-DA-EMPRESA.md não está no repositório: o perfil ficou em branco."
  aviso "Preencha com: nano $EMPRESA_DIR/PERFIL-DA-EMPRESA.md"
fi

titulo "4/5 Escritório 3D (Claw3D)"
if [[ ! -d "$CLAW3D_DIR/.git" ]]; then
  git clone https://github.com/iamlukethedev/Claw3D.git "$CLAW3D_DIR"
fi
cd "$CLAW3D_DIR"
NPM_BIN="$(command -v npm)"
[[ -n "$NPM_BIN" ]] || { aviso "npm não encontrado (o Node vem com o OpenClaw). Instale o Node.js 20+ e rode de novo."; exit 1; }
"$NPM_BIN" install
[[ -f .env ]] || cp .env.example .env
# Compatibilidade Claw3D x OpenClaw 2026.11+: o gateway recusa a "Control UI" sem buildId
# ("protocol mismatch: Control UI updated"). O proxy do Claw3D passa a se identificar como "dev",
# que o gateway aceita. Não mexe na assinatura do dispositivo (buildId não entra nela).
if ! grep -q 'buildId = "dev"' server/gateway-proxy.js 2>/dev/null; then
  sed -i '/const clientId = typeof client.id === "string"/a\      if (upstreamAdapterType === "openclaw" \&\& clientId === "openclaw-control-ui" \&\& !client.buildId) { client.buildId = "dev"; connectParams.client = client; }' server/gateway-proxy.js || true
fi

# O comando só mostra o token num terminal "de verdade": o `script` simula um.
TOKEN_GATEWAY="$(script -qc 'openclaw gateway auth-token --show' /dev/null 2>/dev/null | grep -oE '[A-Za-z0-9_-]{32,}' | tail -n 1 || true)"
if [[ -z "$TOKEN_GATEWAY" ]]; then
  aviso "Não consegui ler o token do gateway automaticamente."
  read -rsp "→ Cole aqui o token (rode 'openclaw gateway auth-token --show' em outro terminal): " TOKEN_GATEWAY; echo
fi

grava_env() { # grava_env CHAVE VALOR
  if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else printf '%s=%s\n' "$1" "$2" >> .env; fi
}
grava_env HOST 127.0.0.1
grava_env PORT "$CLAW3D_PORTA"
grava_env CLAW3D_GATEWAY_URL ws://127.0.0.1:18789   # 127.0.0.1 e não "localhost" (o Node pode tentar IPv6 e falhar)
grava_env CLAW3D_GATEWAY_TOKEN "$TOKEN_GATEWAY"
grava_env CLAW3D_GATEWAY_ADAPTER_TYPE openclaw
# Em produção o Claw3D só conecta em hosts desta lista (vazia = recusa tudo)
grava_env UPSTREAM_ALLOWLIST 127.0.0.1,localhost
# Sem senha extra: o escritório só escuta em 127.0.0.1 e só é aberto pelo Tailscale (rede privada sua).
grava_env STUDIO_ACCESS_TOKEN ""
chmod 600 .env

"$NPM_BIN" run build

cat > /etc/systemd/system/claw3d.service <<EOF
[Unit]
Description=Claw3D - escritorio 3D dos agentes
After=network-online.target

[Service]
WorkingDirectory=$CLAW3D_DIR
EnvironmentFile=$CLAW3D_DIR/.env
Environment=PATH=$(dirname "$NPM_BIN"):/usr/local/bin:/usr/bin:/bin
ExecStart=$NPM_BIN run start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now claw3d
sleep 3
systemctl is-active --quiet claw3d && ok "escritório 3D rodando em 127.0.0.1:$CLAW3D_PORTA" || aviso "o serviço claw3d não subiu: veja 'journalctl -u claw3d -n 50'"

titulo "5/5 Tailscale (acesso privado pelo celular e computador)"
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
if ! tailscale status >/dev/null 2>&1; then
  echo "Vai aparecer um link: abra no navegador e entre com a sua conta Tailscale (gratuita)."
  tailscale up
fi
tailscale serve --yes --bg --https 443 "http://127.0.0.1:$CLAW3D_PORTA"
ENDERECO="$(tailscale status --json 2>/dev/null | grep -o '"DNSName": *"[^"]*"' | head -n1 | cut -d'"' -f4 | sed 's/\.$//')"

cat <<EOF

✅ Pronto!

Escritório 3D:  https://${ENDERECO:-<nome-da-vps>.ts.net}
  • No celular/computador, instale o app Tailscale e entre com a MESMA conta.
  • Se o escritório pedir aprovação: rode  openclaw devices list  e depois  openclaw devices approve <ID do pedido>

Painel do OpenClaw (opcional): rode 'tailscale serve --yes --bg --https 8443 http://127.0.0.1:18789'
  e abra https://${ENDERECO:-<nome-da-vps>.ts.net}:8443

Próximos passos (guia: docs/02-instalacao.md):
  1. Conectar o WhatsApp (passo 6)
  2. Ligar as rotinas: AVISO_CANAL=whatsapp AVISO_PARA=+55DDDNUMERO bash $REPO_DIR/scripts/criar-rotinas.sh
EOF
