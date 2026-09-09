#!/bin/bash
# 3/11 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="provoz-$ZAK2"
SERVER_KONT="$KONT"
# Losování archivu je v provoz-lib.sh, aby se kontrola nemohla rozejít
# se start.sh. Knihovna se tu sourcuje jen kvůli proměnným ARCHIV_*.
source "$(dirname "$0")/../../lib/provoz-lib.sh"

PROVOZ="$HOME/netlab/provoz"
FORMULAR="$PROVOZ/formular.txt"
MISTA="/home/$LAB_UZIVATEL/mista.txt"

if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
STAV="$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)"
if [ -z "$STAV" ]; then
  echo; echo "  Server $KONT neexistuje. Spusťte ./start.sh"; echo; exit 1
elif [ "$STAV" != "RUNNING" ]; then
  echo; echo "  Server $KONT je zastavený — vaše práce na něm zůstala."
  echo "  Nastartujte ho:  ./start.sh"; echo; exit 1
fi

na_serveru() { lxc exec "$KONT" -- bash -c "$1" 2>/dev/null; }
LAB_KONTEJNER="$KONT"

krok 1 "Priorita dávkového zpracování"
# Úkolem je prioritu SNÍŽIT, ne proces zabít. Kdo službu zastaví, obejde
# tím zadání — proto se ptáme nejdřív, jestli vůbec ještě běží.
require_service_active "zpracovani"
PID="$(na_serveru "systemctl show zpracovani -p MainPID --value" | tr -d '\r')"
if [ -z "$PID" ] || [ "$PID" = "0" ]; then
  chyba "dávkové zpracování neběží, takže nemá co mít prioritu"
  poznamka "úkolem je zpomalit ho, ne zastavit — ./start.sh ho nastartuje"
else
  # `ps -o ni=` vypíše nice hodnotu bez hlavičky. Je to živý stav procesu:
  # ručně se nedá podvrhnout, protože ho drží jádro.
  NICE="$(na_serveru "ps -o ni= -p $PID" | tr -d ' \r')"
  case "$NICE" in
    ''|*[!0-9-]*) chyba "prioritu procesu se nepodařilo přečíst" ;;
    *) if [ "$NICE" -ge 10 ]; then
         uspech "dávkové zpracování běží se sníženou prioritou (nice $NICE)"
       else
         chyba "dávkové zpracování má pořád prioritu nice $NICE"
         poznamka "snižte ji aspoň na 10 — čím vyšší nice, tím ohleduplnější proces"
       fi ;;
  esac
fi

krok 2 "Kam se ztrácí místo"
# Doklad, že žák `du` opravdu pustil.
#
# Nestačí hledat jeden řádek se žroutem: kdo zná odpověď (od souseda,
# z modelu), napíše `echo "48 /srv/archiv/2024/faktury" > ~/mista.txt`
# a projde. Proto se porovnává CELÝ výpis proti tomu, co server vrací —
# a rozptylové soubory mají náhodné velikosti, které se z repozitáře
# odvodit nedají. Kdo výpis nepustil, těch devět čísel netrefí.
if ! na_serveru "test -s '$MISTA'"; then
  chyba "na serveru chybí ~/mista.txt s výpisem du"
  poznamka "uložte do něj výpis, ze kterého jste vycházeli"
else
  uspech "výpis du je na serveru"
  SEDI=0; CELKEM=0; ZROUT_SEDI=0
  while IFS=$'\t' read -r MB CESTA; do
    [ -n "${CESTA:-}" ] || continue
    CELKEM=$((CELKEM + 1))
    # Řádek žákova výpisu musí mít u téže cesty stejné číslo (±1 MB kvůli
    # zaokrouhlení, kdyby žák použil jiný přepínač du).
    ZAK_MB="$(na_serveru "grep -F '$CESTA' '$MISTA' | grep -oE '^[0-9]+' | head -1" | tr -d '\r')"
    [ -n "$ZAK_MB" ] || continue
    ROZDIL=$(( ZAK_MB - MB )); [ "$ROZDIL" -lt 0 ] && ROZDIL=$(( -ROZDIL ))
    if [ "$ROZDIL" -le 1 ]; then
      SEDI=$((SEDI + 1))
      case "$CESTA" in *"$ARCHIV_ROK/$ARCHIV_SLOZKA") ZROUT_SEDI=1 ;; esac
    fi
  done <<< "$(na_serveru "du -m /srv/archiv/*/* 2>/dev/null")"

  if [ "$CELKEM" -eq 0 ]; then
    chyba "obsah archivu se nepodařilo přečíst — spusťte ./start.sh"
  elif [ "$ZROUT_SEDI" -eq 1 ] && [ "$SEDI" -ge 3 ]; then
    uspech "výpis odpovídá tomu, co na serveru opravdu je ($SEDI z $CELKEM adresářů)"
  elif [ "$ZROUT_SEDI" -eq 1 ]; then
    chyba "ve výpisu sedí jen adresář se žroutem, ostatní ne"
    poznamka "uložte celý výpis, ne jeden řádek:  du -m /srv/archiv/*/* | sort -n > ~/mista.txt"
  else
    chyba "výpis neodpovídá tomu, co na serveru je"
    poznamka "du -m /srv/archiv/*/* | sort -n > ~/mista.txt"
  fi
fi

krok 3 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/provoz/formular.txt — spusťte ./start.sh, doplní ho"
ODP_CESTA="$(_zaznam "$FORMULAR" zrout)"
# Uznává se s lomítkem na začátku i bez něj a s celou cestou od /srv/archiv.
ODP_CESTA="${ODP_CESTA#/}"
ODP_CESTA="${ODP_CESTA#srv/archiv/}"
if [ "$ODP_CESTA" = "$ARCHIV_ZROUT" ]; then
  uspech "ve formuláři je cesta k největšímu souboru"
else
  chyba "cesta ve formuláři nesedí (máte '${ODP_CESTA:-nic}')"
  poznamka "píše se bez /srv/archiv na začátku, tedy ve tvaru rok/složka/soubor"
fi
ODP_MB="$(_zaznam "$FORMULAR" velikost | grep -oE '^[0-9]+')"
if [ -z "$ODP_MB" ]; then
  chyba "ve formuláři chybí velikost v MB"
elif [ "$ODP_MB" -ge $(( ARCHIV_MB - 2 )) ] && [ "$ODP_MB" -le $(( ARCHIV_MB + 2 )) ]; then
  uspech "velikost ve formuláři sedí"
else
  chyba "velikost ve formuláři nesedí (máte $ODP_MB)"
  poznamka "v celých MB, bez jednotky — du -m ukáže přesně to číslo"
fi

vypis_souhrn
