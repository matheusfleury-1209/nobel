#!/usr/bin/env python3
"""Vendas da Hotmart para o time, SOMENTE LEITURA.

Uso (na VPS):
  python3 scripts/hotmart.py testar
  python3 scripts/hotmart.py sincronizar [--dias 45] [--quieto]

Credenciais: arquivo HOTMART_ENV (padrão ~/.config/nobel/hotmart.env), criado por
scripts/ligar-hotmart.sh, com as linhas:
  HOTMART_CLIENT_ID=...
  HOTMART_CLIENT_SECRET=...
  HOTMART_BASIC=...

O que ele grava em <EMPRESA_DIR>/vendas/hotmart/ (padrão ~/.openclaw/empresa/vendas/hotmart/):
  vendas.csv     todas as transações do período, uma linha por transação
  pendentes.csv  Pix/boleto/cartão que ainda não viraram venda + quem abandonou o checkout
                 (abandonos.csv, gravado pelo hotmart_webhook.py), sem quem comprou depois
  resumo.md      números do dia, da semana e do mês, sem dados pessoais

Este programa só CONSULTA a Hotmart. Ele não reembolsa, não cancela e não cria nada.
Documentação usada: developers.hotmart.com/docs/pt-BR (Autenticação, Histórico de vendas,
Participantes de vendas, Paginação, Rate Limit).
"""

import argparse
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from projeto import carregar as carregar_projeto, produto_do_projeto  # noqa: E402
from datetime import datetime, timedelta, timezone

TOKEN_URL = "https://api-sec-vlc.hotmart.com/security/oauth/token"
API = "https://developers.hotmart.com/payments/api/v1"
BRT = timezone(timedelta(hours=-3))  # Brasília (sem horário de verão desde 2019)

HOME = os.path.expanduser("~")
ENV_FILE = os.environ.get("HOTMART_ENV", os.path.join(HOME, ".config", "nobel", "hotmart.env"))
TOKEN_FILE = os.path.join(os.path.dirname(ENV_FILE), "hotmart-token.json")
EMPRESA_DIR = os.environ.get(
    "EMPRESA_DIR",
    os.path.join(os.environ.get("OPENCLAW_HOME", os.path.join(HOME, ".openclaw")), "empresa"),
)
SAIDA = os.path.join(EMPRESA_DIR, "vendas", "hotmart")

# Todos os status que a API aceita (Histórico de vendas). Sem o filtro, ela só devolve APPROVED e COMPLETE.
STATUS = [
    "APPROVED", "COMPLETE", "WAITING_PAYMENT", "PRINTED_BILLET", "UNDER_ANALISYS",
    "NO_FUNDS", "CANCELLED", "EXPIRED", "BLOCKED", "STARTED", "PROCESSING_TRANSACTION",
    "REFUNDED", "PARTIALLY_REFUNDED", "CHARGEBACK", "PROTESTED", "OVERDUE", "PRE_ORDER",
]
SITUACAO = {
    "APPROVED": "aprovada",
    "COMPLETE": "aprovada (garantia encerrada)",
    "WAITING_PAYMENT": "aguardando pagamento (Pix/boleto)",
    "PRINTED_BILLET": "boleto gerado",
    "UNDER_ANALISYS": "em análise",
    "NO_FUNDS": "cartão recusado (sem limite)",
    "CANCELLED": "cancelada",
    "EXPIRED": "expirou sem pagamento",
    "BLOCKED": "bloqueada",
    "STARTED": "iniciada",
    "PROCESSING_TRANSACTION": "processando",
    "REFUNDED": "reembolsada",
    "PARTIALLY_REFUNDED": "reembolso parcial",
    "CHARGEBACK": "chargeback",
    "PROTESTED": "pedido de reembolso/contestação",
    "OVERDUE": "em atraso",
    "PRE_ORDER": "pré-venda",
}
PAGAS = {"APPROVED", "COMPLETE"}
# Quem ficou no meio do caminho: entra na fila da Bia se não comprou depois
QUASE = {"WAITING_PAYMENT", "PRINTED_BILLET", "UNDER_ANALISYS", "NO_FUNDS", "CANCELLED",
         "EXPIRED", "BLOCKED", "STARTED", "PROCESSING_TRANSACTION"}
