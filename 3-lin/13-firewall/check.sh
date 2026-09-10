#!/bin/bash
# 3/13 — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 zadání je jen prohlídka, není u něj co ověřovat.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="provoz-$ZAK2"
PROVOZ="$HOME/netlab/provoz"
FORMULAR="$PROVOZ/formular-13.txt"
PORT_STAV=$(( 8000 + ZAK ))
PORT_INTERNI=$(( 9000 + ZAK ))

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
IP="$(lxc list "^${KONT}$" -c 4 --format csv 2>/dev/null | awk '{print $1}')"

# Zkouší se skutečné spojení ze stanice, ne text pravidla. `/dev/tcp` je
# vestavěné v bashi, takže na stanici nemusí být nc ani telnet — a odpadá
# tím i závislost na hláškách nástroje, které se překládají.
port_projde() {  # port_projde PORT → 0 = spojení navázáno
  timeout -k 1 4 bash -c "exec 3<>/dev/tcp/$IP/$1" 2>/dev/null
}

krok 2 "Pravidla jsou připravená"
if [ -z "$IP" ]; then
  chyba "server nemá adresu — spusťte ./start.sh"
else
  uspech "server má adresu $IP"
fi
# `ufw show added` vypíše pravidla i tehdy, když je firewall ještě vypnutý.
# Díky tomu tahle část projde přesně tam, kam na ni návod posílá — po
# přípravě pravidel a PŘED `ufw enable`.
PRIPRAVENA="$(na_serveru "LC_ALL=C ufw show added 2>/dev/null" | tr -d '\r')"
# Uznat se musí i pojmenované varianty: `ufw allow ssh` a `ufw allow OpenSSH`
# jsou stejně správné jako `22/tcp`. Žák, který je použil, je v bezpečí —
# vytknout mu to by ho hnalo „opravovat" něco, co je v pořádku.
if printf '%s' "$PRIPRAVENA" | grep -qEi '(^| )22(/tcp)?( |$)|allow 22(/tcp)?( |$)|allow (in )?(on [^ ]+ )?(ssh|openssh)( |$)|port 22( |$)'; then
  uspech "port 22 je mezi připravenými pravidly"
else
  chyba "mezi připravenými pravidly není port 22"
  poznamka "bez něj by vás ufw enable odřízlo od serveru"
fi
if printf '%s' "$PRIPRAVENA" | grep -q "$PORT_STAV"; then
  uspech "port $PORT_STAV je mezi připravenými pravidly"
else
  chyba "mezi připravenými pravidly není port $PORT_STAV"
fi
if printf '%s' "$PRIPRAVENA" | grep -q "$PORT_INTERNI"; then
  chyba "port $PORT_INTERNI je mezi pravidly — ten se povolovat nemá"
  poznamka "schová ho výchozí politika deny, žádné pravidlo pro něj netřeba"
else
  uspech "port $PORT_INTERNI mezi pravidly není"
fi

krok 3 "Firewall běží a filtruje"
# LC_ALL=C: rozhodnutí padá podle anglického `Status: active`, a ten se
# musí vynutit. Bez toho by kontrola závisela na jazyku serveru.
UFW_STAV="$(na_serveru "LC_ALL=C ufw status 2>/dev/null | head -1" | tr -d '\r')"
case "$UFW_STAV" in
  # Pozor: `*active*` by sedlo i na `Status: inactive` — vypnutý firewall
  # by prošel jako zapnutý. Porovnává se proto celý řetězec.
  *"Status: active"*) uspech "ufw je aktivní" ;;
  *)                  chyba "ufw není aktivní"
                      poznamka "nejdřív povolte port 22, teprve potom sudo ufw enable" ;;
esac
POLITIKA="$(na_serveru "LC_ALL=C ufw status verbose 2>/dev/null | grep -i '^Default:'" | tr -d '\r')"
case "$POLITIKA" in
  *"deny (incoming)"*) uspech "výchozí politika pro příchozí provoz je deny" ;;
  *)                   chyba "výchozí politika pro příchozí provoz není deny" ;;
esac

# Tohle je jádro cvičení: nezajímá nás, co je napsané v pravidlech,
# ale co se doopravdy stane.
if port_projde 22; then
  uspech "SSH ze stanice projde"
else
  chyba "SSH ze stanice neprojde — odřízli jste se"
  poznamka "záchrana: ./start.sh --odblokuj (jde mimo SSH, přes lxc)"
fi
if port_projde "$PORT_STAV"; then
  uspech "stavová stránka na portu $PORT_STAV je zvenčí dostupná"
else
  chyba "stavová stránka na portu $PORT_STAV zvenčí neprojde"
  poznamka "ta zůstat dostupná má"
fi
if port_projde "$PORT_INTERNI"; then
  chyba "interní přehled na portu $PORT_INTERNI je zvenčí pořád dostupný"
  poznamka "výchozí politika deny ho měla schovat — zkontrolujte, jestli jste na něj omylem nepovolili pravidlo"
else
  uspech "interní přehled na portu $PORT_INTERNI je zvenčí schovaný"
fi
# Schovat službu tím, že se vypne, není práce firewallu.
require_service_active "interni"

krok 4 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/provoz/formular-13.txt — spusťte ./start.sh, doplní ho"
ODP_POL="$(_zaznam "$FORMULAR" politika | tr 'A-Z' 'a-z')"
case "$ODP_POL" in
  deny|zakázat|zakazat|zamítnout|zamitnout) uspech "ve formuláři je výchozí politika" ;;
  '') chyba "ve formuláři chybí výchozí politika" ;;
  *)  chyba "výchozí politika ve formuláři nesedí (máte '$ODP_POL')" ;;
esac
# Ptáme se na PID interní služby, ne na počet naslouchajících portů.
# Počet je pro celou třídu stejný (a první hotový žák ho řekne ostatním),
# kdežto PID existuje jen v žákově vlastním běhu — model ho nevymyslí
# a soused má jiné. Navíc to žáka donutí spustit `ss -tlnp` se `sudo`,
# protože u cizího procesu jinak sloupec s programem neuvidí.
PID_INTERNI="$(na_serveru "systemctl show interni -p MainPID --value" | tr -d ' \r')"
ODP_PID="$(_zaznam "$FORMULAR" pid-interniho | grep -oE '^[0-9]+')"
if [ -z "$ODP_PID" ]; then
  chyba "ve formuláři chybí PID interní služby"
  poznamka "sudo ss -tlnp — ve sloupci Process je pid=…"
elif [ -z "$PID_INTERNI" ] || [ "$PID_INTERNI" = "0" ]; then
  chyba "interní služba neběží, takže nemá PID"
  poznamka "schovat ji měl firewall, ne vypnutí"
elif [ "$ODP_PID" = "$PID_INTERNI" ]; then
  uspech "PID interní služby sedí"
else
  chyba "PID interní služby nesedí (máte $ODP_PID)"
  poznamka "služba se mezitím mohla restartovat — přečtěte PID znovu"
fi

vypis_souhrn
