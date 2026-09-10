#!/bin/bash
# 3/22 — ověření souborné práce. Části 1 až 6 odpovídají úkolům A až F.
#
# Assessment: kontrola je CHECKPOINT, ne klíč. Hlášky proto říkají, co
# nesedí, ne jak to spravit — u vedených cvičení se radí, tady se ověřuje.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="intraweb-$ZAK2"
PRACE="$HOME/netlab/intraweb"
PROTOKOL="$PRACE/protokol.txt"
JMENO="intraweb.netlab.test"
ROOT=/var/www/intraweb
CA_DIR=/srv/ca
ZBYTEK_PORT=$(( 9000 + ZAK ))
INTERVAL=$(( 2 + $(lab_vyber 4 1 950) ))

for n in lxc curl openssl dig; do
  if ! command -v "$n" >/dev/null 2>&1; then
    [ "$n" = lxc ] && n=LXD
    echo; echo "  Na stanici není $n. Řekněte o tom vyučujícímu."; echo; exit 1
  fi
done
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
KOD="$(lxc config get "$KONT" user.lab322-kod 2>/dev/null | tr -d '\r')"

CA_SOUBOR="$(mktemp)"
trap 'rm -f "$CA_SOUBOR"' EXIT INT TERM
na_serveru "cat $CA_DIR/ca.crt 2>/dev/null" > "$CA_SOUBOR"

stahni() {  # stahni PORT [další argumenty curl…] → tělo odpovědi
  local port="$1"; shift
  local schema=http; [ "$port" = "443" ] && schema=https
  curl -s -m 8 --resolve "$JMENO:$port:$IP" "$@" "$schema://$JMENO/" 2>/dev/null
}
stav_kod() {  # stav_kod PORT [další argumenty curl…]
  local port="$1"; shift
  local schema=http; [ "$port" = "443" ] && schema=https
  curl -s -m 8 -o /dev/null -w '%{http_code}' \
    --resolve "$JMENO:$port:$IP" "$@" "$schema://$JMENO/" 2>/dev/null
}
posle_certifikat() {
  printf '' | timeout 8 openssl s_client -connect "$IP:443" -servername "$JMENO" \
    2>/dev/null | openssl x509 2>/dev/null
}

CERT=""
if krok_aktivni 2 || krok_aktivni 6; then CERT="$(posle_certifikat)"; fi

krok 1 "A — Web pod vlastním jménem"
require_service_active "apache2"
if na_serveru "apache2ctl -S 2>&1 | grep -qE '(namevhost|default server) $JMENO'"; then
  uspech "Apache zná virtual host $JMENO"
else
  chyba "Apache o virtual hostu $JMENO neví"
fi
if krok_aktivni 1; then
  if [ "$(stav_kod 80)" = "200" ] && printf '%s' "$(stahni 80)" | grep -qF "$KOD"; then
    uspech "web na portu 80 vrací stránku s kódem zakázky"
  else
    chyba "web na portu 80 nevrací stránku s kódem zakázky"
  fi
fi

krok 2 "B — HTTPS certifikátem od firemní autority"
if na_serveru "ss -tln 2>/dev/null | grep -q ':443 '"; then
  uspech "server poslouchá na portu 443"
else
  chyba "na portu 443 nikdo neposlouchá"
fi
if [ -z "$CERT" ]; then
  chyba "server v TLS spojení neposlal certifikát"
else
  printf '%s' "$CERT" | openssl x509 -noout -text 2>/dev/null \
    | grep -A1 'Subject Alternative Name' | grep -q "DNS:$JMENO" \
    && uspech "certifikát platí pro jméno $JMENO" \
    || chyba "v certifikátu chybí $JMENO v subjectAltName"
  VYD="$(printf '%s' "$CERT" | openssl x509 -noout -issuer 2>/dev/null)"
  SUB="$(printf '%s' "$CERT" | openssl x509 -noout -subject 2>/dev/null)"
  CA_SUB="$(na_serveru "openssl x509 -in $CA_DIR/ca.crt -noout -subject 2>/dev/null" | tr -d '\r')"
  if [ -n "$CA_SUB" ] && [ "${VYD#issuer=}" = "${CA_SUB#subject=}" ] \
     && [ "${VYD#issuer=}" != "${SUB#subject=}" ]; then
    uspech "certifikát vydala firemní autorita"
  else
    chyba "certifikát nevydala firemní autorita"
  fi
fi
if krok_aktivni 2; then
  [ "$(stav_kod 443 --cacert "$CA_SOUBOR")" = "200" ] \
    && uspech "https projde ověřením proti firemní autoritě" \
    || chyba "https neprojde ověřením proti firemní autoritě"
fi

krok 3 "C — Jméno se překládá"
require_service_active "named"
if krok_aktivni 3; then
  ODP="$(dig "@$IP" "$JMENO" +short +time=3 +tries=1 2>/dev/null | tr -d '\r' | head -1)"
  if [ "$ODP" = "$IP" ]; then
    uspech "$JMENO se překládá na adresu serveru"
  elif [ -n "$ODP" ]; then
    chyba "$JMENO se překládá na $ODP, ne na adresu serveru"
  else
    chyba "$JMENO se na serveru nepřekládá"
  fi
