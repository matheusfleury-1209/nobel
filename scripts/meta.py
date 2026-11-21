#!/usr/bin/env python3
"""Números dos anúncios da Meta para o time, SOMENTE LEITURA (token com ads_read).

Uso (na VPS):
  python3 scripts/meta.py contas          # lista as contas de anúncios que o token enxerga
  python3 scripts/meta.py testar
  python3 scripts/meta.py sincronizar [--dias 30] [--quieto]

Credenciais: arquivo META_ENV (padrão ~/.config/nobel/meta.env), criado por scripts/ligar-meta.sh:
  META_TOKEN=...            token do usuário do sistema (permissão ads_read)
  META_CONTA=act_123...     conta de anúncios
  META_API_VERSION=v27.0    versão da API; se a Meta avisar que ficou velha, o programa troca sozinho

O que ele grava em <EMPRESA_DIR>/marketing/trafego/meta/ (padrão ~/.openclaw/empresa/...):
  diario.csv   um dia por anúncio (últimos 30 dias): gasto, impressões, cliques, conversas...
  ativos.csv   anúncios no ar, em revisão ou com problema, com status e orçamento
  resumo.md    hoje, ontem e 7 dias; por campanha; por anúncio; alertas

Este programa só CONSULTA a Meta. Ele não cria, não pausa e não muda nada.
"""

import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta, timezone

BRT = timezone(timedelta(hours=-3))
VERSAO_PADRAO = "v27.0"
HOME = os.path.expanduser("~")
ENV_FILE = os.environ.get("META_ENV", os.path.join(HOME, ".config", "nobel", "meta.env"))
EMPRESA_DIR = os.environ.get(
    "EMPRESA_DIR",
    os.path.join(os.environ.get("OPENCLAW_HOME", os.path.join(HOME, ".openclaw")), "empresa"),
)
SAIDA = os.path.join(EMPRESA_DIR, "marketing", "trafego", "meta")

ACOES = {  # action_type da Meta -> coluna
    "onsite_conversion.messaging_conversation_started_7d": "conversas",
    "onsite_conversion.messaging_first_reply": "primeiras_respostas",
    "lead": "leads",
    "offsite_conversion.fb_pixel_purchase": "compras_pixel",
}
COLUNAS_DIARIO = [
    "data", "campanha_id", "campanha", "conjunto", "anuncio_id", "anuncio", "gasto", "impressoes",
    "alcance", "frequencia", "cliques_link", "ctr", "cpm", "conversas", "primeiras_respostas",
    "leads", "compras_pixel",
]
COLUNAS_ATIVOS = [
    "anuncio_id", "anuncio", "status", "campanha", "status_campanha", "orcamento_campanha_dia",
    "conjunto", "status_conjunto", "orcamento_conjunto_dia", "problemas",
]
STATUS_PT = {
    "ACTIVE": "no ar", "PAUSED": "pausado", "CAMPAIGN_PAUSED": "campanha pausada",
    "ADSET_PAUSED": "conjunto pausado", "PENDING_REVIEW": "em revisão", "IN_PROCESS": "em revisão",
    "DISAPPROVED": "REPROVADO", "WITH_ISSUES": "COM PROBLEMA", "PREAPPROVED": "pré-aprovado",
    "PENDING_BILLING_INFO": "falta pagamento", "ARCHIVED": "arquivado", "DELETED": "excluído",
}
VER_STATUS = ["ACTIVE", "PENDING_REVIEW", "IN_PROCESS", "DISAPPROVED", "WITH_ISSUES",
              "PREAPPROVED", "PENDING_BILLING_INFO"]


class ErroMeta(Exception):
    pass


def ler_env():
    if not os.path.isfile(ENV_FILE):
        raise ErroMeta(f"Não achei {ENV_FILE}. Rode antes: bash scripts/ligar-meta.sh")
    cfg = {}
    with open(ENV_FILE, encoding="utf-8") as f:
        for linha in f:
            linha = linha.strip()
            if linha and not linha.startswith("#") and "=" in linha:
                k, v = linha.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"').strip("'")
    if not cfg.get("META_TOKEN"):
        raise ErroMeta(f"Falta META_TOKEN em {ENV_FILE}")
    return cfg


