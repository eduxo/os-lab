#!/bin/bash
# 3/17 — HTTPS a vlastní certifikační autorita. Server web-XX přes SSH.
#
# Dvouhodinové cvičení. Server je týž jako v šestnáctce; kdo ji nedělal,
# dostane základní web postavený tímhle skriptem, aby měl co zabezpečit.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="web-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/../../lib/web-lib.sh"

WEB="$HOME/netlab/web"
FORMULAR="$WEB/formular-17.txt"
CA_DIR=/srv/ca
JMENO2="intranet.netlab.test"
ROOT2="/var/www/intranet"

vyrob_formular() {
  mkdir -p "$WEB"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# Obojí přečtěte z certifikátu, který server OPRAVDU POSÍLÁ — ne ze
# souboru na disku. Ze stanice to zjistí `openssl s_client`.
#
# otisk         = otisk (fingerprint) SHA-256 serverového certifikátu,
#                 šestnáctkově, dvojice oddělené dvojtečkou
# seriove-cislo = sériové číslo, které certifikátu přidělila vaše autorita
#                 při podpisu
otisk:
seriove-cislo:
FORM_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

postav_apache || exit 1
zaridi_kod || exit 1

# Nezávislost: kdo nedělal šestnáctku, nemá co zabezpečovat. Základní web
# se proto postaví — ale JEN když ještě není, aby se žákovi nepřepsal ten
# jeho. (Poučení z bloku D: guard musí sedět na tom, co se opravdu staví.)
if ! lxc exec "$SERVER_KONT" -- test -f "$WEB_ROOT/index.html"; then
  lxc exec "$SERVER_KONT" -- bash -c "
    mkdir -p '$WEB_ROOT'
    printf '<!doctype html><meta charset=\"utf-8\"><title>Pobocka %s</title>\n<h1>Pobocka %s</h1>\n<p>Kod pobocky: %s</p>\n' \\
      '$WEB_POBOCKA' '$WEB_POBOCKA' '$WEB_KOD' > '$WEB_ROOT/index.html'
  " >/dev/null 2>&1
  lxc exec "$SERVER_KONT" -- tee /etc/apache2/sites-available/$WEB_POBOCKA.conf >/dev/null <<VHOST
<VirtualHost *:80>
    ServerName $WEB_JMENO
    DocumentRoot $WEB_ROOT
</VirtualHost>
VHOST
  lxc exec "$SERVER_KONT" -- bash -c \
    "a2ensite $WEB_POBOCKA >/dev/null 2>&1; systemctl reload apache2" >/dev/null 2>&1
fi

# Pracovní adresář pro certifikáty patří žákovi, aby na openssl nepotřeboval
# sudo. Soukromé klíče si zpřísní sám — je to součást zadání.
lxc exec "$SERVER_KONT" -- bash -c "
  mkdir -p $CA_DIR $ROOT2
  chown $SERVER_UCET:$SERVER_UCET $CA_DIR
  chmod 750 $CA_DIR
" >/dev/null 2>&1

[ -s "$FORMULAR" ] || vyrob_formular

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI
    Adresa:     $SERVER_IP   (budete ji potřebovat pro curl a prohlížeč)

    Web na portu 80:  $WEB_JMENO
    Pracovní adresář: $CA_DIR   (patří vám, sudo tam nepotřebujete)
    Formulář:         $FORMULAR   (na stanici)

  První blok — zabezpečte web pobočky:

    Jméno:  $WEB_JMENO

  Druhý blok — totéž pro druhý web:

    Jméno:  $JMENO2
    Kořen:  $ROOT2

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/17-https-ca && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
