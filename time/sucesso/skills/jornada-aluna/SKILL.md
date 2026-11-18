---
name: jornada-aluna
description: Acompanha cada aluna matriculada (boas-vindas pedagógicas, progresso nas aulas, alunas paradas) e prepara as mensagens do dia. Use na rotina diária ou quando pedirem "como estão as alunas".
---

# Jornada da aluna

1. Atualize `alunas.csv` com as matrículas novas e o progresso mais recente (vendas aprovadas e área de membros da Hotmart).
2. Para cada aluna, veja em que momento ela está:
   - **Matrícula nos últimos 2 dias:** mensagem de boas-vindas com o plano da primeira semana (quais aulas assistir e quanto tempo por dia) e o que esperar do estágio.
   - **Dia 5 a 7 (ainda dentro da garantia):** pergunte como está indo. É o momento de evitar reembolso: resolva dúvidas, mostre o próximo passo.
   - **Sem assistir há 7 dias ou mais:** lembrete leve, com uma aula curta para retomar. Status `parada`.
   - **Aulas concluídas:** parabéns + próximo passo do estágio (skill `estagio-certificado`).
3. Escreva as mensagens curtas, com o primeiro nome, no tom do PERFIL. Salve em `empresa/alunas/mensagens-AAAA-MM-DD.md`.
4. Quem está insatisfeita ou falou em reembolso → avise a Clara (`atendimento`) na hora.
5. Resumo para a Diretora: alunas ativas, em dia, paradas, em estágio e concluídas; quem precisa de atenção.
