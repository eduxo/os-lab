#!/bin/bash
# Obsah „účetních dat", která leží na poli. Sdílí ho start.sh (vyrábí je)
# i check.sh (ověřuje, že přežila výpadek disku) — proto je generátor
# na JEDNOM místě. Kdyby si ho každý skript psal sám, rozejdou se a žák
# dostane FAIL za data, která má v pořádku.
#
# Data jsou odvozená z čísla žáka, takže check.sh umí spočítat, jak mají
# vypadat, aniž by se ptal souboru na poli. To je podstatné: kdyby se
# porovnávalo jen proti otiskům uloženým vedle dat, přišel by o obojí
# naráz ten, kdo pole omylem postaví znovu — a kontrola by mlčela.

FAKTUR=6

faktura_jmeno() {  # faktura_jmeno INDEX → faktura-01-FA-1234.txt
  # Index v názvu je tam kvůli kolizím: lab_kod má 9000 hodnot, šest losů
  # na žáka dá narozeninově ~6 % pravděpodobnost shody v třídě čtyřiceti.
  # Dvě faktury se stejným jménem by se přepsaly a kontrola by hlásila
  # chybějící i poškozený soubor — a reset.sh by to neopravil, protože
  # kódy jsou deterministické.
  printf 'faktura-%02d-%s.txt\n' "$1" "$(lab_kod FA "faktura$1")"
}

faktura_obsah() {  # faktura_obsah INDEX → obsah souboru na stdout
  local i="$1"
  printf 'Faktura %s\n' "$(lab_kod FA "faktura$i")"
  printf 'Odberatel: NetLab s.r.o., pobocka Kolin\n'
  printf 'Castka: %s Kc\n' "$(lab_cislo 1000 99000 "castka$i")"
  printf 'Zpracoval: %s\n' "$ZAK_UZIVATEL"
}
