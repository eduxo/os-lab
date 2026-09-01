#!/bin/bash
# 2/14 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PODPORA="$HOME/netlab/podpora"
POSOUZENI="$PODPORA/posouzeni.txt"
HLASENI="$PODPORA/hlaseni.txt"
TIKET="$PODPORA/tiket.txt"
RESENI="$PODPORA/reseni.txt"

# Musí souhlasit se start.sh — stejné vzorce, stejné soli.
HLASICI=("Jana Marková, fakturace" "Petr Doležal, obchod" "Ivana Sýkorová, personální" "Tomáš Král, sklad")
PRIJMENI=(Marková Doležal Sýkorová Král)
TEXTY=(
"Nejde mi to. Prosím rychle, mám to na dnešek."
"Zase ten internet!!! Celý den nic nefunguje, takhle se nedá pracovat."
"Dobrý den, asi jsem něco rozbila. Vyskočilo okno s červeným textem a teď se to nechce otevřít. Nevím, co jsem udělala špatně."
"Potřebuju nainstalovat ten program, co jsme se o něm bavili minule. Díky."
)
H=$(lab_vyber 4 1 146)
KOD="$(lab_kod HLA 146)"
CAS="$(printf '%d:%02d' $(( 7 + ZAK % 5 )) $(( (ZAK * 7) % 60 )))"

# Matice priorit. Je to standardní tabulka dopad × naléhavost — hodnotí se,
# jestli si žák sám se sebou neodporuje, ne jestli trefil názor autora na to,
# jak je která situace naléhavá. To je věc rozpravy s vyučujícím.
priorita_z_matice() {  # dopad nalehavost
  case "$1:$2" in
    vysoky:vysoka)   echo kriticka ;;
    vysoky:stredni)  echo vysoka ;;
    vysoky:nizka)    echo stredni ;;
    stredni:vysoka)  echo vysoka ;;
    stredni:stredni) echo stredni ;;
    stredni:nizka)   echo nizka ;;
    nizky:vysoka)    echo stredni ;;
    nizky:stredni)   echo nizka ;;
    nizky:nizka)     echo velmi-nizka ;;
    *) echo "" ;;
  esac
}
slov() { printf '%s' "$1" | wc -w | tr -d ' '; }

krok 1 "Prostředí"
require_soubor_neprazdny "$HLASENI" \
  "hlášení od uživatele je na místě" \
  "chybí ~/netlab/podpora/hlaseni.txt — spusťte ./start.sh, doplní ho"
require_soubor_neprazdny "$POSOUZENI" \
  "formulář pro posouzení situací je na místě" \
  "chybí ~/netlab/podpora/posouzeni.txt — spusťte ./start.sh, doplní ho"
require_soubor_neprazdny "$TIKET" \
  "formulář tiketu je na místě" \
  "chybí ~/netlab/podpora/tiket.txt — spusťte ./start.sh, doplní ho"
require_soubor_neprazdny "$RESENI" \
  "formulář pro uzavření je na místě" \
  "chybí ~/netlab/podpora/reseni.txt — spusťte ./start.sh, doplní ho"

krok 2 "Posouzení situací"
PLATNE=0
PRIORITY=""
for I in 1 2 3 4; do
  D="$(_zaznam "$POSOUZENI" "situace-$I-dopad")"
  N="$(_zaznam "$POSOUZENI" "situace-$I-nalehavost")"
  P="$(_zaznam "$POSOUZENI" "situace-$I-priorita")"
  OCEK="$(priorita_z_matice "$D" "$N")"
  if [ -z "$D" ] || [ -z "$N" ] || [ -z "$P" ]; then
    chyba "situace $I není posouzená celá"
  elif [ -z "$OCEK" ]; then
    chyba "u situace $I je neplatná hodnota dopadu nebo naléhavosti"
    poznamka "dopad: vysoky/stredni/nizky · naléhavost: vysoka/stredni/nizka"
  elif [ "$P" = "$OCEK" ]; then
    uspech "situace $I: priorita odpovídá dopadu a naléhavosti, které jste určili"
    PLATNE=$((PLATNE + 1)); PRIORITY="$PRIORITY $P"
  else
    chyba "u situace $I priorita neodpovídá tabulce"
    poznamka "dopad $D a naléhavost $N dávají podle tabulky jinou prioritu"
  fi
done
# Měkká připomínka, ne hodnocení: čtyři různé situace se stejnou prioritou
# bývají známka toho, že se tabulka vyplňovala bez čtení.
if [ "$PLATNE" -eq 4 ] && [ "$(printf '%s' "$PRIORITY" | tr ' ' '\n' | sort -u | grep -c .)" -eq 1 ]; then
  poznamka "${_M}pozn.:${_0} všechny čtyři situace máte na stejné prioritě — vyučující se zeptá proč"
fi

