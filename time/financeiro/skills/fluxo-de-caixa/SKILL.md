---
name: fluxo-de-caixa
description: Calcula saldo atual, contas a pagar/receber e projeção de caixa 30/60/90 dias a partir de empresa/financeiro/lancamentos.csv. Use para "como está o caixa", "vou ter dinheiro para X?" e na rotina diária.
---

# Fluxo de caixa

1. Leia `empresa/financeiro/lancamentos.csv`. Use o saldo inicial informado no `PERFIL-DA-EMPRESA.md` (seção Financeiro).
2. Marque como `atrasado` todo `pendente` com `vencimento` < hoje (escreva a mudança no CSV).
3. Calcule:
   - Saldo atual = saldo inicial + entradas pagas − saídas pagas.
   - A receber e a pagar: próximos 7, 30, 60, 90 dias.
   - Atrasados (a receber e a pagar), com nomes.
   - Projeção semana a semana dos próximos 30 dias. Destaque a semana de menor saldo.
4. Se der para usar uma ferramenta de cálculo (ex.: script Python), use — não faça conta grande de cabeça.
5. Saída curta:
```
💰 Caixa hoje: R$ X
➕ A receber 7d/30d: R$ A / R$ B   ➖ A pagar 7d/30d: R$ C / R$ D
📉 Menor saldo previsto: R$ Y em DD/MM
⏰ Vence em até 2 dias: ...
🔴 Atrasados: ...
```
6. Salve o detalhamento em `empresa/relatorios/AAAA-MM-DD-financeiro-caixa.md`.
