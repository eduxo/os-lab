#!/bin/bash
# 2/14 — Uživatelská podpora. Prostředí: žákova stanice.
#
# Cvičení dřív potřebovalo kontejner s GLPI. Zrušeno 2026-09-01: systém
# v labu nenesl žádnou látku (žádné pozdější cvičení ho nepoužívalo,
# kontrola do něj neviděla, maturitní okruh nepokrývá) a byl to jediný
# důvod, proč 2. ročník potřeboval kontejner. Látka — priorita z dopadu
# a naléhavosti, napsat a uzavřít tiket — zůstala beze změny.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PODPORA="$HOME/netlab/podpora"
POSOUZENI="$PODPORA/posouzeni.txt"
HLASENI="$PODPORA/hlaseni.txt"
TIKET="$PODPORA/tiket.txt"
RESENI="$PODPORA/reseni.txt"

# ── situace k posouzení ───────────────────────────────────────────
# Čtyři z osmi, u každého žáka jiné. Odpovědi se nikam neukládají: hodnotí
# se, jestli si žák sám se sebou neodporuje (viz check.sh), ne jestli trefil
# můj názor na dopad.
SITUACE=(
"Účetní hlásí, že jí nejde vytisknout fakturu. Tiskárna ve druhém patře nereaguje, ostatní na patře tisknou normálně."
"Nefunguje internet v celé budově. Nikdo se nedostane ke sdíleným dokumentům ani k e-mailu."
"Kolegovi ze skladu se špatně zobrazuje ikona na ploše. Program funguje, jen ikona je bílá."
"Obchodnímu zástupci nejde přihlášení do systému objednávek. Za dvě hodiny jede k zákazníkovi a potřebuje si vytisknout nabídku."
"Server, na kterém běží docházkový systém, má zaplněný disk na 92 %. Systém zatím funguje."
"Vedoucí skladu hlásí, že mu čtečka čárových kódů občas přeskočí znak. Inventura je za tři týdny."
"Personální oddělení nemůže otevřít sdílenou složku se smlouvami. Jsou tam tři lidé a všichni na ní dnes potřebují pracovat."
"Jednomu z brigádníků nejde přehrát video na firemním intranetu. Je to školicí video, které má zhlédnout do konce měsíce."
)

# ── hlášení, ze kterého se dělá tiket ─────────────────────────────
# Všechna čtyři jsou napsaná špatně, každé jinak: vágně, emotivně, bez
# faktů, nebo jako požadavek bez zadání. To je materiál k práci — žák z něj
# musí udělat tiket a hlavně pojmenovat, co si musí doptat.
HLASICI=("Jana Marková, fakturace" "Petr Doležal, obchod" "Ivana Sýkorová, personální" "Tomáš Král, sklad")
TEXTY=(
"Nejde mi to. Prosím rychle, mám to na dnešek."
"Zase ten internet!!! Celý den nic nefunguje, takhle se nedá pracovat."
"Dobrý den, asi jsem něco rozbila. Vyskočilo okno s červeným textem a teď se to nechce otevřít. Nevím, co jsem udělala špatně."
"Potřebuju nainstalovat ten program, co jsme se o něm bavili minule. Díky."
)
H=$(lab_vyber 4 1 146)
KOD="$(lab_kod HLA 146)"
CAS="$(printf '%d:%02d' $(( 7 + ZAK % 5 )) $(( (ZAK * 7) % 60 )))"

vyrob_hlaseni() {
  cat > "$HLASENI" <<HLASENI_KONEC
Hlášení $KOD
Přijato: 4. 11. 2026 $CAS
Hlásí: ${HLASICI[H-1]}

"${TEXTY[H-1]}"

--
Takhle to přišlo. Víc v tom není.
HLASENI_KONEC
}

