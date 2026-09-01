#!/bin/bash
# 2/20 — Zálohování a obnova. Prostředí: žákova stanice.
# Vyrobí tři zálohy z různých dnů a aktuální data, ze kterých jedna položka
# zmizela. Kterou zálohu žák potřebuje, se losuje z čísla žáka.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

ZAL="$HOME/netlab/zalohy"
DATA="$ZAL/data"
FORMULAR="$ZAL/obnova.txt"
TIKET="$ZAL/tiket.txt"
OTISKY="$ZAL/.otisky-zaloh"

# Hledaná položka má vlastní předponu SFP-, aby se její čtyřmístné číslo
# nemohlo trefit do pevných kódů ceníku (SKU-10xx).
KOD="$(lab_kod SFP 20)"                 # hledaná položka, u každého žáka jiná
CENA=$(( 1200 + ZAK * 13 ))
KTERA=$(lab_vyber 3 1 220)              # ve které záloze ta položka je
DNY=(2026-12-05 2026-12-08 2026-12-11)

vyrob_tiket() {
  cat > "$TIKET" <<TIKET_KONEC
Tiket NET-2026-0198 · priorita: střední · dopad: jedno oddělení
Hlásí: Pavel Marek, sklad · Přijato: 11. 12. 2026 14:05

Z ceníku zmizela položka $KOD (Redukce SFP na RJ45). Byla tam jen krátce —
přidali jsme ji a při další úpravě ceníku ji někdo omylem smazal. Potřebuji
ji zpátky i s cenou, ale zbytek ceníku se od té doby změnil, takže starý
ceník nasadit nemůžeme.
TIKET_KONEC
}

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Obnova ze zálohy — vyplňte hodnoty za dvojtečku.
# zaloha = jméno souboru zálohy, ve které jste položku našli
# cena   = cena položky podle té zálohy (jen číslo)
# radku  = kolik řádků má ceník v té záloze (jen číslo)
zaloha:
cena:
radku:
FORMULAR_KONEC
}

# Prostředí, které už stojí, se nepřestavuje — jen se doplní to, co nenese
# žákovu práci a co si mohl omylem smazat. Bez toho posílá kontrola žáka
# na ./start.sh, který mu odpoví „už existuje", a ten se z toho nedostane.
if [ -d "$ZAL" ]; then
  DOPLNENO=""
  [ -f "$TIKET" ]    || { vyrob_tiket;    DOPLNENO="$DOPLNENO tiket.txt"; }
  [ -f "$FORMULAR" ] || { vyrob_formular; DOPLNENO="$DOPLNENO obnova.txt"; }
  echo
  if [ -n "$DOPLNENO" ]; then
    echo "  Prostředí už existuje v $ZAL."
    echo "  Chybělo tohle, doplnila jsem to:$DOPLNENO"
  else
    echo "  Prostředí už existuje v $ZAL — pokračujte, kde jste skončili."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

# Ceník k dané verzi. Verze 1–3 jsou zálohy, verze 4 je dnešní stav.
# Sortiment postupně roste — proto se liší i počty řádků.
vypis_cenik() {  # vypis_cenik VERZE
  local v="$1"
  printf '# Ceník NetLab s.r.o. — sklad kabeláže\n'
  printf 'SKU-1001;Patch kabel UTP 1 m;39\n'
  printf 'SKU-1002;Patch kabel UTP 3 m;59\n'
  printf 'SKU-1003;Krabice pod zásuvku;25\n'
  printf 'SKU-1004;Zásuvka RJ45 cat6;145\n'
  printf 'SKU-1005;Lišta 40x20, 2 m;89\n'
  printf 'SKU-1006;Stahovací pásky, 100 ks;35\n'
  if [ "$v" -ge 2 ]; then
    printf 'SKU-1007;Konektor RJ45, balení 50 ks;210\n'
    printf 'SKU-1008;Kleště krimpovací;690\n'
  fi
  if [ "$v" -ge 3 ]; then
    printf 'SKU-1009;Tester kabeláže;1290\n'
  fi
  # Položka, kterou tiket hledá. Je jen v jedné ze tří záloh — v dnešním
  # stavu (verze 4) chybí, protože ji někdo při úpravě smazal.
  if [ "$v" -eq "$KTERA" ]; then
    printf '%s;Redukce SFP na RJ45;%d\n' "$KOD" "$CENA"
  fi
  # Dvě položky přidané dnes. V žádné záloze nejsou — kontrola podle nich
  # pozná, že žák nepřetáhl přes dnešní ceník celou starou zálohu. Jsou dvě
  # proto, aby se počet řádků dnešního ceníku nerovnal žádné ze záloh;
  # jinak by šlo `radku` uhodnout, aniž by žák archiv otevřel.
  if [ "$v" -eq 4 ]; then
    printf 'SKU-1010;Switch 8 portů 1G;2490\n'
    printf 'SKU-1011;Napájecí adaptér 12 V;340\n'
  fi
}

echo "  Připravuji data a zálohy…"
mkdir -p "$DATA"

# ── tři zálohy z různých dnů ──────────────────────────────────────
for i in 1 2 3; do
  TMP="$(mktemp -d)" || { echo "  Nepodařilo se vyrobit dočasný adresář."; exit 1; }
  mkdir -p "$TMP/data"
  vypis_cenik "$i" > "$TMP/data/cenik.txt"
  printf 'Poznámky skladu k %s.\nInventura proběhla bez závad.\n' "${DNY[i-1]}" \
    > "$TMP/data/poznamky.txt"
  tar -czf "$ZAL/zaloha-${DNY[i-1]}.tar.gz" -C "$TMP" data
  rm -rf "$TMP"
done

# ── dnešní stav: položka z tiketu v něm chybí ────────────────────
vypis_cenik 4 > "$DATA/cenik.txt"
printf 'Poznámky skladu k dnešnímu dni.\nČeká se na doplnění ceníku.\n' \
  > "$DATA/poznamky.txt"

# Otisky záloh. Kontrola podle nich pozná, že žák zálohu přepsal — na
# vlastní zálohy se totiž při obnově nesahá. Který archiv je ten hledaný,
# se z otisků poznat nedá.
: > "$OTISKY"
for z in "$ZAL"/zaloha-*.tar.gz; do
  printf '%s  %s\n' "$(_hash < "$z")" "$(basename "$z")" >> "$OTISKY"
done

vyrob_tiket
vyrob_formular

cat <<EOF

  Prostředí je připravené.

    Tiket:        $TIKET
    Dnešní data:  $DATA
    Zálohy:       $ZAL/zaloha-*.tar.gz
    Formulář:     $FORMULAR

  Přečtěte si tiket a přepněte se do adresáře:

    cat ~/netlab/zalohy/tiket.txt
    cd ~/netlab/zalohy

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/20-zalohovani && ./check.sh --krok 1

EOF
