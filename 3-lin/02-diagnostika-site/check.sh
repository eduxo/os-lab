#!/bin/bash
# 3/02 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

DIAG="$HOME/netlab/diagnostika"
FORMULAR="$DIAG/formular.txt"
PORT=$(( 9000 + ZAK ))

# Musí souhlasit se start.sh — stejné cíle, stejné pořadí.
JMENO="mereni-$ZAK2.netlab.test:80"
ADRESA="10.10.10.2$ZAK2:80"
# Adresu stanice si kontrola nedopočítá — čte ji z toho, co zapsal start.sh.
MOJE="$(cat "$DIAG/.vlastni-adresa" 2>/dev/null)"; MOJE="${MOJE:-127.0.0.1}"
ZAVRENY="$MOJE:$(( 9500 + ZAK ))"
CILE=("$JMENO" "$ADRESA" "$ZAVRENY")
HOSTITELE=("mereni-$ZAK2.netlab.test" "10.10.10.2$ZAK2" "$MOJE")
SPRAVNE=(preklad nedostupny zavreny-port)   # index odpovídá poli CILE
# Pořadí se čte ze souboru, který zapsal start.sh — dopočítávat ho znovu
# by se rozešlo s formulářem, kdyby si žák opravil své číslo.
if [ -s "$DIAG/.poradi" ]; then
  PORADI=($(cat "$DIAG/.poradi"))
else
  PORADI=($(lab_vyber 3 3 310))
fi

krok 1 "Kdo jsem"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na místě" \
  "chybí ~/netlab/diagnostika/formular.txt — spusťte ./start.sh, doplní ho"
if pgrep -f "http.server $PORT" >/dev/null 2>&1; then
  uspech "služba, kterou máte najít, na stanici běží"
else
  chyba "služba, kterou máte najít, neběží — spusťte ./start.sh"
fi

IFACE="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
require_zaznam "$FORMULAR" adresa \
  "$(ip -br a show "$IFACE" 2>/dev/null | awk '{print $3}')" \
  "ve formuláři je adresa vaší stanice"
require_zaznam "$FORMULAR" brana \
  "$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')" \
  "ve formuláři je adresa výchozí brány"
# Ptáme se na DNS KONKRÉTNÍHO rozhraní, ne na první výskyt v celém výpisu.
# `resolvectl status` má blok globální a blok na každý link; první „DNS Servers:"
# tedy nemusí patřit tomu rozhraní, kterým stanice vidí ven — a kontrola by se
# rozešla se zadáním.
require_zaznam "$FORMULAR" dns \
  "$(resolvectl status "$IFACE" 2>/dev/null | awk '/DNS Servers:/{print $3; exit}')" \
  "ve formuláři je adresa prvního DNS serveru vašeho rozhraní"

krok 2 "Kde se to zastavilo"
I=1
for N in "${PORADI[@]}"; do
  require_zaznam "$FORMULAR" "cil-$I" "${SPRAVNE[N-1]}" \
    "cíl $I je zařazený správně" \
    "cíl $I ($(printf '%s' "${CILE[N-1]}")) je zařazený špatně"
  I=$((I+1))
done

# Zařazení cílů jde vyplnit úvahou nad formulářem — proto se k němu žádá
# doklad: výstup nástroje, který u každého cíle padne jinak.
DOKLAD="$DIAG/doklad.txt"
if [ ! -s "$DOKLAD" ]; then
  chyba "chybí doklad.txt s výstupy nástrojů"
  poznamka "u každého cíle připojte výstup toho, čím jste to zjistili"
else
  # Vzory musí uznat i české tvary: `nc` i `ping` berou text chyby ze
  # strerror() v glibc, a ta je na cs_CZ.UTF-8 přeložená. Anglický vzor
  # by se netrefil nikdy — táž třída chyby jako u `chage` v bloku D.
  CHYBI=""
  grep -qi 'NXDOMAIN\|not found\|SERVFAIL\|nenalezen\|neexistuje' "$DOKLAD" \
    || CHYBI="$CHYBI překlad"
  grep -qiE '100% (packet loss|ztráta|ztracených)' "$DOKLAD" \
    || CHYBI="$CHYBI dostupnost"
  grep -qi 'refused\|odmítnuto' "$DOKLAD" \
    || CHYBI="$CHYBI port"
  for C in "${HOSTITELE[0]}" "${HOSTITELE[1]}"; do
    grep -qF "$C" "$DOKLAD" || CHYBI="$CHYBI $C"
  done
  if [ -z "$CHYBI" ]; then
    uspech "doklad.txt obsahuje výstupy ke všem třem cílům"
  else
    chyba "v doklad.txt chybí doklad k:$CHYBI"
    poznamka "výstupy se připojují (>>), ne přepisují (>)"
  fi
fi

krok 3 "Co poslouchá u mě"
require_zaznam "$FORMULAR" port "$PORT" \
  "ve formuláři je port, na kterém něco naslouchá"
# Tvar, ne přesná shoda: `ss -tlnp` může hlásit python3 i python3.12
# a žák nemá přijít o bod za to, co mu vypsal nástroj.
require_zaznam_tvar "$FORMULAR" program '^python' \
  "ve formuláři je program, který ten port drží" \
  "ve formuláři chybí program, který ten port drží"
# Port i jméno programu se dají vyčíst z veřejného start.sh. PID ne — ten
# existuje jen za běhu a je jediná hodnota, kterou od stolu nevyplníte.
PID_BEZI="$(pgrep -f "http.server $PORT" 2>/dev/null | head -1)"
if [ -n "$PID_BEZI" ]; then
  require_zaznam "$FORMULAR" pid "$PID_BEZI" \
    "ve formuláři je PID naslouchající služby"
else
  chyba "služba neběží, takže PID nejde ověřit — spusťte ./start.sh"
fi

vypis_souhrn
