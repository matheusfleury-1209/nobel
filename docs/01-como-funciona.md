# 1. Como funciona (o que aparece no vídeo)

O vídeo mostra **duas ferramentas abertas no navegador**:

| Aba no print | O que é | Para que serve |
|---|---|---|
| **OpenClaw Control** | Painel do [OpenClaw](https://github.com/openclaw/openclaw), um "motor" de agentes de IA de código aberto que roda no seu computador ou num servidor | É onde os agentes **existem de verdade**: cada um tem nome, função, memória, ferramentas, rotinas e pode falar com você pelo WhatsApp/Telegram |
| **Claw3D** | [Claw3D](https://github.com/iamlukethedev/Claw3D), um escritório 3D de código aberto (comunidade, não oficial) que se conecta ao OpenClaw | É só a **visualização**: mostra cada agente como um bonequinho na mesa, andando quando está trabalhando, com a bolinha de status (verde = ativo, amarelo = ocupado) |

Ou seja: **o escritório 3D é a "vitrine"; quem trabalha é o OpenClaw.** Dá para usar o time sem o Claw3D. O Claw3D serve para acompanhar o trabalho de um jeito visual.

## Arquitetura do seu time

```
             VOCÊ (dono)
                 │  Telegram / WhatsApp pessoal / painel
                 ▼
        ┌──────────────────┐
        │ 🧭 Helena         │  Diretora: recebe seus pedidos, delega,
        │   (diretor)       │  cobra e te manda UM resumo por dia
        └────────┬─────────┘
   ┌──────┬──────┼──────┬──────┬──────┬──────┬──────┐
   ▼      ▼      ▼      ▼      ▼      ▼      ▼      ▼
 💰Otávio 📈Gabi 📱Lua  ✍️Duda 🤝Rafa 💬Clara 🔎Theo 🗂️Marcos
 financ.  tráfego social criat. vendas atend.  prosp. admin/RH
                               │       │
                               └───┬───┘
                                   ▼
                     CLIENTES (WhatsApp/Instagram da empresa)

      Todos leem e escrevem na mesma pasta:  empresa/
      (planilhas CSV de caixa, leads, campanhas, calendário, tickets…)

      Claw3D ──(lê o OpenClaw)──► escritório 3D com os 9 agentes
```

## As peças, em linguagem simples

- **Agente** = um "funcionário" com uma pasta própria (workspace) contendo:
  - `SOUL.md` — personalidade e jeito de falar;
  - `AGENTS.md` — o cargo: o que faz, onde salva, limites;
  - `IDENTITY.md` — nome e emoji (é o que aparece no escritório 3D);
  - `USER.md` — quem é você;
  - `skills/` — "procedimentos operacionais" (ex.: como fazer o fluxo de caixa);
  - `memory/` — o diário do agente (ele mesmo escreve).
- **Pasta `empresa/`** = o "servidor de arquivos" do escritório. As planilhas ficam lá e todos os agentes as compartilham.
- **Automações (rotinas)** = o despertador de cada um: "todo dia às 8h faça o briefing".
- **Canais** = por onde as conversas chegam (Telegram, WhatsApp, etc.). Cada canal pode ser ligado a um agente diferente:
  - seu Telegram → Diretora;
  - WhatsApp comercial → Vendedor;
  - WhatsApp de suporte → Atendimento.
- **Delegação** = a Diretora pode acionar os outros agentes (subagentes) e eles conversam entre si.
- **Aprovações** = nada que envolva dinheiro, preço, contrato ou publicação sensível acontece sem você. O pedido aparece em `empresa/aprovacoes/pendentes.md` e a Diretora te avisa.

## O que a IA faz bem e o que ela NÃO deve fazer sozinha

| Faz muito bem | Faz com você aprovando | Não deixe a IA fazer |
|---|---|---|
| Relatórios, resumos, análises de planilha | Mudar orçamento de anúncio | Pagar contas / PIX |
| Legendas, roteiros, copies, propostas | Publicar posts | Assinar contratos |
| Responder leads e clientes com base no FAQ | Dar desconto fora da tabela | Decidir contratação ou demissão |
| Follow-up, organização de CRM | Enviar cobranças | Assumir obrigações fiscais sem o contador |
| Pesquisa de concorrentes e prospecção | Disparos para listas | Mandar mensagem em massa para quem não pediu |

Próximo passo: [2. Instalação](02-instalacao.md).
