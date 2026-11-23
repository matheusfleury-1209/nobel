#!/usr/bin/env node
// Fábrica de artes do Instituto Nobel.
// Gera PNG nos formatos feed (1080x1350), story (1080x1920) e quadrado (1080x1080)
// a partir de um arquivo JSON com os textos. O texto sai sempre exatamente como foi escrito
// (sem erro de português de IA) e passa por uma checagem de promessas proibidas.
//
// Uso:  node artes/gerar.mjs artes/exemplos/asb-black-oferta.json [mais.json ...]
//       (cada JSON pode ter "formatos": ["feed","story"] e "saida": "pasta/nome-base")
//
// Campos: modelo (oferta | beneficios | pergunta), curso, selo, titulo, subtitulo, itens[],
//         preco_rotulo, preco, preco_obs, cta, rodape, resposta (modelo pergunta)
import { readFileSync, mkdirSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createRequire } from "node:module";

const AQUI = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

// ---------------------------------------------------------------- regras de texto
const PROIBIDO = [
  [/100\s*%\s*online/i, "\"100% online\": o curso tem estágio presencial obrigatório"],
  [/garant\w*\s+(o\s+|seu\s+|a\s+sua\s+)?(registro|inscri[çc][ãa]o)/i, "prometer registro/inscrição no CRO"],
  [/garant\w*\s+(a\s+|sua\s+)?vaga\s+de\s+est[áa]gio/i, "prometer vaga de estágio"],
  [/garant\w*\s+(o\s+|seu\s+)?emprego/i, "prometer emprego"],
  [/reconhecid\w*\s+pelo\s+mec/i, "\"reconhecido pelo MEC\""],
  [/cro\s+reconhecid|credenciad\w*\s+(no|pelo|junto\s+ao)\s+(cro|cfo)/i, "\"reconhecido/credenciado no CRO/CFO\""],
  [/com\s+registro\s+(no\s+)?cro|registro\s+garantido/i, "prometer registro no CRO"],
  [/certificado\s+em\s+\d+\s+(dias|semanas|meses)/i, "prazo para o certificado"],
  [/[úu]ltimas\s+vagas/i, "\"últimas vagas\" (escassez falsa)"],
];

function checarTextos(d) {
  const tudo = [d.selo, d.titulo, d.subtitulo, d.resposta, d.preco_rotulo, d.preco, d.preco_obs, d.cta, d.rodape,
                ...(d.itens || [])].filter(Boolean).join(" \n ");
  const erros = PROIBIDO.filter(([re]) => re.test(tudo)).map(([, msg]) => msg);
  if ((d.curso || "").toLowerCase() === "asb" && !/est[áa]gio/i.test(tudo)) {
    erros.push("toda arte de ASB precisa citar o estágio (ex.: \"estágio de 60h em clínica\")");
  }
  return erros;
}

// ---------------------------------------------------------------- utilidades
const esc = (s) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const marca = (arq) => pathToFileURL(join(AQUI, "marca", arq)).href;
const ICONE_CHAT = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.4 8.4 0 0 1-12.3 7.4L3 21l2.1-5.6A8.4 8.4 0 1 1 21 11.5z"/></svg>`;
const ICONE_CHECK = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>`;

function precoHtml(preco) {
  const m = String(preco || "").match(/^\s*(\d+\s*x)\s*(.+)$/i);
  return m ? `<small>${esc(m[1])}</small>${esc(m[2])}` : esc(preco);
}
function tamanhoTitulo(t, base) {  // diminui a fonte em títulos longos
  const n = String(t || "").length;
  return n <= 28 ? base : n <= 45 ? Math.round(base * 0.86) : n <= 65 ? Math.round(base * 0.74) : Math.round(base * 0.64);
}

// ---------------------------------------------------------------- modelos
const MODELOS = {
  // Fundo escuro, preço em destaque. Bom para oferta com prazo.
  oferta: (d, f) => `
