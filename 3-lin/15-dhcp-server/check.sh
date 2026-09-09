#!/bin/bash
# 3/15 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="netlab-$ZAK2"
SERVER_KONT="$KONT"
source "$(dirname "$0")/../../lib/netlab-lib.sh"

DHCP="$HOME/netlab/dhcp"
FORMULAR="$DHCP/formular.txt"
ZAPUJCKY=/var/lib/misc/dnsmasq.leases

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

BRANA="$(lxc network get "$NETLAB_SIT" ipv4.address 2>/dev/null | cut -d/ -f1 | tr -d '\r')"
if [ -z "$BRANA" ]; then
  echo; echo "  Síť $NETLAB_SIT neexistuje. Spusťte ./start.sh"; echo; exit 1
fi
PODSIT="${BRANA%.*}"
SRV="$PODSIT.10"

# Části jdou 1:1 s kroky zadání. Část 1 se schválně ptá jen na KONFIGURAČNÍ
# SOUBOR, protože v tom bodě návodu služba ještě neběží — žák ji spouští
# až v Kroku 2. Kdyby se část 1 ptala na běžící službu, selhala by přesně
# tam, kam na ni návod posílá.

krok 1 "Konfigurace"
KONF=/etc/dnsmasq.d/netlab.conf
if ! na_serveru "test -s $KONF"; then
  chyba "na serveru není $KONF"
  poznamka "konfigurace patří do vlastního souboru v /etc/dnsmasq.d/"
else
  uspech "konfigurační soubor je na serveru"
  ZDROJ="$(na_serveru "cat $KONF" | tr -d '\r')"
  obsahuje() { printf '%s' "$ZDROJ" | grep -qE "$1"; }

  # `dnsmasq --test` sám o sobě čte JEN /etc/dnsmasq.conf — adresář
  # /etc/dnsmasq.d/ mu podstrkuje až init skript volbou -7. Bez uvedení
  # souboru by tedy přečetl samé komentáře a vrátil nulu i nad naprostým
  # nesmyslem, takže by tahle kontrola dávala PASS vždycky.
  if na_serveru "dnsmasq --test --conf-file=$KONF >/dev/null 2>&1"; then
    uspech "konfigurace je syntakticky v pořádku"
  else
    chyba "konfigurace má chybu"
    poznamka "dnsmasq --test na serveru vypíše, kde"
  fi

  obsahuje '^[[:space:]]*port[[:space:]]*=[[:space:]]*0[[:space:]]*$' \
    && uspech "DNS je v konfiguraci vypnuté" \
    || { chyba "v konfiguraci není vypnuté DNS"
         poznamka "port 53 patří serveru z minulé hodiny; dnsmasq má dělat jen DHCP" ; }

  obsahuje '^[[:space:]]*interface[[:space:]]*=[[:space:]]*eth1[[:space:]]*$' \
    && uspech "rozdává se jen na provozním rozhraní" \
    || chyba "v konfiguraci není omezení na rozhraní eth1"

  # Rozsah se ověřuje na hodnoty, ne na text — žák ho může zapsat s mezerami.
  # `,` místo `=` v porovnání: rozsah se smí zapsat i s tagem nebo rozhraním
  # na začátku (`dhcp-range=eth1,10.20.7.100,...`), což je dokumentovaná forma.
  ROZSAH="$(printf '%s' "$ZDROJ" | grep -m1 '^[[:space:]]*dhcp-range' | tr -d ' ')"
  case "$ROZSAH" in
    *"$PODSIT.100,$PODSIT.150,"*) uspech "rozsah odpovídá zadání" ;;
    '') chyba "v konfiguraci chybí rozsah, ze kterého se rozdává" ;;
    *)  chyba "rozsah neodpovídá zadání"
        poznamka "má být $PODSIT.100 až $PODSIT.150 se zápůjčkou 12h" ;;
  esac
  case "$ROZSAH" in *,12h*) uspech "zápůjčka platí 12 hodin" ;;
                    *) chyba "zápůjčka nemá platit jinak než 12 hodin" ;; esac

  # Uznávají se i POJMENOVANÉ volby (`option:router` místo `3`). Zadání
  # posílá žáka do `man dnsmasq`, kde jsou obě formy vedle sebe — dát FAIL
  # za tu z dokumentace by bylo trestání správné práce.
  obsahuje "^[[:space:]]*dhcp-option[[:space:]]*=[[:space:]]*(3|option:router),[[:space:]]*$BRANA[[:space:]]*\$" \
    && uspech "klientům se předává výchozí brána" \
    || chyba "v konfiguraci není správná výchozí brána (volba 3)"
  obsahuje "^[[:space:]]*dhcp-option[[:space:]]*=[[:space:]]*(6|option:dns-server),[[:space:]]*$SRV[[:space:]]*\$" \
    && uspech "klientům se předává DNS server" \
    || chyba "v konfiguraci není správný DNS server (volba 6)"
  obsahuje '^[[:space:]]*dhcp-option[[:space:]]*=[[:space:]]*(15|option:domain-name),[[:space:]]*netlab\.test[[:space:]]*$' \
    && uspech "klientům se předává doména" \
    || chyba "v konfiguraci není doména netlab.test (volba 15)"

  # V7: zadání `bind-interfaces` vyžaduje, tak se to musí i ověřovat.
  obsahuje '^[[:space:]]*bind-interfaces[[:space:]]*$' \
    && uspech "služba se drží jen vyjmenovaného rozhraní" \
    || { chyba "v konfiguraci chybí bind-interfaces"
         poznamka "bez něj je interface= jen filtr, ne omezení" ; }
