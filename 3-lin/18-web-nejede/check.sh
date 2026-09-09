#!/bin/bash
# 3/18 — ověření. Části odpovídají krokům zadání 1:1.
#
# Hlášky [FAIL] nesmí pojmenovat vrstvu ani závadu. Zadání posílá na
# `--krok 1` jako na první příkaz a vypsat tam „ServerName je špatně"
# by znamenalo dát klíč dřív, než žák začne hledat. (Poučení z bloků
# C a D, kde přesně tohle dvakrát prošlo.)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="web-$ZAK2"
SERVER_KONT="$KONT"
source "$(dirname "$0")/../../lib/web-lib.sh"

WEB="$HOME/netlab/web"
PROTOKOL="$WEB/protokol-18.txt"
JMENO="objednavky.netlab.test"
ROOT="/var/www/objednavky"
SITE=objednavky

# LXD se jmenuje jinak než jeho příkaz — hláška má mluvit tak, jak
# se o něm mluví ve zbytku repozitáře i v hodině.
for n in lxc curl; do
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
ZAVEDENO="$(lxc config get "$KONT" "$WEB_VRSTVA_KLIC" 2>/dev/null | tr -d '\r')"
read -r VRSTVA MARKER _ <<< "$ZAVEDENO"

krok 1 "Web odpovídá"
if ! krok_aktivni 1; then :
elif [ -z "$IP" ]; then
  chyba "adresu serveru se nepodařilo zjistit"
else
  # Jedna hláška, bez rozlišení PROČ. Rozlišit „vypršelo" od „odmítnuto"
  # od „odpověděl cizím obsahem" je přesně ta dovednost, kvůli které lab
  # existuje — kontrola by ji žákovi vzala v prvním příkazu, na který ho
  # zadání posílá. Tabulka je v Kroku T1, ať si ji přečte.
  ODPOVED="$(curl -s -m 8 -w '\n%{http_code}' \
    --resolve "$JMENO:80:$IP" "http://$JMENO/" 2>/dev/null)"
  STAV_KOD="$(printf '%s' "$ODPOVED" | tail -n1)"
  OBSAH="$(printf '%s' "$ODPOVED" | sed '$d')"
  if [ "$STAV_KOD" = "200" ] && [ -n "${MARKER:-}" ] && printf '%s' "$OBSAH" | grep -qF "$MARKER"; then
    uspech "web $JMENO odpovídá a vrací svůj obsah"
  else
    chyba "web $JMENO ze stanice nevrací svůj obsah"
    poznamka "curl -v řekne víc než curl — a tabulka v Kroku T1 řekne, kam to ukazuje"
  fi
fi

krok 2 "Vrstva je opravená"
if [ -z "$VRSTVA" ]; then
  chyba "nepodařilo se zjistit, která vrstva byla rozbitá"
  poznamka "spusťte ./reset.sh — prostředí se postaví znovu"
else
  # Kontrola říká jen ANO/NE, ne KTERÁ vrstva to byla. To si má žák
  # zapsat do protokolu sám.
  case "$VRSTVA" in
    L1) na_serveru "grep -q 'ServerName $JMENO' /etc/apache2/sites-available/$SITE.conf" ;;
    L2) na_serveru "LC_ALL=C ufw status | grep -qE '^80(/tcp)?[[:space:]]+ALLOW'" ;;
    L3) [ "$(na_serveru "systemctl is-enabled apache2 2>/dev/null" | tr -d '\r' | tail -n1)" = "enabled" ] \
          && na_serveru "systemctl is-active --quiet apache2" ;;
    L4) na_serveru "a2query -s $SITE >/dev/null 2>&1" ;;
    # Ptáme se CHOVÁNÍM, ne číslem práv: `chmod 750` se skupinou www-data
    # je stejně platná oprava jako `755`, a v praxi lepší. Číselná podmínka
    # by ji odmítla, přestože web funguje.
    L5) na_serveru "runuser -u www-data -- sh -c 'test -x $ROOT && test -r $ROOT/index.html'" ;;
    *)  false ;;
  esac && uspech "závada je odstraněná" \
       || { chyba "závada je pořád v prostředí"
            poznamka "projděte vrstvy odshora dolů a každou zvlášť vylučte" ; }
fi

