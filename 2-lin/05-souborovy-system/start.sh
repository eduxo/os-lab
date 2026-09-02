#!/bin/bash
# 2/05 — Souborový systém a cesty. Prostředí: žákova stanice (bez kontejneru).
# Postaví větvený adresář, ve kterém je jeden hledaný soubor. Hloubka i názvy
# větví se odvozují z čísla žáka, takže cesta je u každého jiná.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

CESTY="$HOME/netlab/cesty"
MAPA="$CESTY/mapa.txt"
NALEZ="$CESTY/nalez.txt"

if [ -d "$CESTY" ]; then
  echo
  echo "  Prostředí už existuje v $CESTY — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Připravuji adresářovou strukturu firmy…"
mkdir -p "$CESTY"

VETEV1=(smlouvy zakazky dodavatele projekty)
VETEV2=(2024 2025 2026 archiv)
VETEV3=(podklady prehledy vystupy protokoly)
# Každá úroveň má vlastní sůl. Se zbytky po 4 a po 16 se větev opakovala
# s periodou 16 — žáci 1, 17 a 33 měli tutéž cestu (ověřeno). Tři úrovně
# místo dvou proto, že 4×4 = 16 možností na 40 žáků prostě nestačí.
V1="${VETEV1[$(( $(lab_vyber 4 1 11) - 1 ))]}"
V2="${VETEV2[$(( $(lab_vyber 4 1 12) - 1 ))]}"
V3="${VETEV3[$(( $(lab_vyber 4 1 13) - 1 ))]}"

# Výchozí bod hledání je pro všechny stejný, cíl ne. Relativní cesta mezi
# nimi je tedy odpověď, kterou nelze opsat od souseda.
mkdir -p "$CESTY/sklad/2025/faktury" "$CESTY/sklad/2026"
mkdir -p "$CESTY/ucetni/mzdy" "$CESTY/ucetni/dane"
for v in "${VETEV1[@]}"; do mkdir -p "$CESTY/provoz/$v"; done
mkdir -p "$CESTY/provoz/$V1/$V2/$V3"

printf 'Faktura 01/2025\n' > "$CESTY/sklad/2025/faktury/f-01.txt"
printf 'Faktura 02/2025\n' > "$CESTY/sklad/2025/faktury/f-02.txt"
printf 'Mzdy za srpen.\n'  > "$CESTY/ucetni/mzdy/08-2026.txt"
printf 'Přiznání k DPH.\n' > "$CESTY/ucetni/dane/dph.txt"
printf 'Poznámky provozu.\n' > "$CESTY/provoz/poznamky.txt"

cat > "$CESTY/provoz/$V1/$V2/$V3/inventura.txt" <<INVENTURA
Inventura provozního skladu

Regál A: 14 položek
Regál B: 9 položek

Kód inventury: $(lab_kod INV 5)
INVENTURA

cat > "$MAPA" <<'FORMULAR'
# Mapa souborového systému — vyplňte hodnoty za dvojtečku.
# Do prvních šesti řádků patří cesta k adresáři, který má daný účel.
konfigurace:
logy:
domovske:
docasne:
programy:
zarizeni:
# Dva řádky o této konkrétní stanici:
bin-odkaz:
ls-cesta:
FORMULAR

cat > "$NALEZ" <<'FORMULAR'
# Nalezený soubor — vyplňte hodnoty za dvojtečku.
# absolutni = celá cesta od kořene až po jméno souboru
# relativni = cesta k témuž souboru z adresáře ~/netlab/cesty/sklad/2025/faktury
# kod       = kód inventury zapsaný v nalezeném souboru
absolutni:
relativni:
kod:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Struktura firmy:   $CESTY
    Formuláře:         mapa.txt  a  nalez.txt

  Začněte tím, že se do adresáře přepnete:

    cd ~/netlab/cesty

  Průběžnou kontrolu spouštějte odsud, ne z ~/netlab/cesty:

    cd ~/os-lab/2/05-souborovy-system && ./check.sh --krok 1

EOF
