---
name: fechamento
description: Fecha a venda no próprio atendimento: envia o link de pagamento oficial, ajuda a pessoa a pagar (Pix, cartão, boleto), confirma a compra e dá as boas-vindas. Use quando o lead estiver qualificado e quiser se matricular, ou pedir o link.
---

# Fechamento

1. **Antes do link**, confira:
   - a pessoa passou na qualificação do PERFIL (pré-requisitos e estágio)
   - ela sabe o valor à vista, a parcela, a garantia e o prazo real da oferta
   - não pediu desconto nem condição especial (se pediu, passe para a pessoa indicada no PERFIL)
2. **Envie o link oficial do PERFIL** para o preço vigente, sem mudar nada nele (nem o `src`). Junto, um resumo curto:
   - "R$ X à vista ou 12x de R$ Y, com 7 dias de garantia pela Hotmart"
   - "É só colocar nome, e-mail e CPF e escolher a forma de pagamento"
   - "Fico aqui enquanto você faz. Se travar, me manda um print"
   - No CRM: `etapa=proposta`, `proximo_passo=confirmar pagamento`, data de hoje.
3. **Se travar no pagamento:**
   - cartão recusado → quase sempre é limite: sugira Pix ou outro cartão
   - Pix → o código vence; se demorou, peça para gerar de novo pelo mesmo link
   - boleto → lembre que a liberação leva até 3 dias úteis
   - erro que você não resolve em 2 tentativas → passe para a pessoa indicada no PERFIL
4. **Sem resposta depois do link:** siga a skill `follow-up`. Na oferta com prazo, use o prazo real.
5. **Quando a pessoa disser que pagou:** peça o print ou o e-mail de confirmação da Hotmart. Com a confirmação:
   - dê as boas-vindas: o acesso chega no e-mail da Hotmart (olhar também o spam)
   - CRM: `etapa=ganho`, valor e forma de pagamento
   - avise a Diretora, o `financeiro` (para conferir na Hotmart) e o `atendimento`/`sucesso` (onboarding)
6. **Nunca:** dar desconto fora do PERFIL, criar link ou cupom, prometer o que o PERFIL não confirma, pedir dados de cartão ou senha pelo chat.
