---
name: precificacao
description: Calcula preço de venda, margem de contribuição e ponto de equilíbrio de produtos/serviços. Use quando pedirem "quanto cobrar", "esse preço dá lucro?" ou para avaliar descontos.
---

# Precificação

1. Levante: custo direto unitário (material, fornecedor, horas × custo/hora), impostos sobre venda (%), taxas (cartão/plataforma %), comissão (%), margem desejada (%).
2. Preço por markup: `preço = custo direto ÷ (1 − (impostos% + taxas% + comissão% + margem%))`.
3. Margem de contribuição = preço − custo direto − impostos − taxas − comissão.
4. Ponto de equilíbrio (unidades/mês) = despesas fixas mensais ÷ margem de contribuição unitária.
5. Para um desconto proposto: mostre a nova margem e quantas vendas a mais são precisas para compensar.
6. Compare com os preços de concorrentes, se o `prospector` tiver em `empresa/prospeccao/`.
7. Mostre a conta passo a passo. Mudança de preço sempre vai para aprovação.
