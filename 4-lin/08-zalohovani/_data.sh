#!/bin/bash
# Ostrá data pobočky, která se zálohují. Generátor sdílí start.sh (vyrábí je)
# i check.sh (ověřuje, že se obnovila nepoškozená) — proto je na JEDNOM místě.
#
# Obsah je odvozený z čísla žáka, takže check.sh umí spočítat, jak mají
# soubory vypadat, aniž by se ptal zálohy. Kdyby se porovnávalo jen proti
# otiskům uloženým vedle dat, přišel by o obojí naráz ten, kdo si data smaže
# a obnovu nezvládne — a kontrola by mlčela.

SMLUV=5

smlouva_jmeno() {  # smlouva_jmeno INDEX
  printf 'smlouva-%02d-%s.txt\n' "$1" "$(lab_kod SML "smlouva$1")"
}

smlouva_obsah() {  # smlouva_obsah INDEX
  local i="$1"
  printf 'Smlouva %s\n' "$(lab_kod SML "smlouva$i")"
  printf 'Pobocka: Kolin\n'
  printf 'Platnost do: 20%d-12-31\n' "$(lab_cislo 27 34 "platnost$i")"
  printf 'Hodnota: %s Kc\n' "$(lab_cislo 20000 900000 "hodnota$i")"
  printf 'Spravce: %s\n' "$ZAK_UZIVATEL"
}
