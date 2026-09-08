#!/bin/bash
# 3/03 — ověření
# Části odpovídají krokům zadání 1:1.
#
# Kontrola sahá na DVA stroje: stanici (known_hosts, formulář) a server
# (soubor, který tam žák vyrobil). Přepíná se proměnnou LAB_KONTEJNER —
# prázdná znamená stanici.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="server-$ZAK2"
SIT="$HOME/netlab/ssh"
FORMULAR="$SIT/formular.txt"

# `lxc info` uspěje i u zastaveného serveru — bez rozlišení by žák po ./stop.sh
# dostal samé FAILy a myslel si, že o práci přišel.
if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
STAV="$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)"
if [ -z "$STAV" ]; then
  echo; echo "  Server $KONT neexistuje. Spusťte ./start.sh"; echo; exit 1
elif [ "$STAV" != "RUNNING" ]; then
  echo; echo "  Server $KONT je zastavený — vaše práce na něm zůstala."
  echo "  Nastartujte ho a připojte se znovu:  ./start.sh"; echo; exit 1
fi

IP="$(lxc list "^${KONT}$" -c4 --format csv 2>/dev/null | cut -d' ' -f1)"

krok 1 "Připojení"
LAB_KONTEJNER=""          # stanice
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/ssh/formular.txt — spusťte ./start.sh, doplní ho"

# Záznam v known_hosts vznikne jedině tím, že se žák opravdu připojil
# a potvrdil otisk. Bez připojení ho nevyrobí.
if [ -n "$IP" ] && ssh-keygen -F "$IP" >/dev/null 2>&1; then
  uspech "stanice si pamatuje klíč serveru — připojili jste se"
else
  chyba "v known_hosts není záznam k tomuto serveru"
  poznamka "vznikne, až se poprvé připojíte a potvrdíte otisk klíče"
fi

krok 2 "Práce na serveru"
LAB_KONTEJNER="$KONT"     # od téhle chvíle se ptáme serveru
PREVZETI="/home/sysadmin/prevzeti.txt"
require_soubor_neprazdny "$PREVZETI" \
  "na serveru je soubor prevzeti.txt" \
  "na serveru chybí ~/prevzeti.txt — vyrobte ho tam, ne na stanici"

JADRO="$(lxc exec "$KONT" -- uname -r 2>/dev/null | tr -d '\r')"
ADR_SERVERU="$(lxc exec "$KONT" -- bash -c \
  "ip -br a 2>/dev/null | awk '\$1!=\"lo\" && \$2==\"UP\" {print \$3; exit}'" 2>/dev/null \
  | cut -d/ -f1 | tr -d '\r')"
[ -n "$JADRO" ] && require_zaznam "$PREVZETI" jadro "$JADRO" \
  "v prevzeti.txt je verze jádra serveru"
[ -n "$ADR_SERVERU" ] && require_zaznam "$PREVZETI" adresa "$ADR_SERVERU" \
  "v prevzeti.txt je adresa serveru"

krok 3 "Formulář"
LAB_KONTEJNER=""          # zpátky na stanici
HOSTNAME_SERVERU="$(lxc exec "$KONT" -- hostname 2>/dev/null | tr -d '\r')"
[ -n "$HOSTNAME_SERVERU" ] && require_zaznam "$FORMULAR" server "$HOSTNAME_SERVERU" \
  "ve formuláři je jméno serveru"
# Otisk se uznává od kteréhokoli klíče serveru — který z nich SSH nabídne,
# záleží na dohodě klienta a serveru a žák to neovlivní.
OTISKY="$(lxc exec "$KONT" -- bash -c \
  'for k in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -lf "$k" 2>/dev/null | awk "{print \$2}"; done' \
  2>/dev/null | tr -d '\r')"
# Ve výzvě SSH končí otisk větnou tečkou. Kdo opíše celý řádek, má na konci
# tečku navíc — je to opis, ne chyba, takže se ořízne.
ODPOVED="$(_zaznam "$FORMULAR" otisk | sed 's/\.$//')"
if [ -z "$OTISKY" ]; then
  chyba "nepodařilo se přečíst otisky klíčů serveru"
elif [ -n "$ODPOVED" ] && printf '%s\n' "$OTISKY" | grep -qxF "$ODPOVED"; then
  uspech "ve formuláři je otisk klíče tohoto serveru"
else
  chyba "otisk ve formuláři neodpovídá žádnému klíči tohoto serveru"
  poznamka "zapisuje se celý, i s předponou SHA256:"
fi

vypis_souhrn
