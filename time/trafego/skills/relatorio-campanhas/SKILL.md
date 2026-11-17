---
name: relatorio-campanhas
description: Gera relatório de desempenho dos anúncios (Meta Ads, Google Ads) com investimento, leads, vendas, CPL, CPA e ROAS por campanha. Use diariamente ou quando pedirem "como estão os anúncios".
---

# Relatório de campanhas

1. Importe exportações novas de `empresa/marketing/trafego/exportacoes/` para `campanhas.csv` (sem duplicar data+campanha+conjunto).
2. Período: ontem (diário) ou últimos 7 dias (semanal), comparando com o período anterior.
3. Por campanha e no total: investimento, impressões, CTR, CPC, leads, CPL, vendas (cruze com `leads.csv`, coluna `origem`), CPA, receita, ROAS.
4. Classifique cada campanha: 🟢 escalar / 🟡 observar / 🔴 pausar ou corrigir — com base nas metas de CPL/CPA do PERFIL.
5. Formato:
```
📈 Anúncios — DD/MM (vs período anterior)
Total: R$ X | N leads (CPL R$ Y) | N vendas (CPA R$ Z) | ROAS N,Nx
🟢 Campanha A: ...
🔴 Campanha B: ... motivo
Recomendo: 1) ... 2) ...
```
6. Salve em `empresa/relatorios/AAAA-MM-DD-trafego-relatorio.md`.
