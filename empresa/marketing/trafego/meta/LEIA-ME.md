# Anúncios da Meta (atualiza sozinho a cada hora)

Gerado pelo `scripts/meta.py` direto da API da Meta, com acesso **só de leitura**. **Não edite à mão**: a próxima atualização apaga a mudança.

| Arquivo | O que tem | Quem usa |
|---|---|---|
| `resumo.md` | hoje, ontem e 7 dias; por campanha; por anúncio no ar; alertas (reprovado, com problema, gasto sem conversa) | Helena, Gabi, Caio, Otávio |
| `diario.csv` | um dia por anúncio, últimos 30 dias: gasto, impressões, alcance, frequência, cliques no link, CTR, CPM, conversas, leads | Gabi, Caio |
| `ativos.csv` | anúncios no ar, em revisão, reprovados ou com problema; status da campanha e do conjunto; orçamento por dia; motivo da reprovação | Gabi |

- Valores em reais, datas no horário de Brasília. `conversas` = conversas iniciadas no WhatsApp/Messenger.
- Os números de hoje chegam com algumas horas de atraso. Para decidir, use ontem e 7 dias.
- Confira "Atualizado em" no `resumo.md`. Se tiver mais de 2 horas, avise a Helena (a atualização parou).