class Meta:
    def __init__(self, exigir_conta=True):
        self.cfg = ler_env()
        self._usar_versao(self.cfg.get("META_API_VERSION", "").strip("/") or VERSAO_PADRAO)
        self.conta = self.cfg.get("META_CONTA", "")
        if self.conta and not self.conta.startswith("act_"):
            self.conta = "act_" + self.conta
        if exigir_conta and not self.conta:
            raise ErroMeta(f"Falta META_CONTA em {ENV_FILE}. Rode: TROCAR=1 bash scripts/ligar-meta.sh")
        self.chamadas = 0

    def _usar_versao(self, ver):
        self.versao = ver
        self.base = f"https://graph.facebook.com/{ver}/"

    def _atualizar_versao(self, mensagem, url):
        """Erro #2635: a Meta diz qual é a versão atual. Passa a usar ela e salva no meta.env."""
        achou = re.search(r"(v\d+\.\d+)", mensagem.split("latest version", 1)[-1])
        if not achou or achou.group(1) == self.versao:
            return None
        nova = achou.group(1)
        self._usar_versao(nova)
        try:
            with open(ENV_FILE, encoding="utf-8") as f:
                texto = f.read()
            if re.search(r"^META_API_VERSION=.*$", texto, flags=re.M):
                texto = re.sub(r"^META_API_VERSION=.*$", f"META_API_VERSION={nova}", texto, flags=re.M)
            else:
                texto = texto.rstrip("\n") + f"\nMETA_API_VERSION={nova}\n"
            with open(ENV_FILE, "w", encoding="utf-8") as f:
                f.write(texto)
        except OSError:
            pass
        return re.sub(r"graph\.facebook\.com/(v\d+\.\d+/)?", f"graph.facebook.com/{nova}/", url, count=1)

    def _get_url(self, url):
        espera = 5
        trocou_versao = False
        for tentativa in range(6):
            self.chamadas += 1
            req = urllib.request.Request(url, headers={"Authorization": f"Bearer {self.cfg['META_TOKEN']}"})
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    return json.loads(r.read().decode("utf-8"))
            except urllib.error.HTTPError as e:
                try:
                    err = json.loads(e.read().decode("utf-8")).get("error", {})
                except ValueError:
                    err = {}
                codigo = err.get("code")
                msg = err.get("message", "")
                if (codigo == 2635 or "#2635" in msg or "deprecated version" in msg) and not trocou_versao:
                    nova_url = self._atualizar_versao(msg, url)
                    if nova_url:
                        trocou_versao = True
                        url = nova_url
                        continue
                if codigo in (4, 17, 32, 613, 80000, 80004) or e.code >= 500:  # limite de uso / instabilidade
                    if tentativa < 4:
                        time.sleep(espera)
                        espera *= 2
                        continue
                if codigo == 190:
                    raise ErroMeta("O token da Meta foi recusado ou expirou. Gere outro e rode: TROCAR=1 bash scripts/ligar-meta.sh")
                if codigo in (10, 200, 294) or e.code == 403:
                    raise ErroMeta("O token não tem permissão para esta conta. Confira se o usuário do sistema "
                                   "tem a conta de anúncios atribuída e a permissão ads_read.")
                raise ErroMeta(f"A Meta respondeu erro {e.code}: {err.get('message', 'sem detalhe')}")
            except (urllib.error.URLError, TimeoutError) as e:
                if tentativa < 4:
                    time.sleep(espera)
                    espera *= 2
                    continue
                raise ErroMeta(f"Sem conexão com a Meta: {e}")
        raise ErroMeta("A Meta não respondeu depois de várias tentativas")

    def get(self, caminho, params=None):
        q = urllib.parse.urlencode(params or {})
        return self._get_url(f"{self.base}{caminho}" + (f"?{q}" if q else ""))

    def listar(self, caminho, params):
        dados = self.get(caminho, params)
        itens = list(dados.get("data") or [])
        for _ in range(100):
            prox = (dados.get("paging") or {}).get("next")
            if not prox:
                break
            dados = self._get_url(prox)
            itens.extend(dados.get("data") or [])
        return itens


