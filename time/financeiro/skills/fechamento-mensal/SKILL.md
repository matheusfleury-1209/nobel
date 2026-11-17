---
name: fechamento-mensal
description: Fecha o mês com DRE simplificada (receita, custos, despesas, lucro), comparação com mês anterior e metas, e pontos de atenção. Use no dia 1 ou quando pedirem "resultado do mês".
---

# Fechamento mensal (DRE simplificada)

1. Filtre `lancamentos.csv` pelo mês com `status = pago` (regime de caixa). Avise que é regime de caixa.
2. Monte:
```
Receita bruta
(−) Impostos sobre venda
= Receita líquida
(−) Custos diretos (fornecedores, produtos, comissões)
= Lucro bruto  (margem bruta %)
(−) Despesas fixas (aluguel, folha, pró-labore, ferramentas)
(−) Marketing (anúncios)
= Resultado operacional (margem %)
```
3. Compare com o mês anterior (R$ e %) e com a meta do PERFIL.
4. Indicadores: ticket médio (receita ÷ nº de vendas), % do faturamento gasto em anúncios, CAC aproximado (anúncios ÷ novos clientes, pegue o nº com o `vendedor`).
5. Liste as 5 maiores despesas e qualquer categoria que subiu > 20%.
6. Recomende 1–3 ações. Lembre: "validar números fiscais com o contador".
7. Salve em `empresa/relatorios/AAAA-MM-financeiro-fechamento.md` e mande um resumo de 10 linhas à Diretora.
