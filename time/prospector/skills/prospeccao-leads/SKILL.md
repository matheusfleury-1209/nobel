---
name: prospeccao-leads
description: Pesquisa e monta lista de empresas-alvo com o perfil de cliente ideal, usando fontes públicas, com pontuação e sugestão de abordagem. Use na rotina de prospecção ou quando pedirem "acha clientes para mim".
---

# Prospecção de leads (B2B)

1. Leia o ICP no PERFIL: segmento, porte, região, sinais de compra (ex.: está contratando, abriu filial, anuncia muito, site desatualizado).
2. Pesquise em fontes públicas (busca na web, sites, perfis comerciais, diretórios). Se a ferramenta de navegação estiver disponível, use; senão, peça ao dono para colar resultados de busca.
3. Para cada empresa: nome, segmento, cidade, site, @, telefone **comercial público**, fonte (URL), score 1–5 e o "gancho" (por que agora, o que observou).
4. Elimine duplicadas com `lista-alvos.csv` e com `empresa/vendas/leads.csv`.
5. Grave as novas com `status=novo`. As de score 4–5 vão ao `vendedor` com uma sugestão de primeira mensagem personalizada (`status=enviado_vendedor`).
6. Resumo: N empresas, N score alto, padrões percebidos.