# ---------------------------------------------------------------- utilidades
def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def brl(v):
    return "R$ " + f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def gravar_csv(caminho, colunas, linhas):
    tmp = f"{caminho}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=colunas, extrasaction="ignore")
        w.writeheader()
        w.writerows(linhas)
    os.replace(tmp, caminho)


def gravar_texto(caminho, texto):
    tmp = f"{caminho}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(texto)
    os.replace(tmp, caminho)


def cel(texto):
    """Texto seguro dentro de tabela Markdown (nomes de campanha usam '|')."""
    return str(texto).replace("|", "\\|")


def custo_por(gasto, qtd):
    return brl(gasto / qtd) if qtd else "—"


# ---------------------------------------------------------------- comandos
def cmd_contas(args):
    m = Meta(exigir_conta=False)
    contas = m.listar("me/adaccounts", {"fields": "account_id,name,currency,account_status", "limit": 100})
    for c in contas:
        if args.tsv:
            print(f"act_{c.get('account_id')}\t{c.get('name', '')}")
        else:
            print(f"act_{c.get('account_id')}  {c.get('name', '')}  ({c.get('currency', '')})")
    if not contas and not args.tsv:
        print("Nenhuma conta de anúncios atribuída a este token.")


def cmd_testar(_args):
    m = Meta()
    c = m.get(m.conta, {"fields": "name,currency,timezone_name,account_status"})
    ativas = m.listar(f"{m.conta}/campaigns", {
        "fields": "id", "limit": 200, "effective_status": json.dumps(["ACTIVE"]),
    })
    print(f"✅ Conectado à conta de anúncios \"{c.get('name')}\" ({c.get('currency')}, {c.get('timezone_name')}). "
          f"Campanhas no ar agora: {len(ativas)}")


def coletar_diario(m, dias):
    hoje = datetime.now(BRT).date()
    inicio = hoje - timedelta(days=dias - 1)
    itens = m.listar(f"{m.conta}/insights", {
        "level": "ad",
        "time_increment": 1,
        "time_range": json.dumps({"since": inicio.isoformat(), "until": hoje.isoformat()}),
        "fields": ",".join([
            "date_start", "campaign_id", "campaign_name", "adset_name", "ad_id", "ad_name", "spend",
            "impressions", "reach", "frequency", "inline_link_clicks", "ctr", "cpm", "actions",
        ]),
        "limit": 500,
    })
    linhas = []
    for it in itens:
        acoes = {a.get("action_type"): num(a.get("value")) for a in it.get("actions") or []}
        linha = {
            "data": it.get("date_start", ""),
            "campanha_id": it.get("campaign_id", ""),
            "campanha": it.get("campaign_name", ""),
            "conjunto": it.get("adset_name", ""),
            "anuncio_id": it.get("ad_id", ""),
            "anuncio": it.get("ad_name", ""),
            "gasto": round(num(it.get("spend")), 2),
            "impressoes": int(num(it.get("impressions"))),
            "alcance": int(num(it.get("reach"))),
            "frequencia": round(num(it.get("frequency")), 2),
            "cliques_link": int(num(it.get("inline_link_clicks"))),
            "ctr": round(num(it.get("ctr")), 2),
            "cpm": round(num(it.get("cpm")), 2),
        }
        for tipo, col in ACOES.items():
            linha[col] = int(acoes.get(tipo, 0))
        linhas.append(linha)
    linhas.sort(key=lambda l: (l["data"], l["campanha"], l["anuncio"]), reverse=True)
    return linhas


