#!/bin/bash
# Podklady zakázky pro souhrnnou práci. Sdílí start.sh i check.sh — obsah
# je odvozený z čísla žáka, takže kontrola umí spočítat, jak mají soubory
# vypadat, aniž by se ptala jich samých.
DAVEK=7

# Velikost požadovaného svazku. Sdílené proto, že start.sh ji vypisuje
# a check.sh ji ověřuje — dva vzorce na dvou místech se rozejdou.
# Rozsah 150–300 MiB: po cvičení 5 zbývá ve skupině kolem 600 MiB
# a kdo splnil jeho Rozšíření, ještě o sto méně.
svazek_velikost() { printf '%s\n' "$(( 150 + 25 * $(lab_cislo 0 6 velikost) ))"; }
davka_jmeno()  { printf 'davka-%02d-%s.csv\n' "$1" "$(lab_kod DAV "davka$1")"; }
davka_obsah()  {
  local i="$1" r
  printf 'cislo;polozka;castka\n'
  for r in 1 2 3; do
    printf '%s;polozka-%d;%s\n' "$(lab_kod DAV "davka$i")" "$r" \
      "$(lab_cislo 500 90000 "castka$i$r")"
  done
}
