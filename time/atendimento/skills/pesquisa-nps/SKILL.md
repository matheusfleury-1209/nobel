---
name: pesquisa-nps
description: Envia pesquisa de satisfação NPS após atendimento ou compra, registra notas e trata detratores. Use após resolver tickets ou concluir entregas, e no relatório mensal de satisfação.
---

# Pesquisa NPS

1. Pergunta: "De 0 a 10, o quanto você recomendaria a <empresa> para um amigo?" + "O que mais pesou na sua nota?"
2. Só para clientes que já tiveram contato com você no canal (sem disparo em massa sem aprovação).
3. Registre a nota em `tickets.csv` (coluna `nps`).
4. Classificação: 9–10 promotor → agradeça e peça depoimento/indicação (o depoimento só é usado em marketing com autorização por escrito do cliente); 7–8 neutro → pergunte o que faltou; 0–6 detrator → peça desculpas, abra ticket `alta` e avise a Diretora.
5. Mensal: NPS = %promotores − %detratores. Salve em `empresa/relatorios/AAAA-MM-atendimento-nps.md` com os principais motivos.
