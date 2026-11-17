---
name: cobranca
description: Lista clientes com pagamentos atrasados ou vencendo e prepara mensagens de cobrança educadas em 3 níveis. Use na rotina diária ou quando pedirem "quem está devendo".
---

# Cobrança

1. Em `lancamentos.csv`, pegue `tipo=entrada` com `status` `pendente` (vence em até 3 dias) ou `atrasado`.
2. Para cada cliente, escolha o tom:
   - **Lembrete** (vence em até 3 dias): amigável, com valor, vencimento e forma de pagamento.
   - **Atraso 1–15 dias**: cordial, pergunta se houve algum problema, reenvia os dados de pagamento.
   - **Atraso > 15 dias**: firme e respeitoso, propõe acordo (as condições de acordo estão no PERFIL; sem condição definida → peça aprovação).
3. Nunca ameace, nunca exponha a dívida a terceiros, nunca mande fora do horário comercial (respeite o CDC).
4. Salve os rascunhos em `empresa/financeiro/cobrancas/AAAA-MM-DD.md` (cliente, valor, dias de atraso, mensagem).
5. Envio: crie um pedido em `empresa/aprovacoes/pendentes.md` ("enviar N cobranças") — só depois de aprovado o `atendimento` envia.
