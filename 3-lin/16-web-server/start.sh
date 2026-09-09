#!/bin/bash
# 3/16 — Web server I. Prostředí: server web-XX přes SSH.
#
# Server je společný pro cvičení 16, 17 a 18. Apache se nainstaluje
# a nastartuje, ale vlastní web si žák postaví sám.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="web-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/../../lib/web-lib.sh"

WEB="$HOME/netlab/web"
FORMULAR="$WEB/formular.txt"

vyrob_formular() {
  mkdir -p "$WEB"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# kod    = kód pobočky z podkladů na serveru
# server = hodnota hlavičky Server, kterou vrací váš web
#          (curl -I ... | grep -i '^server:')
kod:
server:
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
    Adresa:     $SERVER_IP   (budete ji potřebovat pro curl ze stanice)

    Apache:     běží, zatím jen s výchozím webem
    Podklady:   $WEB_PODKLADY   (na serveru)
    Formulář:   $FORMULAR   (na stanici)

  Postavte web pobočky $WEB_POBOCKA:

    Jméno webu:      $WEB_JMENO
    Kořen dokumentů: $WEB_ROOT

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/16-web-server && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
