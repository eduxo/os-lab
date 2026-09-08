#!/bin/bash
# 3/04 — SSH klíče a přenos souborů. Prostředí: server server-XX přes SSH.
#
# Klíč ze stanice se tu NENASAZUJE — nasadit ho je učivo téhle hodiny.
# Server se staví přes lib/server-lib.sh, takže cvičení funguje i žákovi,
# který chyběl na trojce.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"

PRENOS="$HOME/netlab/prenos"
ODCHOZI="$PRENOS/odchozi"
STAZENE="$PRENOS/stazene"
FORMULAR="$PRENOS/formular.txt"

POCET=$(( 3 + $(lab_vyber 4 1 340) ))     # kolik souborů se přenáší
# Ten, co jde přes scp, se losuje z rozsahu, který opravdu vznikne.
HLAVNI="protokol-$(printf '%02d' "$(lab_vyber "$POCET" 1 341)").txt"

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Klíče a přenos souborů — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI.
#
# otisk-klice = otisk VAŠEHO veřejného klíče (ssh-keygen -lf ...), celý i s SHA256:
# velikost    = velikost souboru, který jste poslali přes scp, v bajtech
# podruhe     = kolik souborů přenesl rsync, když jste ho pustili PODRUHÉ
otisk-klice:
velikost:
podruhe:
FORMULAR_KONEC
}

postav_server || exit 1

# ── data na stanici, která se budou přenášet nahoru ───────────────
# Doplňuje se KAŽDÝ chybějící protokol, ne jen když adresář neexistuje.
# Testovat jen existenci adresáře znamená, že žák, který si soubory přesunul
# nebo smazal, uvízne mezi check.sh („spusťte start.sh") a start.sh, který
# nic nedoplní. Protokoly nenesou žákovu práci, takže se doplnit smí.
mkdir -p "$ODCHOZI" "$STAZENE"
for i in $(seq 1 "$POCET"); do
  F="$ODCHOZI/protokol-$(printf '%02d' "$i").txt"
  [ -s "$F" ] || printf 'Protokol o měření %02d\nStanice: %s\nHodnota: %d\n' \
    "$i" "$(hostname)" $(( 100 + ZAK * i )) > "$F"
done
[ -s "$FORMULAR" ] || vyrob_formular

# ── soubor na serveru, který se bude stahovat dolů ────────────────
ZAZNAM="zaznam-$ZAK2.txt"
lxc exec "$SERVER_KONT" -- bash -c "
  mkdir -p /home/$SERVER_UCET/dokumenty
  [ -s /home/$SERVER_UCET/dokumenty/$ZAZNAM ] || printf 'Servisní záznam %s\nServer: %s\nPořadové číslo: %d\n' \
    '$ZAK2' \"\$(hostname)\" $(( 4000 + ZAK * 7 )) > /home/$SERVER_UCET/dokumenty/$ZAZNAM
  chown -R $SERVER_UCET:$SERVER_UCET /home/$SERVER_UCET/dokumenty
" >/dev/null 2>&1

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Heslo:      $SERVER_HESLO   (dnes ho použijete naposledy)

    K odeslání:  $ODCHOZI/   ($POCET souborů)
    Přes scp:    $HLAVNI
    Ke stažení:  ~/dokumenty/$ZAZNAM  (na serveru)
    Stahovat do: $STAZENE/
    Formulář:    $FORMULAR

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/04-ssh-klice && ./check.sh --krok 1

EOF