def coletar_ativos(m):
    ads = m.listar(f"{m.conta}/ads", {
        "fields": ("id,name,effective_status,issues_info,ad_review_feedback,"
                   "campaign{name,effective_status,daily_budget},adset{name,effective_status,daily_budget}"),
        "effective_status": json.dumps(VER_STATUS),
        "limit": 200,
    })
    linhas = []
    for a in ads:
        camp, cj = a.get("campaign") or {}, a.get("adset") or {}
        problemas = []
        for p in a.get("issues_info") or []:
            problemas.append(p.get("error_summary") or p.get("error_message") or "")
        revisao = (a.get("ad_review_feedback") or {}).get("global")
        if isinstance(revisao, dict):
            problemas += [f"{motivo}: {texto}" for motivo, texto in revisao.items()]
        linhas.append({
            "anuncio_id": a.get("id", ""),
            "anuncio": a.get("name", ""),
            "status": STATUS_PT.get(a.get("effective_status"), a.get("effective_status", "")),
            "campanha": camp.get("name", ""),
            "status_campanha": STATUS_PT.get(camp.get("effective_status"), camp.get("effective_status", "")),
            "orcamento_campanha_dia": round(num(camp.get("daily_budget")) / 100, 2) if camp.get("daily_budget") else "",
            "conjunto": cj.get("name", ""),
            "status_conjunto": STATUS_PT.get(cj.get("effective_status"), cj.get("effective_status", "")),
            "orcamento_conjunto_dia": round(num(cj.get("daily_budget")) / 100, 2) if cj.get("daily_budget") else "",
            "problemas": " | ".join(x for x in problemas if x)[:500],
        })
    linhas.sort(key=lambda l: (l["campanha"], l["anuncio"]))
    return linhas


def montar_resumo(conta, diario, ativos, chamadas):
    agora = datetime.now(BRT)
    hoje = agora.date().isoformat()
    ontem = (agora.date() - timedelta(days=1)).isoformat()
    sete = (agora.date() - timedelta(days=6)).isoformat()

    def total(filtro):
        t = defaultdict(float)
        for l in diario:
            if filtro(l):
                for k in ("gasto", "impressoes", "cliques_link", "conversas", "primeiras_respostas", "leads"):
                    t[k] += num(l[k])
        return t

    periodos = [("Hoje (parcial)", total(lambda l: l["data"] == hoje)),
                ("Ontem", total(lambda l: l["data"] == ontem)),
                ("Últimos 7 dias", total(lambda l: l["data"] >= sete))]

    linhas = [
        "# Anúncios da Meta — resumo automático",
        "",
        f"Conta: {conta.get('name', '')} ({conta.get('currency', '')}). "
        f"Atualizado em {agora.strftime('%d/%m/%Y %H:%M')} (Brasília); atualiza sozinho a cada hora.",
        "A Meta costuma atrasar os números de hoje em algumas horas. Para decidir, use ontem e 7 dias.",
        "",
        "| Período | Gasto | Conversas no WhatsApp | Custo por conversa | Cliques no link | Impressões |",
        "|---|---|---|---|---|---|",
    ]
    for nome, t in periodos:
        linhas.append(f"| {nome} | {brl(t['gasto'])} | {int(t['conversas'])} | {custo_por(t['gasto'], t['conversas'])} "
                      f"| {int(t['cliques_link'])} | {int(t['impressoes'])} |")

    # por campanha, 7 dias
    camp = defaultdict(lambda: defaultdict(float))
    for l in diario:
        if l["data"] >= sete:
            c = camp[l["campanha"]]
            c["gasto"] += num(l["gasto"])
            c["conversas"] += num(l["conversas"])
            c["leads"] += num(l["leads"])
    status_camp = {}
    for a in ativos:
        status_camp[a["campanha"]] = (a["status_campanha"], a["orcamento_campanha_dia"] or a["orcamento_conjunto_dia"])
    linhas += ["", "## Por campanha (últimos 7 dias)", "",
               "| Campanha | Agora | Orçamento/dia | Gasto | Conversas | Custo por conversa |",
               "|---|---|---|---|---|---|"]
    for nome, c in sorted(camp.items(), key=lambda kv: -kv[1]["gasto"]):
        st, orc = status_camp.get(nome, ("sem anúncio no ar", ""))
        linhas.append(f"| {cel(nome)} | {st} | {brl(num(orc)) if orc != '' else '—'} | {brl(c['gasto'])} "
                      f"| {int(c['conversas'])} | {custo_por(c['gasto'], c['conversas'])} |")
    if not camp:
        linhas.append("| (sem gasto nos últimos 7 dias) | | | | | |")

    # por anúncio no ar, 7 dias
    por_ad = defaultdict(lambda: defaultdict(float))
    for l in diario:
        if l["data"] >= sete:
            p = por_ad[l["anuncio_id"]]
            p["gasto"] += num(l["gasto"])
            p["conversas"] += num(l["conversas"])
            p["impressoes"] += num(l["impressoes"])
            p["cliques"] += num(l["cliques_link"])
    linhas += ["", "## Anúncios no ar, em revisão ou com problema (últimos 7 dias)", "",
               "| Anúncio | Campanha | Status | Gasto | Conversas | Custo por conversa | CTR do link |",
               "|---|---|---|---|---|---|---|"]
    for a in ativos:
        p = por_ad.get(a["anuncio_id"], {})
        g, cv, imp, cl = (num(p.get(k)) for k in ("gasto", "conversas", "impressoes", "cliques"))
        ctr = f"{cl / imp * 100:.2f}%".replace(".", ",") if imp else "—"
        linhas.append(f"| {cel(a['anuncio'])} | {cel(a['campanha'])} | {a['status']} | {brl(g)} | {int(cv)} "
                      f"| {custo_por(g, cv)} | {ctr} |")
    if not ativos:
        linhas.append("| (nenhum anúncio no ar) | | | | | | |")

    # alertas objetivos
    alertas = []
    for a in ativos:
        if a["status"] in ("REPROVADO", "COM PROBLEMA", "falta pagamento"):
            alertas.append(f"- **{a['anuncio']}** ({a['campanha']}): {a['status']}. {a['problemas']}".rstrip())
    for a in ativos:
        p = por_ad.get(a["anuncio_id"], {})
        if a["status"] == "no ar" and num(p.get("gasto")) >= 20 and num(p.get("conversas")) == 0:
            alertas.append(f"- **{a['anuncio']}** ({a['campanha']}): gastou {brl(num(p.get('gasto')))} em 7 dias "
                           f"sem nenhuma conversa (confira se a campanha é de mensagem).")
    linhas += ["", "## Alertas"]
    linhas += alertas or ["- nenhum"]
    linhas += ["", f"<!-- chamadas à API nesta atualização: {chamadas} -->", ""]
    return "\n".join(linhas)