krok 3 "Tiket"
# Údaje z hlášení — u každého žáka jiné, takže se nedají opsat od souseda.
require_zaznam "$TIKET" kod "$KOD" \
  "v tiketu je kód hlášení, ze kterého vznikl"
require_zaznam_tvar "$TIKET" hlasi "${PRIJMENI[H-1]}" \
  "v tiketu je, kdo potíž nahlásil" \
  "v tiketu chybí hlásící, nebo to není ten z vašeho hlášení"
require_zaznam_tvar "$TIKET" prijato "$CAS" \
  "v tiketu je čas přijetí hlášení" \
  "v tiketu chybí čas přijetí, nebo neodpovídá vašemu hlášení"

TD="$(_zaznam "$TIKET" dopad)"; TN="$(_zaznam "$TIKET" nalehavost)"; TP="$(_zaznam "$TIKET" priorita)"
TOCEK="$(priorita_z_matice "$TD" "$TN")"
if [ -z "$TD" ] || [ -z "$TN" ] || [ -z "$TP" ]; then
  chyba "tiket nemá vyplněný dopad, naléhavost nebo prioritu"
elif [ -z "$TOCEK" ]; then
  chyba "v tiketu je neplatná hodnota dopadu nebo naléhavosti"
elif [ "$TP" = "$TOCEK" ]; then
  uspech "priorita tiketu odpovídá dopadu a naléhavosti, které jste určili"
else
  chyba "priorita tiketu neodpovídá tabulce"
fi

NAZEV="$(_zaznam "$TIKET" nazev)"
if [ "$(slov "$NAZEV")" -ge 3 ]; then
  uspech "tiket má věcný název"
else
  chyba "tiket nemá použitelný název"
  poznamka "název má říct, co je rozbité — ne „nejde to\" a ne celá věta hlásícího"
fi

POPIS="$(_zaznam "$TIKET" popis)"
CITACE="${TEXTY[H-1]}"
if [ "$(slov "$POPIS")" -lt 12 ]; then
  chyba "popis v tiketu je příliš stručný na to, aby se podle něj dalo pracovat"
  poznamka "čekám aspoň dvanáct slov: co se děje, čeho se to týká, od kdy"
elif [ "$(printf '%s' "$POPIS" | tr -d ' .!?„“\"')" = "$(printf '%s' "$CITACE" | tr -d ' .!?„“\"')" ]; then
  chyba "popis je jen opsaná věta hlásícího"
  poznamka "hlášení je surovina — popis píše řešitel svými slovy a věcně"
else
  uspech "popis je věcný a je psaný vašimi slovy"
fi

D1="$(_zaznam "$TIKET" doptat-1)"; D2="$(_zaznam "$TIKET" doptat-2)"
if [ "$(slov "$D1")" -ge 3 ] && [ "$(slov "$D2")" -ge 3 ]; then
  if [ "$D1" = "$D2" ]; then
    chyba "obě otázky k doptání jsou stejné"
  else
    uspech "v tiketu je, co si musíte od hlásícího zjistit"
  fi
else
  chyba "v tiketu chybí, co si musíte od hlásícího zjistit"
  poznamka "hlášení neobsahuje dost na to, aby se dalo řešit — pojmenujte dvě věci, které chybí"
fi

krok 4 "Uzavření tiketu"
for KLIC in pricina postup prevence; do
  HODNOTA="$(_zaznam "$RESENI" "$KLIC")"
  if [ "$(slov "$HODNOTA")" -ge 4 ]; then
    uspech "v záznamu o uzavření je vyplněné: $KLIC"
  else
    chyba "v záznamu o uzavření chybí nebo je příliš stručné: $KLIC"
  fi
done

POTVRDIL="$(_zaznam "$RESENI" potvrdil)"
STAV="$(_zaznam "$RESENI" stav)"
case "$STAV" in
  uzavren)
    # Tady je celý smysl rozdílu vyřešený × uzavřený: uzavírá se až potom,
    # co uživatel potvrdí, že to funguje.
    if [ -n "$POTVRDIL" ]; then
      uspech "tiket je uzavřený a je doložené, kdo funkčnost potvrdil"
    else
      chyba "tiket je uzavřený, ale nikdo nepotvrdil, že to funguje"
      poznamka "vyřešený znamená „myslím, že jsem to spravil\"; uzavřený znamená"
      poznamka "„uživatel potvrdil, že to funguje\" — bez potvrzení se neuzavírá"
    fi ;;
  vyresen)
    chyba "tiket je jen vyřešený, ne uzavřený"
    poznamka "doplňte, kdo funkčnost potvrdil, a teprve pak stav změňte" ;;
  "") chyba "v záznamu o uzavření chybí stav tiketu" ;;
  *)  chyba "neznámý stav tiketu"
      poznamka "povolené hodnoty: vyresen | uzavren" ;;
esac

vypis_souhrn
