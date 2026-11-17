---
name: copy-anuncio
description: Escreve copies de anúncios (Meta Ads, Google Ads) em variações para teste A/B, com ganchos, textos principais, títulos e CTAs. Use quando o tráfego pedir criativos ou houver campanha nova.
---

# Copy de anúncio

1. Leia o plano da campanha (`empresa/marketing/trafego/planos/`) e o PERFIL (oferta, público, dores, diferenciais, provas reais).
2. Gere 3 ângulos diferentes: **Dor** (problema → solução), **Desejo** (resultado → como chegar), **Prova** (caso real, número real, autoridade).
3. Para cada ângulo, Meta Ads:
   - Texto principal curto (até 125 caracteres antes do "ver mais") e versão longa.
   - Título (até 40 caracteres) e descrição.
   - Gancho dos 3 primeiros segundos para vídeo.
4. Google Ads (pesquisa): 15 títulos (≤ 30 caracteres) e 4 descrições (≤ 90 caracteres), com palavras-chave do plano.
5. Tabela final: ID da variação (ex.: `DOR-A`), plataforma, textos. O ID vai no nome do anúncio para o `trafego` medir.
6. Salve em `empresa/marketing/criativos/AAAA-MM-DD-<campanha>-copies.md` e avise o `trafego`.
