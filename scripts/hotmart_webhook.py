#!/usr/bin/env python3
"""Recebe os avisos (webhooks) da Hotmart na VPS. Só grava; não fala com ninguém.

- Abandono de carrinho (PURCHASE_OUT_OF_SHOPPING_CART): grava em
  <EMPRESA_DIR>/vendas/hotmart/abandonos.csv (a Bia usa, via pendentes.csv).
- Qualquer evento de compra (PURCHASE_APPROVED, PURCHASE_BILLET_PRINTED, ...): dispara na hora
  o `hotmart.py sincronizar`, para o Rafa ver o pagamento sem esperar os 10 minutos.

Configuração em ~/.config/nobel/hotmart-webhook.env (criada por scripts/ligar-carrinho.sh):
  CAMINHO=/hotmart-<segredo>   endereço secreto (só ele é aceito)
  PORTA=8787                   escuta só em 127.0.0.1; o Tailscale Funnel publica na internet
  HOTTOK=...                   código de verificação da Hotmart (cabeçalho X-HOTMART-HOTTOK).
                               Vazio = aprende do primeiro aviso válido e passa a exigir.
"""

import csv
import hmac
import json
import os
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BRT = timezone(timedelta(hours=-3))
HOME = os.path.expanduser("~")
CFG_FILE = os.environ.get("HOTMART_WEBHOOK_ENV", os.path.join(HOME, ".config", "nobel", "hotmart-webhook.env"))
EMPRESA_DIR = os.environ.get(
    "EMPRESA_DIR",
    os.path.join(os.environ.get("OPENCLAW_HOME", os.path.join(HOME, ".openclaw")), "empresa"),
)
SAIDA = os.path.join(EMPRESA_DIR, "vendas", "hotmart")
ABANDONOS = os.path.join(SAIDA, "abandonos.csv")
LOG = os.path.join(SAIDA, "avisos.log")  # sem dados pessoais
REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLUNAS = ["data", "nome", "email", "telefone", "produto", "produto_id", "oferta", "pais", "evento_id"]
LIMITE_CORPO = 256 * 1024
INTERVALO_SYNC = 60  # segundos entre duas sincronizações disparadas por aviso

trava = threading.Lock()
cfg = {}
ids_vistos = set()
sync_estado = {"ultima": 0.0, "agendada": False}


def agora():
    return datetime.now(BRT).strftime("%Y-%m-%d %H:%M:%S")


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"{agora()} {msg}\n")
    except OSError:
        pass


def ler_cfg():
    dados = {}
    with open(CFG_FILE, encoding="utf-8") as f:
        for linha in f:
            linha = linha.strip()
            if linha and not linha.startswith("#") and "=" in linha:
                k, v = linha.split("=", 1)
                dados[k.strip()] = v.strip()
    if not dados.get("CAMINHO", "").startswith("/hotmart-") or len(dados["CAMINHO"]) < 20:
        sys.exit(f"CAMINHO inválido em {CFG_FILE}")
    return dados


def salvar_hottok(valor):
    with open(CFG_FILE, encoding="utf-8") as f:
        linhas = [l for l in f.read().splitlines() if not l.startswith("HOTTOK=")]
    linhas.append(f"HOTTOK={valor}")
    with open(CFG_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas) + "\n")
    cfg["HOTTOK"] = valor


def telefone_br(v):
    d = "".join(ch for ch in str(v or "") if ch.isdigit())
    if not d:
        return ""
    if len(d) in (10, 11):
        d = "55" + d
    return "+" + d


def parece_teste(email, nome):
    e, n = (email or "").lower(), (nome or "").lower()
    return any(x in e for x in ("example.com", "@email.com", "teste", "test@")) or n in ("buyer name", "teste")


