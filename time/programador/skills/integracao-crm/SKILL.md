---
name: integracao-crm
description: Planeja e implementa a passagem de dados do time para o CRM Nobel (leads do Rafa, cartão do lead para a vendedora, status de venda), sempre em branch e com aprovação. Use quando o CRM Nobel estiver pronto para receber leads.
---

# Integração com o CRM Nobel

1. Leia a documentação do CRM (repositório `crm-nobel`: README, `docs/`, migrations) e entenda as tabelas (`contatos`, `conversas`, `mensagens`, futuras `leads`).
2. Proponha o desenho mínimo:
   - o Rafa cria ou atualiza o lead com origem, cidade, respostas da triagem e resumo
   - a vendedora recebe o cartão do lead no CRM
   - o status de venda volta para o time
3. Implemente em **branch própria**, com testes, sem chaves no código. Abra um pull request para o Matheus aprovar.
4. Enquanto o CRM não estiver no ar: mantenha `empresa/vendas/leads.csv` como fonte e documente o mapeamento de campos para a migração.
