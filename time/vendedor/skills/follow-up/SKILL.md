---
name: follow-up
description: Faz o follow-up dos leads com próximo passo vencido, com mensagens personalizadas e cadência definida. Use nas rotinas de 9h e 15h ou quando pedirem "quem precisa de retorno".
---

# Follow-up

1. Em `leads.csv`, filtre etapas `novo`, `qualificado`, `proposta`, `negociacao` com `data_proximo_passo` ≤ hoje.
2. Cadência (única para o time):
   - **D0:** até 2h depois, só dentro do horário comercial (senão, às 8h do próximo dia útil)
   - **D1** e **D3**
   - **D7:** encerramento ("vou parar de te mandar mensagem pra não incomodar; se quiser, é só responder")
   - Em ofertas com prazo, 1 lembrete no último dia
   - Depois disso → `perdido` (motivo: sem resposta)
   - Quem pediu para parar sai na hora
3. Mensagem personalizada usando o histórico (`observacoes`): retome o que o cliente disse, traga algo útil (resposta a dúvida, case, condição válida), termine com uma pergunta simples.
4. Se você está ligado ao WhatsApp e o cliente já conversou com você, envie. Se não, gere a lista de mensagens em `empresa/vendas/followups/AAAA-MM-DD.md` para o dono enviar.
5. Atualize `proximo_passo` e `data_proximo_passo` de cada lead.
6. Resumo para a Diretora: N follow-ups feitos, N respostas, N avançaram de etapa.
