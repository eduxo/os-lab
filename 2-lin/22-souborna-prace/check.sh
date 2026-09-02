#!/bin/bash
# 2/22 — ověření souborné práce
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PREV="$HOME/netlab/prevzeti"
DOK="$PREV/dokumenty"
INST="$PREV/instalace"
KARANTENA="$PREV/karantena"
SDILENY="$PREV/expedice"
# Odkladiště je SOUROZENEC sdíleného adresáře, ne jeho podadresář. Uvnitř
# adresáře, kam ostatní nesmí vstoupit, by právo „psát smí každý" nešlo
# ani předvést — a přesně to cvičení 17 na sticky bitu ukazovalo.
ODKLAD="$PREV/odkladiste"
VYSLEDEK="$PREV/vysledek"
OBNOVENO="$VYSLEDEK/obnoveno"
PROTOKOL="$PREV/protokol.txt"
TIKET="$PREV/tiket.txt"
STARA="$PREV/zaloha-2026-06-30.tar.gz"
ZNACKA_STOP="$PREV/.stop-pouzit"

# Musí souhlasit se start.sh — stejné vzorce, stejné soli.
JMENA=(mvesela rkolar jsedlak bnovotny lkrizova pmoravec)
CELE=("Marie Veselá" "Radek Kolář" "Jan Sedlák" "Bohumil Novotný" "Lenka Křížová" "Petr Moravec")
IDX=$(lab_vyber 6 1 221)
UZIVATEL="${JMENA[IDX-1]}"
CELE_JMENO="${CELE[IDX-1]}"
MESIC=$(( 1 + ZAK % 6 ))
DATUM="$(printf '2027-%02d-15' "$MESIC")"
VADNY=$(lab_vyber 2 1 222)
BALICEK="balicek-skladnik-1.$VADNY.tar.gz"
DOBRY="balicek-skladnik-1.$(( 3 - VADNY )).tar.gz"
KOD_SMLOUVY="$(lab_kod SML 22)"
SMLOUVA="smlouva-$KOD_SMLOUVY.txt"
USEKY=(prijem vydej reklamace inventura)
SBER="sber-${USEKY[$(( $(lab_vyber 4 1 223) - 1 ))]}.sh"
NECITELNY=$(lab_vyber 5 1 224)
LIST="dodaci-list-$(printf '%02d' "$NECITELNY").txt"
DOKUMENTY=(dodaci-list-01.txt dodaci-list-02.txt dodaci-list-03.txt \
           dodaci-list-04.txt dodaci-list-05.txt poznamky.txt)

obsah_listu() { printf 'Dodací list %02d\nOddělení: sklad\nPoložek: %d\n' "$1" $(( 3 + (ZAK + $1) % 9 )); }
skupina_adresare() { ls -ld "$1" 2>/dev/null | awk '{print $4}'; }   # stat -c %G je jen GNU

krok 1 "Prostředí"
require_soubor_neprazdny "$TIKET" \
  "tiket je na místě" \
  "chybí ~/netlab/prevzeti/tiket.txt — spusťte ./start.sh, doplní ho"
require_soubor_neprazdny "$PROTOKOL" \
  "předávací protokol je na místě" \
  "chybí ~/netlab/prevzeti/protokol.txt — spusťte ./start.sh, doplní ho"
require_path "$DOK" \
  "dokumenty po kolegovi jsou na místě" \
  "chybí ~/netlab/prevzeti/dokumenty — spusťte ./start.sh"
require_soubor_neprazdny "$STARA" \
  "stará záloha po kolegovi je na místě" \
  "chybí ~/netlab/prevzeti/zaloha-2026-06-30.tar.gz — obnovíte ji přes ./reset.sh"