vyrob_posouzeni() {
  {
    echo "# Posouzení situací — vyplňte hodnoty za dvojtečku."
    echo "#"
    echo "# dopad      = vysoky | stredni | nizky      (kolika lidí se to týká)"
    echo "# nalehavost = vysoka | stredni | nizka      (jak moc to spěchá)"
    echo "# priorita   = odvodíte z tabulky v zadání"
    echo
    I=1
    for N in $(lab_vyber 8 4 145); do
      printf '# Situace %d: %s\n' "$I" "${SITUACE[N-1]}"
      printf 'situace-%d-dopad:\n' "$I"
      printf 'situace-%d-nalehavost:\n' "$I"
      printf 'situace-%d-priorita:\n\n' "$I"
      I=$((I+1))
    done
  } > "$POSOUZENI"
}

vyrob_tiket() {
  cat > "$TIKET" <<'TIKET_KONEC'
# Tiket — vyplňte hodnoty za dvojtečku.
#
# kod        = kód hlášení, ze kterého tiket vznikl
# nazev      = věcný název na jednu řádku (co je rozbité, ne jak to hlásící prožívá)
# hlasi      = kdo hlásí
# prijato    = kdy hlášení přišlo
# dopad      = vysoky | stredni | nizky
# nalehavost = vysoka | stredni | nizka
# priorita   = odvodíte z tabulky
# popis      = co se děje, vašimi slovy a věcně (aspoň 12 slov, na jedné řádce)
# doptat-1   = co si musíte od hlásícího zjistit, aby se to dalo řešit
# doptat-2   = druhá věc, kterou se musíte doptat
kod:
nazev:
hlasi:
prijato:
dopad:
nalehavost:
priorita:
popis:
doptat-1:
doptat-2:
TIKET_KONEC
}

vyrob_reseni() {
  cat > "$RESENI" <<'RESENI_KONEC'
# Uzavření tiketu — vyplňte hodnoty za dvojtečku.
#
# pricina   = co potíž způsobilo (ne co jste udělali — proč k ní došlo)
# postup    = co jste udělali, aby to fungovalo
# prevence  = čím se dá zařídit, aby se to neopakovalo
# potvrdil  = kdo z uživatelů potvrdil, že to funguje
# stav      = vyresen | uzavren
pricina:
postup:
prevence:
potvrdil:
stav:
RESENI_KONEC
}

# Prostředí, které už stojí, se nepřestavuje — jen se doplní formuláře,
# které si žák smazal nebo vyprázdnil.
if [ -d "$PODPORA" ]; then
  DOPLNENO=""
  [ -s "$HLASENI" ]   || { vyrob_hlaseni;   DOPLNENO="$DOPLNENO hlaseni.txt"; }
  [ -s "$POSOUZENI" ] || { vyrob_posouzeni; DOPLNENO="$DOPLNENO posouzeni.txt"; }
  [ -s "$TIKET" ]     || { vyrob_tiket;     DOPLNENO="$DOPLNENO tiket.txt"; }
  [ -s "$RESENI" ]    || { vyrob_reseni;    DOPLNENO="$DOPLNENO reseni.txt"; }
  echo
  if [ -n "$DOPLNENO" ]; then
    echo "  Prostředí už existuje v $PODPORA."
    echo "  Chybělo tohle, doplnila jsem to:$DOPLNENO"
  else
    echo "  Prostředí už existuje v $PODPORA — pokračujte, kde jste skončili."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

mkdir -p "$PODPORA"
vyrob_hlaseni
vyrob_posouzeni
vyrob_tiket
vyrob_reseni

cat <<EOF

  Prostředí je připravené.

    Hlášení od uživatele:  $HLASENI
    Situace k posouzení:   $POSOUZENI
    Tiket k sepsání:       $TIKET
    Uzavření tiketu:       $RESENI

  Přečtěte si hlášení a přepněte se do adresáře:

    cat ~/netlab/podpora/hlaseni.txt
    cd ~/netlab/podpora

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/14-uzivatelska-podpora && ./check.sh --krok 1

EOF
