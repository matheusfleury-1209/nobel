# 4. Integrações (anúncios, banco, redes, CRM)

O time já funciona **sem nenhuma integração**: você salva os relatórios e extratos (CSV) nas pastas de `empresa/` e os agentes leem.
Depois, se quiser, dá para automatizar cada fonte. Vá por etapas.

## Nível 1 — Exportar e salvar (funciona no dia 1)

| Dado | De onde exportar | Onde salvar | Quem usa |
|---|---|---|---|
| Resultados de anúncios Meta | Gerenciador de Anúncios → Relatórios → Exportar (CSV) | `empresa/marketing/trafego/exportacoes/` | Gabi |
| Resultados Google Ads | Google Ads → Relatórios → Download (CSV) | `empresa/marketing/trafego/exportacoes/` | Gabi |
| Extrato bancário | App/internet banking → Extrato → CSV ou OFX | `empresa/financeiro/extratos/` | Otávio |
| Métricas do Instagram | Meta Business Suite → Insights → Exportar | `empresa/marketing/social/` | Lua |
| Vendas da plataforma (Hotmart, Shopify, Nuvemshop…) | Relatório de vendas (CSV) | `empresa/financeiro/extratos/` | Otávio / Rafa |

Diga ao agente: "salvei o arquivo X em tal pasta, importa".

## Nível 2 — Conversas com clientes (WhatsApp / Telegram / Instagram)

O OpenClaw conecta canais de mensagem e direciona cada um para um agente (bindings). Veja o passo a passo em [02-instalacao.md](02-instalacao.md#6-conectar-whatsapp-e-telegram).

⚠️ **Atenção com WhatsApp:** a conexão por QR code (como no WhatsApp Web) é ótima para conversar com quem te chamou, mas **não use para disparo em massa** — o número pode ser banido. Para volume alto, use a API oficial do WhatsApp Business por meio de um provedor.

## Nível 3 — APIs (automação total)

Cada integração vira uma **skill** com credenciais guardadas no servidor (nunca dentro das pastas dos agentes, nem no Git).

| Integração | Como | Cuidados |
|---|---|---|
| Meta Marketing API (ler métricas) | App em developers.facebook.com + token de usuário do sistema com permissão `ads_read` | Comece **só leitura**. Permissão de escrita (`ads_management`) só depois de muita confiança, e mesmo assim com aprovação |
| Google Ads API | Developer token + OAuth | Mesma regra: só leitura no começo |
| Instagram (publicar) | Instagram Graph API (conta profissional ligada a uma Página) | Publicar só posts com status `aprovado` |
| Banco | Open Finance via agregador (ex.: Pluggy, Belvo) ou extrato OFX | **Apenas leitura.** Nunca dê ao agente poder de pagar |
| CRM (Pipedrive, RD Station, HubSpot) | API do CRM | Pode substituir o `leads.csv` |
| Google Sheets | API do Google ou ferramenta MCP | Bom para você ver as planilhas no celular |
| Emissão de NF | API da sua prefeitura/emissor | Só rascunho + aprovação |

Como adicionar uma integração como skill:
1. Crie `~/.openclaw/workspace-<agente>/skills/<nome>/SKILL.md` descrevendo **quando** usar e **qual comando** rodar (ex.: um script `python3 scripts/meta_insights.py --dias 7` que imprime CSV).
2. Coloque o token em variável de ambiente ou no gerenciador de segredos do servidor — nunca no texto da skill.
3. Teste pedindo ao agente: "usa a skill X para puxar os dados de ontem".

Outra opção é usar **servidores MCP** prontos (há MCPs da comunidade para Google Sheets, Notion, CRMs etc.) — veja a documentação do OpenClaw sobre ferramentas/MCP.

## Ordem recomendada
1. Semana 1: tudo por exportação manual (nível 1) + Telegram com a Diretora.
2. Semana 2: WhatsApp comercial com o Vendedor (depois de testar com você).
3. Mês 2: API de leitura da Meta/Google para o tráfego e extrato automático para o financeiro.
4. Depois: publicação automática no Instagram, CRM, etc.
