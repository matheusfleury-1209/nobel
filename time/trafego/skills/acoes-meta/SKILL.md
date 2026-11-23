---
name: acoes-meta
description: Ativa, pausa, muda verba e cria anúncios novos (pausados) na Meta, sempre com a aprovação do Matheus e dentro do limite de verba. Use quando um anúncio aprovado precisar ir ao ar, quando o Matheus aprovar pausar ou mudar verba, ou para montar um anúncio novo com uma arte aprovada.
---

# Ações nos anúncios (com travas)

O programa `python3 ~/time-ia/scripts/meta_acoes.py` faz as mudanças na Meta. Ele **recusa sozinho** o que não estiver aprovado e avisa o Matheus no celular a cada ação.

## Regras fixas (decisão do Matheus)
- **Ativar, pausar ou mudar verba:** só com um bloco `[APROVADO ...]` em `empresa/aprovacoes/pendentes.md` que cite o **ID** e a **ação** (e o **valor**, no caso de verba).
- **Verba diária máxima: R$ 50** por campanha ou conjunto. Nunca peça para aumentar verba sem mostrar os números de vendas da Hotmart.
- **Anúncio novo nasce pausado** (não gasta). Só vai ao ar depois de aprovado.
- **Instagram orgânico: nada.** Posts não são publicados pelo time.

## Comandos
- Ver IDs e status: `python3 ~/time-ia/scripts/meta_acoes.py listar`
- Ativar: `python3 ~/time-ia/scripts/meta_acoes.py ativar <ID>`
- Pausar: `python3 ~/time-ia/scripts/meta_acoes.py pausar <ID>`
- Verba: `python3 ~/time-ia/scripts/meta_acoes.py verba <ID_campanha_ou_conjunto> 50`
- Anúncio novo (pausado), com arte da Duda já aprovada pela Vera:
```
python3 ~/time-ia/scripts/meta_acoes.py novo-anuncio --conjunto <ID_do_conjunto> \
  --imagem empresa/marketing/criativos/artes/<arquivo>-feed.png --nome "C7 | <tema>" \
  --texto "<texto principal>" --titulo "<título curto>" --descricao "<opcional>" \
  --saudacao "Oi, {{user_first_name}}! 😊 Aqui é do Instituto Nobel. Manda sua mensagem que já te respondo sobre o curso de ASB." \
  --mensagem "Oi! Vi o anúncio do curso de ASB."
```

## Como pedir a aprovação (para o programa aceitar)
Escreva em `empresa/aprovacoes/pendentes.md` um bloco assim e avise a Diretora:
```
## [PENDENTE] AAAA-MM-DD HH:MM — tráfego — ativar anúncio 120255...
- O que: ativar o anúncio 120255... ("C7 | ...") no conjunto 120255...
- Por que: <números: custo por conversa, vendas>
- Custo/risco: verba da campanha continua R$ 30/dia
- Se aprovado eu faço: meta_acoes.py ativar 120255...
```
Para verba, escreva o valor assim: `aumentar a verba da campanha 120255... para R$ 50/dia`.
Um pedido por ação. Não junte "ativar e aumentar verba" no mesmo bloco.

## Se o programa recusar
- "Sem aprovação": o bloco não existe, ainda está `[PENDENTE]`, ou não cita o ID/ação/valor certos. **Não edite o status você mesma**: só a Diretora muda para `[APROVADO]`, depois da resposta do Matheus.
- "passa do limite": a verba está acima de R$ 50. Não tente contornar; leve ao Matheus.
- "Texto proibido": reescreva o texto do anúncio.
