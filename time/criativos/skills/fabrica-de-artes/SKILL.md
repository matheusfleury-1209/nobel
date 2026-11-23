---
name: fabrica-de-artes
description: Gera as artes (PNG) do Instituto Nobel nos formatos feed, story e quadrado a partir dos modelos da marca, com o texto exato e checagem automática de promessas proibidas. Use sempre que precisar de uma arte de anúncio ou post.
---

# Fábrica de artes

As artes saem dos modelos da marca (cores e logo do Instituto Nobel, fonte Inter). Você escreve **só o texto**, num arquivo JSON, e roda um comando. Não use gerador de imagem por IA para texto: os modelos garantem português certo e a cara da marca.

## Modelos
- `oferta`: fundo escuro, preço em destaque. Para oferta com prazo real.
- `beneficios`: fundo claro, lista de até 4 benefícios com hexágonos. Para explicar o curso.
- `pergunta`: fundo ciano, pergunta grande + resposta. Para falar com um público específico ("Já trabalha em consultório?").
- Exemplos prontos: `~/time-ia/artes/exemplos/*.json`.

## Passo a passo
1. Crie o JSON em `empresa/marketing/criativos/artes/AAAA-MM-DD-<nome>.json`:
```json
{
  "modelo": "oferta",
  "curso": "asb",
  "formatos": ["feed", "story"],
  "selo": "Black Nobel",
  "titulo": "Curso de Auxiliar em Saúde Bucal",
  "subtitulo": "Aulas online no seu horário + estágio de 60h numa clínica perto de você",
  "itens": ["43 aulas gravadas", "Certificado de 300h", "Acesso vitalício"],
  "preco_rotulo": "Na Black, até 30/11 às 23h59",
  "preco": "12x R$ 31,14",
  "preco_obs": "ou R$ 373,60 à vista · 7 dias de garantia",
  "cta": "Chame no WhatsApp",
  "rodape": "Instituto Nobel · escola com sede em Jaraguá-GO"
}
```
   Campos opcionais: `selo`, `subtitulo`, `itens`, `preco_rotulo`, `preco_obs`, `rodape`. No modelo `pergunta`, use `resposta`.
2. Rode: `node ~/time-ia/artes/gerar.mjs empresa/marketing/criativos/artes/AAAA-MM-DD-<nome>.json`
   As imagens saem ao lado do JSON: `...-<nome>-feed.png`, `...-story.png`.
3. Se aparecer:
   - `❌ texto proibido` → reescreva a frase (o motivo vem na mensagem) e rode de novo.
   - `⚠️ texto demais` → encurte título, subtítulo ou itens e rode de novo.
4. Abra a imagem e confira: preço e prazo iguais ao PERFIL, nada cortado, estágio citado (ASB).
5. Mande para a Vera (`revisor`) com o caminho do PNG. Com o ✅ dela, coloque em `empresa/aprovacoes/pendentes.md` com o caminho da imagem, para o pacote do Matheus.

## Regras
- Preço, prazo, garantia e condições **só** do PERFIL ou do Guia do Rafa. Nunca invente "últimas vagas" nem prazo falso.
- Arte de ASB sempre cita o estágio. Nunca "100% online", nunca prometer registro no CRO, vaga de estágio, emprego ou prazo de certificado (o gerador bloqueia, mas a responsabilidade é sua).
- Fotos de alunas ou da escola só com autorização por escrito.
