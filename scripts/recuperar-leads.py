#!/usr/bin/env python3
"""Recupera empresa/vendas/leads.csv a partir das conversas guardadas dos agentes.

Os agentes escrevem a planilha com as ferramentas de arquivo (write/edit) e às vezes a leem (read).
Tudo isso fica nos históricos em ~/.openclaw/agents/*/sessions/*.jsonl. Este programa:
  1. acha a versão completa mais recente da planilha (uma escrita inteira ou uma leitura);
  2. aplica, em ordem, as edições feitas depois dela;
  3. junta com o que sobrou no arquivo atual (linhas cujo id não apareceu na recuperação);
  4. grava leads.recuperado.csv para conferência. Só troca o arquivo com --aplicar (e guarda backup).

Uso:
  python3 scripts/recuperar-leads.py            # só mostra e grava leads.recuperado.csv
  python3 scripts/recuperar-leads.py --aplicar  # troca leads.csv pela versão recuperada
"""

import csv
import glob
import io
import json
import os
import shutil
import sys
import time
from datetime import datetime

HOME = os.path.expanduser("~")
OPENCLAW = os.environ.get("OPENCLAW_HOME", os.path.join(HOME, ".openclaw"))
ARQ = os.path.join(os.environ.get("EMPRESA_DIR", os.path.join(OPENCLAW, "empresa")), "vendas", "leads.csv")
CABECALHO = "id,data_entrada,nome"
CHAVES_CAMINHO = ("path", "file_path", "filePath", "file", "filename")
VELHO = ("oldText", "old_string", "old_str", "oldString", "search")
NOVO = ("newText", "new_string", "new_str", "newString", "replace")


def quando(obj, padrao):
    for k in ("timestamp", "ts", "time", "createdAt", "created_at", "date"):
        v = obj.get(k) if isinstance(obj, dict) else None
        if isinstance(v, (int, float)):
            return float(v) / (1000 if v > 1e12 else 1)
        if isinstance(v, str):
            try:
                return datetime.fromisoformat(v.replace("Z", "+00:00")).timestamp()
            except ValueError:
                pass
    return padrao


def caminho_eh_leads(d):
    return any(isinstance(d.get(k), str) and d[k].replace("\\", "/").endswith("vendas/leads.csv") for k in CHAVES_CAMINHO)


def extrair(no, achados):
    """Procura, recursivamente, escritas/edições de leads.csv e textos que são a planilha inteira."""
    if isinstance(no, dict):
        if caminho_eh_leads(no):
            if isinstance(no.get("content"), str):
                achados.append(("completo", no["content"]))
            velho = next((no[k] for k in VELHO if isinstance(no.get(k), str)), None)
            novo = next((no[k] for k in NOVO if isinstance(no.get(k), str)), None)
            if velho is not None and novo is not None:
                achados.append(("edicao", (velho, novo)))
            for e in no.get("edits") or []:
                if isinstance(e, dict):
                    v = next((e[k] for k in VELHO if isinstance(e.get(k), str)), None)
                    n = next((e[k] for k in NOVO if isinstance(e.get(k), str)), None)
                    if v is not None and n is not None:
                        achados.append(("edicao", (v, n)))
        for v in no.values():
            extrair(v, achados)
    elif isinstance(no, list):
        for v in no:
            extrair(v, achados)
    elif isinstance(no, str):
        t = no.strip()
        if t.startswith(CABECALHO):
            achados.append(("completo", t + "\n"))
        elif t.startswith("{") and "leads.csv" in t:
            try:
                extrair(json.loads(t), achados)
            except ValueError:
                pass