<div class="arte oferta ${f}" style="background:radial-gradient(120% 80% at 85% 0%, #0F4248 0%, var(--fundo-escuro) 60%)">
  <div class="hex" style="width:760px;height:860px;right:-300px;top:-260px;background:rgba(45,186,239,.10)"></div>
  <div class="hex" style="width:420px;height:480px;left:-210px;bottom:${f === "story" ? 520 : 300}px;background:rgba(148,217,248,.07)"></div>
  <img class="icone-fundo" src="${marca("icone.png")}" style="width:520px;right:-140px;bottom:${f === "story" ? 330 : 120}px;opacity:.16">
  <header><img class="logo" src="${marca("logo-negativo.png")}"></header>
  ${d.selo ? `<span class="selo" style="background:var(--ciano);color:var(--escuro)">${esc(d.selo)}</span>` : ""}
  <h1 style="color:#fff;font-size:${tamanhoTitulo(d.titulo, f === "quadrado" ? 80 : 92)}px">${esc(d.titulo)}</h1>
  ${d.subtitulo ? `<p class="sub" style="color:var(--ciano-claro)">${esc(d.subtitulo)}</p>` : ""}
  ${(d.itens || []).length ? `<ul style="list-style:none;display:flex;flex-wrap:wrap;gap:14px">${d.itens.map((i) =>
      `<li style="font-weight:700;font-size:30px;color:#fff;border:2px solid rgba(148,217,248,.55);border-radius:999px;padding:12px 24px">${esc(i)}</li>`).join("")}</ul>` : ""}
  <div class="espaco"></div>
  ${d.preco ? `<section class="preco" style="background:var(--ciano);color:var(--escuro);border-radius:36px;padding:34px 44px;display:flex;flex-direction:column;gap:10px">
    ${d.preco_rotulo ? `<div class="rotulo">${esc(d.preco_rotulo)}</div>` : ""}
    <div class="valor" style="font-size:${f === "quadrado" ? 96 : 112}px">${precoHtml(d.preco)}</div>
    ${d.preco_obs ? `<div class="obs">${esc(d.preco_obs)}</div>` : ""}
  </section>` : ""}
  <footer style="display:flex;flex-direction:column;gap:18px">
    ${d.cta ? `<div class="cta" style="align-self:flex-start;background:#fff;color:var(--escuro)">${ICONE_CHAT}${esc(d.cta)}</div>` : ""}
    ${d.rodape ? `<div class="rodape" style="color:rgba(255,255,255,.72)">${esc(d.rodape)}</div>` : ""}
  </footer>
</div>`,

  // Fundo claro, lista de benefícios com hexágonos. Bom para explicar o curso.
  beneficios: (d, f) => `
<div class="arte beneficios ${f}" style="background:var(--claro);gap:${f === "story" ? 34 : 20}px">
  <div class="hex" style="width:640px;height:730px;right:-260px;top:-200px;background:rgba(148,217,248,.35)"></div>
  <div class="hex" style="width:260px;height:300px;right:60px;top:${f === "story" ? 1040 : 820}px;background:rgba(45,186,239,.08)"></div>
  <header><img class="logo" src="${marca("logo-cor.png")}"></header>
  ${d.selo ? `<span class="selo" style="background:var(--escuro);color:var(--ciano)">${esc(d.selo)}</span>` : ""}
  <h1 style="color:var(--escuro);font-size:${tamanhoTitulo(d.titulo, f === "quadrado" ? 68 : 80)}px">${esc(d.titulo)}</h1>
  ${d.subtitulo ? `<p class="sub" style="color:var(--azul-petroleo)">${esc(d.subtitulo)}</p>` : ""}
  <ul style="list-style:none;display:flex;flex-direction:column;gap:${f === "story" ? 34 : 18}px">
    ${(d.itens || []).map((i) => `<li style="display:flex;align-items:center;gap:24px;font-weight:700;font-size:${f === "quadrado" ? 32 : 36}px;color:var(--escuro);line-height:1.2">
      <span style="flex:none;width:64px;height:72px;display:grid;place-items:center;background:var(--ciano);color:#fff;clip-path:polygon(50% 0,100% 25%,100% 75%,50% 100%,0 75%,0 25%)"><span style="width:36px;height:36px;display:block">${ICONE_CHECK}</span></span>
      <span>${esc(i)}</span></li>`).join("")}
  </ul>
  <div class="espaco"></div>
  <section style="background:var(--escuro);border-radius:36px;padding:30px 40px;display:flex;flex-direction:column;gap:16px">
    ${d.preco ? `<div class="preco" style="color:#fff;display:flex;flex-direction:column;gap:8px">
      ${d.preco_rotulo ? `<div class="rotulo" style="color:var(--ciano)">${esc(d.preco_rotulo)}</div>` : ""}
      <div class="valor" style="font-size:${f === "quadrado" ? 72 : 80}px">${precoHtml(d.preco)}</div>
      ${d.preco_obs ? `<div class="obs" style="color:rgba(255,255,255,.78)">${esc(d.preco_obs)}</div>` : ""}
    </div>` : ""}
    ${d.cta ? `<div class="cta" style="align-self:flex-start;background:var(--ciano);color:var(--escuro)">${ICONE_CHAT}${esc(d.cta)}</div>` : ""}
    ${d.rodape ? `<div class="rodape" style="color:rgba(255,255,255,.72);font-size:24px">${esc(d.rodape)}</div>` : ""}
  </section>
</div>`,

  // Fundo ciano, pergunta grande que prende a atenção. Bom para público específico.
  pergunta: (d, f) => `
