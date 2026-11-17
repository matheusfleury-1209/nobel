# 5. Custos e segurança

## Quanto custa

O vídeo fala em ~R$ 150/mês para 9 agentes. É possível, mas depende de **quanto** eles trabalham. Os custos são:

| Item | Opções | Observação |
|---|---|---|
| **Onde roda** | Seu próprio PC (grátis, mas precisa ficar ligado) **ou** uma VPS Linux pequena (2 vCPU / 4 GB RAM é suficiente) | VPS é o recomendado: fica 24h ligada |
| **Modelo de IA** | Assinatura (Claude, ChatGPT etc., se o OpenClaw suportar login por assinatura no seu caso) **ou** API paga por uso | É o maior custo variável |
| Claw3D | Grátis (código aberto) | Opcional |
| WhatsApp/Telegram | Grátis (QR code / bot) | API oficial do WhatsApp é paga por conversa |

### Como manter o custo baixo
- **Modelo certo para cada agente**: o instalador usa um modelo mais forte para Diretora, Financeiro, Tráfego e Vendas e um modelo mais rápido/barato para Social, Criativos, Atendimento, Prospecção e Administrativo. Ajuste em `scripts/instalar-time.sh` (variáveis `MODELO_FORTE` e `MODELO_RAPIDO`).
- **Menos rotinas**: cada automação é uma execução paga. Comece só com o briefing diário e o caixa; ligue as outras aos poucos.
- **Planilhas enxutas**: CSV gigante = mais texto lido = mais caro. Arquive meses antigos em subpastas.
- **Acompanhe o gasto** no painel do provedor do modelo e defina um **limite mensal de gasto** lá.

## Segurança — leia antes de ligar o WhatsApp

1. **Servidor só seu.** Não deixe o painel do OpenClaw nem o Claw3D abertos na internet. Acesse por túnel SSH ou Tailscale (ver instalação). Se expuser o Claw3D, defina `STUDIO_ACCESS_TOKEN`.
2. **Token do gateway é senha.** Quem tem o token controla os agentes.
3. **Agentes que falam com clientes** (Vendedor e Atendimento) estão configurados **sem** acesso a terminal (`exec`), navegador e automações. Um cliente mal-intencionado pode tentar "dar ordens" ao agente pela conversa (*prompt injection*); com menos ferramentas, o estrago possível é menor. Para isolamento total, ative o sandbox Docker nesses dois (`sandbox: { mode: "all", scope: "agent" }`).
4. **Dinheiro nunca é automático.** Nenhum agente tem acesso a banco para pagar. Integrações bancárias: somente leitura.
5. **Aprovações.** Tudo que custa dinheiro, muda preço ou é jurídico passa por `empresa/aprovacoes/pendentes.md`.
6. **LGPD.** Você é o controlador dos dados dos clientes. Colete o mínimo, não compre listas, não faça disparos não solicitados, e tenha uma política de privacidade. A prospecção usa apenas dados públicos de **empresas**.
7. **Backup.** Faça backup diário da pasta `~/.openclaw/empresa` (é o "banco de dados" do seu negócio) e dos workspaces. Ex.: `rclone` para o Google Drive ou snapshot da VPS.
8. **Não versione segredos.** Nunca coloque `~/.openclaw/openclaw.json`, tokens ou a pasta `empresa/` com dados reais num repositório público.
9. **Revise no começo.** Nas 2 primeiras semanas, leia o que os agentes produzem. Corrija e peça para "anotar na memória".
10. **Contador e advogado continuam necessários.** Os agentes organizam e fazem rascunhos; quem valida impostos e contratos é um profissional.
