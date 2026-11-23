# Fábrica de artes do Instituto Nobel

Gera PNG com a marca (logo, cores e fonte Inter) nos formatos **feed 1080×1350**, **story 1080×1920** e **quadrado 1080×1080**.
O texto vem de um JSON e sai exatamente como escrito. Antes de gerar, o programa bloqueia promessas proibidas
("100% online", registro no CRO garantido, vaga de estágio garantida, MEC, prazo de certificado, "últimas vagas")
e exige que toda arte de ASB cite o estágio.

```
node artes/gerar.mjs artes/exemplos/asb-black-oferta.json
```

- Modelos: `oferta` (escuro, preço em destaque), `beneficios` (claro, lista), `pergunta` (ciano, pergunta grande).
- Marca: `marca/logo-cor.png`, `marca/logo-negativo.png` (fundo escuro), `marca/logo-branco.png` (fundo colorido), `marca/icone.png`.
- Cores: ciano `#2DBAEF`, azul-petróleo `#2793B0`, ciano-claro `#94D9F8`, escuro `#0D363A` (definidas em `modelos/base.css`).
- Na VPS: instale com `bash scripts/ligar-artes.sh` (Playwright + Chromium). A Duda usa a skill `fabrica-de-artes`.
- Próximo passo: modelos com foto real (quando houver fotos autorizadas na pasta "Nobel - Marca" do Drive).
