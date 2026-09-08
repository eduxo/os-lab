#!/bin/bash
# 3/06 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="server-$ZAK2"
UCET="sysadmin"
REPO="/home/$UCET/skripty"
VERZE="$HOME/netlab/verzovani"
FORMULAR="$VERZE/formular.txt"
EMAIL="$ZAK_UZIVATEL@netlab.test"

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

# Git se pouští jako žák a v jeho repozitáři.
g() { lxc exec "$KONT" -- runuser -u "$UCET" -- git -C "$REPO" "$@" 2>/dev/null; }

krok 1 "Repozitář a identita"
if ! lxc exec "$KONT" -- bash -c 'command -v git >/dev/null' 2>/dev/null; then
  chyba "na serveru není nainstalovaný git — spusťte ./start.sh, doinstaluje ho"
fi
if lxc exec "$KONT" -- test -d "$REPO/.git" 2>/dev/null; then
  uspech "v ~/skripty je založený repozitář"
else
  chyba "v ~/skripty žádný repozitář není"
  poznamka "zakládá se příkazem git init v tom adresáři"
fi
JMENO="$(g config user.name | tr -d '\r')"
MAIL="$(g config user.email | tr -d '\r')"
if [ -n "$JMENO" ]; then uspech "commiter má nastavené jméno ($JMENO)"
else chyba "commiter nemá nastavené jméno"
     poznamka "bez user.name a user.email git commit odmítne"; fi
if [ "$MAIL" = "$EMAIL" ]; then uspech "commiter má e-mail podle zadání"
else chyba "e-mail commitera neodpovídá zadání (má '${MAIL:-nic}')"; fi

krok 2 "Commity a .gitignore"
POCET="$(g rev-list --count HEAD | tr -d '\r')"; POCET="${POCET:-0}"
# Tady stačí PRVNÍ commit — tři jich má být až po Kroku 3 a kontroluje je
# část 3. Kdyby se tři žádaly tady, `--krok 2` by v okamžiku, kdy na něj
# zadání posílá, vždycky selhal.
if [ "$POCET" -ge 1 ]; then
  uspech "repozitář má první commit"
else
  chyba "repozitář zatím nemá žádný commit"
  poznamka "bez user.name a user.email git commit odmítne"
fi
if g ls-files | grep -qx 'stav.sh'; then
  uspech "skript stav.sh je sledovaný"
else
  chyba "skript stav.sh není v repozitáři sledovaný"
fi
# Log je výstup, ne zdroj — do repozitáře nepatří. Nestačí ho uvést
# v .gitignore, nesmí být ani sledovaný: na už sledované soubory .gitignore
# neplatí a tuhle past žák snadno spadne.
if g ls-files | grep -qx 'stav.log'; then
  chyba "stav.log je sledovaný, přestože do repozitáře nepatří"
  poznamka ".gitignore na už sledovaný soubor neplatí — musí se ze sledování vyjmout"
elif g check-ignore -q stav.log; then
  # Ptáme se gitu, ne grepem na text. Žák, který napsal `*.log` místo
  # `stav.log`, to udělal líp — a doslovný vzor by ho za to potrestal.
  uspech "stav.log je vyloučený ze sledování a .gitignore ho pokrývá"
else
  chyba "stav.log není v .gitignore pokrytý"
  poznamka "pokrýt ho může i vzor jako *.log"
fi
if g ls-files | grep -qx '.gitignore'; then
  uspech ".gitignore je sám také sledovaný"
else
  chyba ".gitignore není sledovaný — kolegům by se nepropsal"
fi

krok 3 "Návrat k předchozí verzi"
PRVNI="$(g rev-list --max-parents=0 HEAD | tr -d '\r' | head -1)"
if [ -z "$PRVNI" ] || [ "$POCET" -lt 3 ]; then
  chyba "návrat nejde ověřit, dokud nejsou aspoň tři commity"
else
  A="$(lxc exec "$KONT" -- runuser -u "$UCET" -- git -C "$REPO" show "$PRVNI:stav.sh" 2>/dev/null | _hash)"
  B="$(lxc exec "$KONT" -- runuser -u "$UCET" -- git -C "$REPO" show "HEAD:stav.sh" 2>/dev/null | _hash)"
  C="$(lxc exec "$KONT" -- runuser -u "$UCET" -- git -C "$REPO" show "HEAD~1:stav.sh" 2>/dev/null | _hash)"
  # Pozor: `_hash` prázdného vstupu vrací otisk prázdného řetězce, takže
  # test na neprázdnost by byl mrtvý. Ověřuje se, že soubor v commitu vůbec je.
  MA_SOUBOR=0
  lxc exec "$KONT" -- runuser -u "$UCET" -- git -C "$REPO" cat-file -e "$PRVNI:stav.sh" 2>/dev/null && MA_SOUBOR=1
  if [ "$MA_SOUBOR" -eq 0 ]; then
    chyba "v prvním commitu není soubor stav.sh"
  elif [ "$A" = "$B" ] && [ "$A" != "$C" ]; then
    uspech "poslední commit vrátil skript do podoby z prvního commitu"
  elif [ "$A" = "$C" ]; then
    chyba "mezi prvním a posledním commitem se skript vůbec nezměnil"
    poznamka "prostřední commit má obsahovat úpravu, kterou pak vrátíte"
  else
    chyba "poslední commit neodpovídá podobě z prvního commitu"
    poznamka "vrací se obsahem, ne smazáním historie"
  fi
fi

krok 4 "Formulář"
require_zaznam "$FORMULAR" commitu "$POCET" \
  "ve formuláři je počet commitů"
if [ -n "$PRVNI" ]; then
  ODP="$(_zaznam "$FORMULAR" prvni)"
  # Uzná se zkrácený i celý otisk — délku zkrácení volí git podle velikosti
  # repozitáře a žák ji neovlivní. Porovnává se PŘEDPONA přes `case`, ne
  # grepem: odpověď by v regulárním výrazu fungovala jako vzor a `.*` by
  # prošlo. A hláška zkrácený otisk nevypisuje, byla by to odpověď.
  case "$PRVNI" in
    "$ODP"*) DELKA_OK=1 ;;
    *)       DELKA_OK=0 ;;
  esac
  if [ -n "$ODP" ] && [ "${#ODP}" -ge 7 ] && [ "$DELKA_OK" -eq 1 ]; then
    uspech "ve formuláři je otisk prvního commitu"
  elif [ -n "$ODP" ] && [ "${#ODP}" -lt 7 ]; then
    chyba "otisk prvního commitu je ve formuláři příliš krátký"
    poznamka "git zkracuje na sedm znaků a víc"
  else
    chyba "otisk prvního commitu ve formuláři nesedí (máte '${ODP:-nic}')"
    poznamka "vypíše ho git log --oneline"
  fi
fi
require_zaznam "$FORMULAR" ignorovano stav.log \
  "ve formuláři je jméno vyloučeného souboru"

vypis_souhrn