krok 2 "Účet, skupina a sdílené adresáře"
require_group expedice
require_user "$UZIVATEL"
if id "$UZIVATEL" >/dev/null 2>&1; then
  require_member "$UZIVATEL" expedice
  # Celé jméno je v tiketu, takže ho hláška prozradit smí.
  GECOS="$(getent passwd "$UZIVATEL" | cut -d: -f5 | cut -d, -f1)"
  if [ "$GECOS" = "$CELE_JMENO" ]; then
    uspech "$UZIVATEL má vyplněné celé jméno"
  else
    chyba "$UZIVATEL nemá jako celé jméno '$CELE_JMENO' (má '${GECOS:-nic}')"
    poznamka "zakládá se přepínačem -c, doplnit jde příkazem usermod"
  fi

  # Platnost účtu se čte z osmého pole /etc/shadow — počet dní od epochy.
  # Přes `chage -l` by se hledal řetězec data, a ten závisí na jazyce
  # i na formátu výpisu; v bloku D na tom kontrola platnosti spadla celé
  # třídě. Číslo je jednoznačné.
  STIN="$(sudo -n getent shadow "$UZIVATEL" 2>/dev/null || sudo getent shadow "$UZIVATEL" 2>/dev/null)"
  CEKANO="$(date -d "$DATUM" +%s 2>/dev/null)"
  if [ -z "$STIN" ]; then
    chyba "u $UZIVATEL se nepodařilo přečíst nastavení platnosti"
    poznamka "kontrola potřebuje práva správce — zadejte heslo, až se zeptá"
  elif [ -z "$CEKANO" ]; then
    chyba "nepodařilo se spočítat očekávané datum platnosti"
  else
    MA="$(printf '%s' "$STIN" | cut -d: -f8)"
    if [ "${MA:-}" = "$(( CEKANO / 86400 ))" ]; then
      uspech "účet $UZIVATEL platí do data z tiketu"
    else
      chyba "účet $UZIVATEL nemá platnost do data z tiketu"
    fi
  fi
  # Negativní: zástup na dobu určitou nedostává práva správce.
  if id -nG "$UZIVATEL" 2>/dev/null | tr ' ' '\n' | grep -qx sudo; then
    chyba "$UZIVATEL dostal práva správce — tiket o nich nemluví"
  else
    uspech "$UZIVATEL nedostal práva správce"
  fi
fi

require_path "$SDILENY" \
  "sdílený adresář expedice existuje" \
  "chybí ~/netlab/prevzeti/expedice"
if [ -d "$SDILENY" ]; then
  SK="$(skupina_adresare "$SDILENY")"
  if [ "$SK" = "expedice" ]; then uspech "sdílený adresář patří skupině expedice"
  else chyba "sdílený adresář nepatří skupině expedice (má '${SK:-?}')"; fi
  # Hlášky v ověřovacím cvičení neprozrazují, jaká práva se čekají —
  # odvodit si je má žák sám ze zadání.
  require_setgid "$SDILENY" \
    "co ve sdíleném adresáři vznikne, nedostane skupinu expedice samo od sebe"
  require_mode "$SDILENY" 2770 \
    "práva sdíleného adresáře neodpovídají tomu, co žádá tiket"
fi
require_path "$ODKLAD" \
  "odkladiště existuje" \
  "chybí ~/netlab/prevzeti/odkladiste"
[ -d "$ODKLAD" ] && require_mode "$ODKLAD" 1777 \
  "práva odkladiště neodpovídají tomu, co žádá tiket"

# Negativní: 777 bez sticky je obchvat, ne řešení. Hlásit se má jen tehdy,
# když je co kontrolovat — jinak by [PASS] dostal i ten, kdo nic nezaložil.
OBCHVAT=""
for A in "$SDILENY" "$PREV" "$VYSLEDEK" "$KARANTENA"; do
  [ -d "$A" ] || continue
  case "$(ls -ld "$A" 2>/dev/null | cut -c1-10)" in
    drwxrwxrwx) OBCHVAT="$OBCHVAT $(basename "$A")" ;;
  esac
done
if [ -n "$OBCHVAT" ]; then
  chyba "práva 777 bez sticky:$OBCHVAT — to není řešení, to je díra"
elif [ -d "$SDILENY" ]; then
  uspech "žádný adresář nemá práva 777 bez sticky"
fi

krok 3 "Balíčky, nečitelný dokument a zálohy"
# Hláška nesmí rozlišit „přesunul jsi špatný" od „nepřesunul jsi nic" —
# jinak by se dala kontrola použít jako věštírna: tipnout a nechat si
# poradit, aniž by žák otisky vůbec spočítal.
if [ -f "$KARANTENA/$BALICEK" ] && [ ! -f "$INST/$BALICEK" ] \
   && [ -f "$INST/$DOBRY" ] && [ ! -f "$KARANTENA/$DOBRY" ]; then
  uspech "v karanténě je právě ten balíček, jehož otisk nesedí"
elif [ ! -f "$KARANTENA/$BALICEK" ] && [ ! -f "$INST/$BALICEK" ]; then
  chyba "jeden z balíčků zmizel — smazaný nález se nedá reklamovat"
