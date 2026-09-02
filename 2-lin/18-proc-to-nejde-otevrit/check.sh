#!/bin/bash
# 2/18 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

NALEZY="$LAB_KOREN/nalezy.txt"

krok 1 "Prostředí"
require_soubor_neprazdny "$NALEZY" \
  "formulář nálezů je na místě" \
  "chybí $NALEZY — spusťte ./start.sh"
if [ -f "$LAB_ZALOHY/zavedeno" ]; then
  uspech "závady jsou zavedené"
elif [ -f "$LAB_ZALOHY/uklizeno" ]; then
  chyba "závady odstranil ./stop.sh, ne vy — spusťte ./reset.sh a zkuste to znovu"
else
  chyba "závady nejsou zavedené — spusťte ./start.sh"
fi

krok 2 "Odstranění závad"
if [ -f "$LAB_ZALOHY/zavedeno" ]; then
  HOTOVO=0; CELKEM=0
  # Soubor patří rootovi (jsou v něm kódy závad), takže se čte přes sudo.
  # Bez toho by přesměrování tiše selhalo, smyčka by se neprovedla a celá
  # tahle část by zmizela ze souhrnu — lab by šel „splnit" bez opravy.
  SEZNAM_ZAVAD="$(cti_jako_root "$LAB_ZALOHY/zavedeno")"
  while read -r Z; do
    [ -n "$Z" ] || continue
    CELKEM=$((CELKEM + 1))
    if "opraveno_$Z"; then
      HOTOVO=$((HOTOVO + 1))
      uspech "závada $CELKEM je odstraněná — $("popis_$Z")"
    else
      chyba "závada $CELKEM pořád trvá"
    fi
  done <<< "$SEZNAM_ZAVAD"
  [ "$HOTOVO" -lt "$CELKEM" ] && \
    poznamka "začněte tím, že si zkusíte do adresářů vejít a soubory otevřít"
else
  chyba "závady nejsou zavedené, není co kontrolovat"
fi

krok 3 "Stav struktury a nálezy"
# Negativní kontroly: 777 ani smazání není oprava.
# Všechny kromě odkladiste — to má být zapisovatelné pro všechny, ale
# se sticky bitem (ten se kontroluje zvlášť v části 2).
for A in sklad ucetni vedeni verejne tym; do
  negative_no_777 "$LAB_KOREN/$A"
done
# Počítat přes `find` z pozice žáka nejde: dokud trvá závada, která bere
# právo čtení adresáři, find dovnitř nevidí a napočítá míň — a kontrola by
# žáka obvinila z mazání za stav, který mu zavedl start.sh. Ptáme se proto
# jmenovitě a přes roota.
CHYBI=""
for F in sklad/cenik.txt ucetni/faktury.txt vedeni/porada.txt          verejne/oznameni.txt tym/podklad.txt; do
  sudo -n test -e "$LAB_KOREN/$F" 2>/dev/null || sudo test -e "$LAB_KOREN/$F" 2>/dev/null     || CHYBI="$CHYBI $(basename "$F")"
done
if [ -z "$CHYBI" ]; then
  uspech "žádný soubor se neztratil"
else
  chyba "ve struktuře chybí soubory:$CHYBI — smazat je není oprava"
fi

for N in 1 2 3; do
  require_zaznam_tvar "$NALEZY" "zavada-$N" '.{20,}' \
    "u závady $N je popsané, co bylo špatně"
done

# Nápověda se nehodnotí, ale je vidět — vyučující tak pozná, kde se
# třída zasekla.
if [ -f "$LAB_KOREN/.napoveda" ]; then
  UROVEN=$(sort -n "$LAB_KOREN/.napoveda" | tail -1)
  poznamka "${_M}pozn.:${_0} použili jste nápovědu až po úroveň $UROVEN ze 3"
fi

pouzil_diagnostiku 'namei|ls -l|stat |getfacl' \
  "příště začněte od 'namei -l' a 'ls -ld'"

vypis_souhrn
