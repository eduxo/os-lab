#!/bin/bash
# 3/17 — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 je jen prohlídka.
#
# Certifikát se čte Z TOHO, CO SERVER POSÍLÁ, ne ze souboru na disku.
# Soubor může být správný a Apache přitom posílat úplně jiný.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="web-$ZAK2"
SERVER_KONT="$KONT"
source "$(dirname "$0")/../../lib/web-lib.sh"

WEB="$HOME/netlab/web"
FORMULAR="$WEB/formular-17.txt"
CA_DIR=/srv/ca
JMENO2="intranet.netlab.test"

# LXD se jmenuje jinak než jeho příkaz — hláška má mluvit tak, jak
# se o něm mluví ve zbytku repozitáře i v hodině.
for n in lxc curl openssl; do
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

# Certifikát autority si stáhneme na stanici — bez něj nejde ověřit řetěz
# tak, jak by ho ověřoval skutečný klient.
CA_SOUBOR="$(mktemp)"
trap 'rm -f "$CA_SOUBOR"' EXIT INT TERM
na_serveru "cat $CA_DIR/ca.crt 2>/dev/null" > "$CA_SOUBOR"

# Co server v TLS handshake opravdu pošle. -servername kvůli SNI: bez něj
# by u víc virtual hostů odpověděl ten první.
posle_certifikat() {  # posle_certifikat JMENO → PEM
  # `timeout` je nutný: s_client na nedostupném portu čeká, dokud ho
  # nezastaví jádro — a kontrola by vypadala zaseknutě.
  printf '' | timeout 8 openssl s_client -connect "$IP:443" -servername "$1" \
    -showcerts 2>/dev/null | openssl x509 2>/dev/null
}

# Certifikát se stahuje JEN tehdy, když ho některá vypisovaná část
# potřebuje. Bez toho by `--krok 2` — první kontrola, na kterou návod
# posílá — čekal dvakrát osm vteřin na port 443, kde v tu chvíli
# ještě nikdo neposlouchá, a třikrát osm na HTTPS.
CERT=""; CERT2=""
if krok_aktivni 3 || krok_aktivni 4 || krok_aktivni 5 || krok_aktivni 6; then
  CERT="$(posle_certifikat "$WEB_JMENO")"
fi
if krok_aktivni 5; then
  CERT2="$(posle_certifikat "$JMENO2")"
fi

krok 2 "Certifikační autorita"
if na_serveru "test -s $CA_DIR/ca.crt"; then
  uspech "certifikát autority je na serveru"
  if na_serveru "openssl x509 -in $CA_DIR/ca.crt -noout -checkend 0 >/dev/null 2>&1"; then
    uspech "certifikát autority je platný"
  else
    chyba "certifikát autority je prošlý"
  fi
  # Autorita musí umět podepisovat — bez basicConstraints CA:TRUE ji
  # klient odmítne, i když je jinak v pořádku.
  if na_serveru "openssl x509 -in $CA_DIR/ca.crt -noout -text | grep -q 'CA:TRUE'"; then
    uspech "certifikát autority má příznak CA"
  else
    chyba "certifikát autority nemá příznak CA:TRUE"
    poznamka "self-signed certifikát serveru není autorita — musí vzniknout jako CA"
  fi
  # Autorita musí být JEDEN certifikát. Svazek dvou self-signed by prošel
  # všemi ostatními kontrolami — `openssl verify` by uznal oba a otisky
  # by se lišily.
  POCET_CRT="$(na_serveru "grep -c 'BEGIN CERTIFICATE' $CA_DIR/ca.crt" | tr -d '\r')"
  if [ "${POCET_CRT:-0}" -eq 1 ]; then
    uspech "soubor autority obsahuje právě jeden certifikát"
  else
    chyba "soubor autority obsahuje ${POCET_CRT:-0} certifikátů, má být jeden"
    poznamka "autorita je jedna a podepisuje obojí — o tom celé cvičení je"
  fi
else
  chyba "na serveru není $CA_DIR/ca.crt"
fi
# Soukromý klíč autority nesmí být čitelný pro kohokoli.
PRAVA="$(na_serveru "stat -c %a $CA_DIR/ca.key 2>/dev/null" | tr -d '\r')"
case "$PRAVA" in
  "")            chyba "na serveru není $CA_DIR/ca.key" ;;
  600|400) uspech "klíč autority má přiměřená práva ($PRAVA)" ;;
  *)       chyba "klíč autority má práva $PRAVA — dostane se k němu i někdo jiný"
           poznamka "soukromý klíč patří jen svému majiteli: chmod 600" ;;
