#!/bin/bash
# 3/22 — ověření souborné práce. Části 1 až 6 odpovídají úkolům A až F.
#
# Assessment: kontrola je CHECKPOINT, ne klíč. Hlášky proto říkají, co
# nesedí, ne jak to spravit — u vedených cvičení se radí, tady se ověřuje.
# Ze stejného důvodu kontrola NEPOJMENOVÁVÁ zbytek po předchůdci: jeho
# port i jméno programu si má žák najít sám, jsou to hodnocené položky.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="intraweb-$ZAK2"
PRACE="$HOME/netlab/intraweb"
PROTOKOL="$PRACE/protokol.txt"
JMENO="intraweb.netlab.test"
ROOT=/var/www/intraweb
CA_DIR=/srv/ca
CA_KLIC="user.lab322-ca"
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

# Časový limit: zaseknutý příkaz v kontejneru by jinak zavěsil celou
# kontrolu. Všechny ostatní sondy (curl, dig, /dev/tcp) limit mají.
na_serveru() { timeout 15 lxc exec "$KONT" -- bash -c "$1" 2>/dev/null; }
LAB_KONTEJNER="$KONT"
IP="$(na_serveru "ip -4 -o addr show dev eth0 | awk '{print \$4}' | cut -d/ -f1" | tr -d '\r' | head -1)"
if [ -z "$IP" ]; then
  echo; echo "  Server $KONT nemá adresu. Spusťte ./start.sh"; echo; exit 1
fi
KOD="$(lxc config get "$KONT" user.lab322-kod 2>/dev/null | tr -d '\r')"

# ── kotva důvěry ──────────────────────────────────────────────────
# Adresář /srv/ca patří žákovi — cvičení 17 v něm učí pracovat bez sudo
# (žádost, přípony, -CAcreateserial). Kontrola se proto NESMÍ opřít
# o ca.crt v něm: kdo by si ho přepsal vlastní autoritou, prošel by
# úkolem B na porovnání sebe se sebou. Otisk pravé autority drží
# prostředí v konfiguraci kontejneru, kam žák nedosáhne.
CA_SOUBOR="$(mktemp)"
trap 'rm -f "$CA_SOUBOR"' EXIT INT TERM
na_serveru "cat $CA_DIR/ca.crt 2>/dev/null" > "$CA_SOUBOR"
CA_CEKANY="$(lxc config get "$KONT" "$CA_KLIC" 2>/dev/null | tr -d '\r')"
CA_OTISK="$(openssl x509 -in "$CA_SOUBOR" -noout -fingerprint -sha256 2>/dev/null \
  | cut -d= -f2 | tr -d ' :\r' | tr 'a-f' 'A-F')"
CA_PRAVA=ano
if [ -n "$CA_CEKANY" ] && [ "$CA_OTISK" != "$CA_CEKANY" ]; then CA_PRAVA=ne; fi

stahni() {  # stahni PORT CESTA [další argumenty curl…] → tělo odpovědi
  local port="$1" cesta="$2"; shift 2
  local schema=http; [ "$port" = "443" ] && schema=https
  curl -s -m 8 --resolve "$JMENO:$port:$IP" "$@" "$schema://$JMENO$cesta" 2>/dev/null
}
stav_kod() {  # stav_kod PORT CESTA [další argumenty curl…]
  local port="$1" cesta="$2"; shift 2
  local schema=http; [ "$port" = "443" ] && schema=https
  curl -s -m 8 -o /dev/null -w '%{http_code}' \
    --resolve "$JMENO:$port:$IP" "$@" "$schema://$JMENO$cesta" 2>/dev/null
}
posle_certifikat() {
  printf '' | timeout 8 openssl s_client -connect "$IP:443" -servername "$JMENO" \
    2>/dev/null | openssl x509 2>/dev/null
}
port_otevreny() {  # port_otevreny PORT → 0, když se na něj ze stanice dá připojit
  timeout -k 1 4 bash -c "exec 3<>/dev/tcp/$IP/$1" 2>/dev/null
}

