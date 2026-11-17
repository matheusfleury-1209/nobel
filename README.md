# Time de IA para gerir a empresa

Kit pronto para montar um **time de 9 funcionários de IA**, igual ao do vídeo (escritório 3D com os agentes trabalhando):
diretora, financeiro, gestor de tráfego, social media, copywriter, vendedor, atendimento, prospecção e administrativo/RH.

- **Motor dos agentes:** [OpenClaw](https://github.com/openclaw/openclaw), de código aberto. É a aba "OpenClaw Control" do vídeo.
- **Escritório 3D:** [Claw3D](https://github.com/iamlukethedev/Claw3D), de código aberto e opcional. É a aba "Claw3D" do vídeo.
- **Este repositório:** os 9 agentes já configurados (personalidade, cargo, regras e procedimentos), as planilhas da empresa, as rotinas automáticas e o instalador.

## O time

| | Agente (id) | Função | O que faz | Rotina automática |
|---|---|---|---|---|
| 🧭 | **Helena** (`diretor`) | Diretora de Operações | Recebe seus pedidos, delega, cobra o time e te manda um resumo | Briefing seg–sex 8h; revisão semanal sexta 17h |
| 💰 | **Otávio** (`financeiro`) | Financeiro | Caixa, contas a pagar e receber, conciliação, DRE, cobrança, precificação | Caixa 7h30; cobranças 10h; fechamento no dia 1 |
| 📈 | **Gabi** (`trafego`) | Gestora de tráfego | Meta Ads e Google Ads: relatórios, CPL/CPA/ROAS, otimizações, planejamento | Relatório 9h; otimização às segundas |
| 📱 | **Lua** (`social`) | Social media | Calendário editorial, legendas, roteiros de Reels, comentários | Calendário às segundas; posts de amanhã às 14h |
| ✍️ | **Duda** (`criativos`) | Copy e criativos | Copies de anúncio A/B, briefings de arte e vídeo, prompts de imagem | Fila de pedidos às 15h |
| 🤝 | **Rafa** (`vendedor`) | Vendedor | Atende leads no WhatsApp, qualifica, faz proposta, contorna objeções e faz follow-up | Follow-ups às 9h e 15h |
| 💬 | **Clara** (`atendimento`) | Atendimento e pós-venda | Suporte, reclamações, onboarding, NPS | Tickets às 11h |
| 🔎 | **Theo** (`prospector`) | Prospecção e mercado | Listas de clientes ideais (dados públicos), análise de concorrentes | Terça e quinta 10h; concorrentes no dia 1 |
| 🗂️ | **Marcos** (`administrativo`) | Administrativo e RH | Obrigações e vencimentos, rascunhos de contratos, recrutamento | Segunda 8h |

Os nomes são sugestões: troque em `time/<agente>/IDENTITY.md`.

## Como funciona

```
VOCÊ ──Telegram──► 🧭 Diretora ──delega──► 💰 📈 📱 ✍️ 🤝 💬 🔎 🗂️
                                                │   │
CLIENTES ─────WhatsApp da empresa──────────────┘   └── (vendedor / atendimento)

Todos compartilham a pasta empresa/ (planilhas de caixa, leads, campanhas, calendário, tickets…)
O que envolve dinheiro, preço, contrato ou publicação fica esperando a SUA aprovação.
O Claw3D lê o OpenClaw e mostra todo mundo trabalhando no escritório 3D.
```

Explicação completa: [docs/01-como-funciona.md](docs/01-como-funciona.md)

## Começo rápido

```bash
# 1. Instale o OpenClaw (servidor Linux, Mac ou Windows/WSL2)
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon

# 2. Instale o time
git clone https://github.com/matheusfleury-1209/nobel.git time-ia && cd time-ia
./scripts/instalar-time.sh

# 3. Preencha o perfil da empresa (o passo mais importante)
nano ~/.openclaw/empresa/PERFIL-DA-EMPRESA.md

# 4. Ligue as rotinas (os resumos chegam no seu Telegram)
AVISO_CANAL=telegram AVISO_PARA=<seu_id_telegram> ./scripts/criar-rotinas.sh

# 5. (Opcional) Escritório 3D, no seu computador
git clone https://github.com/iamlukethedev/Claw3D.git claw3d && cd claw3d
npm install && cp .env.example .env && npm run dev    # abra http://localhost:3000
```

Passo a passo detalhado, com WhatsApp, Telegram e acesso à VPS: **[docs/02-instalacao.md](docs/02-instalacao.md)**

## Documentação

1. [Como funciona](docs/01-como-funciona.md): o que é cada peça e o que a IA deve ou não fazer sozinha
2. [Instalação](docs/02-instalacao.md): VPS, OpenClaw, time, canais, rotinas e Claw3D
3. [Uso no dia a dia](docs/03-uso-no-dia-a-dia.md): exemplos de pedidos para cada agente
4. [Integrações](docs/04-integracoes.md): Meta Ads, Google Ads, banco, Instagram, CRM
5. [Custos e segurança](docs/05-custos-e-seguranca.md): como gastar pouco e não ter dor de cabeça

Versão visual, com a planta do escritório, a agenda de rotinas e a instalação: [docs/escritorio-ia.html](docs/escritorio-ia.html)

Prévia 3D simulada do escritório (antes de instalar o Claw3D): [docs/escritorio-3d.html](docs/escritorio-3d.html)

## Estrutura do repositório

```
time/
  _comum/REGRAS-GERAIS.md    regras que valem para todos (aprovações, LGPD, segurança)
  _comum/USER.md             aponta para a seção "Sobre o dono" do PERFIL
  <agente>/
    IDENTITY.md              nome e emoji (aparecem no escritório 3D)
    SOUL.md                  personalidade
    AGENTS.md                cargo: missão, onde salva, limites, rotinas
    skills/<skill>/SKILL.md  procedimentos (fluxo de caixa, proposta, follow-up…)
empresa/                     pasta compartilhada: PERFIL + planilhas CSV (vai para ~/.openclaw/empresa)
openclaw/time.json5          modelo da configuração do OpenClaw (para conferir ou editar à mão)
scripts/instalar-time.sh     instala ou atualiza o time
scripts/criar-rotinas.sh     cria as automações (cron) de cada agente
docs/                        guias
```

## Rotinas automáticas

Fuso: America/Sao_Paulo. Para mudar, edite `scripts/criar-rotinas.sh`.

| Quando | Agente | Rotina |
|---|---|---|
| Seg–sex 7h30 | Financeiro | Caixa do dia + alertas |
| Seg–sex 8h | Diretora | Briefing diário → seu celular |
| Segunda 8h | Administrativo | Obrigações da semana |
| Seg–sex 9h | Tráfego | Relatório de anúncios de ontem |
| Segunda 9h | Social | Calendário da semana |
| Seg–sex 9h e 15h | Vendedor | Follow-ups |
| Seg–sex 10h | Financeiro | Rascunhos de cobrança |
| Segunda 10h | Tráfego | Otimização semanal |
| Terça e quinta 10h | Prospecção | 20 novos alvos |
| Seg–sex 11h | Atendimento | Revisão de tickets |
| Seg–sex 14h | Social | Posts de amanhã |
| Seg–sex 15h | Criativos | Fila de pedidos |
| Sexta 17h | Diretora | Revisão semanal → seu celular |
| Dia 1, 9h–10h | Financeiro / Prospecção | Fechamento do mês / concorrentes |

## Regras de ouro

- **Nenhum agente movimenta dinheiro.** Pagamentos, orçamento de anúncios, descontos fora da tabela, contratos e publicações passam por `empresa/aprovacoes/pendentes.md`, e a Diretora te pergunta.
- **Vendedor e Atendimento** (que falam com clientes) rodam sem acesso a terminal, navegador e automações.
- **Nada de números inventados:** os agentes só citam dados das planilhas e sempre dizem a fonte.
- **Contador e advogado continuam necessários:** os agentes organizam e preparam rascunhos.

## Aviso

OpenClaw e Claw3D são projetos independentes de código aberto, mantidos por suas comunidades e sem vínculo com este kit. Os dois evoluem rápido: se algum comando mudar, siga a documentação oficial de cada um.
