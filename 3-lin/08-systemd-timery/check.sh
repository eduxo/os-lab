#!/bin/bash
# 3/08 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="sluzby-$ZAK2"
UCET="sysadmin"
CAS="$HOME/netlab/timery"
FORMULAR="$CAS/formular.txt"
SKRIPT="/usr/local/bin/zaloha.sh"
INTERVAL=$(( 1 + $(lab_vyber 4 1 380) ))

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

krok 1 "Zálohovací skript"
require_path "$SKRIPT" \
  "skript zaloha.sh je na serveru" \
  "na serveru chybí /usr/local/bin/zaloha.sh"
if na_serveru "test -f '$SKRIPT'"; then
  na_serveru "head -1 '$SKRIPT'" | grep -q '^#!' \
    && uspech "skript má shebang" \
    || chyba "skript nemá na prvním řádku shebang"
  na_serveru "test -x '$SKRIPT'" \
    && uspech "skript je spustitelný" \
    || chyba "skript není spustitelný"
  # Skript se opravdu pustí a výsledek se rozbalí. Přibylý soubor sám o sobě
  # nedokládá nic — `touch zaloha.tar.gz` by prošel taky. Proto se ověřuje
  # hlavička gzip a počet položek uvnitř archivu proti počtu souborů v datech.
  na_serveru "rm -f /tmp/lab308-znacka && touch /tmp/lab308-znacka" >/dev/null 2>&1
  na_serveru "timeout 60 bash '$SKRIPT'" >/dev/null 2>&1
  NOVA="$(na_serveru "find /srv/zalohy -newer /tmp/lab308-znacka -type f | head -1" | tr -d '\r')"
  na_serveru "rm -f /tmp/lab308-znacka" >/dev/null 2>&1
  if [ -z "$NOVA" ]; then
    chyba "spuštění skriptu žádnou zálohu nevyrobilo"
    poznamka "záloha má vzniknout v /srv/zalohy a mít v názvu datum a čas"
  else
    uspech "spuštění skriptu vyrobilo zálohu"
    # 1f 8b jsou první dva bajty každého souboru gzip.
    if na_serveru "head -c2 '$NOVA' | od -An -tx1 | tr -d ' \n' | grep -q '^1f8b'"; then
      uspech "záloha je opravdu archiv gzip"
      V_ARCHIVU="$(na_serveru "tar tzf '$NOVA' 2>/dev/null | grep -c '[^/]$'" | tr -d '\r')"
      V_DATECH="$(na_serveru "find /srv/data -type f | grep -c ''" | tr -d '\r')"
      if [ "${V_ARCHIVU:-0}" -ge "${V_DATECH:-1}" ]; then
        uspech "v archivu jsou všechny soubory z /srv/data"
      else
        chyba "v archivu je jen ${V_ARCHIVU:-0} souborů z ${V_DATECH:-?}"
        poznamka "balit se má celý obsah /srv/data, ne jeden soubor"
      fi
    else
      chyba "soubor vznikl, ale archiv gzip to není"
      poznamka "samotné jméno s příponou .tar.gz nestačí — soubor musí vyrobit tar"
    fi
  fi
fi

krok 2 "Dvojice unitů"
require_path "/etc/systemd/system/zaloha.service" \
  "unit zaloha.service existuje" \
  "chybí /etc/systemd/system/zaloha.service"
require_path "/etc/systemd/system/zaloha.timer" \
  "unit zaloha.timer existuje" \
  "chybí /etc/systemd/system/zaloha.timer"
require_unit_valid "zaloha.service"
require_unit_valid "zaloha.timer"
# Timer se páruje se službou podle JMÉNA. Kdo pojmenuje service jinak,
# má dva platné unity, které o sobě nevědí.
# Vlastnost Unit je nastavená vždycky — i když ji žák v unitu neuvedl,
# systemd ji odvodí ze jména. Proto se čte pokaždé; podmíněná větev by
# rozdávala PASS zadarmo tomu, kdo direktivu vynechal a pojmenoval to špatně.
CIL="$(na_serveru "systemctl show zaloha.timer -p Unit --value" | tr -d '\r')"
if [ "$CIL" = "zaloha.service" ]; then
  uspech "timer míří na zaloha.service"
