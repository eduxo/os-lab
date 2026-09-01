#!/bin/bash
# 2/22 — Souborná práce 2. ročníku. Prostředí: žákova stanice.
# Postaví stanici v takovém stavu, v jakém ji junior přebírá po kolegovi:
# nepořádek v dokumentech, jeden dokument nečitelný, dva balíčky (jeden
# poškozený), stará záloha a JEDEN BĚŽÍCÍ PROCES po kolegovi.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PREV="$HOME/netlab/prevzeti"
DOK="$PREV/dokumenty"
INST="$PREV/instalace"
PROTOKOL="$PREV/protokol.txt"
TIKET="$PREV/tiket.txt"

# ── losované parametry ────────────────────────────────────────────
JMENA=(mvesela rkolar jsedlak bnovotny lkrizova pmoravec)
CELE=("Marie Veselá" "Radek Kolář" "Jan Sedlák" "Bohumil Novotný" "Lenka Křížová" "Petr Moravec")
IDX=$(lab_vyber 6 1 221)
UZIVATEL="${JMENA[IDX-1]}"
CELE_JMENO="${CELE[IDX-1]}"
MESIC=$(( 1 + ZAK % 6 ))
DATUM_CZ="$(printf '15. %d. 2027' "$MESIC")"
VADNY=$(lab_vyber 2 1 222)          # který ze dvou balíčků je poškozený
KOD_SMLOUVY="$(lab_kod SML 22)"
USEKY=(prijem vydej reklamace inventura)
SBER="sber-${USEKY[$(( $(lab_vyber 4 1 223) - 1 ))]}.sh"
NECITELNY=$(lab_vyber 5 1 224)      # který dodací list nejde přečíst
LIST="dodaci-list-$(printf '%02d' "$NECITELNY").txt"

# Obsah dodacího listu — musí být na jednom místě, kontrola podle něj pozná,
# že žák nečitelný soubor opravdu opravil a nepodstrčil místo něj nový.
obsah_listu() {  # obsah_listu N
  printf 'Dodací list %02d\nOddělení: sklad\nPoložek: %d\n' "$1" $(( 3 + (ZAK + $1) % 9 ))
}

vyrob_tiket() {
  cat > "$TIKET" <<TIKET_KONEC
Tiket NET-2026-0231 · priorita: vysoká · dopad: celá firma
Hlásí: Ing. Eva Krátká, vedení · Přijato: 18. 12. 2026 7:55

Kolega, který spravoval stanici skladu, u nás skončil. Přebíráte ji po něm.
Do konce dne potřebuji, aby byla předaná — tedy:

1. Zakládá se nové oddělení EXPEDICE. Zřiďte skupinu a v ní účet — jméno
   a příjmení: $CELE_JMENO, přihlašovací jméno: $UZIVATEL. Je to zástup
   na dobu určitou: posledním dnem, kdy se smí přihlásit, je $DATUM_CZ.
2. Expedice potřebuje adresář, kde budou lidé pracovat společně, a k němu
   odkládací prostor.
3. Kolega stáhl dva instalační balíčky a nikde není napsané, jestli je
   ověřil. Ověřte je a s poškozeným naložte tak, aby nešel omylem
   nainstalovat, ale zůstal k dispozici pro reklamaci u dodavatele.
4. Jeden z dodacích listů se mi nedaří otevřít. Zjistěte proč a spravte to.
5. Dokumenty, které po sobě kolega nechal, zazálohujte. A ze staré zálohy
   mi vytáhněte smlouvu s číslem $KOD_SMLOUVY — jenom ji, nic jiného.
6. Na stanici pořád něco běží. Zjistěte co, uveďte to do protokolu
   a ukončete to.

Do předávacího protokolu zapište, co jste zjistili.
TIKET_KONEC
}

vyrob_protokol() {
  cat > "$PROTOKOL" <<'PROTOKOL_KONEC'
# Předávací protokol — vyplňte hodnoty za dvojtečku.
# uzivatel          = přihlašovací jméno účtu, který jste založili
# balicek-vadny     = jméno poškozeného balíčku (i s příponou)
# otisk-skutecny    = skutečný otisk poškozeného balíčku, prvních 12 znaků
# necitelny-soubor  = jméno dokumentu, který nešel přečíst
# obnoveny-soubor   = jméno smlouvy, kterou jste obnovili ze staré zálohy
# proces-pid        = PID procesu, který na stanici běžel po kolegovi
# proces-jmeno      = jméno souboru toho procesu (i s příponou)
uzivatel:
balicek-vadny:
otisk-skutecny:
necitelny-soubor:
obnoveny-soubor:
proces-pid:
proces-jmeno:
PROTOKOL_KONEC
}

spust_sber() {
  # Kolegův proces. Píše do logu i s PID, aby šlo doložit, že žák našel
  # opravdu ten běžící, a ne že si číslo vymyslel.
  pgrep -f "bash .*$SBER" >/dev/null 2>&1 && return   # už běží, druhý nechceme
  if [ ! -f "$PREV/$SBER" ]; then
    cat > "$PREV/$SBER" <<SBER_KONEC
#!/bin/bash
# Sběr dat z terminálů — spuštěno ručně, nikdy neukončeno.
LOG="\$HOME/netlab/prevzeti/sber.log"
while true; do
  printf '%s PID=%d sber probiha\n' "\$(date +%H:%M:%S)" "\$\$" >> "\$LOG"
  sleep 4
done
SBER_KONEC
    chmod +x "$PREV/$SBER"
  fi
  # setsid odpojí proces od terminálu, takže přežije zavření okna — přesně
  # jako kolegův proces, který na stanici zůstal. Kde setsid není, stačí
  # nohup. Podmínka musí testovat dostupnost: uvozený `&` vrací nulu vždycky,
  # takže by se záložní větev nikdy nespustila.
  if command -v setsid >/dev/null; then
    ( cd "$PREV" && setsid nohup "./$SBER" >/dev/null 2>&1 & )
  else
    ( cd "$PREV" && nohup "./$SBER" >/dev/null 2>&1 & )
  fi
}

