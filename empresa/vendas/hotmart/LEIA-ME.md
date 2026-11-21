# Vendas da Hotmart (atualiza sozinho a cada 10 minutos)

Estes arquivos são gerados pelo `scripts/hotmart.py` direto da API da Hotmart. **Não edite à mão**: a próxima atualização apaga a mudança. Anote o que precisar no seu próprio CSV (leads, recuperação, alunas, lançamentos).

| Arquivo | O que tem | Quem usa |
|---|---|---|
| `resumo.md` | vendas de hoje, 7 dias e mês; por origem, produto e forma de pagamento; fila de recuperação; reembolsos. Sem dados pessoais | Helena, Otávio, Gabi, Caio |
| `vendas.csv` | uma linha por transação dos últimos 45 dias: status, datas, produto, nome, e-mail, telefone, cidade, valor, forma de pagamento, `origem_src` | Rafa, Nina, Otávio |
| `pendentes.csv` | quem gerou Pix/boleto, teve cartão recusado ou parou no meio nos últimos 14 dias **e não comprou depois** | Bia (e o Rafa, para quem é da conversa dele) |

Status que contam como venda: `APPROVED` e `COMPLETE` (coluna `situacao` = "aprovada"). Datas no horário de Brasília. `origem_src` = o `src` do link (ex.: `whatsapp-rafa`).

Regras:
- São dados pessoais de alunas: use só para atender, recuperar e acompanhar. Nunca copie para fora da pasta `empresa/` nem mande para terceiros.
- Confira a hora de "Atualizado em" no `resumo.md`. Se tiver mais de 1 hora, avise a Helena (a atualização parou).
- Os números daqui são a fonte oficial de vendas. Não invente nem arredonde.