FORMA = {
    "PIX": "Pix", "CREDIT_CARD": "cartão", "BILLET": "boleto", "PAYPAL": "PayPal",
    "PAYPAL_INTERNACIONAL": "PayPal", "GOOGLE_PAY": "Google Pay", "SAMSUNG_PAY": "Samsung Pay",
    "PICPAY": "PicPay", "HYBRID": "híbrido", "WALLET": "carteira", "FINANCED_BILLET": "boleto parcelado",
}

COLUNAS_VENDAS = [
    "transacao", "status", "situacao", "data_pedido", "data_aprovacao", "produto", "produto_id",
    "nome", "email", "telefone", "cidade", "uf", "valor", "moeda", "forma_pagamento", "parcelas",
    "oferta", "origem_src", "origem_sck", "fim_garantia",
]
COLUNAS_PENDENTES = [
    "transacao", "status", "situacao", "data_pedido", "produto", "nome", "telefone", "email",
    "valor", "forma_pagamento", "origem_src",
]


class ErroHotmart(Exception):
    pass


# ---------------------------------------------------------------- credenciais e token
def ler_credenciais():
    if not os.path.isfile(ENV_FILE):
        raise ErroHotmart(f"Não achei {ENV_FILE}. Rode antes: bash scripts/ligar-hotmart.sh")
    cred = {}
    with open(ENV_FILE, encoding="utf-8") as f:
        for linha in f:
            linha = linha.strip()
            if not linha or linha.startswith("#") or "=" not in linha:
                continue
            k, v = linha.split("=", 1)
            cred[k.strip()] = v.strip().strip('"').strip("'")
    faltando = [k for k in ("HOTMART_CLIENT_ID", "HOTMART_CLIENT_SECRET", "HOTMART_BASIC") if not cred.get(k)]
    if faltando:
        raise ErroHotmart(f"Faltam no {ENV_FILE}: {', '.join(faltando)}")
    basic = cred["HOTMART_BASIC"]
    if basic.lower().startswith("basic "):
        basic = basic[6:].strip()
    cred["HOTMART_BASIC"] = basic
    return cred


def _http(metodo, url, headers, tentativas=4):
    espera = 2
    for i in range(tentativas):
        req = urllib.request.Request(url, method=metodo, headers=headers, data=b"" if metodo == "POST" else None)
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return r.status, json.loads(r.read().decode("utf-8") or "{}")
        except urllib.error.HTTPError as e:
            corpo = e.read().decode("utf-8", "replace")[:300]
            if e.code == 429 or e.code >= 500:
                if i < tentativas - 1:
                    time.sleep(espera)
                    espera *= 2
                    continue
            return e.code, {"_erro": corpo}
        except (urllib.error.URLError, TimeoutError) as e:
            if i < tentativas - 1:
                time.sleep(espera)
                espera *= 2
                continue
            raise ErroHotmart(f"Sem conexão com a Hotmart: {e}")
    raise ErroHotmart("A Hotmart não respondeu depois de várias tentativas")


def novo_token(cred):
    q = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": cred["HOTMART_CLIENT_ID"],
        "client_secret": cred["HOTMART_CLIENT_SECRET"],
    })
    status, dados = _http("POST", f"{TOKEN_URL}?{q}", {
        "Content-Type": "application/json",
        "Authorization": f"Basic {cred['HOTMART_BASIC']}",
    })
    if status != 200 or "access_token" not in dados:
        raise ErroHotmart(
            "A Hotmart recusou as credenciais (código %s). Confira o Client ID, o Client Secret e o Basic "
            "e rode de novo: TROCAR=1 bash scripts/ligar-hotmart.sh" % status
        )
    validade = time.time() + int(dados.get("expires_in", 3600)) - 300
    antigo = os.umask(0o077)
    try:
        with open(TOKEN_FILE, "w", encoding="utf-8") as f:
            json.dump({"access_token": dados["access_token"], "valido_ate": validade}, f)
    finally:
        os.umask(antigo)
    return dados["access_token"]


def token(cred, forcar=False):
    if not forcar and os.path.isfile(TOKEN_FILE):
        try:
            with open(TOKEN_FILE, encoding="utf-8") as f:
                t = json.load(f)
            if t.get("valido_ate", 0) > time.time():
                return t["access_token"]
        except (ValueError, KeyError, OSError):
            pass
    return novo_token(cred)