fi

krok 2 "Služba běží, DNS jí neuhnulo a klient dostane adresu"
require_service_active  "dnsmasq"
require_service_enabled "dnsmasq"
# Vypnout DNS server, aby se uvolnil port 53, není řešení — je to výměna
# jedné nefunkční služby za druhou. Zadání chce obojí naráz.
if na_serveru "systemctl is-active --quiet named"; then
  uspech "DNS server běží dál"
else
  chyba "DNS server neběží — port 53 se měl uvolnit jinak než jeho vypnutím"
  poznamka "dnsmasq umí DNS i DHCP; zakázat se má ta půlka, kterou nechcete"
fi

# ── klient je součástí části 2: bez adresy nemá služba smysl ────
# Klient se musí rozlišit: „neexistuje" a „nedostal adresu" jsou dvě různé
# věci a nápověda k nim je jiná.
STAV_KLIENT="$(lxc list "^${NETLAB_KLIENT}$" -c s --format csv 2>/dev/null)"
ADRESA=""
if [ -z "$STAV_KLIENT" ]; then
  chyba "testovací klient neexistuje"
  poznamka "spusťte ./start.sh — postaví ho"
elif [ "$STAV_KLIENT" != "RUNNING" ]; then
  chyba "testovací klient neběží"
  poznamka "spusťte ./start.sh — nastartuje ho"
else
  # Obnovu vyžádáme JEN tehdy, když klient adresu nemá, a JEN když se tahle
  # část opravdu vypisuje. Filtr --krok potlačuje výpis, ne provádění —
  # bez druhé podmínky by `--krok 1` klientovi zahodil adresu a jedenáct
  # vteřin čekal na tu, kterou v tu chvíli ještě nikdo nerozdává.
  ADRESA="$(klient_adresa)"
  if [ -z "$ADRESA" ] && krok_aktivni 2; then
    klient_znovu || true
    ADRESA="$(klient_adresa)"
  fi
fi
if [ -z "$ADRESA" ]; then
  [ -n "$STAV_KLIENT" ] && [ "$STAV_KLIENT" = "RUNNING" ] && {
    chyba "klient žádnou adresu nedostal"
    poznamka "zkuste ./start.sh --klient a potom na serveru journalctl -u dnsmasq" ; }
else
  # Adresa musí být z rozsahu, který zadání předepisuje — ne jakákoli.
  OKTET="${ADRESA##*.}"
  if [ "${ADRESA%.*}" = "$PODSIT" ] && [ "$OKTET" -ge 100 ] && [ "$OKTET" -le 150 ]; then
    uspech "klient dostal adresu $ADRESA z předepsaného rozsahu"
  else
    chyba "klient dostal adresu $ADRESA, která do rozsahu nepatří"
    poznamka "rozsah je $PODSIT.100 až $PODSIT.150"
  fi
fi

# Co klient opravdu dostal — ne co je v konfiguráku na serveru.
#
# Ptáme se PODPOROVANÝCH nástrojů (`ip`, `resolvectl`). Soubor
# /run/systemd/netif/leases/* má v hlavičce „This is private data. Do not
# parse." — je to vnitřní formát systemd, který se může změnit. Zůstává
# jako záloha pro případ, že v obrazu neběží systemd-resolved.
na_klientovi() { lxc exec "$NETLAB_KLIENT" -- bash -c "$1" 2>/dev/null | tr -d '\r'; }
LEASE="$(na_klientovi 'cat /run/systemd/netif/leases/* 2>/dev/null')"
hodnota_z_lease() { printf '%s\n' "$LEASE" | grep -m1 "^$1=" | cut -d= -f2-; }

