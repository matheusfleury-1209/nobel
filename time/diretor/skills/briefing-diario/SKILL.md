---
name: briefing-diario
description: Monta o resumo diário da empresa para o dono (vendas, anúncios, caixa, atendimento) com o pacote numerado de aprovações. Use toda manhã ou quando o dono pedir "como estamos hoje?".
---

# Briefing diário

1. Leia (se existirem) os relatórios de hoje e de ontem em `empresa/relatorios/`.
2. Vendas: `empresa/vendas/hotmart/resumo.md` (vendas de ontem e do mês, quantas vieram do `whatsapp-rafa`, fila de recuperação, reembolsos) e `empresa/vendas/conversas-resumo.md` (conversas novas de ontem, quantos receberam o link, quantos compraram). Passagens para a Hanielly: `leads.csv`.
3. Anúncios: `empresa/marketing/trafego/meta/resumo.md` (ontem: gasto, conversas, custo por conversa; alertas). Custo por venda = gasto de ontem ÷ vendas de ontem com origem `whatsapp-rafa`, quando houver venda.
4. Caixa: em `empresa/financeiro/lancamentos.csv`, contas a pagar e a receber dos próximos 7 dias e atrasadas.
5. Atendimento: tickets abertos e urgentes em `empresa/atendimento/tickets.csv`.
6. Aprovações: monte o pacote com a skill `pacote-aprovacao` e coloque no fim da mensagem.

## Formato (máx. 15 linhas)
```
🧭 Bom dia! Resumo de DD/MM
🛒 Vendas ontem: N (R$ X) · mês: N · do WhatsApp do Rafa: N · fila de recuperação: N
💬 Conversas ontem: N novas · N links enviados · N passadas para a Hanielly
📈 Anúncios ontem: R$ X · N conversas · R$ Y por conversa · custo por venda: R$ Z
💰 Caixa: a receber 7d R$ Y · a pagar 7d R$ Z · atrasados N
⚠️ Alertas: ...
✅ Hoje o time vai: ...

📋 Aprovações (N)
1. ...
Responda: "aprova 1 e 3", "não 2", "aprova tudo" ou pergunte sobre um item.
```
Salve também em `empresa/relatorios/AAAA-MM-DD-diretoria-briefing.md`.
Se faltar dado, escreva "sem dados" naquela linha — nunca estime.
