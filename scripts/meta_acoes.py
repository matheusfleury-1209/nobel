#!/usr/bin/env python3
"""Ações da Gabi nos anúncios da Meta, com travas.

Regras fixas (o Matheus decidiu em 24/11/2026: "sim, com limites e sem publicar no instagram"):
  - Ativar, pausar ou mudar verba SÓ com um bloco [APROVADO ...] em empresa/aprovacoes/pendentes.md
    que cite o ID do anúncio/conjunto/campanha e a ação (e o valor, no caso de verba).
  - Verba diária nunca acima de META_LIMITE_DIARIO (padrão R$ 50) por campanha ou conjunto.
  - Anúncio novo nasce SEMPRE pausado (não gasta nada) e só vai ao ar com aprovação.
  - Nada no Instagram orgânico: este programa só mexe em anúncios.
  - Toda ação fica registrada em ~/.config/nobel/meta-acoes.log e avisa o Matheus no celular (ntfy).

Uso (na VPS, pela Gabi):
  python3 scripts/meta_acoes.py permissoes
  python3 scripts/meta_acoes.py listar
  python3 scripts/meta_acoes.py ativar <id>
  python3 scripts/meta_acoes.py pausar <id>
  python3 scripts/meta_acoes.py verba <id_campanha_ou_conjunto> <reais_por_dia>
  python3 scripts/meta_acoes.py novo-anuncio --conjunto <id> --imagem arte.png --nome "C7 | ..." \
      --texto "texto principal" --titulo "título" [--descricao "..."] \
      --saudacao "Oi, {{user_first_name}}! ..." --mensagem "Oi! Vi o anúncio ..."
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meta import BRT, EMPRESA_DIR, ENV_FILE, ErroMeta, Meta  # noqa: E402

HOME = os.path.expanduser("~")
LOG = os.path.join(HOME, ".config", "nobel", "meta-acoes.log")
ALARME = os.path.join(HOME, ".config", "nobel", "alarme.env")
APROVACOES = os.path.join(EMPRESA_DIR, "aprovacoes", "pendentes.md")

PROIBIDO = [
    (r"100\s*%\s*online", '"100% online" (o curso tem estágio presencial obrigatório)'),
    (r"garant\w*\s+(o\s+|seu\s+|a\s+sua\s+)?(registro|inscri[çc][ãa]o)", "prometer registro/inscrição no CRO"),
    (r"garant\w*\s+(a\s+|sua\s+)?vaga\s+de\s+est[áa]gio", "prometer vaga de estágio"),
    (r"garant\w*\s+(o\s+|seu\s+)?emprego", "prometer emprego"),
    (r"reconhecid\w*\s+pelo\s+mec", '"reconhecido pelo MEC"'),
    (r"cro\s+reconhecid|credenciad\w*\s+(no|pelo|junto\s+ao)\s+(cro|cfo)", '"reconhecido/credenciado no CRO/CFO"'),
    (r"com\s+registro\s+(no\s+)?cro|registro\s+garantido", "prometer registro no CRO"),
    (r"certificado\s+em\s+\d+\s+(dias|semanas|meses)", "prazo para o certificado"),
    (r"[úu]ltimas\s+vagas", '"últimas vagas" (escassez falsa)'),
]
PALAVRAS = {
    "ativar": r"\bativ|\blig(ar|ue|a)\b|\bpublic|\bsub(ir|a)\b|\bno ar\b|\bvoltar\b",
    "pausar": r"\bpaus|\bdeslig|\bparar\b|tirar do ar",
    "verba": r"verba|or[çc]amento|budget",
}


def limite_diario():
    try:
        with open(ENV_FILE, encoding="utf-8") as f:
            m = re.search(r"^META_LIMITE_DIARIO=\s*([\d.,]+)", f.read(), flags=re.M)
        if m:
            return float(m.group(1).replace(",", "."))
    except OSError:
        pass
    return 50.0


def avisar_celular(titulo, texto):
    try:
        with open(ALARME, encoding="utf-8") as f:
            m = re.search(r"^NTFY_TOPICO=(\S+)", f.read(), flags=re.M)
        if not m:
            return
        corpo = json.dumps({"topic": m.group(1), "priority": 3, "title": titulo, "message": texto,
                            "tags": ["robot"]})
        subprocess.run(["curl", "-s", "-m", "20", "-o", "/dev/null", "-H", "Content-Type: application/json",
                        "-d", corpo, "https://ntfy.sh/"], check=False)
    except OSError:
        pass


def registrar(acao, detalhe, aprovacao=""):
    linha = f"{datetime.now(BRT).strftime('%Y-%m-%d %H:%M')} | {acao} | {detalhe}" + (f" | aprovação: {aprovacao}" if aprovacao else "")
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(linha + "\n")
    avisar_celular(f"Gabi: {acao}", detalhe + (f"\nAprovação: {aprovacao}" if aprovacao else ""))
    print("✅ " + detalhe)


def achar_aprovacao(obj_id, acao, valor=None):
    """Bloco '## [APROVADO ...]' que cite o ID, a ação e (para verba) o valor."""
    try:
        with open(APROVACOES, encoding="utf-8") as f:
            texto = f.read()
    except OSError:
        texto = ""
    blocos = re.split(r"(?m)^(?=## \[)", texto)
    for b in blocos:
        if not re.match(r"## \[APROVADO", b):
            continue
        if obj_id not in b or not re.search(PALAVRAS[acao], b, flags=re.I):
            continue
        if valor is not None:
            numeros = {float(n.replace(".", "").replace(",", ".")) for n in re.findall(r"R\$\s*([\d.]+(?:,\d{1,2})?)", b)}
            numeros |= {float(n) for n in re.findall(r"\b(\d{2,4})\s*(?:reais|/dia|por dia)", b)}
            if valor not in numeros:
                continue
        return b.splitlines()[0].strip("# ").strip()
    raise ErroMeta(
        f"Sem aprovação do Matheus para {acao} {obj_id}. Escreva o pedido em empresa/aprovacoes/pendentes.md "
        f"citando o ID {obj_id}" + (f" e o valor R$ {valor:.2f}" if valor is not None else "")
        + ", mande para a Diretora e espere o bloco virar [APROVADO].")


def tipo_de(m, obj_id):
    """Descobre se o ID é campanha, conjunto ou anúncio desta conta."""
    for tipo, campos in (("anúncio", "name,effective_status,account_id,campaign_id,adset_id"),
                         ("conjunto", "name,effective_status,account_id,campaign_id,daily_budget,lifetime_budget"),
                         ("campanha", "name,effective_status,account_id,daily_budget,lifetime_budget,objective")):
        try:
            d = m.get(obj_id, {"fields": campos})
        except ErroMeta:
            continue
        if tipo == "anúncio" and "adset_id" not in d:
            continue
        if tipo == "conjunto" and ("campaign_id" not in d or "adset_id" in d):
            continue
        if f"act_{d.get('account_id', '')}" != m.conta:
            raise ErroMeta(f"O ID {obj_id} não é da conta {m.conta}.")
        return tipo, d
    raise ErroMeta(f"Não achei o ID {obj_id} nesta conta.")


def verba_da_campanha(m, campanha_id, conjunto=None):
    """Maior verba diária que pode ser gasta (campanha ou conjunto), em reais."""
    c = m.get(campanha_id, {"fields": "daily_budget,lifetime_budget"})
    if c.get("lifetime_budget") or (conjunto or {}).get("lifetime_budget"):
        raise ErroMeta("Campanha com verba total (vitalícia): este programa só trabalha com verba diária.")
    if c.get("daily_budget"):
        return int(c["daily_budget"]) / 100
    if conjunto and conjunto.get("daily_budget"):
        return int(conjunto["daily_budget"]) / 100
    return 0.0


def checar_texto(*textos):
    tudo = " \n ".join(t for t in textos if t)
    erros = [msg for padrao, msg in PROIBIDO if re.search(padrao, tudo, flags=re.I)]
    if re.search(r"\b(asb|sa[úu]de bucal)\b", tudo, flags=re.I) and not re.search(r"est[áa]gio", tudo, flags=re.I):
        erros.append("anúncio de ASB precisa citar o estágio")
    if erros:
        raise ErroMeta("Texto proibido: " + "; ".join(erros))


# ---------------------------------------------------------------- comandos
def cmd_permissoes(m, _a):
    dados = m.get("me/permissions")
    ok = {p["permission"] for p in dados.get("data", []) if p.get("status") == "granted"}
    for p in ("ads_read", "ads_management", "pages_show_list", "pages_read_engagement"):
        print(("✅ " if p in ok else "❌ ") + p)
    if "ads_management" not in ok:
        print("Sem ads_management a Gabi só consegue ler. Gere o token de novo com essa permissão.")


def cmd_listar(m, _a):
    filtro = json.dumps(["ACTIVE", "PAUSED", "IN_PROCESS", "WITH_ISSUES", "DISAPPROVED", "PENDING_REVIEW"])
    camps = m.listar(f"{m.conta}/campaigns", {"fields": "id,name,effective_status,daily_budget", "limit": 100,
                                               "effective_status": json.dumps(["ACTIVE"])})
    for c in camps:
        verba = f"R$ {int(c['daily_budget']) / 100:.2f}/dia" if c.get("daily_budget") else "verba no conjunto"
        print(f"CAMPANHA {c['id']}  {c['name']}  [{c['effective_status']}, {verba}]")
        for cj in m.listar(f"{c['id']}/adsets", {"fields": "id,name,effective_status,daily_budget", "limit": 100,
                                                  "effective_status": filtro}):
            print(f"  CONJUNTO {cj['id']}  {cj['name']}  [{cj['effective_status']}]")
            for ad in m.listar(f"{cj['id']}/ads", {"fields": "id,name,effective_status", "limit": 100,
                                                   "effective_status": filtro}):
                print(f"    ANÚNCIO {ad['id']}  {ad['name']}  [{ad['effective_status']}]")


def cmd_ativar(m, a):
    tipo, d = tipo_de(m, a.id)
    aprov = achar_aprovacao(a.id, "ativar")
    camp_id = a.id if tipo == "campanha" else d["campaign_id"]
    conjunto = d if tipo == "conjunto" else (m.get(d["adset_id"], {"fields": "daily_budget,lifetime_budget"}) if tipo == "anúncio" else None)
    verba = verba_da_campanha(m, camp_id, conjunto)
    if verba > limite_diario():
        raise ErroMeta(f"A verba diária ({verba:.2f}) passa do limite de R$ {limite_diario():.2f}. Não ativei.")
    m.post(a.id, {"status": "ACTIVE"})
    registrar("ativou", f"{tipo} {a.id} ({d.get('name', '')}) ativado; verba R$ {verba:.2f}/dia", aprov)


def cmd_pausar(m, a):
    tipo, d = tipo_de(m, a.id)
    aprov = achar_aprovacao(a.id, "pausar")
    m.post(a.id, {"status": "PAUSED"})
    registrar("pausou", f"{tipo} {a.id} ({d.get('name', '')}) pausado", aprov)


def cmd_verba(m, a):
    tipo, d = tipo_de(m, a.id)
    if tipo == "anúncio":
        raise ErroMeta("Verba fica na campanha ou no conjunto, não no anúncio.")
    if a.reais <= 0 or a.reais > limite_diario():
        raise ErroMeta(f"Valor fora do limite: o máximo é R$ {limite_diario():.2f} por dia.")
    if d.get("lifetime_budget"):
        raise ErroMeta("Este item usa verba total (vitalícia); mude pelo Gerenciador.")
    if not d.get("daily_budget"):
        raise ErroMeta(f"Este {tipo} não tem verba diária própria (ela fica no outro nível).")
    aprov = achar_aprovacao(a.id, "verba", round(a.reais, 2))
    antes = int(d["daily_budget"]) / 100
    m.post(a.id, {"daily_budget": str(int(round(a.reais * 100)))})
    registrar("mudou a verba", f"{tipo} {a.id} ({d.get('name', '')}): R$ {antes:.2f} → R$ {a.reais:.2f} por dia", aprov)


def cmd_novo_anuncio(m, a):
    checar_texto(a.texto, a.titulo, a.descricao, a.saudacao, a.mensagem)
    cj = m.get(a.conjunto, {"fields": "name,account_id,campaign_id,destination_type"})
    if f"act_{cj.get('account_id', '')}" != m.conta:
        raise ErroMeta("Esse conjunto não é desta conta.")
    # Página e Instagram iguais aos anúncios que já estão no conjunto
    modelo = None
    for ad in m.listar(f"{a.conjunto}/ads", {"fields": "creative{object_story_spec}", "limit": 25}):
        oss = (ad.get("creative") or {}).get("object_story_spec") or {}
        if oss.get("page_id"):
            modelo = oss
            break
    if not modelo:
        raise ErroMeta("O conjunto não tem nenhum anúncio para copiar a Página e o Instagram.")
    with open(a.imagem, "rb") as f:
        bruto = f.read()
    img = m.post(f"{m.conta}/adimages", {"bytes": base64.b64encode(bruto).decode()})
    hash_img = next(iter((img.get("images") or {}).values()), {}).get("hash")
    if not hash_img:
        raise ErroMeta(f"A Meta não devolveu a imagem enviada: {img}")
    boas_vindas = json.dumps({
        "type": "VISUAL_EDITOR", "version": 2, "landing_screen_type": "welcome_message", "media_type": "text",
        "text_format": {"customer_action_type": "autofill_message",
                        "message": {"autofill_message": {"content": a.mensagem}, "text": a.saudacao}},
        "user_edit": False, "surface": "visual_editor_new"}, ensure_ascii=False)
    link_data = {
        "link": "https://api.whatsapp.com/send", "image_hash": hash_img, "message": a.texto, "name": a.titulo,
        "call_to_action": {"type": "WHATSAPP_MESSAGE", "value": {"app_destination": "WHATSAPP"}},
        "page_welcome_message": boas_vindas,
    }
    if a.descricao:
        link_data["description"] = a.descricao
    oss = {"page_id": modelo["page_id"], "link_data": link_data}
    if modelo.get("instagram_user_id"):
        oss["instagram_user_id"] = modelo["instagram_user_id"]
    sem_ia = {"creative_features_spec": {k: {"enroll_status": "OPT_OUT"} for k in (
        "text_optimizations", "inline_comment", "image_brightness_and_contrast", "enhance_cta",
        "image_touchups", "image_animation")}}
    criativo = m.post(f"{m.conta}/adcreatives", {
        "name": a.nome, "object_story_spec": json.dumps(oss, ensure_ascii=False),
        "degrees_of_freedom_spec": json.dumps(sem_ia)})
    anuncio = m.post(f"{m.conta}/ads", {
        "name": a.nome, "adset_id": a.conjunto, "status": "PAUSED",
        "creative": json.dumps({"creative_id": criativo["id"]})})
    registrar("criou anúncio pausado",
              f"anúncio {anuncio['id']} \"{a.nome}\" no conjunto {a.conjunto} (pausado, não gasta). "
              f"Para ir ao ar precisa de aprovação citando o ID {anuncio['id']}.")


def main():
    ap = argparse.ArgumentParser(description="Ações da Gabi nos anúncios (com travas)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("permissoes")
    sub.add_parser("listar")
    for nome in ("ativar", "pausar"):
        s = sub.add_parser(nome)
        s.add_argument("id")
    s = sub.add_parser("verba")
    s.add_argument("id")
    s.add_argument("reais", type=lambda v: float(v.replace(",", ".")))
    s = sub.add_parser("novo-anuncio")
    for campo, obrig in (("conjunto", True), ("imagem", True), ("nome", True), ("texto", True), ("titulo", True),
                         ("descricao", False), ("saudacao", True), ("mensagem", True)):
        s.add_argument(f"--{campo}", required=obrig)
    a = ap.parse_args()
    try:
        m = Meta()
        {"permissoes": cmd_permissoes, "listar": cmd_listar, "ativar": cmd_ativar, "pausar": cmd_pausar,
         "verba": cmd_verba, "novo-anuncio": cmd_novo_anuncio}[a.cmd](m, a)
    except ErroMeta as e:
        print(f"❌ {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
