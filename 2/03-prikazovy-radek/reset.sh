#!/bin/bash
# 2/03 — návrat do výchozího stavu (smaže vaši práci v ~/netlab)
set -uo pipefail
BAZE="$HOME/netlab"
# Maže se jen to, co postavilo tohle cvičení. V ~/netlab mají svoje
# podadresáře i pozdější cvičení a ta nemají důvod přijít o práci.
MOJE=(ucetni sklad vedeni archiv reklamace prevzato odpoved.txt)
echo
echo "  Tím smažete svou práci ze cvičení Příkazový řádek I:"
echo "    ${MOJE[*]}"
echo "  v adresáři $BAZE. Ostatní cvičení zůstanou nedotčená."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    for m in "${MOJE[@]}"; do rm -rf "${BAZE:?}/$m"; done
    echo "  Smazáno."; exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