krok 3 "Nic se neobešlo"
# Opravit web tím, že se zruší firewall nebo že se z něj udělá výchozí
# stránka, není oprava — je to výměna jedné poruchy za jinou.
case "$(na_serveru "LC_ALL=C ufw status 2>/dev/null | head -1" | tr -d '\r')" in
  *active*)
    uspech "firewall zůstal zapnutý" ;;
  *)
    chyba "firewall je vypnutý — to není oprava, to je díra"
    poznamka "otevřít se měl jeden port, ne celý server" ;;
esac
if na_serveru "test -s $ROOT/index.html"; then
  uspech "obsah webu je na svém místě"
else
  chyba "v $ROOT chybí index.html"
  poznamka "obsah se měl zpřístupnit, ne přesunout jinam"
fi
# POZOR: tady se NESMÍ ptát na správné ServerName. U vrstvy 1 je právě
# to hledaná závada a hláška by ji vyzradila v prvním příkazu, který žák
# pustí. Ptáme se proto na OBCHVAT: web se nesmí ozývat na cizí jméno,
# tedy nesmí z něj být catch-all.
if krok_aktivni 3 && [ -n "$IP" ] && [ -n "${MARKER:-}" ]; then
  CIZI="$(stahni_web "neznamy.netlab.test" 80 "$IP")"
  if printf '%s' "$CIZI" | grep -qF "$MARKER"; then
    chyba "web se ozývá i na cizí jméno"
    poznamka "udělat z něj výchozí web není oprava — má odpovídat jen na to své"
  else
    uspech "web se na cizí jméno neozývá"
  fi
fi

pouzil_diagnostiku 'curl|systemctl|apache2ctl|a2query|ufw|journalctl|ss ' \
  "u webu se jde odshora dolů: jméno, síť, služba, konfigurace, obsah"

krok 4 "Protokol"
LAB_KONTEJNER=""
require_soubor_neprazdny "$PROTOKOL" \
  "protokol je na stanici" \
  "chybí ~/netlab/web/protokol-18.txt — spusťte ./start.sh, doplní ho"
POPSANO=0
for V in vrstva-1-jmeno vrstva-2-sit vrstva-3-sluzba vrstva-4-konfigurace vrstva-5-obsah; do
  H="$(_zaznam "$PROTOKOL" "$V")"
  [ "$(printf '%s' "$H" | wc -w | tr -d ' ')" -ge 4 ] && POPSANO=$((POPSANO + 1))
done
if [ "$POPSANO" -eq 5 ]; then
  uspech "v protokolu jsou popsané všechny vrstvy"
else
  chyba "v protokolu je popsaných jen $POPSANO vrstev z pěti"
  poznamka "i vyloučená vrstva je práce — napište, čím jste ji vyloučili"
fi
# Číslo vrstvy je jediné místo, kde žák dokládá, že závadu opravdu
# našel, a ne jen náhodou opravil.
ODP_V="$(_zaznam "$PROTOKOL" zavada | grep -oE '^[1-5]')"
if [ -z "$ODP_V" ]; then
  chyba "v protokolu chybí číslo vrstvy, ve které závada byla"
  poznamka "na začátek řádku zavada patří číslo 1 až 5"
elif [ "L$ODP_V" = "$VRSTVA" ]; then
  uspech "vrstva v protokolu sedí"
else
  chyba "vrstva v protokolu nesedí"
  poznamka "vraťte se k tomu, co jste opravili, a rozmyslete, do které vrstvy to patří"
fi
POPIS="$(_zaznam "$PROTOKOL" zavada | sed 's/^[1-5][[:space:]]*//')"
if [ "$(printf '%s' "$POPIS" | wc -w | tr -d ' ')" -ge 4 ]; then
  uspech "v protokolu je popsané, co konkrétně bylo špatně"
else
  chyba "v protokolu chybí popis, co konkrétně bylo špatně"
  poznamka "za číslo vrstvy napište aspoň čtyři slova vlastními slovy"
fi

# Číslo evidence je vidět jedině na opravené stránce — dokud web nejede,
# nemá ho žák odkud vzít. Je to jediná hodnota z vlastního běhu, kterou
# protokol obsahuje.
ODP_D="$(_zaznam "$PROTOKOL" dukaz | tr -d ' ')"
if [ -z "${MARKER:-}" ]; then
  chyba "číslo evidence se nepodařilo přečíst — spusťte ./reset.sh"
elif [ "$ODP_D" = "$MARKER" ]; then
  uspech "číslo evidence v protokolu sedí"
else
  chyba "číslo evidence v protokolu nesedí (máte '${ODP_D:-nic}')"
  poznamka "je na opravené stránce — až web pojede, uvidíte ho"
fi

vypis_souhrn