def cmd_sincronizar(args):
    m = Meta()
    conta = m.get(m.conta, {"fields": "name,currency"})
    diario = coletar_diario(m, args.dias)
    ativos = coletar_ativos(m)
    os.makedirs(SAIDA, exist_ok=True)
    gravar_csv(os.path.join(SAIDA, "diario.csv"), COLUNAS_DIARIO, diario)
    gravar_csv(os.path.join(SAIDA, "ativos.csv"), COLUNAS_ATIVOS, ativos)
    gravar_texto(os.path.join(SAIDA, "resumo.md"), montar_resumo(conta, diario, ativos, m.chamadas))
    if not args.quieto:
        gasto = sum(num(l["gasto"]) for l in diario)
        print(f"✅ Meta sincronizada: {len(diario)} linhas (anúncio×dia) em {args.dias} dias, "
              f"{brl(gasto)} de gasto, {len(ativos)} anúncio(s) no ar/em revisão/com problema.")
        print(f"   Arquivos em {SAIDA}")


def main():
    ap = argparse.ArgumentParser(description="Anúncios da Meta para o time (somente leitura)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("contas", help="lista as contas de anúncios do token")
    c.add_argument("--tsv", action="store_true")
    sub.add_parser("testar", help="confere token e conta")
    s = sub.add_parser("sincronizar", help="atualiza diario.csv, ativos.csv e resumo.md")
    s.add_argument("--dias", type=int, default=30)
    s.add_argument("--quieto", action="store_true")
    args = ap.parse_args()
    try:
        {"contas": cmd_contas, "testar": cmd_testar, "sincronizar": cmd_sincronizar}[args.cmd](args)
    except ErroMeta as e:
        print(f"[{datetime.now(BRT).strftime('%Y-%m-%d %H:%M')}] ❌ {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