esac

krok 3 "Certifikát serveru a jeho nasazení"
require_service_active "apache2"
if na_serveru "apache2ctl -M 2>/dev/null | grep -q ssl_module"; then
  uspech "modul ssl je zapnutý"
else
  chyba "modul ssl není zapnutý"
  poznamka "a2enmod ssl a potom restart Apache"
fi
if na_serveru "ss -tln 2>/dev/null | grep -q ':443 '"; then
  uspech "server poslouchá na portu 443"
else
  chyba "na portu 443 nikdo neposlouchá"
fi

if [ -z "$CERT" ]; then
  chyba "server v TLS spojení neposlal žádný certifikát"
  poznamka "openssl s_client -connect $IP:443 -servername $WEB_JMENO ukáže, kde to vázne"
else
  uspech "server posílá certifikát"
  # Moderní klienti CN neuznávají — jméno musí být v subjectAltName.
  if printf '%s' "$CERT" | openssl x509 -noout -text 2>/dev/null \
       | grep -A1 'Subject Alternative Name' | grep -q "DNS:$WEB_JMENO"; then
    uspech "certifikát platí pro jméno $WEB_JMENO (subjectAltName)"
  else
    chyba "v certifikátu chybí $WEB_JMENO v subjectAltName"
    poznamka "samotné CN dnes nestačí — prohlížeče i curl se dívají na SAN"
  fi
  VYDAVATEL="$(printf '%s' "$CERT" | openssl x509 -noout -issuer 2>/dev/null)"
  SUBJEKT="$(printf '%s' "$CERT" | openssl x509 -noout -subject 2>/dev/null)"
  SUBJEKT_CA="$(na_serveru "openssl x509 -in $CA_DIR/ca.crt -noout -subject 2>/dev/null" | tr -d '\r')"
  if [ -n "$SUBJEKT_CA" ] && [ "${VYDAVATEL#issuer=}" = "${SUBJEKT_CA#subject=}" ]; then
    uspech "certifikát vydala vaše autorita"
  else
    chyba "certifikát nevydala vaše autorita"
    poznamka "self-signed certifikát není totéž co certifikát podepsaný CA"
  fi
  # Kdyby si certifikát vydal sám sobě, byl by vydavatel týž jako subjekt —
  # a předchozí kontrola by prošla, kdyby `ca.crt` byl tentýž soubor.
  if [ "${VYDAVATEL#issuer=}" = "${SUBJEKT#subject=}" ]; then
    chyba "certifikát serveru je podepsaný sám sebou"
    poznamka "má ho podepsat autorita — vydavatel a subjekt se musí lišit"
  else
    uspech "certifikát serveru není podepsaný sám sebou"
  fi
  # Serverový certifikát nesmí být zároveň autoritou.
  if printf '%s' "$CERT" | openssl x509 -noout -text 2>/dev/null | grep -q 'CA:TRUE'; then
    chyba "certifikát serveru má příznak CA:TRUE"
    poznamka "server nepodepisuje cizí certifikáty — patří mu CA:FALSE"
  else
    uspech "certifikát serveru není autoritou"
  fi
fi

krok 4 "Řetěz důvěry ze stanice"
# Tohle je jádro cvičení. `--cacert` znamená „důvěřuj téhle autoritě
# a nikomu jinému" — přesně to, co dělá prohlížeč s importovanou CA.
if ! krok_aktivni 4; then :
elif [ ! -s "$CA_SOUBOR" ]; then
  chyba "certifikát autority se nepodařilo přenést na stanici"
else
  STAV_TLS="$(stav_webu "$WEB_JMENO" 443 "$IP" --cacert "$CA_SOUBOR")"
  case "$STAV_TLS" in
    200) uspech "https://$WEB_JMENO/ projde ověřením proti vaší autoritě" ;;
    000) chyba "https://$WEB_JMENO/ neprojde ověřením"
         poznamka "curl -v --cacert ... vypíše, na čem ověření selhalo" ;;
    *)   chyba "https://$WEB_JMENO/ vrací stav $STAV_TLS" ;;
  esac
  # Bez znalosti autority se spojení navázat NESMÍ — jinak certifikát
  # nepodepsala vlastní CA, ale někdo, komu stanice věří odjinud.
  if [ "$(stav_webu "$WEB_JMENO" 443 "$IP")" = "000" ]; then
    uspech "bez znalosti vaší autority se ověření nezdaří (správně)"
  else
    chyba "spojení projde i bez vaší autority"
    poznamka "to znamená, že certifikát nevydala ta autorita, kterou jste vyrobili"
  fi
