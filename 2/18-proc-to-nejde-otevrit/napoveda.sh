#!/bin/bash
# 2/18 — odstupňovaná nápověda. Plán ji u diagnostických cvičení vyžaduje
# a chce, aby její použití hlásil check.sh — proto skript, ne text v zadání.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

mkdir -p "$LAB_KOREN"
UROVEN="${1:-1}"
case "$UROVEN" in 1|2|3) ;; *) echo "  Použití: ./napoveda.sh [1|2|3]"; exit 1 ;; esac
echo "$UROVEN" >> "$LAB_KOREN/.napoveda"

echo
case "$UROVEN" in
1)
  cat <<'TEXT'
  ── Nápověda 1 ze 3 — čím se dá zkoušet ─────────────────────────

  Tyhle příkazy nic nemění a řeknou vám nejvíc:

    namei -l ~/netlab/porucha/sklad/cenik.txt
        vypíše práva KAŽDÉ složky na cestě. Když někde chybí x,
        je jedno, co je na konci — dál se nedostanete.

    ls -ld ~/netlab/porucha/*
        práva a vlastnictví všech složek naráz, na jeden pohled.

    stat -c '%a %A %U:%G %n' ~/netlab/porucha/*
        totéž číselně i symbolicky. Čtyřmístné číslo znamená,
        že je nastavený rozšířený bit.

  Porovnávejte s tabulkou správného stavu v zadání. Liší se přesně
  tři věci.
TEXT
  ;;
2)
  cat <<'TEXT'
  ── Nápověda 2 ze 3 — na co se dívat ────────────────────────────

  Závady jsou ve čtyřech oblastech a vy máte tři, každou z jiné:

    práva adresáře     chybí r nebo x, nebo obojí
    práva souboru      soubor nejde přečíst nebo do něj zapsat
    vlastnictví        složka patří jiné skupině, než má
    rozšířené bity     chybí setgid nebo sticky, nebo je bit
                       nastavený bez práva x (ve výpisu velké S)

  Pozor na dvě věci, které vypadají v pořádku a nejsou:
    · 2770 versus 0770 — čtyřmístné číslo se pozná jen ve stat,
      v ls -ld je to písmeno s místo x
    · složka může mít správná práva a patřit špatné skupině
TEXT
  ;;
3)
  cat <<'TEXT'
  ── Nápověda 3 ze 3 — vaše oblasti ──────────────────────────────

  Tohle jsou oblasti, ve kterých máte závadu. Kterou složku a co
  přesně, musíte najít sami.
TEXT
  echo
  SEZNAM="$(sudo cat "$LAB_ZALOHY/zavedeno" 2>/dev/null)"
  if [ -n "$SEZNAM" ]; then
    printf '%s\n' "$SEZNAM" | while read -r Z; do
      [ -n "$Z" ] || continue
      case "${Z:0:1}" in
        A) echo "    · práva některého adresáře" ;;
        B) echo "    · práva některého souboru" ;;
        C) echo "    · vlastnictví (skupina) některé složky" ;;
        D) echo "    · rozšířený bit u sdílené složky nebo odkladiště" ;;
      esac
    done
  else
    echo "    (závady nejsou zavedené — spusťte ./start.sh)"
  fi
  ;;
esac
echo
echo "  Použití nápovědy se objeví ve výpisu kontroly."
echo
