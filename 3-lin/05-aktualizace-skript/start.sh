#!/bin/bash
# 3/05 — Repozitáře, aktualizace a první skript. Prostředí: server-XX přes SSH.
#
# Server se staví přes lib/server-lib.sh, takže cvičení funguje i žákovi,
# který chyběl na trojce nebo čtyřce. Klíč ze stanice se nasadí, pokud nějaký
# je — od téhle hodiny se počítá s přihlášením bez hesla.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"

SPRAVA="$HOME/netlab/sprava"
FORMULAR="$SPRAVA/formular.txt"

# Co má skript zjišťovat — u každého žáka jiné.
UKOLY=("volné místo na / v MB" "zatížení systému za poslední minutu" "počet přihlášených uživatelů")
KLICE=(misto zatizeni prihlaseni)
IDX=$(lab_vyber 3 1 350)
UKOL="${UKOLY[IDX-1]}"
KLIC="${KLICE[IDX-1]}"

vyrob_formular() {
  mkdir -p "$SPRAVA"
  cat > "$FORMULAR" <<FORMULAR_KONEC
# Aktualizace a první skript — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# vydani  = kódové jméno vydání, které na serveru běží (jedno slovo)
# hodnota = poslední hodnota, kterou váš skript zapsal do logu
# radku   = kolik řádků má váš log stav.log
#
# Váš skript má hlásit: $UKOL
vydani:
hodnota:
radku:
FORMULAR_KONEC
}

postav_server || exit 1

if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO   (klíč jste si zatím nevyrobili — viz cvičení 4)"
fi

# Automatické aktualizace musí být na začátku vypnuté — zapnout je je úkol.
# JEN u nově postaveného serveru! Bez té podmínky by druhé spuštění start.sh
# (po ./stop.sh, po restartu stanice, po ztracené adrese) smazalo žákovi
# hotovou práci — a to porušuje pravidlo „start.sh existující prostředí
# nechá být".
if [ "$SERVER_NOVY" -eq 1 ]; then
  lxc exec "$SERVER_KONT" -- bash -c \
    "rm -f /etc/apt/apt.conf.d/20auto-upgrades" >/dev/null 2>&1
fi

# Balíček, který se v Kroku 2 zapíná. Zadání ho zakazuje instalovat uvnitř
# labu, takže tady musí být jistota, že na serveru je.
lxc exec "$SERVER_KONT" -- bash -c \
  "command -v unattended-upgrade >/dev/null || dpkg -s unattended-upgrades >/dev/null 2>&1 \
     || { apt-get update -qq && apt-get install -y -qq unattended-upgrades lsb-release; }" \
  >/dev/null 2>&1

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
    Formulář:   $FORMULAR   (na stanici)

  Váš skript má hlásit: $UKOL

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/05-aktualizace-skript && ./check.sh --krok 1

EOF
