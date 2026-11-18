# 2. Instalação passo a passo

Tempo estimado: 1 a 2 horas na primeira vez. Não precisa saber programar, mas vai usar o terminal (copiar e colar comandos).

> Os comandos abaixo foram conferidos na documentação oficial do OpenClaw e no README do Claw3D (nov/2026). Os dois projetos mudam rápido: se algum comando der erro, confira em https://github.com/openclaw/openclaw e https://github.com/iamlukethedev/Claw3D.

## Atalho: instalação completa na VPS com um script
Numa VPS **Ubuntu 24.04** nova, logado como root (pelo terminal do painel da VPS ou por SSH):

```bash
apt-get update && apt-get install -y git
git clone -b claude/ai-team-business-management-1yfh0h https://github.com/matheusfleury-1209/nobel.git time-ia
cd time-ia && bash scripts/instalar-vps.sh
```

O `scripts/instalar-vps.sh` faz tudo em sequência e para nos pontos em que você precisa agir:
1. Atualiza o sistema e liga o firewall (só o SSH fica aberto).
2. Instala o OpenClaw e abre a configuração inicial. Ali você escolhe a IA e cola a chave.
3. Instala os 16 agentes e libera o perfil da empresa, que está no arquivo criptografado `privado.tar.gz.enc` (pede a senha).
4. Instala o escritório 3D (Claw3D) como serviço.
5. Liga o Tailscale. No final, ele mostra o endereço do escritório e a senha de acesso.

Os passos abaixo explicam a mesma coisa, só que feita à mão.

## 1. Onde rodar

**Recomendado: uma VPS Linux (Ubuntu 24.04)** com 2 vCPU e 4 GB de RAM, de qualquer provedor (Hostinger, Contabo, DigitalOcean, Hetzner, Oracle Cloud…). Ela fica ligada 24h, então os agentes trabalham mesmo com seu PC desligado.

Também funciona no seu computador (macOS, Linux ou Windows com WSL2), mas os agentes só trabalham enquanto ele estiver ligado.

Conecte-se à VPS:
```bash
ssh root@IP_DA_SUA_VPS
```

## 2. Instalar o OpenClaw

Precisa de **Node.js 24** ou mais novo. O instalador oficial já cuida disso:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

Alternativa via npm (se já tiver Node 24+):
```bash
npm install -g openclaw@latest
```

No Windows (PowerShell): `iwr -useb https://openclaw.ai/install.ps1 | iex`

## 3. Configuração inicial (onboarding)

```bash
openclaw onboard --install-daemon
```

O assistente vai perguntar:
- **Provedor de IA**: escolha Anthropic (Claude) ou outro de sua preferência e faça login / cole a chave de API.
- **Canais**: pode pular por enquanto (fazemos no passo 6).
- **Daemon**: aceite. Assim o OpenClaw liga sozinho quando o servidor reinicia.

Confira se está rodando:
```bash
openclaw gateway status
```

O painel **OpenClaw Control** (a primeira aba do vídeo) fica em `http://127.0.0.1:18789/`.
Para entrar, ele pede o token do gateway:
```bash
openclaw gateway auth-token --show
```
(Se não houver token: `openclaw doctor --generate-gateway-token`, depois `openclaw gateway restart`.)

> Está numa VPS? Não abra a porta 18789 para a internet. No seu computador, rode
> `ssh -L 18789:127.0.0.1:18789 root@IP_DA_SUA_VPS` e acesse `http://127.0.0.1:18789/` normalmente.

## 4. Baixar este kit e instalar o time

```bash
git clone https://github.com/matheusfleury-1209/nobel.git time-ia
cd time-ia
./scripts/instalar-time.sh
```

O script:
1. copia `empresa/` (planilhas + PERFIL) para `~/.openclaw/empresa`;
2. cria os 16 agentes (`openclaw agents add`), cada um com seu modelo;
3. instala personalidade, cargo, identidade e skills no workspace de cada um;
4. liga a pasta `empresa/` dentro de cada workspace;
5. configura a Diretora como coordenadora, libera a conversa entre os agentes e restringe as ferramentas de quem fala com clientes.

Opções úteis:
```bash
DRY_RUN=1 ./scripts/instalar-time.sh            # só mostra o que faria
MODELO_FORTE=anthropic/claude-opus-5-5 ./scripts/instalar-time.sh   # Diretora/Financeiro/Tráfego/Vendas mais fortes
MODELO_RAPIDO=anthropic/claude-sonnet-5-5 ./scripts/instalar-time.sh
```
Usa outro provedor? Troque os modelos pelo formato `provedor/modelo` que aparece em `openclaw models list` (se disponível na sua versão) ou no onboarding.

Confira:
```bash
openclaw agents list --bindings
```

Se algo não foi aceito pela sua versão do OpenClaw, o script avisa. Compare com [`openclaw/time.json5`](../openclaw/time.json5) e rode `openclaw doctor --fix`.

## 5. Preencher o perfil da empresa (o passo mais importante)

```bash
nano ~/.openclaw/empresa/PERFIL-DA-EMPRESA.md
nano ~/.openclaw/empresa/atendimento/faq.md
```
Produtos, preços, limites de desconto, público, tom de voz, metas, saldo inicial do caixa e regras de autonomia.
Sem isso os agentes trabalham "no escuro".

Teste no painel (`http://127.0.0.1:18789/`): escolha a **Diretora** e mande *"Se apresente e me diga quem está no time"*.

## 6. Conectar WhatsApp e Telegram

### Telegram (você ↔ Diretora)
1. No Telegram, fale com **@BotFather** → `/newbot` → copie o token.
2. Conecte:
   ```bash
   openclaw channels add --channel telegram --token <TOKEN_DO_BOT>
   ```