# ── prostředí už stojí: jen doplnit, co nenese žákovu práci ───────
# Testuje se -s, ne -f: žák si soubor umí vyprázdnit přesměrováním `>`,
# a kontrola se ptá na neprázdný. Nulabajtový soubor by jinak propadl mezi
# oběma skripty a žák by se z té smyčky nedostal jinak než resetem.
if [ -d "$PREV" ]; then
  DOPLNENO=""
  [ -s "$TIKET" ]     || { vyrob_tiket;     DOPLNENO="$DOPLNENO tiket.txt"; }
  [ -s "$PROTOKOL" ]  || { vyrob_protokol;  DOPLNENO="$DOPLNENO protokol.txt"; }
  # Kolegův proces nepřežije restart stanice a cvičení je na dva bloky.
  # Dokud žák nemá PID v protokolu, potřebuje ho — vrátíme mu ho. Mlčky:
  # že proces něčím zase běží, není součást zadání.
  if ! grep -qE '^[[:space:]]*proces-pid[[:space:]]*:[[:space:]]*[0-9]' "$PROTOKOL" 2>/dev/null; then
    spust_sber
  fi
  echo
  if [ -n "$DOPLNENO" ]; then
    echo "  Prostředí už existuje v $PREV."
    echo "  Chybělo tohle, doplnila jsem to:$DOPLNENO"
  else
    echo "  Prostředí už existuje v $PREV — pokračujte, kde jste skončili."
  fi
  echo "  Chcete začít úplně znovu?  ./reset.sh"
  echo
  exit 0
fi

echo "  Přebírám stanici po kolegovi…"
mkdir -p "$DOK" "$INST"

# ── dokumenty po kolegovi ─────────────────────────────────────────
for i in 1 2 3 4 5; do
  obsah_listu "$i" > "$DOK/dodaci-list-$(printf '%02d' "$i").txt"
done
printf 'Poznámky k předání\n------------------\nStanici jsem spravoval od jara.\nHesla jsou u vedení.\n' \
  > "$DOK/poznamky.txt"

# Jeden dodací list kolega omylem znepřístupnil. Žák to musí najít, protože
# jinak neprojde ani záloha — tar ten soubor nepřečte.
chmod 000 "$DOK/$LIST"

# ── dva balíčky a jejich otisky; jeden je poškozený ───────────────
for i in 1 2; do
  BAL="$INST/balicek-skladnik-1.$i.tar.gz"
  TMP="$(mktemp -d)" || { echo "  Nepodařilo se vyrobit dočasný adresář."; exit 1; }
  mkdir -p "$TMP/skladnik"
  printf 'Skladník %s — instalační balíček.\nSestavení: %d\n' "1.$i" $(( 400 + ZAK )) \
    > "$TMP/skladnik/README"
  printf '#!/bin/sh\necho "instaluji skladnik 1.%d"\n' "$i" > "$TMP/skladnik/instalace.sh"
  tar -czf "$BAL" -C "$TMP" skladnik
  rm -rf "$TMP"
  # Otisk se počítá z NEPOŠKOZENÉHO souboru — tak, jak ho vydal dodavatel.
  printf '%s  %s\n' "$(_hash < "$BAL")" "$(basename "$BAL")" > "$BAL.sha256"
  # A teď se jeden z nich cestou poškodí. Otisk od dodavatele zůstává.
  if [ "$i" -eq "$VADNY" ]; then
    printf 'poskozeno pri prenosu' >> "$BAL"
  fi
done

# ── stará záloha po kolegovi ──────────────────────────────────────
TMP="$(mktemp -d)" || { echo "  Nepodařilo se vyrobit dočasný adresář."; exit 1; }
mkdir -p "$TMP/smlouvy"
for k in "$(lab_kod SML 22)" "$(lab_kod SML 32)" "$(lab_kod SML 42)"; do
  printf 'Smlouva %s\nDodavatel: NetLab s.r.o.\nPlatnost: do 31. 12. 2027\n' "$k" \
    > "$TMP/smlouvy/smlouva-$k.txt"
done
printf 'Zápis z inventury 2026.\nRozdíly: žádné.\n' > "$TMP/smlouvy/inventura-2026.txt"
tar -czf "$PREV/zaloha-2026-06-30.tar.gz" -C "$TMP" smlouvy
rm -rf "$TMP"

vyrob_tiket
vyrob_protokol
spust_sber

cat <<EOF

  Stanice je připravená k převzetí.

    Tiket:      $TIKET
    Protokol:   $PROTOKOL
    Převzato:   $PREV

  Přečtěte si tiket a přepněte se do adresáře:

    cat ~/netlab/prevzeti/tiket.txt
    cd ~/netlab/prevzeti

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/22-souborna-prace && ./check.sh --krok 1

EOF
