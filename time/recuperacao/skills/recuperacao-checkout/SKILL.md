---
name: recuperacao-checkout
description: Monta a fila de recuperação de vendas (checkout abandonado, Pix/boleto pendente, cartão recusado, link sem resposta) com uma mensagem pronta e pessoal para cada pessoa. Use nas rotinas de 10h30 e 16h30 ou quando pedirem "quem quase comprou".
---

# Recuperação de checkout

1. Leia `empresa/vendas/hotmart/pendentes.csv` (veja a hora em `resumo.md`), o `leads.csv` e, se houver, exportações de abandono em `empresa/financeiro/extratos/`. Cruze pelo telefone ou e-mail.
   - `origem_src = whatsapp-rafa` ou a pessoa está no `leads.csv` com `responsavel=vendedor` → é conversa do Rafa: mande para ele (`sessions_send` para `vendedor`) o nome, o telefone e o que aconteceu, com a mensagem sugerida.
2. Tire da lista:
   - quem já comprou depois (confira as vendas aprovadas)
   - quem está como `nao_contatar`
   - quem já recebeu 2 tentativas neste caso
3. Prioridade da fila:
   1. Pix ou boleto gerado nas últimas 24h (a pessoa quis pagar)
   2. cartão recusado (quase sempre é limite: ofereça Pix ou parcelamento)
   3. checkout abandonado nas últimas 24h
   4. link enviado pela Hanielly sem resposta há 1 dia ou mais
4. Para cada pessoa, escreva a mensagem:
   - curta, com o primeiro nome, no tom do PERFIL
   - retome o que ela fez ("vi que você começou a inscrição no curso de ASB")
   - ofereça ajuda concreta: dúvida sobre o estágio, como pagar com Pix, parcelamento, garantia de 7 dias
   - termine com uma pergunta simples
   - preço e condições **só** do PERFIL; se houver oferta com prazo, use o prazo real
5. Salve em `empresa/vendas/recuperacao/fila-AAAA-MM-DD.md`, na ordem de prioridade, e atualize o `recuperacao.csv` (`status=na_fila`, `tentativa`).
6. Separe a fila por quem atendeu: as pessoas que conversaram com o Rafa vão para ele (`sessions_send` ao `vendedor`), e as da Hanielly vão para a Diretora repassar. Avise a Diretora: "Fila de recuperação: N pessoas, R$ X em vendas possíveis. Arquivo: …".
7. No dia seguinte, atualize quem respondeu, comprou ou pediu para parar.