3. Mande qualquer mensagem para o seu bot. Ele responde com um código de pareamento e o seu **id numérico**.
4. Aprove:
   ```bash
   openclaw pairing list telegram
   openclaw pairing approve telegram <CÓDIGO>
   ```
5. Ligue o Telegram à Diretora:
   ```bash
   openclaw agents bind --agent diretor --bind telegram
   ```

### WhatsApp (clientes ↔ Vendedor / Atendimento)
Use um número **da empresa** (de preferência um chip só para isso), não o seu pessoal.
```bash
openclaw channels login --channel whatsapp --account comercial   # mostra um QR code
```
No celular: WhatsApp → Aparelhos conectados → Conectar aparelho → leia o QR.

```bash
openclaw agents bind --agent vendedor --bind whatsapp:comercial
```
Para um segundo número de suporte: repita com `--account suporte` e `--agent atendimento`.

### Prefere falar com a Diretora pelo WhatsApp (sem Telegram)?
Dá para usar o **mesmo número do vendedor**. As mensagens que vêm do **seu número pessoal** vão para a Diretora, e as dos clientes vão para o Vendedor. Não precisa de chip extra.

1. Em `~/.openclaw/openclaw.json`, dentro de `bindings`, coloque esta regra **acima** da regra do vendedor (troque pelo seu número com +55 e DDD):
   ```json5
   { agentId: "diretor", match: { channel: "whatsapp", accountId: "comercial", peer: { kind: "direct", id: "+5562999999999" } } },
   ```
2. Em `channels.whatsapp.accounts.comercial.allowFrom`, inclua o seu número (ou `"*"`, se a conta já for aberta para clientes).
3. `openclaw gateway restart` e mande um "oi" do seu celular para o número da empresa. Quem deve responder é a Diretora.

A regra por pessoa sempre vence a regra da conta. Mesmo assim, teste antes de divulgar o número.

Para clientes desconhecidos poderem chamar o Vendedor, a conta precisa aceitar mensagens de qualquer pessoa (ver bloco `channels.whatsapp` em [`openclaw/time.json5`](../openclaw/time.json5)). Outra opção é deixar no modo pareamento e aprovar cada contato (`openclaw pairing approve whatsapp <CÓDIGO>`).

> **Antes de ligar para clientes reais:** converse com o Vendedor fingindo ser cliente por alguns dias, ajuste o PERFIL e o FAQ, e só então divulgue o número.

Reinicie e confira:
```bash
openclaw gateway restart
openclaw agents list --bindings
openclaw channels status --probe
```

## 7. Ligar as rotinas automáticas

```bash
AVISO_CANAL=telegram AVISO_PARA=<SEU_ID_NUMÉRICO_DO_TELEGRAM> ./scripts/criar-rotinas.sh
openclaw automations list
```
Diretora no WhatsApp? Use `AVISO_CANAL=whatsapp AVISO_PARA=+5562999999999` (o seu número). Confira com `openclaw automations list` e rode uma rotina na mão para testar a entrega (`openclaw automations run <id>`).

Isso cria o briefing das 8h, o caixa diário, os relatórios de anúncios, o calendário de posts, os follow-ups etc. (lista completa no [README](../README.md#rotinas-automáticas)).
Os resumos da Diretora chegam no seu Telegram.

Dica de custo: comece só com algumas rotinas. Para remover uma: `openclaw automations remove <id>`.

## 8. O escritório 3D (Claw3D)

O Claw3D é um projeto da comunidade (não oficial), gratuito e de código aberto. Ele precisa de Node.js 20+.

**No seu computador** (não precisa ser na VPS):
```bash
git clone https://github.com/iamlukethedev/Claw3D.git claw3d
cd claw3d
npm install
cp .env.example .env
npm run dev
```

Abra `http://localhost:3000`:
1. Escolha o backend **OpenClaw**.
2. URL do gateway: `ws://localhost:18789`.
   - OpenClaw na VPS? Antes, abra o túnel em outro terminal: `ssh -L 18789:127.0.0.1:18789 root@IP_DA_SUA_VPS`. Assim você também usa `ws://localhost:18789`.
   - Com Tailscale: na VPS, `tailscale serve --yes --bg --https 443 http://127.0.0.1:18789`, e no Claw3D use `wss://<nome-da-vps>.ts.net`.
3. Token: o mesmo de `openclaw gateway auth-token --show`.
4. Se pedir aprovação do dispositivo, rode na máquina do OpenClaw: `openclaw devices approve --latest`.
5. Vá para **/office**: os 16 agentes aparecem como bonecos nas mesas, com nome e status. Use **/office/builder** para montar o layout (salas, mesas, mesa de ping-pong…) e dar o nome do seu escritório.

Para não precisar digitar URL/token toda vez, coloque no `.env` do Claw3D:
```
CLAW3D_GATEWAY_URL=ws://localhost:18789
CLAW3D_GATEWAY_TOKEN=<seu token>
CLAW3D_GATEWAY_ADAPTER_TYPE=openclaw
```

> Se for deixar o Claw3D acessível fora do seu computador, defina `STUDIO_ACCESS_TOKEN` no `.env`.

## 9. Atualizar o time depois

Editou algum agente neste repositório (ex.: mudou a personalidade da Lua)? Rode de novo:
```bash
git pull
./scripts/instalar-time.sh
```
Arquivos que você tinha alterado direto no servidor viram backup (`*.bak-<data>`), e a pasta `empresa/` com seus dados **nunca** é sobrescrita.

Próximo: [3. Uso no dia a dia](03-uso-no-dia-a-dia.md).
