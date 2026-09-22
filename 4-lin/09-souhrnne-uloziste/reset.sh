#!/bin/bash
# 4/09 — návrat do výchozího stavu: smaže se svazek zakázky a záznam ve fstab.
# Repozitáře ze cvičení 8 ani projektu se to netýká.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
LAB="$HOME/netlab/souhrn"
PRIPOJ="$HOME/netlab/ucto"
SKUPINA="data-$ZAK2"
SVAZEK="ucetnictvi"
mkdir -p "$LAB"
echo
echo "  Tím smažete logický svazek $SVAZEK i jeho řádek ve /etc/fstab."
echo "  Zálohy ze cvičení 8 ani ročníkový projekt se nemění."
echo "  Šifrovaný kontejner ani jeho heslo se nemažou."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    mountpoint -q "$PRIPOJ" 2>/dev/null && sudo umount "$PRIPOJ"
    # Řádek se maže podle bodu připojení; fstab se zapisuje atomicky.
    if grep -qE "[[:space:]]$PRIPOJ[[:space:]]" /etc/fstab 2>/dev/null; then
      awk -v c="$PRIPOJ" '$2!=c' /etc/fstab > "$LAB/fstab.nove" \
        && sudo cp "$LAB/fstab.nove" /etc/fstab.novy \
        && sudo chmod 644 /etc/fstab.novy && sudo chown root:root /etc/fstab.novy \
        && sudo mv /etc/fstab.novy /etc/fstab && rm -f "$LAB/fstab.nove" \
        && echo "  Řádek ve fstab odstraněn."
    fi
    # Svazek se ruší, teprve když ve fstab po něm nezbyl řádek — jinak by
    # stanice při příštím startu hledala zařízení, které neexistuje.
    if grep -qE "[[:space:]]$PRIPOJ([[:space:]]|$)|$SKUPINA/$SVAZEK" /etc/fstab 2>/dev/null; then
      echo "  Ve /etc/fstab po svazku pořád zbývá řádek — svazek nemažu."
      echo "  Odstraňte ho a spusťte reset znovu."
      exit 1
    fi
    sudo lvremove -f "/dev/$SKUPINA/$SVAZEK" >/dev/null 2>&1 \
      && echo "  Svazek $SVAZEK smazán."
    if sudo -n findmnt --verify 2>&1 | grep -qF '[E]'; then
      echo "  POZOR: findmnt --verify hlásí ve /etc/fstab chybu."
      echo "  Nerestartujte stanici a řekněte to vyučujícímu."
      exit 1
    fi
    rm -rf "$LAB"
    echo "  Hotovo."
    exec "$(dirname "$0")/start.sh" ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