<div class="arte pergunta ${f}" style="background:linear-gradient(165deg,var(--ciano) 0%,#1FA6DA 55%,var(--azul-petroleo) 100%)">
  <div class="hex" style="width:700px;height:800px;right:-280px;top:-240px;background:rgba(255,255,255,.12)"></div>
  <div class="hex" style="width:380px;height:430px;left:-180px;top:${f === "story" ? 900 : 640}px;background:rgba(13,54,58,.10)"></div>
  <header><img class="logo" src="${marca("logo-branco.png")}"></header>
  ${d.selo ? `<span class="selo" style="background:var(--escuro);color:#fff">${esc(d.selo)}</span>` : ""}
  <h1 style="color:#fff;font-size:${tamanhoTitulo(d.titulo, f === "quadrado" ? 88 : 104)}px">${esc(d.titulo)}</h1>
  ${d.resposta ? `<p style="background:#fff;color:var(--escuro);font-weight:700;font-size:${f === "quadrado" ? 36 : 42}px;line-height:1.25;border-radius:32px;padding:32px 38px">${esc(d.resposta)}</p>` : ""}
  ${d.subtitulo ? `<p class="sub" style="color:#fff">${esc(d.subtitulo)}</p>` : ""}
  <div class="espaco"></div>
  ${d.preco ? `<section class="preco" style="color:#fff;display:flex;flex-direction:column;gap:8px">
    ${d.preco_rotulo ? `<div class="rotulo" style="color:var(--escuro)">${esc(d.preco_rotulo)}</div>` : ""}
    <div class="valor" style="font-size:${f === "quadrado" ? 84 : 100}px">${precoHtml(d.preco)}</div>
    ${d.preco_obs ? `<div class="obs" style="color:#fff">${esc(d.preco_obs)}</div>` : ""}
  </section>` : ""}
  <footer style="display:flex;flex-direction:column;gap:18px">
    ${d.cta ? `<div class="cta" style="align-self:flex-start;background:var(--escuro);color:#fff">${ICONE_CHAT}${esc(d.cta)}</div>` : ""}
    ${d.rodape ? `<div class="rodape" style="color:rgba(255,255,255,.88)">${esc(d.rodape)}</div>` : ""}
  </footer>
</div>`,
};

function pagina(d, f) {
  const css = pathToFileURL(join(AQUI, "modelos", "base.css")).href;
  const html = MODELOS[d.modelo](d, f);
  return `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><link rel="stylesheet" href="${css}"></head>
<body class="${f}">${html}</body></html>`;
}

// ---------------------------------------------------------------- execução
const arquivos = process.argv.slice(2);
if (!arquivos.length) {
  console.error("Uso: node artes/gerar.mjs <arte.json> [mais.json ...]");
  process.exit(2);
}
const { chromium } = require("playwright");
const browser = await chromium.launch();
const TMP = mkdtempSync(join(tmpdir(), "nobel-arte-"));
let falhou = false, n = 0;
try {
  for (const arq of arquivos) {
    const d = JSON.parse(readFileSync(arq, "utf8"));
    if (!MODELOS[d.modelo]) { console.error(`❌ ${arq}: modelo "${d.modelo}" não existe (use: ${Object.keys(MODELOS).join(", ")})`); falhou = true; continue; }
    const erros = checarTextos(d);
    if (erros.length) { console.error(`❌ ${arq}: texto proibido → ${erros.join("; ")}`); falhou = true; continue; }
    const base = resolve(d.saida || arq.replace(/\.json$/i, ""));
    mkdirSync(dirname(base), { recursive: true });
    for (const f of d.formatos || ["feed"]) {
      const [w, h] = { feed: [1080, 1350], story: [1080, 1920], quadrado: [1080, 1080] }[f] || [];
      if (!w) { console.error(`❌ formato "${f}" não existe (feed, story, quadrado)`); falhou = true; continue; }
      const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
      const html = join(TMP, `pagina-${++n}.html`);
      writeFileSync(html, pagina(d, f));
      await page.goto(pathToFileURL(html).href, { waitUntil: "load" });
      await page.evaluate(() => document.fonts.ready);
      // aviso se algum texto passou da área da arte
      const estourou = await page.evaluate(() => {
        const a = document.querySelector(".arte");
        return a.scrollHeight > a.clientHeight + 2;
      });
      const saida = `${base}-${f}.png`;
      await page.screenshot({ path: saida, type: "png" });
      await page.close();
      console.log(`${estourou ? "⚠️  texto demais (encurte)" : "✅"} ${saida}`);
      if (estourou) falhou = true;
    }
  }
} finally {
  await browser.close();
  rmSync(TMP, { recursive: true, force: true });
}
process.exit(falhou ? 1 : 0);
