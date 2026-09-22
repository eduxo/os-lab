#!/bin/bash
# 4/06 — návrat do výchozího stavu: fstab se vrátí do podoby před cvičením.
#
# Na disky se nesahá. Jediné, co tenhle lab mění, je konfigurace — a právě
# tu je potřeba umět vrátit, když se do ní žák zamotá.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/fstab"
ZALOHA="$LAB/fstab.pred-cvicenim"
echo
if [ ! -s "$ZALOHA" ]; then
  echo "  Zálohu $ZALOHA nenajdu — nemám co vrátit."
  echo "  Řekněte o tom vyučujícímu, fstab raději neupravujte naslepo."
  echo
  exit 1
fi
echo "  Tím vrátíte /etc/fstab do podoby, v jaké byl na začátku cvičení."
echo "  Data ani disky se nemění — jen konfigurace připojení."
read -r -p "  Opravdu? [a/N] " o
case "$o" in
  [aAyY])
    sudo cp "$ZALOHA" /etc/fstab || { echo "  Vrácení se nepodařilo."; exit 1; }
    rm -f "$LAB/.proslo-startem"
    # Ověřit, že se do stroje nevrátil rozbitý soubor — na tom visí start.
    if sudo -n findmnt --verify 2>&1 | grep -qF '[E]'; then
      echo "  POZOR: findmnt --verify hlásí u vráceného fstab chybu."
      echo "  Nerestartujte stanici a řekněte to vyučujícímu."
      exit 1
    fi
    echo "  Hotovo, /etc/fstab je zpátky."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
