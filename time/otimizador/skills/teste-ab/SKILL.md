---
name: teste-ab
description: Desenha, registra e avalia testes A/B (anúncio, mensagem de abertura, oferta, follow-up), com hipótese, métrica, tamanho mínimo e regra de decisão. Use quando houver uma melhoria a validar.
---

# Teste A/B

Registre em `empresa/melhorias/testes.csv` (`id,data_inicio,hipotese,variavel,a,b,metrica,minimo,resultado,decisao`).

1. **Hipótese:** "Se explicarmos o estágio na 1ª mensagem, menos leads somem depois do preço."
2. **Uma variável por teste.** Métrica principal = venda; se o volume for baixo, use a etapa logo antes (link enviado).
3. **Tamanho mínimo antes de decidir:** ≥ 30 conversas por versão ou ≥ R$ 150 por anúncio. Antes disso: "sem conclusão".
4. Decisão: vence quem tiver a melhor métrica principal com diferença clara. Empate → fica a mais simples.
5. Comunique o resultado à Diretora e à área dona da mudança.
