#!/bin/bash
# 3/16 — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 je jen prohlídka, u té není co ověřovat.
#
# Stránka se stahuje ZE STANICE, ne ze serveru. `curl localhost` na serveru
# by uspěl i u webu, ke kterému se zvenčí nikdo nedostane.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="web-$ZAK2"
SERVER_KONT="$KONT"
source "$(dirname "$0")/../../lib/web-lib.sh"

WEB="$HOME/netlab/web"
FORMULAR="$WEB/formular.txt"

if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo; echo "  Na stanici není curl. Řekněte o tom vyučujícímu."; echo; exit 1
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
IP="$(na_serveru "ip -4 -o addr show dev eth0 | awk '{print \$4}' | cut -d/ -f1" | tr -d '\r' | head -1)"
KOD="$(lxc config get "$KONT" "$WEB_KOD_KLIC" 2>/dev/null | tr -d '\r')"

krok 2 "Obsah webu"
if na_serveru "test -d '$WEB_ROOT'"; then
  uspech "kořen dokumentů $WEB_ROOT existuje"
else
  chyba "na serveru není adresář $WEB_ROOT"
fi
if na_serveru "test -s '$WEB_ROOT/index.html'"; then
  uspech "v kořeni je index.html"
  # Kód pobočky leží jen na serveru a nikde se nevypisuje. Do stránky
  # se dostane jedině tak, že se žák na server podívá.
  if [ -z "$KOD" ]; then
    chyba "kód pobočky se nepodařilo přečíst — spusťte ./reset.sh"
  elif na_serveru "grep -qF '$KOD' '$WEB_ROOT/index.html'"; then
    uspech "na stránce je kód pobočky"
  else
    chyba "na stránce chybí kód pobočky"
    poznamka "najdete ho v podkladech na serveru: $WEB_PODKLADY"
  fi
else
  chyba "v kořeni chybí index.html"
fi

krok 3 "Virtual host"
VYPIS="$(na_serveru "apache2ctl -S 2>&1")"
if printf '%s' "$VYPIS" | grep -q "$WEB_JMENO"; then
  uspech "Apache zná virtual host $WEB_JMENO"
else
  chyba "Apache o virtual hostu $WEB_JMENO neví"
  poznamka "soubor v sites-available nestačí — musí se povolit a2ensite a načíst reload"
fi
if na_serveru "apache2ctl configtest 2>&1 | grep -q 'Syntax OK'"; then
  uspech "konfigurace Apache je syntakticky v pořádku"
else
  chyba "konfigurace Apache má chybu"
  poznamka "apache2ctl configtest ji vypíše i s číslem řádku"
fi
require_service_active "apache2"

krok 4 "Web odpovídá ze stanice"
# Filtr --krok potlačuje výpis, ne provádění. Bez téhle podmínky by
# `--krok 2` — první kontrola, na kterou návod posílá — čekal tři krát
# osm vteřin na web, který v tu chvíli ještě neexistuje.
if ! krok_aktivni 4; then :
elif [ -z "$IP" ]; then
  chyba "adresa serveru se nepodařilo zjistit"
else
  STAV_KOD="$(stav_webu "$WEB_JMENO" 80 "$IP")"
  case "$STAV_KOD" in
    200) uspech "web $WEB_JMENO odpovídá stavem 200" ;;
    000) chyba "web $WEB_JMENO se ze stanice nedovolá"
         poznamka "běží Apache? poslouchá na portu 80?" ;;
    *)   chyba "web $WEB_JMENO odpovídá stavem $STAV_KOD" ;;
  esac
  OBSAH="$(stahni_web "$WEB_JMENO" 80 "$IP")"
  if [ -n "$KOD" ] && printf '%s' "$OBSAH" | grep -qF "$KOD"; then
    uspech "stránka vrácená ze stanice obsahuje kód pobočky"
  else
    chyba "stránka vrácená ze stanice kód pobočky neobsahuje"
    poznamka "možná odpovídá výchozí web místo vašeho — zkontrolujte ServerName"
  fi
  # Virtual host se pozná podle JMÉNA. Když se na týž server zeptáme
  # cizím jménem, náš web se ozvat nesmí — jinak je to catch-all.
  CIZI="$(stahni_web "neznamy.netlab.test" 80 "$IP")"
  if [ -n "$KOD" ] && printf '%s' "$CIZI" | grep -qF "$KOD"; then
    chyba "váš web odpovídá i na cizí jméno"
    poznamka "výchozí web nechte povolený — pak se váš ozve jen na své ServerName"
  else
    uspech "na cizí jméno se váš web neozývá"
  fi
fi

krok 5 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/web/formular.txt — spusťte ./start.sh, doplní ho"
ODP_KOD="$(_zaznam "$FORMULAR" kod | tr -d ' ')"
if [ -z "$KOD" ]; then
  chyba "kód pobočky se nepodařilo přečíst"
elif [ "$ODP_KOD" = "$KOD" ]; then
  uspech "kód pobočky ve formuláři sedí"
else
  chyba "kód pobočky ve formuláři nesedí (máte '${ODP_KOD:-nic}')"
fi
# Hlavička Server je živý údaj z odpovědi — přečte se jedině tak, že
# si žák pustí curl -I. V repozitáři není a liší se podle verze Apache.
HLAVICKA="$(curl -s -m 8 -I --resolve "$WEB_JMENO:80:$IP" "http://$WEB_JMENO/" 2>/dev/null \
  | grep -i '^server:' | cut -d' ' -f2- | tr -d '\r\n ')"
ODP_SRV="$(_zaznam "$FORMULAR" server | tr -d ' ')"
if [ -z "$HLAVICKA" ]; then
  chyba "hlavičku Server se nepodařilo přečíst — web ze stanice neodpovídá"
elif [ "$ODP_SRV" = "$HLAVICKA" ]; then
  uspech "hlavička Server ve formuláři sedí"
else
  chyba "hlavička Server ve formuláři nesedí (máte '${ODP_SRV:-nic}')"
  poznamka "curl -I --resolve $WEB_JMENO:80:$IP http://$WEB_JMENO/ | grep -i '^server:'"
fi

vypis_souhrn