def gravar_abandono(evento):
    d = evento.get("data") or {}
    comprador = d.get("buyer") or {}
    produto = d.get("product") or {}
    email = (comprador.get("email") or "").strip().lower()
    nome = (comprador.get("name") or "").strip()
    if parece_teste(email, nome):
        return "teste (não gravado)"
    linha = {
        "data": datetime.fromtimestamp(int(evento.get("creation_date") or time.time() * 1000) / 1000, tz=BRT)
                .strftime("%Y-%m-%d %H:%M"),
        "nome": nome,
        "email": email,
        "telefone": telefone_br(comprador.get("phone")),
        "produto": produto.get("name", ""),
        "produto_id": str(produto.get("id", "")),
        "oferta": (d.get("offer") or {}).get("code", ""),
        "pais": (d.get("checkout_country") or {}).get("iso", ""),
        "evento_id": evento.get("id", ""),
    }
    novo = not os.path.isfile(ABANDONOS)
    antigo = os.umask(0o077)
    try:
        with open(ABANDONOS, "a", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=COLUNAS)
            if novo:
                w.writeheader()
            w.writerow(linha)
    finally:
        os.umask(antigo)
    return "gravado"


def sincronizar_agora():
    """Roda o hotmart.py sincronizar, no máximo 1 vez por minuto."""
    with trava:
        espera = sync_estado["ultima"] + INTERVALO_SYNC - time.time()
        if espera > 0:
            if sync_estado["agendada"]:
                return
            sync_estado["agendada"] = True
            threading.Timer(espera, _rodar_sync).start()
            return
        sync_estado["ultima"] = time.time()
    threading.Thread(target=_rodar_sync, args=(False,), daemon=True).start()


def _rodar_sync(marcar=True):
    if marcar:
        with trava:
            sync_estado["agendada"] = False
            sync_estado["ultima"] = time.time()
    r = subprocess.run([sys.executable, os.path.join(REPO_DIR, "scripts", "hotmart.py"), "sincronizar", "--quieto"],
                       cwd=REPO_DIR, capture_output=True, text=True, timeout=600)
    log("sincronização disparada por aviso: " + ("ok" if r.returncode == 0 else "ERRO " + r.stderr.strip()[-200:]))


class Avisos(BaseHTTPRequestHandler):
    server_version = "nobel"
    sys_version = ""

    def log_message(self, *args):  # não registra IP/caminho no journal
        pass

    def _responder(self, codigo, texto="ok"):
        corpo = texto.encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):
        self._responder(404, "")

    def do_POST(self):
        if self.path.split("?", 1)[0].rstrip("/") != cfg["CAMINHO"]:
            return self._responder(404, "")
        try:
            tamanho = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return self._responder(400, "")
        if tamanho <= 0 or tamanho > LIMITE_CORPO:
            return self._responder(413, "")
        try:
            evento = json.loads(self.rfile.read(tamanho).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return self._responder(400, "")
        if not isinstance(evento, dict):
            return self._responder(400, "")

        recebido = self.headers.get("X-HOTMART-HOTTOK") or str(evento.get("hottok") or "")
        with trava:
            esperado = cfg.get("HOTTOK", "")
            if not esperado and recebido:
                salvar_hottok(recebido)
                esperado = recebido
                log("hottok aprendido do primeiro aviso e salvo")
        if not esperado or not hmac.compare_digest(recebido.encode(), esperado.encode()):
            log("aviso recusado: " + ("sem hottok (teste de conexão ou desconhecido)" if not recebido else "hottok inválido"))
            return self._responder(401, "")

        nome_evento = str(evento.get("event") or "")
        eid = str(evento.get("id") or "")
        with trava:
            repetido = bool(eid) and eid in ids_vistos
            if eid:
                ids_vistos.add(eid)
        if repetido:
            return self._responder(200)

        if nome_evento == "PURCHASE_OUT_OF_SHOPPING_CART":
            with trava:
                resultado = gravar_abandono(evento)
            log(f"{nome_evento} {resultado}")
        elif nome_evento.startswith("PURCHASE_"):
            log(f"{nome_evento} recebido; atualizando vendas")
            sincronizar_agora()
        else:
            log(f"{nome_evento or 'evento sem nome'} recebido (ignorado)")
        return self._responder(200)


def main():
    cfg.update(ler_cfg())
    os.makedirs(SAIDA, exist_ok=True)
    if os.path.isfile(ABANDONOS):
        with open(ABANDONOS, encoding="utf-8") as f:
            ids_vistos.update(r.get("evento_id", "") for r in csv.DictReader(f))
    porta = int(cfg.get("PORTA", "8787"))
    srv = ThreadingHTTPServer(("127.0.0.1", porta), Avisos)
    log(f"recebedor de avisos ligado na porta {porta}")
    srv.serve_forever()


if __name__ == "__main__":
    main()
