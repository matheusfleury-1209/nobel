---
name: agenda-obrigacoes
description: Lista obrigações fiscais, trabalhistas, contratuais e administrativas que vencem na semana e no mês, com alertas. Use às segundas ou quando pedirem "o que vence".
---

# Agenda de obrigações

1. Leia `empresa/admin/obrigacoes.csv`. Para itens recorrentes já pagos/feitos, gere a próxima ocorrência.
2. Liste: vencidos (🔴), vence em até 7 dias (🟠), vence no mês (🟡).
3. Para cada item: o que é, valor (se houver, pegue do `financeiro`), quem faz (dono, contador, você), o que precisa (guia, documento, acesso).
4. Peça ao `financeiro` para incluir os valores em `lancamentos.csv` como `pendente`.
5. Salve em `empresa/relatorios/AAAA-MM-DD-admin-obrigacoes.md` e avise a Diretora só se houver 🔴 ou 🟠.
