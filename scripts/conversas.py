#!/usr/bin/env python3
"""Lista automática das conversas do Rafa no WhatsApp, lida direto do banco do OpenClaw (sem IA).

Não depende do Rafa lembrar de anotar: cada pessoa que conversou com ele aparece em
<EMPRESA_DIR>/vendas/conversas.csv, com quando falou, se está esperando resposta, se recebeu
o link de pagamento e se já comprou (cruzando com a Hotmart).

Uso:
  python3 scripts/conversas.py               # atualiza conversas.csv e conversas-resumo.md
  python3 scripts/conversas.py --vigia       # imprime "N MIN": quantos esperam resposta há mais de 15 min e a maior espera
  python3 scripts/conversas.py --diagnostico # mostra a estrutura (números mascarados) para conferir o formato

Banco: ~/.openclaw/agents/vendedor/agent/openclaw-agent.sqlite (aberto só para leitura).
Números internos (Matheus, Hanielly) ficam fora: ~/.config/nobel/internos.txt, um por linha.
"""

import csv
import json
import os
import re
import sqlite3
import sys
import time
from datetime import datetime, timedelta, timezone

BRT = timezone(timedelta(hours=-3))
HOME = os.path.expanduser("~")
OPENCLAW = os.environ.get("OPENCLAW_HOME", os.path.join(HOME, ".openclaw"))
EMPRESA = os.environ.get("EMPRESA_DIR", os.path.join(OPENCLAW, "empresa"))
DB = os.environ.get("CONVERSAS_DB", os.path.join(OPENCLAW, "agents", "vendedor", "agent", "openclaw-agent.sqlite"))
SAIDA = os.path.join(EMPRESA, "vendas", "conversas.csv")
RESUMO = os.path.join(EMPRESA, "vendas", "conversas-resumo.md")
VENDAS = os.path.join(EMPRESA, "vendas", "hotmart", "vendas.csv")
INTERNOS = os.path.join(HOME, ".config", "nobel", "internos.txt")
ESPERA_ALERTA_MIN = 15
COLUNAS = ["telefone", "contato", "primeira_mensagem", "ultima_do_cliente", "ultima_do_rafa", "msgs_cliente",
           "msgs_rafa", "esperando_min", "link_enviado", "comprou", "situacao"]