fi

krok 4 "D — Stavová stránka se obnovuje sama"
require_service_active  "stav.timer"
require_service_enabled "stav.timer"
NAST="$(na_serveru "systemctl show stav.timer -p TimersMonotonic --value" \
  | tr -d '\r' | sed 's/ *; *next_elapse=[^}]*//g')"
printf '%s' "$NAST" | grep -qE "OnUnitActive[A-Za-z]*=${INTERVAL}min([^0-9]|$)" \
  && uspech "timer se opakuje v předepsaném intervalu" \
  || chyba "interval opakování neodpovídá zadání"
POSL="$(na_serveru "systemctl show stav.timer -p LastTriggerUSec --value" | tr -d '\r')"
case "$POSL" in
  ''|0|n/a) chyba "timer se zatím ani jednou nespustil" ;;
  *)        uspech "timer už aspoň jednou vystřelil" ;;
esac
# Stránka musí být ČERSTVÁ — jinak by stačilo ji jednou vyrobit ručně.
STARI="$(na_serveru "test -f $ROOT/stav.html && echo \$(( \$(date +%s) - \$(stat -c %Y $ROOT/stav.html) ))")"
STARI="$(printf '%s' "$STARI" | tr -d '\r')"
case "$STARI" in
  ''|*[!0-9]*) chyba "stavová stránka $ROOT/stav.html na serveru není" ;;
  *) if [ "$STARI" -lt $(( (INTERVAL + 2) * 60 )) ]; then
       uspech "stavová stránka je čerstvá (změněna před $STARI s)"
     else
       chyba "stavová stránka je stará $STARI s — timer ji neobnovuje"
     fi ;;
esac

krok 5 "E — Dostupné je jen to, co má být"
case "$(na_serveru "LC_ALL=C ufw status 2>/dev/null | head -1" | tr -d '\r')" in
  *active*) uspech "firewall je zapnutý" ;;
  *)        chyba "firewall není zapnutý" ;;
esac
if krok_aktivni 5; then
  # Zvenčí musí projít web a SSH, a nesmí projít zbytek po předchůdci.
  for P in 22 80 443; do
    if timeout -k 1 4 bash -c "exec 3<>/dev/tcp/$IP/$P" 2>/dev/null; then
      uspech "port $P je ze stanice dostupný"
    else
      chyba "port $P není ze stanice dostupný"
    fi
  done
  if timeout -k 1 4 bash -c "exec 3<>/dev/tcp/$IP/$ZBYTEK_PORT" 2>/dev/null; then
    chyba "port $ZBYTEK_PORT je ze stanice pořád dostupný"
  else
    uspech "port $ZBYTEK_PORT je zvenčí schovaný"
  fi
fi
# Schovat službu tím, že se vypne, není práce firewallu — a v protokolu
# se na ni žák má podívat.
require_service_active "prehledy"

krok 6 "F — Předávací protokol"
LAB_KONTEJNER=""
require_soubor_neprazdny "$PROTOKOL" \
  "protokol je na stanici" \
  "chybí ~/netlab/intraweb/protokol.txt — spusťte ./start.sh, doplní ho"
ODP_KOD="$(_zaznam "$PROTOKOL" kod | tr -d ' ' | tr 'a-z' 'A-Z')"
[ -n "$KOD" ] && [ "$ODP_KOD" = "$KOD" ] \
  && uspech "kód zakázky v protokolu sedí" \
  || chyba "kód zakázky v protokolu nesedí"
OTISK="$(printf '%s' "$CERT" | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
  | cut -d= -f2 | tr -d ' :\r' | tr 'a-f' 'A-F')"
ODP_OT="$(_zaznam "$PROTOKOL" otisk | sed 's/.*=//' | tr -d ' :\r' | tr 'a-f' 'A-F')"
if [ -z "$OTISK" ]; then
  chyba "otisk se nepodařilo přečíst — server certifikát neposlal"
elif [ "$ODP_OT" = "$OTISK" ]; then
  uspech "otisk certifikátu v protokolu sedí"
else
  chyba "otisk certifikátu v protokolu nesedí"
fi
ODP_INT="$(_zaznam "$PROTOKOL" interval | grep -oE '^[0-9]+')"
[ "$ODP_INT" = "$INTERVAL" ] \
  && uspech "interval v protokolu sedí" \
  || chyba "interval v protokolu nesedí"
ODP_ZB="$(_zaznam "$PROTOKOL" zbytek | tr 'A-Z' 'a-z')"
case "$ODP_ZB" in
  *python*) uspech "v protokolu je, co na tom portu poslouchalo" ;;
  '')       chyba "v protokolu chybí, co na tom portu poslouchalo" ;;
  *)        chyba "v protokolu nesedí, co na tom portu poslouchalo" ;;
esac

vypis_souhrn