CERT=""
if krok_aktivni 2 || krok_aktivni 6; then CERT="$(posle_certifikat)"; fi

krok 1 "A — Web pod vlastním jménem"
require_service_active "apache2"
# Tvar výpisu apache2ctl -S se liší podle toho, kolik vhostů na portu je:
# u jediného je to holý řádek „*:80  jmeno (soubor:radek)", u víc jich
# přibude „port 80 namevhost jmeno (…)". Společné mají „jmeno (".
if na_serveru "apache2ctl -S 2>&1" | grep -qF "$JMENO ("; then
  uspech "Apache zná virtual host $JMENO"
else
  chyba "Apache o virtual hostu $JMENO neví"
fi
if krok_aktivni 1; then
  if [ -z "$KOD" ]; then
    chyba "kód zakázky se nepodařilo přečíst — spusťte ./start.sh"
  elif [ "$(stav_kod 80 /)" = "200" ] && printf '%s' "$(stahni 80 /)" | grep -qF "$KOD"; then
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
if [ "$CA_PRAVA" = ne ]; then
  chyba "firemní autorita na serveru není ta, kterou tam dalo prostředí"
  poznamka "Spusťte ./start.sh — původní autoritu vrátí zpátky."
fi
if [ -z "$CERT" ]; then
  chyba "server v TLS spojení neposlal certifikát"
else
  uspech "server v TLS spojení posílá certifikát"
  printf '%s' "$CERT" | openssl x509 -noout -text 2>/dev/null \
    | grep -A2 'Subject Alternative Name' | grep -q "DNS:$JMENO" \
    && uspech "certifikát platí pro jméno $JMENO" \
    || chyba "certifikát pro jméno $JMENO neplatí"
  # Otisky DN místo řetězců: formát -issuer/-subject se mezi verzemi
  # OpenSSL liší (`C=CZ` vs. `C = CZ`) a stanice a kontejner nemusí mít
  # navždy stejnou. Hash je stabilní.
  VYD="$(printf '%s' "$CERT" | openssl x509 -noout -issuer_hash 2>/dev/null | tr -d '\r')"
  SUB="$(printf '%s' "$CERT" | openssl x509 -noout -subject_hash 2>/dev/null | tr -d '\r')"
  CA_SUB="$(openssl x509 -in "$CA_SOUBOR" -noout -subject_hash 2>/dev/null | tr -d '\r')"
  if [ "$CA_PRAVA" = ano ] && [ -n "$CA_SUB" ] && [ "$VYD" = "$CA_SUB" ] && [ "$VYD" != "$SUB" ]; then
    uspech "certifikát vydala firemní autorita"
  else
    chyba "certifikát nevydala firemní autorita"
  fi
fi
if krok_aktivni 2; then
  [ "$CA_PRAVA" = ano ] && [ "$(stav_kod 443 / --cacert "$CA_SOUBOR")" = "200" ] \
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
  elif ! dig "@$IP" . NS +time=3 +tries=1 >/dev/null 2>&1; then
    # Server neodpověděl vůbec — příčina může být v DNS i cestou k němu.
    # Kontrola tvrdí jen to, co ví.
    chyba "server na dotaz ze stanice vůbec neodpověděl"
  else
    chyba "$JMENO se na serveru nepřekládá"
  fi
fi

krok 4 "D — Stavová stránka se obnovuje sama"
if na_serveru "systemctl is-active --quiet stav.timer"; then
  uspech "časovač stav.timer běží"
else
  chyba "časovač stav.timer neběží"
fi
TSTAV="$(na_serveru "systemctl is-enabled stav.timer 2>/dev/null" | tr -d '\r' | tail -n1)"
[ "$TSTAV" = "enabled" ] \
  && uspech "časovač naběhne i po restartu serveru" \
  || chyba "časovač po restartu serveru nenaběhne"
