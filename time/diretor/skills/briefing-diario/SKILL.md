---
name: briefing-diario
description: Monta o resumo diário da empresa para o dono (caixa, vendas, marketing, atendimento, aprovações pendentes). Use toda manhã ou quando o dono pedir "como estamos hoje?".
---

# Briefing diário

1. Leia (se existirem) os relatórios de hoje e de ontem em `empresa/relatorios/`.
2. Caixa: em `empresa/financeiro/lancamentos.csv`, some saldo realizado, contas a pagar e a receber dos próximos 7 dias e atrasadas.
3. Vendas: em `empresa/vendas/leads.csv`, conte leads novos (ontem), por etapa, propostas abertas (valor total) e follow-ups vencidos.
4. Marketing: último relatório do `trafego` (investimento, leads, CPL, ROAS) e posts previstos para hoje em `empresa/marketing/calendario-editorial.csv`.
5. Atendimento: tickets abertos e de prioridade alta em `empresa/atendimento/tickets.csv`.
6. Aprovações: itens `[PENDENTE]` em `empresa/aprovacoes/pendentes.md`.

## Formato (máx. 15 linhas)
```
🧭 Bom dia! Resumo de DD/MM
💰 Caixa: R$ X | a receber 7d: R$ Y | a pagar 7d: R$ Z | atrasados: N
🤝 Vendas: N leads novos | N propostas (R$ X) | N follow-ups atrasados
📈 Anúncios (ontem): R$ X investidos, N leads, CPL R$ Y
📱 Hoje no ar: ...
💬 Atendimento: N abertos (N urgentes)
⚠️ Precisa de você: 1) ... 2) ...
✅ Hoje o time vai: ...
```
Salve também em `empresa/relatorios/AAAA-MM-DD-diretoria-briefing.md`.
Se faltar dado, escreva "sem dados" naquela linha — nunca estime.
