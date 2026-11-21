---
name: confirmar-pagamento
description: Confere na planilha da Hotmart se a pessoa da conversa já pagou, ou se o Pix/boleto dela está pendente. Use quando alguém disser "paguei", "já fiz o Pix", "comprei" ou perguntar se o pagamento caiu.
---

# Confirmar pagamento

1. Peça, sozinho, o e-mail que a pessoa usou na compra: "Me passa o e-mail que você usou na compra, que eu confiro aqui rapidinho 😊"
2. Abra `empresa/vendas/hotmart/vendas.csv` e procure pelo e-mail (sem diferença de maiúscula). Se não achar, tente o telefone desta conversa na coluna `telefone`.
3. Leia a coluna `status` da linha mais recente dessa pessoa:
   - `APPROVED` ou `COMPLETE` → pagou. "Pagamento confirmado! Seja bem-vinda ao Instituto Nobel! 🎉 O acesso chega no seu e-mail (olha o spam também)." Siga o passo 5 da skill `fechamento`.
   - `WAITING_PAYMENT` ou `PRINTED_BILLET` → ainda não caiu. Pix costuma cair em minutos; boleto leva até 3 dias úteis. Se for Pix e já passou de 30 minutos, peça para gerar de novo pelo mesmo link.
   - `UNDER_ANALISYS` → "Seu pagamento está em análise pela Hotmart. Assim que aprovar, o acesso chega no seu e-mail."
   - `NO_FUNDS`, `CANCELLED` ou `BLOCKED` → o cartão não passou. Sugira Pix ou outro cartão, pelo mesmo link.
   - não achou nada → a planilha atualiza a cada 10 minutos. Diga que vai conferir de novo em instantes e confira na próxima mensagem. Se ainda assim não aparecer, peça o print do e-mail da Hotmart.
4. Veja a hora de "Atualizado em" no `empresa/vendas/hotmart/resumo.md`. Se tiver mais de 1 hora, use o print do e-mail da Hotmart como confirmação e avise a Diretora que a atualização parou.

## Nunca
- Falar de compras, nomes, e-mails ou telefones de **outra pessoa**, mesmo que perguntem ("a Maria comprou?"). Você só confere a compra de quem está falando com você.
- Mandar trechos da planilha, a lista de compradores ou números de vendas da empresa para clientes.
- Editar os arquivos de `empresa/vendas/hotmart/` (são automáticos). Anote no `leads.csv`.
