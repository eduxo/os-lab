#!/bin/bash
# 3/09 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="sluzby-$ZAK2"
LOGY="$HOME/netlab/logy"
FORMULAR="$LOGY/formular.txt"
SKRIPT="/usr/local/bin/hlaska.sh"
HLASKA_LOG="/home/sysadmin/hlaska.log"

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

krok 1 "Služba a její log"
require_service_active "sber"
# Ptáme se na počet RŮZNÝCH čidel, ne na počet řádků. Služba loguje své chyby
# při každém startu, takže počet řádků roste s každým restartem — a restartuje
# ji i tahle kontrola v části 2. Žák by tak honil cíl, který se mu pod rukama
# posouvá. Počet různých čidel je proti restartům imunní.
POCET_CHYB="$(na_serveru "journalctl -u sber -p err --no-pager -q | grep -oE 'cidlo [0-9]+' | sort -u | grep -c ''" | tr -d '\r')"
POCET_CHYB="${POCET_CHYB:-0}"
if [ "$POCET_CHYB" -gt 0 ]; then
  uspech "služba sber má v journalu chybové záznamy"
else
  chyba "služba sber zatím nemá v journalu žádnou chybu"
  poznamka "chyby se logují při startu služby — spusťte ./start.sh"
fi

# Část 2 službu na chvíli zastaví. Kdyby kontrola v tu chvíli spadla (Ctrl+C,
# zacyklený žákův skript, výpadek lxc), zůstala by sber dole a příští kontrola
# by v části 1 vytkla „služba neběží" — přesně ta diagnostická past, před
# kterou zadání varuje. Proto se stav vrací i při nechtěném konci.
obnov_sber() { lxc exec "$KONT" -- systemctl start sber >/dev/null 2>&1; }
trap obnov_sber EXIT INT TERM

krok 2 "Skript s podmínkou"
require_path "$SKRIPT" \
  "skript hlaska.sh je na serveru" \
  "na serveru chybí /usr/local/bin/hlaska.sh"
if na_serveru "test -x '$SKRIPT'"; then
  uspech "skript je spustitelný"
  # Podmínka se neověřuje čtením kódu, ale chováním: skript musí při běžící
  # a zastavené službě zapsat něco jiného. Stav služby se pak vrátí zpátky.
  na_serveru "systemctl start sber" >/dev/null 2>&1
  sleep 1
  # HOME se předává explicitně: bez něj by `runuser -u` mohl nechat HOME roota
  # a korektní skript by psal do /root/hlaska.log, kde ho kontrola nenajde.
  # timeout kvůli žákovu skriptu, který se zacyklí.
  na_serveru "rm -f '$HLASKA_LOG'; timeout 20 runuser -u sysadmin -- env HOME=/home/sysadmin bash -c 'cd /home/sysadmin && bash $SKRIPT'" >/dev/null 2>&1
  BEZI="$(na_serveru "tail -1 '$HLASKA_LOG' 2>/dev/null" | tr -d '\r')"
  na_serveru "systemctl stop sber" >/dev/null 2>&1
  sleep 1
  na_serveru "timeout 20 runuser -u sysadmin -- env HOME=/home/sysadmin bash -c 'cd /home/sysadmin && bash $SKRIPT'" >/dev/null 2>&1
  NEBEZI="$(na_serveru "tail -1 '$HLASKA_LOG' 2>/dev/null" | tr -d '\r')"
  na_serveru "systemctl start sber" >/dev/null 2>&1
  if [ -z "$BEZI" ] || [ -z "$NEBEZI" ]; then
    chyba "skript nic nezapsal do ~/hlaska.log"
    poznamka "má připojovat řádek při každém spuštění"
  elif [ "$BEZI" != "$NEBEZI" ]; then
    uspech "skript se opravdu rozhoduje podle stavu služby"
  else
    chyba "skript zapíše totéž, ať služba běží, nebo ne"
    poznamka "podmínka se pozná tím, že se výsledek liší — ne tím, že je v kódu if"
  fi
else
  chyba "skript není spustitelný"
fi

krok 3 "Formulář"
LAB_KONTEJNER=""
require_zaznam "$FORMULAR" chyb "$POCET_CHYB" \
  "ve formuláři je počet chybových záznamů"
CAS="$(na_serveru "journalctl -u sber -p err --no-pager -q -o short-iso | grep -m1 'CHYBA'" \
  | grep -oE 'T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 | tr -d 'T\r')"
if [ -n "$CAS" ]; then
  require_zaznam "$FORMULAR" cas "$CAS" \
    "ve formuláři je čas prvního chybového záznamu"
else
  chyba "z journalu se nepodařilo přečíst čas prvního chybového záznamu"
fi

vypis_souhrn
