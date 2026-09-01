#!/bin/bash
# 2/21 — Procesy. Prostředí: žákova stanice.
# Vyrobí dva dlouhoběžící skripty. Nespouští je — spuštění je učivo.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PROC="$HOME/netlab/procesy"
FORMULAR="$PROC/procesy.txt"

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Procesy — vyplňte hodnoty za dvojtečku.
# skript   = jméno souboru vašeho hlídače (i s příponou)
# interval = kolik sekund hlídač čeká mezi dvěma zápisy (jen číslo)
# pid      = PID hlídače z vašeho běhu (jen číslo)
# pamet    = kolik kB paměti hlídač zabíral (sloupec RSS), jen číslo
# signal   = číslo signálu, kterým se podařilo ukončit tvrdohlavý proces
skript:
interval:
pid:
pamet:
signal:
FORMULAR_KONEC
}

# Prostředí, které už stojí, se nepřestavuje — jen se doplní formulář,
# pokud si ho žák smazal. Bez toho ho kontrola posílá na ./start.sh,
# ten odpoví „už existuje", a žák se z té smyčky nedostane.
if [ -d "$PROC" ]; then
  echo
  if [ -f "$FORMULAR" ]; then
    echo "  Prostředí už existuje v $PROC — pokračujte, kde jste skončili."
  else
    vyrob_formular
    echo "  Prostředí už existuje v $PROC. Chyběl formulář, doplnila jsem ho."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

# Jméno hlídače a jeho interval se u každého žáka liší — hodnoty ve formuláři
# pak nejdou opsat od souseda.
USEKY=(sklad vratnice kotelna serverovna recepce dilna)
IDX=$(lab_vyber 6 1 211)
USEK="${USEKY[IDX-1]}"
SKRIPT="$PROC/hlidac-$USEK.sh"
INTERVAL=$(( 2 + ZAK % 4 ))

mkdir -p "$PROC"

cat > "$SKRIPT" <<SKRIPT_KONEC
#!/bin/bash
# Hlídač úseku $USEK. Běží pořád dokola a hlásí do logu, že je vše v pořádku.
INTERVAL=$INTERVAL
LOG="\$HOME/netlab/procesy/hlidac.log"
while true; do
  printf '%s PID=%d hlidac $USEK: vse v poradku\n' "\$(date +%H:%M:%S)" "\$\$" >> "\$LOG"
  sleep "\$INTERVAL"
done
SKRIPT_KONEC

# Druhý skript si signál TERM zakáže. Na něm žák uvidí, proč `kill -9`
# existuje — a proč není první volbou.
cat > "$PROC/tvrdohlavy.sh" <<SKRIPT_KONEC
#!/bin/bash
# Sběr dat z čidel. Zápis nesmí zůstat rozdělaný, proto si program
# ošetřuje ukončení sám — a v tomhle případě si ho ošetřil špatně.
trap '' TERM
LOG="\$HOME/netlab/procesy/tvrdohlavy.log"
while true; do
  printf '%s PID=%d sber dat probiha\n' "\$(date +%H:%M:%S)" "\$\$" >> "\$LOG"
  sleep 3
done
SKRIPT_KONEC

chmod +x "$SKRIPT" "$PROC/tvrdohlavy.sh"
vyrob_formular

cat <<EOF

  Prostředí je připravené.

    Váš hlídač:   $SKRIPT
    Druhý skript: $PROC/tvrdohlavy.sh
    Formulář:     $FORMULAR

  Skripty zatím neběží — spustit si je máte sami.

    cd ~/netlab/procesy

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/21-procesy && ./check.sh --krok 1

EOF