def coletar():
    ops = []
    arquivos = glob.glob(os.path.join(OPENCLAW, "agents", "*", "sessions", "*.jsonl*"))
    for arq in arquivos:
        base_t = os.path.getmtime(arq)
        try:
            with open(arq, encoding="utf-8", errors="replace") as f:
                for i, linha in enumerate(f):
                    if "leads.csv" not in linha and CABECALHO not in linha:
                        continue
                    try:
                        obj = json.loads(linha)
                    except ValueError:
                        continue
                    achados = []
                    extrair(obj, achados)
                    t = quando(obj, base_t - 1e6 + i)
                    for k, (tipo, dado) in enumerate(achados):
                        ops.append((t, i, k, tipo, dado))
        except OSError:
            continue
    ops.sort(key=lambda o: (o[0], o[1], o[2]))
    return ops, len(arquivos)


def ids(texto):
    out = {}
    for campos in csv.reader(io.StringIO(texto)):
        if campos and campos[0] and campos[0] != "id":
            out[campos[0]] = campos
    return out


def main():
    aplicar = "--aplicar" in sys.argv
    atual = open(ARQ, encoding="utf-8").read() if os.path.isfile(ARQ) else ""
    ops, n_arq = coletar()
    completos = [i for i, o in enumerate(ops) if o[3] == "completo"]
    print(f"Históricos lidos: {n_arq} · versões completas achadas: {len(completos)} · "
          f"edições achadas: {sum(1 for o in ops if o[3] == 'edicao')}")
    if not completos:
        print("❌ Não achei nenhuma versão completa da planilha nos históricos. Me mande este print.")
        sys.exit(1)
    def reconstruir(inicio):
        texto, ok, falhou = ops[inicio][4], 0, 0
        for _, _, _, tipo, dado in ops[inicio + 1:]:
            if tipo == "completo":
                # uma versão completa posterior só substitui se não for menor (evita pegar a versão cortada)
                if len(ids(dado)) >= len(ids(texto)):
                    texto = dado
                continue
            velho, novo = dado
            if velho and velho in texto:
                texto, ok = texto.replace(velho, novo, 1), ok + 1
            else:
                falhou += 1
        return texto, ok, falhou
    # testa as 30 versões completas mais recentes como ponto de partida e fica com a que guarda mais leads
    melhor = None
    for inicio in completos[-30:]:
        r = reconstruir(inicio)
        if melhor is None or len(ids(r[0])) >= len(ids(melhor[0])):
            melhor = r
    texto, ok, falhou = melhor
    rec = ids(texto)
    cur = ids(atual)
    faltando_no_atual = [i for i in rec if i not in cur]
    so_no_atual = [i for i in cur if i not in rec]
    linhas = texto.rstrip("\n").splitlines()
    cab = linhas[0] if linhas and linhas[0].startswith("id,") else (atual.splitlines()[0] if atual else "")
    corpo = [l for l in linhas[1:] if l.strip()]
    # linhas que só existem no arquivo atual entram no fim, sem mudar nada
    for l in atual.splitlines()[1:]:
        campos = next(csv.reader([l]), [])
        if campos and campos[0] in so_no_atual:
            corpo.append(l)
    final = cab + "\n" + "\n".join(corpo) + "\n"
    saida = ARQ.replace(".csv", ".recuperado.csv")
    with open(saida, "w", encoding="utf-8") as f:
        f.write(final)
    print(f"Planilha atual: {len(cur)} leads · recuperada: {len(rec)} leads · edições aplicadas {ok}, puladas {falhou}")
    print(f"Leads que tinham sumido e voltam: {len(faltando_no_atual)}")
    print(f"Versão recuperada gravada em: {saida}")
    if aplicar:
        bak = f"{ARQ}.antes-da-recuperacao-{time.strftime('%Y%m%d-%H%M%S')}"
        if os.path.isfile(ARQ):
            shutil.copy2(ARQ, bak)
        shutil.copy2(saida, ARQ)
        print(f"✅ leads.csv substituída pela versão recuperada (a anterior ficou em {bak})")
    else:
        print("Nada foi trocado ainda. Se os números fizerem sentido, rode de novo com --aplicar")


if __name__ == "__main__":
    main()
