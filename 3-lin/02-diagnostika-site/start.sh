#!/bin/bash
# 3/02 — Diagnostika sítě. Prostředí: žákova stanice.
#
# Rozbít žákovi vlastní síť by ho odřízlo od `git pull` i od zbytku hodiny,
# proto se nic nerozbíjí. Místo toho dostane TŘI CÍLE, z nichž každý selže
# na jiné vrstvě — a jeho práce je rozpoznat na které. Pořadí cílů se losuje.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

DIAG="$HOME/netlab/diagnostika"
FORMULAR="$DIAG/formular.txt"
SLUZBA="$DIAG/naslouchac.sh"
PORT=$(( 9000 + ZAK ))

# Tři cíle. Každý selže jinak a všechny fungují i bez internetu.
# Všechny tři mají tvar hostitel:port. Kdyby se lišily zápisem (jméno ×
# adresa × adresa s portem), dalo by se zařazení uhodnout, aniž by žák
# spustil jediný nástroj.
# Cíl se zavřeným portem míří na VLASTNÍ adresu stanice, ne na 127.0.0.1.
# Loopback by prozradil, že stroj žije, a zařazení by šlo uhodnout bez měření.
# Takhle jsou dva ze tří cílů obyčejné adresy a rozliší je jen zkouška.
MOJE="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
MOJE="${MOJE:-127.0.0.1}"
JMENO="mereni-$ZAK2.netlab.test:80"       # překlad neprojde
ADRESA="10.10.10.2$ZAK2:80"               # přeloží se, ale nikdo neodpoví
ZAVRENY="$MOJE:$(( 9500 + ZAK ))"         # odpoví, ale port je zavřený
CILE=("$JMENO" "$ADRESA" "$ZAVRENY")
PORADI=($(lab_vyber 3 3 310))             # u každého žáka jiné pořadí

spust_naslouchac() {
  pgrep -f "http.server $PORT" >/dev/null 2>&1 && return
  if ! command -v python3 >/dev/null; then
    echo "  Na stanici chybí python3, takže nejde spustit službu, kterou máte"
    echo "  najít. Řekněte o tom vyučujícímu."
    return 1
  fi
  # Vlastní prázdný adresář, ne ten s formulářem: http.server poslouchá na
  # 0.0.0.0, takže by jinak kdokoli ze stejného segmentu stáhl
  # http://<stanice>:90XX/formular.txt i s vyplněnými odpověďmi.
  mkdir -p "$DIAG/.sluzba"
  if command -v setsid >/dev/null; then
    ( cd "$DIAG/.sluzba" && setsid nohup python3 -m http.server "$PORT" >/dev/null 2>&1 & )
  else
    ( cd "$DIAG/.sluzba" && nohup python3 -m http.server "$PORT" >/dev/null 2>&1 & )
  fi
}

vyrob_formular() {
  # Pořadí se uloží. Kdyby si žák opravil číslo v ~/.os-lab-zak, formulář
  # a kontrola by se jinak tiše rozešly.
  printf '%s\n' "${PORADI[@]}" > "$DIAG/.poradi"
  printf '%s\n' "$MOJE" > "$DIAG/.vlastni-adresa"
  {
    echo "# Diagnostika sítě — vyplňte hodnoty za dvojtečku."
    echo "#"
    echo "# ── kdo jsem ─────────────────────────────────────────────────"
    echo "# adresa = adresa vaší stanice i s prefixem na rozhraní, kterým vidíte ven"
    echo "# brana  = adresa výchozí brány"
    echo "# dns    = adresa prvního DNS serveru, který stanice používá"
    echo "adresa:"
    echo "brana:"
    echo "dns:"
    echo
    echo "# ── kde se to zastavilo ──────────────────────────────────────"
    echo "# Výstupy nástrojů připojujte do doklad.txt (viz Krok 2 zadání)."
    echo "# U každého cíle napište JEDNO ze tří slov:"
    echo "#   preklad       = nepodařilo se přeložit jméno na adresu"
    echo "#   nedostupny    = adresa je známá, ale nikdo neodpovídá"
    echo "#   zavreny-port  = stroj odpovídá, ale na tom portu nic neposlouchá"
    local i=1
    for N in "${PORADI[@]}"; do
      printf '# cil-%d = %s\n' "$i" "${CILE[N-1]}"
      printf 'cil-%d:\n' "$i"
      i=$((i+1))
    done
    echo
    echo "# ── co poslouchá u mě ────────────────────────────────────────"
    echo "# port    = číslo portu v rozsahu 9000-9099, na kterém na této stanici něco naslouchá"
    echo "# program = jméno programu, který ten port drží"
    echo "# pid     = PID toho programu"
    echo "port:"
    echo "program:"
    echo "pid:"
  } > "$FORMULAR"
}

if [ -d "$DIAG" ]; then
  echo
  [ -s "$FORMULAR" ] || vyrob_formular
  spust_naslouchac
  echo "  Prostředí už existuje v $DIAG — pokračujte, kde jste skončili."
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

mkdir -p "$DIAG"
vyrob_formular
spust_naslouchac

cat <<EOF

  Prostředí je připravené. Vaše síť je v pořádku — rozbité jsou cíle,
  na které se budete ptát.

    Formulář:  $FORMULAR

  Přepněte se do adresáře:

    cd ~/netlab/diagnostika

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/3-lin/02-diagnostika-site && ./check.sh --krok 1

EOF