else
  chyba "obsah karantény neodpovídá výsledku ověření otisků"
  poznamka "spočítejte otisky obou balíčků a porovnejte je se soubory .sha256"
fi

# Otisk se počítá z balíčku tak, jak leží — ať už ho žák přesunul kamkoli.
KDE="$KARANTENA/$BALICEK"; [ -f "$KDE" ] || KDE="$INST/$BALICEK"
if [ -f "$KDE" ]; then
  SKUTECNY="$(_hash < "$KDE")"
  # Uzná se prvních 12 znaků i celý otisk — smysl úkolu je otisk spočítat,
  # ne trefit délku výpisu.
  require_zaznam_tvar "$PROTOKOL" otisk-skutecny "^${SKUTECNY:0:12}" \
    "v protokolu je skutečný otisk poškozeného balíčku" \
    "v protokolu chybí skutečný otisk poškozeného balíčku, nebo nesouhlasí"
fi
require_zaznam_jmeno "$PROTOKOL" balicek-vadny "$BALICEK" \
  "v protokolu je jméno poškozeného balíčku"

# Nečitelný dokument: musí jít přečíst, musí být původní a nesmí být
# zpřístupněný všem.
if [ ! -f "$DOK/$LIST" ]; then
  chyba "jeden z dodacích listů v dokumentech chybí"
elif [ ! -r "$DOK/$LIST" ]; then
  chyba "jeden z dodacích listů pořád nejde přečíst"
  poznamka "podívejte se na práva souborů v dokumentech — jeden se od ostatních liší"
elif [ "$(obsah_listu "$NECITELNY")" != "$(cat "$DOK/$LIST" 2>/dev/null)" ]; then
  chyba "obsah opraveného dodacího listu neodpovídá původnímu"
  poznamka "soubor se měl zpřístupnit, ne přepsat nebo založit znovu"
else
  case "$(ls -l "$DOK/$LIST" 2>/dev/null | cut -c1-10)" in
    *w*w*w*) chyba "opravený dodací list je zapisovatelný pro všechny"
             poznamka "zpřístupnit se měl vám, ne celému světu" ;;
    *) uspech "dodací list jde zase přečíst a je původní" ;;
  esac
fi
require_zaznam_jmeno "$PROTOKOL" necitelny-soubor "$LIST" \
  "v protokolu je jméno dokumentu, který nešel přečíst"

# Zálohy: víc archivů = nejednoznačné zadání pro kontrolu i pro hodnocení.
POCET_ZAL=$(ls -1 "$VYSLEDEK"/zaloha-prevzeti-*.tar.gz 2>/dev/null | grep -c '')
ZALOHA="$(ls -1 "$VYSLEDEK"/zaloha-prevzeti-*.tar.gz 2>/dev/null | tail -n1)"
if [ "${POCET_ZAL:-0}" -eq 0 ]; then
  chyba "chybí záloha dokumentů (vysledek/zaloha-prevzeti-RRRR-MM-DD.tar.gz)"
elif [ "$POCET_ZAL" -gt 1 ]; then
  chyba "ve vysledek/ je víc záloh — nechte jen tu platnou"
elif ! printf '%s' "$(basename "$ZALOHA")" | grep -qE '^zaloha-prevzeti-[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz$'; then
  chyba "jméno zálohy neodpovídá tvaru zaloha-prevzeti-RRRR-MM-DD.tar.gz"
else
  require_soubor_magie "$ZALOHA" "1f8b" "záloha dokumentů je komprimovaný archiv"
  # Porovnávají se JMÉNA, ne počet: šest prázdných souborů by prošlo taky.
  # Seznam je pevný, ne dopočítaný z adresáře — kdo dokumenty po záloze
  # uklidí, nemá dostat výtku mířenou na archiv.
  V_ARCHIVU="$(tar -tzf "$ZALOHA" 2>/dev/null | sed 's#.*/##' | grep -v '^$' | sort | tr '\n' ' ')"
  CEKANE="$(printf '%s\n' "${DOKUMENTY[@]}" | sort | tr '\n' ' ')"
  if [ "$V_ARCHIVU" = "$CEKANE" ]; then
    uspech "záloha obsahuje všechny dokumenty po kolegovi"
  else
    chyba "záloha neobsahuje přesně dokumenty po kolegovi"
    poznamka "zálohuje se celý adresář dokumenty; pokud tar něco nepřečetl, ohlásil to"
  fi
  # A jeden vzorek bajtově — proti archivu z prázdných souborů.
  if tar -xzOf "$ZALOHA" '*/poznamky.txt' 2>/dev/null | cmp -s - "$DOK/poznamky.txt"; then
    uspech "obsah zálohy odpovídá dokumentům na disku"
  else
    chyba "obsah zálohy neodpovídá dokumentům na disku"
  fi