def segundos(v):
    """created_at pode vir em ms, s ou texto ISO."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return v / 1000 if v > 1e12 else float(v)
    s = str(v).strip()
    if re.fullmatch(r"\d+(\.\d+)?", s):
        return segundos(float(s))
    try:
        d = datetime.fromisoformat(s.replace("Z", "+00:00"))
        return (d if d.tzinfo else d.replace(tzinfo=timezone.utc)).timestamp()
    except ValueError:
        return None


def br(ts):
    return datetime.fromtimestamp(ts, tz=BRT).strftime("%Y-%m-%d %H:%M") if ts else ""


def digitos_telefone(*valores):
    for v in valores:
        for m in re.findall(r"\d{10,13}", str(v or "")):
            if m.startswith("55") and len(m) in (12, 13):
                return "+" + m
            if len(m) in (10, 11):
                return "+55" + m
    return ""


def internos():
    nums = set()
    try:
        with open(INTERNOS, encoding="utf-8") as f:
            for l in f:
                d = re.sub(r"\D", "", l)
                if len(d) >= 10:
                    nums.add(d if d.startswith("55") else "55" + d)
    except OSError:
        pass
    # as duas formas (com e sem o 9) de cada número
    extra = set()
    for d in nums:
        if len(d) == 13:
            extra.add(d[:4] + d[5:])
        elif len(d) == 12:
            extra.add(d[:4] + "9" + d[4:])
    return nums | extra


def compradores():
    tels = set()
    try:
        with open(VENDAS, encoding="utf-8") as f:
            for r in csv.DictReader(f):
                if r.get("status") in ("APPROVED", "COMPLETE") and r.get("telefone"):
                    d = re.sub(r"\D", "", r["telefone"])
                    tels.add(d)
                    if len(d) == 13:
                        tels.add(d[:4] + d[5:])
                    elif len(d) == 12:
                        tels.add(d[:4] + "9" + d[4:])
    except OSError:
        pass
    return tels


def abrir():
    if not os.path.isfile(DB):
        raise SystemExit(f"Banco do Rafa não encontrado: {DB}")
    c = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=10)
    c.row_factory = sqlite3.Row
    return c


def colunas(c, tabela):
    return {r[1] for r in c.execute(f'pragma table_info("{tabela}")')}


def coletar(c):
    conv_cols = colunas(c, "conversations")
    pegar = [x for x in ("conversation_id", "channel", "account_id", "kind", "peer_id", "delivery_target",
                         "native_direct_user_id", "label", "metadata_json") if x in conv_cols]
    convs = [dict(r) for r in c.execute(f"select {', '.join(pegar)} from conversations")]
    sessoes_por_conv = {}
    for r in c.execute("select conversation_id, session_id from session_conversations"):
        sessoes_por_conv.setdefault(r["conversation_id"], set()).add(r["session_id"])
    ev_cols = colunas(c, "transcript_events")
    tem_json = "event_json" in ev_cols
    tem_fts = bool(c.execute("select 1 from sqlite_master where name='session_transcript_fts'").fetchone())
    pessoas = {}
    for cv in convs:
        if (cv.get("channel") or "").lower() != "whatsapp":
            continue
        if (cv.get("kind") or "direct").lower() not in ("direct", "dm", "private"):
            continue
        tel = digitos_telefone(cv.get("peer_id"), cv.get("delivery_target"), cv.get("native_direct_user_id"),
                               cv.get("metadata_json"))
        chave = tel or str(cv.get("peer_id") or cv.get("conversation_id"))
        p = pessoas.setdefault(chave, {"telefone": tel, "contato": cv.get("label") or "", "eventos": [], "link": False})
        for sid in sessoes_por_conv.get(cv["conversation_id"], ()):
            campos = "seq, created_at, message_role" + (", event_json" if tem_json else "")
            for e in c.execute(f"select {campos} from transcript_events where session_id = ? order by seq", (sid,)):
                papel = (e["message_role"] or "").lower()
                if papel not in ("user", "assistant"):
                    continue
                t = segundos(e["created_at"])
                if t:
                    p["eventos"].append((t, papel))
                if papel == "assistant" and tem_json and e["event_json"] and "pay.hotmart.com" in e["event_json"]:
                    p["link"] = True
            if tem_fts and not p["link"]:
                try:
                    if c.execute("select 1 from session_transcript_fts where session_id = ? and role = 'assistant' "
                                 "and text like '%hotmart%' limit 1", (sid,)).fetchone():
                        p["link"] = True
                except sqlite3.Error:
                    pass
    return pessoas


def montar(pessoas):
    agora = time.time()
    fora = internos()
    compraram = compradores()
    linhas = []
    for p in pessoas.values():
        dig = re.sub(r"\D", "", p["telefone"])
        if dig and dig in fora:
            continue
        ev = sorted(p["eventos"])
        cliente = [t for t, r in ev if r == "user"]
        rafa = [t for t, r in ev if r == "assistant"]
        if not cliente:
            continue
        ult_c, ult_r = max(cliente), (max(rafa) if rafa else None)
        esperando = int((agora - ult_c) // 60) if (ult_r is None or ult_r < ult_c) else 0
        comprou = bool(dig) and dig in compraram
        situacao = ("comprou" if comprou else "esperando resposta" if esperando else
                    "recebeu o link" if p["link"] else "em conversa")
        linhas.append({
            "telefone": p["telefone"], "contato": p["contato"], "primeira_mensagem": br(min(cliente)),
            "ultima_do_cliente": br(ult_c), "ultima_do_rafa": br(ult_r), "msgs_cliente": len(cliente),
            "msgs_rafa": len(rafa), "esperando_min": esperando, "link_enviado": "sim" if p["link"] else "não",
            "comprou": "sim" if comprou else "não", "situacao": situacao, "_ult": ult_c})
    linhas.sort(key=lambda l: l["_ult"], reverse=True)
    return linhas


def gravar(linhas):
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    tmp = f"{SAIDA}.{os.getpid()}.tmp"
    antigo = os.umask(0o077)
    try:
        with open(tmp, "w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=COLUNAS, extrasaction="ignore")
            w.writeheader()
            w.writerows(linhas)
    finally:
        os.umask(antigo)
    os.replace(tmp, SAIDA)
    hoje = datetime.now(BRT).strftime("%Y-%m-%d")
    ontem = (datetime.now(BRT) - timedelta(days=1)).strftime("%Y-%m-%d")
    novas = lambda d: sum(1 for l in linhas if l["primeira_mensagem"].startswith(d))
    esperando = [l for l in linhas if l["esperando_min"] >= ESPERA_ALERTA_MIN]
    texto = "\n".join([
        "# Conversas do Rafa — resumo automático",
        "",
        f"Atualizado em {datetime.now(BRT).strftime('%d/%m/%Y %H:%M')} (a cada 5 minutos, direto do WhatsApp, sem IA).",
        "Detalhes por pessoa em `conversas.csv` (dados pessoais: use só para atender).",
        "",
        f"- Conversas novas hoje: {novas(hoje)} · ontem: {novas(ontem)} · total: {len(linhas)}",
        f"- Receberam o link de pagamento: {sum(1 for l in linhas if l['link_enviado'] == 'sim')}",
        f"- Compraram (cruzando com a Hotmart pelo telefone): {sum(1 for l in linhas if l['comprou'] == 'sim')}",
        f"- Esperando resposta há mais de {ESPERA_ALERTA_MIN} min agora: {len(esperando)}",
        "",
    ])
    with open(RESUMO, "w", encoding="utf-8") as f:
        f.write(texto)


def main():
    c = abrir()
    if "--diagnostico" in sys.argv:
        mask = lambda s: re.sub(r"\d", "#", str(s))
        for r in c.execute("select * from conversations limit 3"):
            d = dict(r)
            print({k: (mask(v)[:50] if v is not None else None) for k, v in d.items() if k != "metadata_json"})
        print("papéis:", [tuple(r) for r in c.execute(
            "select message_role, count(*) from transcript_events group by message_role")])
        print("exemplo de created_at:", [r[0] for r in c.execute("select created_at from transcript_events limit 2")])
    pessoas = coletar(c)
    linhas = montar(pessoas)
    if "--vigia" in sys.argv:
        esperando = [l["esperando_min"] for l in linhas if ESPERA_ALERTA_MIN <= l["esperando_min"] <= 24 * 60]
        print(f"{len(esperando)} {max(esperando) if esperando else 0}")
        gravar(linhas)
        return
    gravar(linhas)
    if "--quieto" not in sys.argv:
        print(f"✅ {len(linhas)} conversas · esperando resposta agora: "
              f"{sum(1 for l in linhas if l['esperando_min'] >= ESPERA_ALERTA_MIN)} · arquivo: {SAIDA}")


if __name__ == "__main__":
    main()
