#!/usr/bin/env bash
# Instalação completa numa VPS Ubuntu 24.04 (rodar como root):
#   1. Sistema e firewall
#   2. OpenClaw (motor dos agentes) + configuração inicial (você escolhe a IA e cola a chave)
#   3. Time de 13 agentes + perfil da empresa (se estiver em privado/)
#   4. Escritório 3D (Claw3D) rodando como serviço, só acessível pelo Tailscale
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

titulo "1/5 Sistema e firewall"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl ufw ca-certificates openssl
# Só SSH aberto para a internet. O painel do OpenClaw e o escritório 3D ficam fechados
# e são acessados pelo Tailscale (rede privada).
ufw allow OpenSSH >/dev/null
ufw --force enable >/dev/null
ok "firewall ativo (só SSH aberto)"

titulo "2/5 OpenClaw"
if ! command -v openclaw >/dev/null 2>&1; then
  curl -fsSL https://openclaw.ai/install.sh | bash
  hash -r
fi
command -v openclaw >/dev/null 2>&1 || { aviso "openclaw não apareceu no PATH. Feche e abra o terminal e rode este script de novo."; exit 1; }
ok "OpenClaw instalado: $(openclaw --version 2>/dev/null || echo 'versão desconhecida')"

if ! openclaw gateway status >/dev/null 2>&1; then
  cat <<'EOF'

Agora vem a configuração inicial do OpenClaw (é interativa):
  • Provedor de IA: escolha Anthropic (Claude) e cole a sua chave de API
    (crie em console.anthropic.com e defina um LIMITE DE GASTO MENSAL lá).
  • Canais: pode PULAR por enquanto (WhatsApp entra depois).
  • Daemon/serviço: ACEITE (assim liga sozinho quando o servidor reinicia).
EOF
  pausa "Pronto para começar"
  openclaw onboard --install-daemon
fi
openclaw gateway status || true

titulo "3/5 Time de 13 agentes + perfil da empresa"
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

TOKEN_GATEWAY="$(openclaw gateway auth-token --show 2>/dev/null | tail -n 1 | tr -d '[:space:]' || true)"
if [[ -z "$TOKEN_GATEWAY" ]]; then
  aviso "Não consegui ler o token do gateway automaticamente."
  read -rsp "→ Cole aqui o token (rode 'openclaw gateway auth-token --show' em outro terminal): " TOKEN_GATEWAY; echo
fi
TOKEN_ESCRITORIO="$(grep -E '^STUDIO_ACCESS_TOKEN=' .env | cut -d= -f2- || true)"
[[ -n "$TOKEN_ESCRITORIO" ]] || TOKEN_ESCRITORIO="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"

grava_env() { # grava_env CHAVE VALOR
  if grep -qE "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else printf '%s=%s\n' "$1" "$2" >> .env; fi
}
grava_env HOST 127.0.0.1
grava_env PORT "$CLAW3D_PORTA"
grava_env CLAW3D_GATEWAY_URL ws://localhost:18789
grava_env CLAW3D_GATEWAY_TOKEN "$TOKEN_GATEWAY"
grava_env CLAW3D_GATEWAY_ADAPTER_TYPE openclaw
grava_env STUDIO_ACCESS_TOKEN "$TOKEN_ESCRITORIO"
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
  • Senha de acesso do escritório (STUDIO_ACCESS_TOKEN): $TOKEN_ESCRITORIO
  • Se o escritório pedir aprovação do dispositivo, rode aqui:  openclaw devices approve --latest

Painel do OpenClaw (opcional): rode 'tailscale serve --yes --bg --https 8443 http://127.0.0.1:18789'
  e abra https://${ENDERECO:-<nome-da-vps>.ts.net}:8443

Próximos passos (guia: docs/02-instalacao.md):
  1. Conectar o WhatsApp (passo 6)
  2. Ligar as rotinas: AVISO_CANAL=whatsapp AVISO_PARA=+55DDDNUMERO bash $REPO_DIR/scripts/criar-rotinas.sh
EOF