L_ROUTER="$(na_klientovi "ip -4 route show default dev eth0 | awk '{print \$3}' | head -1")"
[ -n "$L_ROUTER" ] || L_ROUTER="$(hodnota_z_lease ROUTER)"
L_DNS="$(na_klientovi 'resolvectl dns eth0 2>/dev/null | sed "s/^.*: //"')"
[ -n "$L_DNS" ] || L_DNS="$(hodnota_z_lease DNS)"
L_DOMENA="$(na_klientovi 'resolvectl domain eth0 2>/dev/null | sed "s/^.*: //"')"
[ -n "$L_DOMENA" ] || L_DOMENA="$(hodnota_z_lease DOMAINNAME)"

if [ -z "$L_ROUTER$L_DNS$L_DOMENA" ]; then
  chyba "na klientovi se nepodařilo zjistit, co dostal"
  poznamka "bez adresy žádná zápůjčka není — nejdřív rozběhněte rozdávání"
else
  [ "$L_ROUTER" = "$BRANA" ] \
    && uspech "klient dostal výchozí bránu $BRANA" \
    || { chyba "výchozí brána v zápůjčce nesedí (klient má '${L_ROUTER:-nic}')"
         poznamka "brána se rozdává volbou číslo 3" ; }
  case " $L_DNS " in
    *" $SRV "*) uspech "klient dostal adresu DNS serveru" ;;
    *)          chyba "DNS server v zápůjčce nesedí (klient má '${L_DNS:-nic}')"
                poznamka "DNS se rozdává volbou číslo 6" ;;
  esac
  L_DOMENA="$(printf '%s' "$L_DOMENA" | tr -d ' ')"
  [ "$L_DOMENA" = "netlab.test" ] \
    && uspech "klient dostal doménu netlab.test" \
    || { chyba "doména v zápůjčce nesedí (klient má '${L_DOMENA:-nic}')"
         poznamka "doména se rozdává volbou číslo 15" ; }
fi

krok 3 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/dhcp/formular.txt — spusťte ./start.sh, doplní ho"
# Porovnává se proti DATABÁZI ZÁPŮJČEK na serveru. Adresa i MAC existují
# jen v žákově vlastním běhu — model je nevymyslí a soused má jiné.
# Vybírá se řádek TOHO klienta, ne první v pořadí — po Rozšíření
# s `dhcp-host=` může být záznamů víc a žák by se porovnával s cizím.
if [ -n "$ADRESA" ]; then
  RADEK="$(na_serveru "grep -F ' $ADRESA ' $ZAPUJCKY 2>/dev/null" | tr -d '\r' | head -1)"
else
  RADEK=""
fi
[ -n "$RADEK" ] || RADEK="$(na_serveru "cat $ZAPUJCKY 2>/dev/null" | tr -d '\r' | head -1)"
LEASE_MAC="$(printf '%s' "$RADEK" | awk '{print $2}' | tr 'A-Z' 'a-z')"
LEASE_IP="$(printf '%s' "$RADEK" | awk '{print $3}')"
ODP_IP="$(_zaznam "$FORMULAR" adresa-klienta | tr -d ' ')"
ODP_MAC="$(_zaznam "$FORMULAR" mac-klienta | tr -d ' ' | tr 'A-Z' 'a-z')"

if [ -z "$LEASE_IP" ]; then
  chyba "na serveru zatím žádná zápůjčka není"
  poznamka "až klient dostane adresu, zapíše se sem: $ZAPUJCKY"
else
  [ "$ODP_IP" = "$LEASE_IP" ] \
    && uspech "adresa klienta ve formuláři sedí" \
    || chyba "adresa klienta ve formuláři nesedí (máte '${ODP_IP:-nic}')"
  [ "$ODP_MAC" = "$LEASE_MAC" ] \
    && uspech "hardwarová adresa klienta ve formuláři sedí" \
    || { chyba "hardwarová adresa ve formuláři nesedí (máte '${ODP_MAC:-nic}')"
         poznamka "je ve druhém sloupci databáze zápůjček" ; }
fi

vypis_souhrn
