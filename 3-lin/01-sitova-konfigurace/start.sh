#!/bin/bash
# 3/01 — Síťová konfigurace (netplan). Prostředí: žákova stanice, dva adaptéry.
# Skript SÍŤ NENASTAVUJE — to je učivo. Jen si poznamená výchozí stav, aby
# kontrola poznala, že žák nesáhl na rozhraní, kterým stanice vidí ven.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

SIT="$HOME/netlab/sit"
FORMULAR="$SIT/formular.txt"
PRIMARNI="$SIT/.primarni-adapter"
VOLNA="$SIT/.volna-rozhrani"

# Rozhraní se čte podle klíčového slova `dev`, ne podle pozice pole. Trasa
# bez `via` (on-link brána) má jiné pořadí a `$5` by ukázalo na `proto`.
primarni_rozhrani() {
  ip route show default 2>/dev/null \
    | awk '/^default/{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}

# Jen fyzické karty. `ip -br link` by započítal i `lxdbr0` a `veth*`, kterých
# je na stanici s LXD několik — a skript by žákovi tvrdil nesmysl.
fyzicka_rozhrani() {
  local d n
  for d in /sys/class/net/*/device; do
    [ -e "$d" ] || continue
    n="$(basename "$(dirname "$d")")"
    printf '%s\n' "$n"
  done
}

# Poznámka o výchozím stavu se zapisuje v OBOU větvích. Kdyby vznikala jen
# při prvním založení, `reset.sh` → `start.sh` by ji nikdy neobnovil a žák
# by uvízl ve smyčce mezi check.sh, reset.sh a start.sh.
poznamenej_vychozi_stav() {
  local iface; iface="$(primarni_rozhrani)"
  if [ -z "$iface" ]; then
    echo "  Stanice nemá výchozí trasu. Kontrola nepozná, na které rozhraní"
    echo "  se nesmí sahat — řekněte o tom vyučujícímu."
    return 1
  fi
  printf '%s\n' "$iface" > "$PRIMARNI"
  # Rozhraní, která na začátku neměla adresu. Kontrola podle nich pozná, že
  # žák adresu nedal na `lo` ani na virtuální rozhraní.
  fyzicka_rozhrani | while read -r n; do
    ip -br a show "$n" 2>/dev/null | grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/' || printf '%s\n' "$n"
  done > "$VOLNA"
  return 0
}

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Síťová konfigurace — vyplňte hodnoty za dvojtečku.
# renderer = který program na téhle stanici řídí síť (jméno z výstupu netplan get)
# adapter  = jméno rozhraní, na které jste dali statickou adresu
# adresa   = adresa i s prefixem, kterou jste nastavili (tvar 10.10.10.1XX/24)
# primarni = jméno rozhraní, kterým stanice vidí ven
renderer:
adapter:
adresa:
primarni:
FORMULAR_KONEC
}

if [ -d "$SIT" ]; then
  DOPLNENO=""
  [ -s "$FORMULAR" ] || { vyrob_formular; DOPLNENO="$DOPLNENO formular.txt"; }
  [ -s "$PRIMARNI" ] || { poznamenej_vychozi_stav && DOPLNENO="$DOPLNENO poznámku o výchozím stavu"; }
  echo
  if [ -n "$DOPLNENO" ]; then
    echo "  Prostředí už existuje v $SIT."
    echo "  Chybělo tohle, doplnila jsem to:$DOPLNENO"
  else
    echo "  Prostředí už existuje v $SIT — pokračujte, kde jste skončili."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

mkdir -p "$SIT"
poznamenej_vychozi_stav || { echo; exit 1; }
vyrob_formular

cat <<EOF

  Prostředí je připravené. Síť je zatím nedotčená — nastavit ji je vaše práce.

    Formulář:  $FORMULAR

  Kromě rozhraní, kterým vidíte ven, je na stanici ještě aspoň jedno
  nepoužívané. Které to je, zjistíte v Kroku 2.

  Přepněte se do adresáře:

    cd ~/netlab/sit

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/3-lin/01-sitova-konfigurace && ./check.sh --krok 1

EOF
