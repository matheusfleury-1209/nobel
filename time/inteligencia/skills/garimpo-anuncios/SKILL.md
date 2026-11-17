---
name: garimpo-anuncios
description: Pesquisa a Biblioteca de Anúncios da Meta para achar os anúncios do nicho que estão funcionando (ativos há muito tempo, com muitas variações), registra os padrões e indica os conceitos a modelar. Use semanalmente ou quando pedirem "o que os concorrentes estão anunciando que funciona".
---

# Garimpo de anúncios

1. Busque anúncios **ativos** no Brasil com 2 a 4 termos do nicho (ex.: "auxiliar de saúde bucal", "curso ASB", "ASB online").
2. Para as páginas que mais aparecem, busque todos os anúncios delas (ativos e inativos) e anote:
   - data de início de cada anúncio (dias no ar)
   - nº de variações do mesmo título
   - destino (WhatsApp ou página)
   - título e formato (vídeo/imagem/carrossel)
   - oferta (preço, parcela, Black, bônus)
3. Classifique cada conceito:
   - 🟢 provável vencedor (≥ 21 dias no ar ou ≥ 5 variações)
   - 🟡 em teste (< 21 dias, poucas variações)
   - 🔴 descartado (sumiu rápido)
4. Abra os 🟢 pelo link da Biblioteca (`ad_snapshot_url`) e descreva: gancho dos 3 primeiros segundos, estrutura do texto, prova usada, CTA. A API pode não trazer o texto: use o navegador ou peça ao Matheus um print.
5. Atualize `empresa/marketing/inteligencia/concorrentes.csv` (colunas: `data,page_id,pagina,anuncio_id,titulo,destino,formato,oferta,dias_no_ar,variacoes,classificacao,link`).
6. Relatório em `empresa/relatorios/AAAA-MM-DD-inteligencia-garimpo.md` com os padrões e os 3 conceitos mais promissores. Para cada um, diga se podemos usar com honestidade (o que a página confirma) ou não.