fi

krok 5 "Druhý web"
if [ -z "$CERT2" ]; then
  chyba "pro $JMENO2 server žádný certifikát neposlal"
else
  if printf '%s' "$CERT2" | openssl x509 -noout -text 2>/dev/null \
       | grep -A1 'Subject Alternative Name' | grep -q "DNS:$JMENO2"; then
    uspech "certifikát pro $JMENO2 platí pro své jméno"
  else
    chyba "certifikát pro $JMENO2 na to jméno neplatí"
    poznamka "každý web má svůj certifikát; SNI rozhoduje, který se pošle"
  fi
  OTISK1="$(printf '%s' "$CERT"  | openssl x509 -noout -fingerprint -sha256 2>/dev/null)"
  OTISK2="$(printf '%s' "$CERT2" | openssl x509 -noout -fingerprint -sha256 2>/dev/null)"
  if [ -z "$OTISK1" ] || [ -z "$OTISK2" ]; then
    chyba "otisky obou certifikátů se nepodařilo porovnat"
    poznamka "jeden z webů certifikát neposlal — nejdřív rozběhněte oba"
  elif [ "$OTISK1" = "$OTISK2" ]; then
    chyba "oba weby posílají tentýž certifikát"
    poznamka "druhý web má mít vlastní — jinak by stačil jeden pro všechno"
  else
    uspech "každý web posílá svůj vlastní certifikát"
  fi
fi
if ! krok_aktivni 5; then :
elif [ -s "$CA_SOUBOR" ] && [ "$(stav_webu "$JMENO2" 443 "$IP" --cacert "$CA_SOUBOR")" = "200" ]; then
  uspech "https://$JMENO2/ projde ověřením proti vaší autoritě"
else
  chyba "https://$JMENO2/ neprojde ověřením"
fi

krok 6 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/web/formular-17.txt — spusťte ./start.sh, doplní ho"
# Otisk existuje jen v žákově vlastním certifikátu — v repozitáři není,
# soused má jiný a model ho nevymyslí.
# Dvojtečky i velikost písmen se z obou stran srovnají — žák může otisk
# opsat v libovolném z tvarů, které openssl a prohlížeče používají.
OTISK_ZIVE="$(printf '%s' "$CERT" | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
  | cut -d= -f2 | tr -d ' :\r' | tr 'a-f' 'A-F')"
# Uznává se i celý zkopírovaný řádek `sha256 Fingerprint=AB:CD:…`
ODP_OTISK="$(_zaznam "$FORMULAR" otisk | sed 's/.*=//' | tr -d ' :\r' | tr 'a-f' 'A-F')"
if [ -z "$OTISK_ZIVE" ]; then
  chyba "otisk se nepodařilo přečíst — server certifikát neposlal"
elif [ "$ODP_OTISK" = "$OTISK_ZIVE" ]; then
  uspech "otisk certifikátu ve formuláři sedí"
else
  chyba "otisk certifikátu ve formuláři nesedí"
  poznamka "openssl s_client -connect $IP:443 -servername $WEB_JMENO </dev/null | openssl x509 -noout -fingerprint -sha256"
fi
# Druhá položka musí být taky VLASTNÍ. `CN` vydavatele je doslova v zadání
# a pro celou třídu stejné, takže by ho vyplnil kdokoli bez rozběhnutého
# prostředí. Sériové číslo vzniká při podpisu a je jedinečné.
SERIAL_ZIVE="$(printf '%s' "$CERT" | openssl x509 -noout -serial 2>/dev/null \
  | cut -d= -f2 | tr -d ' :\r' | tr 'a-f' 'A-F')"
ODP_SER="$(_zaznam "$FORMULAR" seriove-cislo | tr -d ' :\r' | tr 'a-f' 'A-F')"
if [ -z "$SERIAL_ZIVE" ]; then
  chyba "sériové číslo se nepodařilo přečíst"
elif [ "$ODP_SER" = "$SERIAL_ZIVE" ]; then
  uspech "sériové číslo certifikátu ve formuláři sedí"
else
  chyba "sériové číslo certifikátu ve formuláři nesedí"
  poznamka "openssl x509 -noout -serial nad tím, co server posílá"
fi

vypis_souhrn
