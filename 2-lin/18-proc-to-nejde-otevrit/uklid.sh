#!/bin/bash
# 2/18 — obnovení správného stavu. Běží pod správcem.
set -uo pipefail
# Účet se předává, protože skript běží pod rootem a `id -un` by vrátilo root.
LAB_KOREN="${1:?}"; LAB_ZALOHY="${2:?}"; UCET="${3:-sysadmin}"
chown -R "$UCET":"$UCET" "$LAB_KOREN" 2>/dev/null
chgrp sklad  "$LAB_KOREN/sklad"  2>/dev/null
chgrp ucetni "$LAB_KOREN/ucetni" 2>/dev/null
chgrp vedeni "$LAB_KOREN/vedeni" "$LAB_KOREN/tym" 2>/dev/null
chmod 644 "$LAB_KOREN"/*/*.txt 2>/dev/null
chmod 750 "$LAB_KOREN/sklad" "$LAB_KOREN/ucetni" "$LAB_KOREN/vedeni"
chmod 755 "$LAB_KOREN/verejne"
chmod 2770 "$LAB_KOREN/tym"
chmod 1777 "$LAB_KOREN/odkladiste"
rm -f "$LAB_ZALOHY/zavedeno"
date +%Y-%m-%dT%H:%M > "$LAB_ZALOHY/uklizeno"
exit 0
