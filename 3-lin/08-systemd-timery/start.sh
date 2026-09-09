#!/bin/bash
# 3/08 — systemd: timery. Prostředí: server sluzby-XX přes SSH.
#
# Skript ani unity NEVYRÁBÍ — to je celé učivo. Připraví jen data, která
# se budou zálohovat. Server staví lib/server-lib.sh, takže cvičení funguje
# i žákovi, který na sedmičce nebyl.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="sluzby-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

CAS="$HOME/netlab/timery"
FORMULAR="$CAS/formular.txt"
INTERVAL=$(( 1 + $(lab_vyber 4 1 380) ))     # 2 až 5 minut
POCET=$(( 4 + $(lab_vyber 5 1 381) ))        # kolik souborů se zálohuje

vyrob_formular() {
  mkdir -p "$CAS"
  cat > "$FORMULAR" <<FORMULAR_KONEC
# Timery — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# interval = po kolika minutách se má úloha opakovat (jen číslo)
# souboru  = kolik souborů je v adresáři /srv/data
# zaloha   = jméno kterékoli zálohy, která v /srv/zalohy vznikla
interval:
souboru:
zaloha:
FORMULAR_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

# ── data k zálohování ─────────────────────────────────────────────
# Doplní se každý chybějící soubor, ne jen když adresář neexistuje —
# jinak by byl uklizený adresář slepá ulička.
lxc exec "$SERVER_KONT" -- bash -c "mkdir -p /srv/data /srv/zalohy" >/dev/null 2>&1
for i in $(seq 1 "$POCET"); do
  lxc exec "$SERVER_KONT" -- bash -c \
    "F=/srv/data/mereni-$(printf '%02d' "$i").txt
     [ -s \"\$F\" ] || printf 'Měření %02d\nÚsek: sklad\nHodnota: %d\n' $i $(( 200 + ZAK * i )) > \"\$F\"" \
    >/dev/null 2>&1
done

# Čeština: „každé 2 minuty" × „každých 5 minut" — skloňování se řídí číslem.
case "$INTERVAL" in
  5) INTERVAL_SLOVY="každých $INTERVAL minut" ;;
  *) INTERVAL_SLOVY="každé $INTERVAL minuty" ;;
esac

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

    K zálohování:  /srv/data
    Kam zálohovat: /srv/zalohy
    Interval:      $INTERVAL_SLOVY

    Formulář:      $FORMULAR   (na stanici)

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/08-systemd-timery && ./check.sh --krok 1

EOF
