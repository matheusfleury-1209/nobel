#!/usr/bin/env bash
# Cópia diária da pasta empresa/ (planilhas, relatórios, aprovações). Guarda 14 dias em ~/backups.
set -euo pipefail
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
DEST="$HOME/backups"
mkdir -p "$DEST"; chmod 700 "$DEST"
tar czf "$DEST/empresa-$(date +%Y-%m-%d_%H%M).tar.gz" -C "$OPENCLAW_HOME" empresa
find "$DEST" -name 'empresa-*.tar.gz' -mtime +14 -delete