# Interval: monotónní i kalendářní časovač je legitimní řešení. Cvičení 8
# učí OnUnitActiveSec a v Rozšíření zve k OnCalendar — kontrola nesmí
# jedno z toho odmítnout.
NAST="$(na_serveru "systemctl show stav.timer -p TimersMonotonic -p TimersCalendar --value" \
  | tr -d '\r' | sed 's/ *; *next_elapse=[^}]*//g')"
printf '%s' "$NAST" \
  | grep -qE "(OnUnitActive[A-Za-z]*=${INTERVAL}min([^0-9]|$)|OnCalendar=[^;}]*/0*${INTERVAL}(:00)?([^0-9:]|$))" \
  && uspech "časovač se opakuje v předepsaném intervalu" \
  || chyba "opakování časovače neodpovídá zadání"
POSL="$(na_serveru "systemctl show stav.timer -p LastTriggerUSec --value" | tr -d '\r')"
case "$POSL" in
  ''|0|n/a) chyba "časovač se zatím ani jednou nespustil" ;;
  *)        uspech "časovač už aspoň jednou vystřelil" ;;
esac
# Stránka musí být ČERSTVÁ — jinak by stačilo ji jednou vyrobit ručně.
STARI="$(na_serveru "test -f $ROOT/stav.html && echo \$(( \$(date +%s) - \$(stat -c %Y $ROOT/stav.html) ))")"
STARI="$(printf '%s' "$STARI" | tr -d '\r')"
case "$STARI" in
  ''|*[!0-9]*) chyba "stavová stránka $ROOT/stav.html na serveru není" ;;
  *) if [ "$STARI" -lt $(( (INTERVAL + 2) * 60 )) ]; then
       uspech "stavová stránka je čerstvá (změněna před $STARI s)"
     else
       chyba "stavová stránka je stará $STARI s"
     fi ;;
esac
# A musí ji servírovat web — jinak vzniká někde, kam nikdo nevidí.
if krok_aktivni 4; then
  [ "$(stav_kod 80 /stav.html)" = "200" ] \
    && uspech "stavová stránka je dostupná i přes web" \
    || chyba "stavová stránka není přes web dostupná"
fi

krok 5 "E — Dostupné je jen to, co má být"
case "$(na_serveru "LC_ALL=C ufw status 2>/dev/null | head -1" | tr -d '\r')" in
  *"Status: active"*) uspech "firewall je zapnutý" ;;
  *)                  chyba "firewall není zapnutý" ;;
esac
if krok_aktivni 5; then
  # Zvenčí musí projít web a SSH, a nesmí projít zbytek po předchůdci.
  for P in 22 80 443; do
    if port_otevreny "$P"; then
      uspech "port $P je ze stanice dostupný"
    else
      chyba "port $P není ze stanice dostupný"
    fi
  done
  # DNS z úkolu C taky musí projít. Ptáme se přes UDP dotazem, ne na TCP:
  # i odpověď „REFUSED" dokazuje, že se k serveru dá dostat.
  if dig "@$IP" . NS +time=3 +tries=1 >/dev/null 2>&1; then
    uspech "DNS na serveru je ze stanice dostupné"
  else
    chyba "DNS na serveru není ze stanice dostupné"
  fi
  if port_otevreny "$ZBYTEK_PORT"; then
    chyba "port po předchůdci je ze stanice pořád dostupný"
  else
    uspech "port po předchůdci je zvenčí schovaný"
  fi
fi
# Schovat službu tím, že se vypne nebo přenastaví, není práce firewallu —
# a v protokolu se na ni žák má podívat.
if ! na_serveru "systemctl is-active --quiet prehledy"; then
  chyba "služba po předchůdci neběží — úkolem bylo schovat ji, ne vypnout"
elif ! na_serveru "ss -tln 2>/dev/null | grep -qE '(0\.0\.0\.0|\*):$ZBYTEK_PORT '"; then
  chyba "služba po předchůdci už neposlouchá tam, kde poslouchala"
else
  uspech "služba po předchůdci pořád běží — je schovaná, ne vypnutá"
fi

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
