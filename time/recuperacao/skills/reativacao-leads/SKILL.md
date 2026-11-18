---
name: reativacao-leads
description: Reativa leads antigos que pediram contato e não compraram, só quando há um motivo real e novo (oferta nova, turma, dúvida respondida). Use quando a Diretora pedir uma reativação.
---

# Reativação de leads

1. Só comece com um **motivo real e novo**, aprovado pelo Matheus (ex.: condição nova, novidade sobre o estágio, resposta a uma dúvida comum). Sem motivo, não há reativação.
2. Selecione no `leads.csv` quem:
   - conversou com a gente nos últimos 90 dias
   - está como `perdido` por "sem resposta" ou "timing"
   - **não** pediu para parar
3. Separe em grupos pelo motivo da perda (preço, medo de curso online, estágio, timing) e escreva **uma mensagem por grupo**, personalizada com o nome e com o que a pessoa disse.
4. Mande os modelos para a Vera (`revisor`) e a lista para aprovação em `empresa/aprovacoes/pendentes.md`.
5. Depois de aprovado, a fila vai para a Hanielly enviar aos poucos (no máximo 30 por dia), pelo número oficial.
6. Uma tentativa só. Registre no `recuperacao.csv` com `origem=reativacao` e meça quantos voltaram a conversar e quantos compraram.
