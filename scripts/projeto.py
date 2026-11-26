"""Foco do time: só o projeto ASB online (config/projeto.json)."""
import json
import os

ARQ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "projeto.json")


def carregar():
    try:
        with open(ARQ, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def campanha_do_projeto(cfg, campanha_id="", campanha_nome=""):
    """Sem config, nada é filtrado (comportamento antigo)."""
    if not cfg:
        return True
    ids = {str(i) for i in cfg.get("meta_campanhas", [])}
    prefixo = cfg.get("meta_prefixo_nome") or ""
    return str(campanha_id) in ids or (bool(prefixo) and str(campanha_nome or "").startswith(prefixo))


def produto_do_projeto(cfg, nome_produto=""):
    termos = [t.lower() for t in (cfg or {}).get("hotmart_produto_contem", [])]
    if not termos:
        return True
    n = str(nome_produto or "").lower()
    return any(t in n for t in termos)
