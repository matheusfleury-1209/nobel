---
name: follow-up
description: Faz o follow-up dos leads com próximo passo vencido, com mensagens personalizadas e cadência definida. Use nas rotinas de 9h e 15h ou quando pedirem "quem precisa de retorno".
---

# Follow-up

1. Em `leads.csv`, filtre etapas `novo`, `qualificado`, `proposta`, `negociacao` com `data_proximo_passo` ≤ hoje.
2. Cadência após proposta: D+2, D+5, D+10, D+20 (última: "vou encerrar por aqui, se mudar algo é só chamar"). Depois disso → `perdido` (motivo: sem resposta).
3. Mensagem personalizada usando o histórico (`observacoes`): retome o que o cliente disse, traga algo útil (resposta a dúvida, case, condição válida), termine com uma pergunta simples.
4. Se você está ligado ao WhatsApp e o cliente já conversou com você, envie. Se não, gere a lista de mensagens em `empresa/vendas/followups/AAAA-MM-DD.md` para o dono enviar.
5. Atualize `proximo_passo` e `data_proximo_passo` de cada lead.
6. Resumo para a Diretora: N follow-ups feitos, N respostas, N avançaram de etapa.
