#!/bin/bash
# 3/14 — ověření. Části odpovídají krokům zadání 1:1.
#
# Kontrola se ptá ZE STANICE, ne ze serveru. Server si vlastní zónu přeloží
# i tehdy, když poslouchá jen na localhostu — a to by v provozu nikomu
# nepomohlo. Dotaz zvenčí je jediný důkaz, že služba opravdu slouží.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="netlab-$ZAK2"
SERVER_KONT="$KONT"
source "$(dirname "$0")/../../lib/netlab-lib.sh"

DNS="$HOME/netlab/dns"
FORMULAR="$DNS/formular.txt"
ZONA="netlab.test"

JMENA=(tiskarna sklad kamera)
HOST="${JMENA[$(( $(lab_vyber 3 1 601) - 1 ))]}"
HOST_OKTET=$(( 30 + $(lab_vyber 9 1 602) ))

if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
if ! command -v dig >/dev/null 2>&1; then
  echo; echo "  Na stanici není dig (balíček bind9-dnsutils)."
  echo "  Řekněte o tom vyučujícímu — patří do obrazu VM."; echo; exit 1
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

# Adresy se berou ZE SÍTĚ, ne z výpočtu — kdyby síť vznikla s jiným
# rozsahem, musí se kontrola řídit tím, co je, ne tím, co jsme chtěli.
BRANA="$(lxc network get "$NETLAB_SIT" ipv4.address 2>/dev/null | cut -d/ -f1 | tr -d '\r')"
if [ -z "$BRANA" ]; then
  echo; echo "  Síť $NETLAB_SIT neexistuje. Spusťte ./start.sh"; echo; exit 1
fi
PODSIT="${BRANA%.*}"
SRV="$PODSIT.10"
IP_WWW="$PODSIT.20"
IP_HOST="$PODSIT.$HOST_OKTET"

# +time a +tries: u nefunkčního serveru by kontrola jinak čekala 15 vteřin
# na každý dotaz a vypadala by zaseknutě.
zeptej_se() {  # zeptej_se JMENO [TYP] → odpověď dig +short
  dig "@$SRV" "$1" "${2:-A}" +short +time=3 +tries=1 2>/dev/null | tr -d '\r'
}

# Filtr --krok potlačuje výpis, ne provádění. U nefunkčního serveru trvá
# každý dotaz tři vteřiny, takže `--krok 5` (formulář) by bez tohohle
# obalení mlčel patnáct vteřin kvůli částem, které žák vidět nechce.
preskoc_cast() { ! krok_aktivni "$1"; }

# Části začínají DVOJKOU a jdou 1:1 s kroky zadání. Krok 1 je jen prohlídka,
# u té není co ověřovat. Zvlášť podstatné je, že se část 2 ptá jen na SOUBOR
# zóny — v tom bodě návodu ještě zóna není přihlášená serveru, takže dotaz
# přes síť by musel selhat.

krok 2 "Soubor zóny"
if na_serveru "test -f /etc/bind/db.$ZONA"; then
  uspech "soubor zóny je na serveru"
  if na_serveru "named-checkzone $ZONA /etc/bind/db.$ZONA >/dev/null 2>&1"; then
    uspech "soubor zóny je syntakticky v pořádku"
  else
    chyba "soubor zóny má chybu"
    poznamka "named-checkzone $ZONA /etc/bind/db.$ZONA vypíše, kde a jakou"
  fi
  # V tomhle bodě se dá ověřit jen obsah souboru — přes síť ještě nic
  # neodpovídá. Skutečný důkaz přijde v části 4.
  # Komentáře se odřezávají a uznává se i plné jméno vlastníka
  # (`www.netlab.test.`). Obojí je v souborech zóny běžné — kostra, kterou
  # žák dostal, sama komentáře za `;` používá — a `named-checkzone` to
  # přijímá. Falešný FAIL za správně napsaný záznam je vada.
  ZDROJ="$(na_serveru "sed 's/;.*//' /etc/bind/db.$ZONA")"
  printf '%s' "$ZDROJ" | grep -qE "^(www|www\.$ZONA\.)[[:space:]].*[[:space:]]$IP_WWW[[:space:]]*\$" \
    && uspech "v souboru je záznam pro www" \
    || chyba "v souboru chybí záznam pro www s adresou ze zadání"
  printf '%s' "$ZDROJ" | grep -qE "^($HOST|$HOST\.$ZONA\.)[[:space:]].*[[:space:]]$IP_HOST[[:space:]]*\$" \
    && uspech "v souboru je záznam pro $HOST" \
    || chyba "v souboru chybí záznam pro $HOST s adresou ze zadání"
  printf '%s' "$ZDROJ" | grep -qiE "^(intranet|intranet\.$ZONA\.)[[:space:]].*CNAME" \
    && uspech "v souboru je alias intranet" \
    || { chyba "v souboru chybí alias intranet"
         poznamka "alias se zapisuje typem CNAME, ne druhým A záznamem" ; }
else
  chyba "na serveru není /etc/bind/db.$ZONA"
  poznamka "spusťte ./start.sh — kostru zóny doplní"
