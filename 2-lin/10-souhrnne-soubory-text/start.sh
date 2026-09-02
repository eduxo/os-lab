#!/bin/bash
# 2/10 — Souhrnné ověřovací cvičení. Prostředí: žákova stanice.
# Postaví nepořádek, ze kterého má žák samostatně udělat pořádek.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

AUDIT="$HOME/netlab/audit"
ODPOVEDI="$AUDIT/odpovedi.txt"

if [ -d "$AUDIT" ]; then
  echo
  echo "  Prostředí už existuje v $AUDIT — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Rozbaluji archiv k auditu…"
mkdir -p "$AUDIT"/{prichozi,prichozi/skener,stare}

# Dokumenty. Rok je uvnitř, jméno o něm nic neříká — stejně jako ve cvičení
# o práci se soubory, jen jich je víc a leží ve třech adresářích.
POCET=15
# První tři doklady dostanou každý jiný rok. Bez té pojistky by mohl některý
# rok zůstat prázdný — a „0 2024" žádná roura nevypíše, takže by žák nemohl
# splnit úkol B, ať by dělal cokoli.
PRVNI_ROKY=($(lab_vyber 3 3 103))
for i in $(seq 1 "$POCET"); do
  if [ "$i" -le 3 ]; then
    ROK=$(( 2023 + ${PRVNI_ROKY[$((i-1))]} ))
  else
    ROK=$(( 2024 + ($(lab_vyber 3 1 $((100 + i))) - 1) ))
  fi
  case $(( i % 3 )) in
    0) D="prichozi" ;;
    1) D="prichozi/skener" ;;
    *) D="stare" ;;
  esac
  # Doklady mají různý počet řádků — jinak by kód vždycky vyšel na pátý řádek
  # a odpověď `kod-radek` by nenesla žádnou informaci.
  {
    printf 'Rok: %d\nTyp: protokol\n\nZáznam auditu %d.\n' "$ROK" "$i"
    for r in $(seq 1 $(( 1 + i % 4 ))); do
      printf 'Položka %d: bez připomínek.\n' "$r"
    done
  } > "$AUDIT/$D/$(printf 'doklad-%04d.txt' $(( 200 + i * 3 + ZAK )))"
done

# Jeden zřetelně velký soubor — hledá se podle velikosti.
{ for i in $(seq 1 6000); do printf 'radek %06d polozka skladu\n' "$i"; done; } \
  > "$AUDIT/stare/inventura-export.dat"

# Log se dvěma druhy chybových řádků.
POCET_CHYB=$(( 4 + $(lab_vyber 7 1 101) ))
{
  for i in $(seq 1 30); do printf '2026-08-%02d INFO  zaloha dokoncena\n' $(( i % 28 + 1 )); done
  for i in $(seq 1 "$POCET_CHYB"); do printf '2026-08-%02d ERROR zaloha selhala\n' $(( i % 28 + 1 )); done
} > "$AUDIT/zaloha.log"

# Auditní kód schovaný v jednom z dokladů.
CILE=($(find "$AUDIT" -name 'doklad-*.txt' | sort))
CIL="${CILE[$(( $(lab_vyber "${#CILE[@]}" 1 102) - 1 ))]}"
printf 'Auditní kód: %s\n' "$(lab_kod AUDIT 10)" >> "$CIL"

cat > "$ODPOVEDI" <<'FORMULAR'
# Odpovědi k auditu — vyplňte hodnoty za dvojtečku.
# cesty pište od tečky, tak jak je vypíše find
velky-soubor:
kod:
kod-soubor:
kod-radek:
FORMULAR

cat <<EOF

  Archiv je rozbalený.

    Archiv k auditu:  $AUDIT
    Formulář:         $ODPOVEDI

  Zadání je v cvičení na webu. Postup v něm není — ten je na vás.

    cd ~/netlab/audit

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/10-souhrnne-soubory-text && ./check.sh --krok 1

EOF
