#!/bin/bash
# 3/03 — SSH a vzdálená správa. Prostředí: LXD kontejner, přístup přes SSH.
#
# První cvičení ročníku, kde žák pracuje na serveru. Server `server-XX` slouží
# celému bloku B (cvičení 3 až 6) a každé z těch cvičení ho umí postavit samo —
# pravidlo o nezávislosti na předchozím stavu. Stavbu drží lib/server-lib.sh.
#
# Klíč ze stanice se tu SCHVÁLNĚ nenasazuje: přihlášení heslem je učivo téhle
# hodiny a nasazení klíče je učivo té příští.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"

SIT="$HOME/netlab/ssh"
FORMULAR="$SIT/formular.txt"

vyrob_formular() {
  mkdir -p "$SIT"
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# SSH a vzdálená správa — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru. Mějte otevřená dvě okna.
#
# server = jméno serveru, jak se hlásí po přihlášení (příkaz hostname)
# otisk  = otisk klíče serveru ve tvaru SHA256:...
server:
otisk:
#
# Kromě formuláře máte úkol na SERVERU — soubor ~/prevzeti.txt, viz zadání.
FORMULAR_KONEC
}

postav_server || exit 1
[ -s "$FORMULAR" ] || vyrob_formular

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Heslo:      $SERVER_HESLO
    Formulář:   $FORMULAR   (na STANICI, ne na serveru)

  Otevřete si dvě okna terminálu: v jednom budete na serveru, ve druhém
  na stanici. Kontrola běží na stanici.

    cd ~/os-lab/3-lin/03-ssh && ./check.sh --krok 1

EOF