fi

krok 3 "Služba běží a poslouchá na síti netlab"
if ! preskoc_cast 3; then   # dotazy jen tehdy, když se část 3 opravdu vypisuje
require_service_active "named"
if na_serveru "ss -tuln 2>/dev/null | grep -q ':53 '"; then
  uspech "na serveru něco poslouchá na portu 53"
else
  chyba "na portu 53 na serveru nic neposlouchá"
  poznamka "systemctl status named řekne, proč služba nenaběhla"
fi
# Dotaz ze stanice je to podstatné — server sám sobě odpoví vždycky.
if [ -n "$(zeptej_se "ns.$ZONA")" ]; then
  uspech "server odpovídá na dotazy ze stanice"
else
  chyba "server ze stanice neodpovídá"
  poznamka "poslouchá i na adrese $SRV? podívejte se na listen-on v named.conf.options"
fi
# BIND bez `listen-on` poslouchá na všech adresách, takže samotné „odpovídá
# ze stanice" tenhle krok nedokládá. Cíl slibuje, že žák umí okruh zúžit —
# tak se to musí i ověřit.
if na_serveru "grep -qE '^[[:space:]]*listen-on[[:space:]]*\{[^}]*$SRV' /etc/bind/named.conf.options"; then
  uspech "server má poslouchání omezené na provozní adresu"
else
  chyba "v named.conf.options není listen-on s adresou $SRV"
  poznamka "bez něj server poslouchá na všech adresách včetně správní"
fi
ODP_NS="$(zeptej_se "$ZONA" NS)"
case "$ODP_NS" in
  *"ns.$ZONA."*) uspech "server je za zónu odpovědný" ;;
  *)             chyba "server se k zóně nehlásí"
                 poznamka "je zóna přihlášená v named.conf.local?" ;;
esac

fi

krok 4 "Překlad ze stanice"
if ! preskoc_cast 4; then   # totéž pro část 4
if [ "$(zeptej_se "www.$ZONA")" = "$IP_WWW" ]; then
  uspech "www.$ZONA se překládá správně"
else
  chyba "www.$ZONA se nepřekládá na adresu ze zadání"
fi
if [ "$(zeptej_se "$HOST.$ZONA")" = "$IP_HOST" ]; then
  uspech "$HOST.$ZONA se překládá správně"
else
  chyba "$HOST.$ZONA se nepřekládá na adresu ze zadání"
fi
# CNAME musí být opravdu CNAME, ne druhý A záznam na tutéž adresu.
ODP_CNAME="$(zeptej_se "intranet.$ZONA" CNAME)"
case "$ODP_CNAME" in
  "www.$ZONA."*) uspech "intranet.$ZONA je alias na www" ;;
  '')            chyba "intranet.$ZONA není alias (CNAME)"
                 poznamka "druhý A záznam na tutéž adresu není totéž — alias se pozná typem" ;;
  *)             chyba "intranet.$ZONA míří jinam než na www.$ZONA" ;;
esac

fi

krok 5 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/dns/formular.txt — spusťte ./start.sh, doplní ho"
# Sériové číslo je v kostře zóny na serveru a nikde se nevypisuje — do
# formuláře se dostane jedině tak, že se žák na server podívá.
SERIAL_SERVER="$(na_serveru "grep -oE '[0-9]{9,10}' /etc/bind/db.$ZONA | head -1" | tr -d '\r')"
ODP_SERIAL="$(_zaznam "$FORMULAR" serial | grep -oE '[0-9]+')"
if [ -z "$SERIAL_SERVER" ]; then
  chyba "sériové číslo se nepodařilo přečíst ze souboru zóny"
elif [ "$ODP_SERIAL" = "$SERIAL_SERVER" ]; then
  uspech "ve formuláři je sériové číslo zóny"
else
  chyba "sériové číslo ve formuláři nesedí (máte '${ODP_SERIAL:-nic}')"
  poznamka "je v hlavičce souboru /etc/bind/db.$ZONA, na řádku se slovem Serial"
fi
# TTL se losuje při stavění zóny a nikde se nevypisuje. Žák ho musí
# přečíst z odpovědi serveru — tedy si dotaz opravdu pustit a rozumět
# tomu, který sloupec je který.
TTL_ZIVE="$(dig "@$SRV" "www.$ZONA" +noall +answer +time=3 +tries=1 2>/dev/null \
  | awk '$4=="A"{print $2; exit}' | tr -d '\r')"
ODP_TTL="$(_zaznam "$FORMULAR" ttl | grep -oE '^[0-9]+')"
if [ -z "$TTL_ZIVE" ]; then
  chyba "TTL se nepodařilo přečíst — server na dotaz neodpověděl"
elif [ "$ODP_TTL" = "$TTL_ZIVE" ]; then
  uspech "TTL ve formuláři sedí s tím, co server hlásí"
else
  chyba "TTL ve formuláři nesedí (máte '${ODP_TTL:-nic}')"
  poznamka "dig @$SRV www.$ZONA — bez +short; TTL je druhý sloupec odpovědi"
fi

vypis_souhrn