fi

if [ ! -d "$OBNOVENO" ]; then
  chyba "chybí ~/netlab/prevzeti/vysledek/obnoveno — obnovte smlouvu stranou"
else
  POCET=$(find "$OBNOVENO" -type f 2>/dev/null | grep -c '')
  if [ "$POCET" -eq 1 ]; then uspech "v adresáři obnoveno je jediný soubor"
  elif [ "$POCET" -eq 0 ]; then chyba "adresář obnoveno je prázdný"
  else chyba "v adresáři obnoveno není jediný soubor (napočítáno: $POCET)"
       poznamka "tiket žádá jednu smlouvu, ne celou zálohu"; fi
  OBN="$(find "$OBNOVENO" -type f -name "$SMLOUVA" 2>/dev/null | head -n1)"
  if [ -z "$OBN" ]; then
    chyba "smlouva z tiketu mezi obnovenými soubory není"
  elif tar -xzOf "$STARA" "smlouvy/$SMLOUVA" 2>/dev/null | cmp -s - "$OBN"; then
    uspech "obnovená smlouva je přesná kopie té ze zálohy"
  else
    chyba "obnovená smlouva se od té ve staré záloze liší"
    poznamka "smlouva se ze zálohy rozbaluje, neopisuje"
  fi
fi

krok 4 "Kolegův proces a protokol"
BEZI="$(pgrep -f "bash .*$SBER" 2>/dev/null | tr '\n' ' ')"
if [ -n "${BEZI// /}" ]; then
  chyba "proces po kolegovi pořád běží (PID: ${BEZI% })"
  poznamka "tiket žádá, abyste ho ukončili"
elif [ -f "$ZNACKA_STOP" ]; then
  chyba "kolegův proces ukončil stop.sh, ne vy"
  poznamka "úklidový skript to udělal za vás — úkol je ukončit ho sám"
elif [ ! -s "$PREV/sber.log" ]; then
  # Neexistence procesu není totéž co jeho ukončení.
  chyba "kolegův proces na stanici nikdy neběžel — spusťte ./start.sh"
else
  uspech "proces po kolegovi už neběží"
fi

PID="$(_zaznam "$PROTOKOL" proces-pid)"
if printf '%s' "$PID" | grep -qE '^[0-9]+$'; then
  if [ -f "$PREV/sber.log" ] && grep -q "PID=$PID " "$PREV/sber.log"; then
    uspech "PID v protokolu odpovídá procesu, který na stanici běžel"
  else
    chyba "PID $PID v logu kolegova procesu není"
  fi
else
  chyba "v protokolu chybí PID kolegova procesu, nebo to není číslo"
fi
require_zaznam_jmeno "$PROTOKOL" proces-jmeno "$SBER" \
  "v protokolu je jméno kolegova skriptu"
require_zaznam "$PROTOKOL" uzivatel "$UZIVATEL" \
  "v protokolu je přihlašovací jméno založeného účtu"
require_zaznam_jmeno "$PROTOKOL" obnoveny-soubor "$SMLOUVA" \
  "v protokolu je jméno obnovené smlouvy"

POSTUP="$VYSLEDEK/postup.txt"
require_min_radku "$POSTUP" 25 \
  "postup je doložený historií příkazů" \
  "ve vysledek/postup.txt chybí historie vaší práce (čekám aspoň 25 řádků)"
if [ -f "$POSTUP" ]; then
  # Doklad vlastní práce nesmí jít vyrobit jedním příkazem. Hledají se stopy
  # po nástrojích, bez kterých se úkoly udělat nedaly.
  CHYBI=""
  for VZOR in 'sha256sum|shasum' 'tar' 'chmod|chown' 'ps |pgrep|top|kill'; do
    grep -qE "$VZOR" "$POSTUP" 2>/dev/null || CHYBI="$CHYBI ${VZOR%%|*}"
  done
  if [ -z "$CHYBI" ]; then
    uspech "v postupu je vidět práce se všemi nástroji, které úkoly vyžadovaly"
  else
    chyba "v postupu chybí stopa po nástrojích:$CHYBI"
    poznamka "ukládá se skutečná historie z okna, ve kterém jste pracovali"
  fi
fi

vypis_souhrn