else
  chyba "timer míří na ${CIL:-nic}, ne na zaloha.service"
  poznamka "timer se páruje se službou podle jména, nebo se cíl uvede direktivou Unit="
fi

krok 3 "Timer běží a už se spustil"
require_service_enabled "zaloha.timer"
require_service_active  "zaloha.timer"
# Interval čteme z TimersMonotonic. Tvar je
#   { OnBootUSec=1min ; next_elapse=... } { OnUnitActiveUSec=3min ; next_elapse=... }
# a `next_elapse` je ODPOČET do dalšího spuštění — ten se mění každou vteřinu
# a klidně chvíli ukazuje zrovna hledané číslo. Kdyby se grepoval celý blok,
# uznal by špatně nastavený timer. Proto se odpočty nejdřív vystřihnou.
# Hodnoty se tisknou lidsky čitelně (`3min`), nikdy jako počet vteřin.
NASTAVENO="$(na_serveru "systemctl show zaloha.timer -p TimersMonotonic --value" \
  | tr -d '\r' | sed 's/ *; *next_elapse=[^}]*//g')"
if printf '%s' "$NASTAVENO" | grep -qE "OnUnitActive[A-Za-z]*=${INTERVAL}min([^0-9]|$)"; then
  uspech "timer se opakuje v intervalu ze zadání"
else
  chyba "interval opakování neodpovídá zadání"
  poznamka "interval máte ve výpisu ./start.sh; do unitu se píše ve tvaru Nmin"
fi
# Jediný doklad, že timer opravdu vystřelil. Ručně se nevyrobí.
POSLEDNI="$(na_serveru "systemctl show zaloha.timer -p LastTriggerUSec --value" | tr -d '\r')"
if [ -n "$POSLEDNI" ] && [ "$POSLEDNI" != "0" ] && [ "$POSLEDNI" != "n/a" ]; then
  uspech "timer se už aspoň jednou spustil"
else
  chyba "timer se zatím ani jednou nespustil"
  poznamka "enable sám nestačí — timer se musí i nastartovat, a pak chvíli počkat"
fi

krok 4 "Formulář"
LAB_KONTEJNER=""
require_zaznam "$FORMULAR" interval "$INTERVAL" \
  "ve formuláři je interval ze zadání"
SOUBORU="$(na_serveru "find /srv/data -type f | grep -c ''" | tr -d '\r')"
if [ -n "$SOUBORU" ] && [ "$SOUBORU" -gt 0 ]; then
  require_zaznam "$FORMULAR" souboru "$SOUBORU" \
    "ve formuláři je počet souborů v /srv/data"
else
  # Bez else by kontrola tiše zmizela i ze jmenovatele a souhrn by tvrdil
  # „Hotovo 4 ze 4" tam, kde se čtvrtá věc vůbec neověřila.
  chyba "ze serveru se nepodařilo přečíst obsah /srv/data"
  poznamka "spusťte ./start.sh — adresář s daty doplní"
fi
# Uzná se KTERÁKOLI záloha, která na serveru je — mezi vyplněním formuláře
# a kontrolou může timer vystřelit znovu a přibýt další.
ODP="$(_zaznam "$FORMULAR" zaloha)"
if [ -n "$ODP" ] && na_serveru "ls -1 /srv/zalohy 2>/dev/null" | grep -qxF "$ODP"; then
  uspech "ve formuláři je jméno zálohy, která na serveru opravdu je"
else
  chyba "jméno zálohy ve formuláři neodpovídá žádné na serveru (máte '${ODP:-nic}')"
fi

vypis_souhrn
