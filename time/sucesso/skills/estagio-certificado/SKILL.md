---
name: estagio-certificado
description: Organiza o estágio presencial de 60h das alunas (vaga em clínica, documentos, controle de horas) e o pedido do certificado de 300h. Use na rotina de quarta ou quando pedirem "como estão os estágios".
---

# Estágio e certificado

1. Liste as alunas que terminaram as aulas e ainda não têm estágio (`estagio.csv` sem linha ou `aguardando_vaga`).
2. Para cada uma, procure clínica parceira na cidade dela ou perto, em `empresa/parcerias/parceiros.csv`.
   - Achou: prepare o pedido de vaga para o Matheus confirmar com a clínica.
   - Não achou: peça ao Pedro (`parcerias`) uma clínica nova naquela cidade, com prazo.
3. Estágio agendado: envie à aluna (via Clara ou lista) o que levar, os documentos e como as horas são registradas, conforme o PERFIL.
4. Toda semana, atualize `horas_feitas`. Quem está parada no estágio recebe um lembrete.
5. 60h concluídas e documentos ok: prepare o pedido do certificado de 300h em `empresa/aprovacoes/pendentes.md` para o Matheus emitir.
6. Certificado entregue: status `concluiu`, peça um depoimento (com autorização) e convide para o programa de indicação do Pedro.