class Cliente:
    def __init__(self):
        self.cred = ler_credenciais()
        self.tk = token(self.cred)
        self.chamadas = 0

    def get(self, caminho, params):
        url = f"{API}{caminho}?{urllib.parse.urlencode(params)}"
        for tentativa in range(2):
            self.chamadas += 1
            status, dados = _http("GET", url, {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.tk}",
            })
            if status == 401 and tentativa == 0:
                self.tk = token(self.cred, forcar=True)
                continue
            if status != 200:
                raise ErroHotmart(f"Erro {status} em {caminho}: {dados.get('_erro', '')}")
            return dados
        raise ErroHotmart("Token recusado pela Hotmart")

    def listar(self, caminho, params):
        """Percorre todas as páginas (paginação por cursor)."""
        itens, pagina = [], None
        for _ in range(200):
            p = dict(params, max_results=50)
            if pagina:
                p["page_token"] = pagina
            dados = self.get(caminho, p)
            itens.extend(dados.get("items") or [])
            pagina = (dados.get("page_info") or {}).get("next_page_token")
            if not pagina:
                break
        return itens


# ---------------------------------------------------------------- utilidades
def data_br(ms):
    if not ms:
        return ""
    return datetime.fromtimestamp(int(ms) / 1000, tz=BRT).strftime("%Y-%m-%d %H:%M")


def so_digitos(s):
    return "".join(ch for ch in str(s or "") if ch.isdigit())


def telefone_br(*valores):
    for v in valores:
        d = so_digitos(v)
        if not d:
            continue
        if len(d) in (10, 11) and not d.startswith("55"):
            d = "55" + d
        return "+" + d
    return ""


def gravar_csv(caminho, colunas, linhas):
    tmp = f"{caminho}.{os.getpid()}.tmp"
    antigo = os.umask(0o077)
    try:
        with open(tmp, "w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=colunas, extrasaction="ignore")
            w.writeheader()
            w.writerows(linhas)
    finally:
        os.umask(antigo)
    os.replace(tmp, caminho)


def gravar_texto(caminho, texto):
    tmp = f"{caminho}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(texto)
    os.replace(tmp, caminho)


def brl(v):
    s = f"{v:,.2f}"
    return "R$ " + s.replace(",", "X").replace(".", ",").replace("X", ".")


# ---------------------------------------------------------------- comandos
def cmd_testar(_args):
    c = Cliente()
    agora = int(time.time() * 1000)
    dados = c.get("/sales/history", {
        "transaction_status": "APPROVED",
        "start_date": agora - 30 * 86400 * 1000,
        "end_date": agora,
        "max_results": 1,
    })
    total = (dados.get("page_info") or {}).get("total_results")
    if total is None:
        total = len(dados.get("items") or [])
    print(f"✅ Conectado à Hotmart. Vendas aprovadas nos últimos 30 dias: {total}")


def coletar(c, dias):
    agora = int(time.time() * 1000)
    janela = {"start_date": agora - dias * 86400 * 1000, "end_date": agora}

    vendas = {}
    for st in STATUS:
        for it in c.listar("/sales/history", dict(janela, transaction_status=st)):
            compra = it.get("purchase") or {}
            tr = compra.get("transaction")
            if not tr:
                continue
            preco = compra.get("price") or {}
            pag = compra.get("payment") or {}
            trk = compra.get("tracking") or {}
            status = compra.get("status") or st
            vendas[tr] = {
                "transacao": tr,
                "status": status,
                "situacao": SITUACAO.get(status, status.lower()),
                "data_pedido": data_br(compra.get("order_date")),
                "data_aprovacao": data_br(compra.get("approved_date")) if status in PAGAS else "",
                "produto": (it.get("product") or {}).get("name", ""),
                "produto_id": (it.get("product") or {}).get("id", ""),
                "nome": (it.get("buyer") or {}).get("name", ""),
                "email": ((it.get("buyer") or {}).get("email") or "").lower(),
                "telefone": "", "cidade": "", "uf": "",
                "valor": preco.get("value", ""),
                "moeda": preco.get("currency_code", ""),
                "forma_pagamento": FORMA.get(pag.get("type") or pag.get("method"), (pag.get("type") or "").lower()),
                "parcelas": pag.get("installments_number", ""),
                "oferta": (compra.get("offer") or {}).get("code", ""),
                "origem_src": trk.get("source", ""),
                "origem_sck": trk.get("source_sck", ""),
                "fim_garantia": data_br(compra.get("warranty_expire_date")),
                "_ms": int(compra.get("order_date") or 0),
            }

    # Telefone e cidade vêm do endpoint de participantes (papel BUYER)
    for st in STATUS:
        for it in c.listar("/sales/users", dict(janela, transaction_status=st)):
            tr = it.get("transaction")
            if tr not in vendas:
                continue
            for u in it.get("users") or []:
                if u.get("role") != "BUYER":
                    continue
                user = u.get("user") or {}
                end = user.get("address") or {}
                v = vendas[tr]
                v["telefone"] = telefone_br(user.get("cellphone"), user.get("phone"))
                v["cidade"] = end.get("city", "")
                v["uf"] = end.get("state", "")
                if not v["nome"]:
                    v["nome"] = user.get("name", "")
                if not v["email"]:
                    v["email"] = (user.get("email") or "").lower()
    return sorted(vendas.values(), key=lambda v: v["_ms"], reverse=True)


def ler_abandonos(dias=7):
    """Abandonos de checkout recebidos pelo hotmart_webhook.py (últimos `dias`)."""
    caminho = os.path.join(SAIDA, "abandonos.csv")
    if not os.path.isfile(caminho):
        return []
    limite = (datetime.now(BRT) - timedelta(days=dias)).strftime("%Y-%m-%d %H:%M")
    linhas = []
    with open(caminho, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if (r.get("data") or "") < limite:
                continue
            try:
                ms = int(datetime.strptime(r["data"], "%Y-%m-%d %H:%M").replace(tzinfo=BRT).timestamp() * 1000)
            except (KeyError, ValueError):
                continue
            linhas.append({
                "transacao": "", "status": "ABANDONO", "situacao": "abandonou o checkout (só preencheu os dados)",
                "data_pedido": r["data"], "produto": r.get("produto", ""), "produto_id": r.get("produto_id", ""),
                "nome": r.get("nome", ""), "telefone": r.get("telefone", ""), "email": (r.get("email") or "").lower(),
                "valor": "", "forma_pagamento": "", "origem_src": "", "_ms": ms,
            })
    return linhas


def montar_pendentes(vendas, dias=14, abandonos=()):
    limite = (time.time() - dias * 86400) * 1000
    compraram = set()
    for v in vendas:
        if v["status"] in PAGAS:
            for contato in (v["email"], v["telefone"]):
                if contato:
                    compraram.add((str(v["produto_id"]), contato))
    candidatos = [v for v in vendas if v["status"] in QUASE and v["_ms"] >= limite]
    candidatos += list(abandonos)
    candidatos.sort(key=lambda v: v["_ms"], reverse=True)  # mais novo primeiro
    vistos, fila = set(), []
    for v in candidatos:
        contatos = [c for c in (v["email"], v["telefone"]) if c]
        chaves = {(str(v["produto_id"]), c) for c in contatos}
        if not chaves or chaves & compraram or chaves & vistos:
            continue
        vistos |= chaves
        fila.append(v)
    return fila


def montar_resumo(vendas, pendentes, chamadas):
    agora = datetime.now(BRT)
    hoje = agora.strftime("%Y-%m-%d")
    sete = (agora - timedelta(days=7)).strftime("%Y-%m-%d")
    mes = agora.strftime("%Y-%m")

    def pagas(prefixo_ou_min, por_inicio=True):
        out = []
        for v in vendas:
            if v["status"] not in PAGAS or not v["data_aprovacao"]:
                continue
            d = v["data_aprovacao"][:10]
            if (por_inicio and d.startswith(prefixo_ou_min)) or (not por_inicio and d >= prefixo_ou_min):
                out.append(v)
        return out

    def soma(lst):
        total = 0.0
        for v in lst:
            try:
                total += float(v["valor"] or 0)
            except ValueError:
                pass
        return total

    v_hoje, v_7, v_mes = pagas(hoje), pagas(sete, por_inicio=False), pagas(mes)
    por_origem = Counter((v["origem_src"] or "sem origem") for v in v_mes)
    por_produto = Counter(v["produto"] for v in v_mes)
    por_forma = Counter(v["forma_pagamento"] for v in v_mes)
    problemas = Counter(v["situacao"] for v in vendas
                        if v["status"] in {"REFUNDED", "PARTIALLY_REFUNDED", "CHARGEBACK", "PROTESTED"}
                        and v["data_pedido"][:7] == mes)
    fila = Counter(v["situacao"] for v in pendentes)

    linhas = [
        "# Vendas da Hotmart — resumo automático",
        "",
        f"Atualizado em {agora.strftime('%d/%m/%Y %H:%M')} (horário de Brasília). Atualiza sozinho a cada 10 minutos.",
        "Dados pessoais ficam em `vendas.csv` e `pendentes.csv`, nesta mesma pasta.",
        "",
        "| Período | Vendas aprovadas | Valor bruto |",
        "|---|---|---|",
        f"| Hoje | {len(v_hoje)} | {brl(soma(v_hoje))} |",
        f"| Últimos 7 dias | {len(v_7)} | {brl(soma(v_7))} |",
        f"| Mês ({mes}) | {len(v_mes)} | {brl(soma(v_mes))} |",
        "",
        "Valor bruto = preço pago pela aluna, antes das taxas da Hotmart.",
        "",
        "## Vendas do mês por origem (`src` do link)",
    ]
    linhas += [f"- {k}: {n}" for k, n in por_origem.most_common()] or ["- nenhuma"]
    linhas += ["", "## Vendas do mês por produto"]
    linhas += [f"- {k}: {n}" for k, n in por_produto.most_common()] or ["- nenhuma"]
    linhas += ["", "## Vendas do mês por forma de pagamento"]
    linhas += [f"- {k}: {n}" for k, n in por_forma.most_common()] or ["- nenhuma"]
    linhas += ["", f"## Fila de recuperação (últimos 14 dias): {len(pendentes)} pessoa(s)"]
    linhas += [f"- {k}: {n}" for k, n in fila.most_common()] or ["- ninguém"]
    linhas += ["", "## Reembolsos, contestações e chargebacks no mês"]
    linhas += [f"- {k}: {n}" for k, n in problemas.most_common()] or ["- nenhum"]
    linhas += ["", f"<!-- chamadas à API nesta atualização: {chamadas} -->", ""]
    return "\n".join(linhas)


def cmd_sincronizar(args):
    c = Cliente()
    projeto = carregar_projeto()
    todas = coletar(c, args.dias)
    vendas = [v for v in todas if produto_do_projeto(projeto, v["produto"])]
    if getattr(args, "produtos", False):
        nomes = Counter(v["produto"] for v in todas)
        for nome, n in nomes.most_common():
            print(f"   {'✅ conta' if produto_do_projeto(projeto, nome) else '⛔ fora '}  {nome}  ({n} transações)")
    pendentes = montar_pendentes(vendas, abandonos=[a for a in ler_abandonos() if produto_do_projeto(projeto, a["produto"])])
    os.makedirs(SAIDA, exist_ok=True)
    gravar_csv(os.path.join(SAIDA, "vendas.csv"), COLUNAS_VENDAS, vendas)
    gravar_csv(os.path.join(SAIDA, "pendentes.csv"), COLUNAS_PENDENTES, pendentes)
    gravar_texto(os.path.join(SAIDA, "resumo.md"), montar_resumo(vendas, pendentes, c.chamadas))
    if not args.quieto:
        pagas = sum(1 for v in vendas if v["status"] in PAGAS)
        print(f"✅ Hotmart sincronizada: {len(vendas)} transações nos últimos {args.dias} dias "
              f"({pagas} aprovadas), {len(pendentes)} na fila de recuperação.")
        print(f"   Arquivos em {SAIDA}")


def main():
    ap = argparse.ArgumentParser(description="Vendas da Hotmart para o time (somente leitura)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("testar", help="confere se as credenciais funcionam")
    s = sub.add_parser("sincronizar", help="atualiza vendas.csv, pendentes.csv e resumo.md")
    s.add_argument("--dias", type=int, default=45, help="quantos dias para trás (padrão 45)")
    s.add_argument("--quieto", action="store_true", help="não imprime nada quando dá certo (para o agendamento)")
    s.add_argument("--produtos", action="store_true", help="mostra quais produtos contam para o projeto")
    args = ap.parse_args()
    try:
        {"testar": cmd_testar, "sincronizar": cmd_sincronizar}[args.cmd](args)
    except ErroHotmart as e:
        stamp = datetime.now(BRT).strftime("%Y-%m-%d %H:%M")
        print(f"[{stamp}] ❌ {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
