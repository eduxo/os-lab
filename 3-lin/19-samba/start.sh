#!/bin/bash
# 3/19 — Samba / file server. Prostředí: server data-XX přes SSH.
#
# Heslo pro Sambu je TOTOŽNÉ s heslem účtu, které losuje server-lib.sh
# na stanici. Do repozitáře se tím nedostane heslo ani vzorec — a žák
# nemusí vymýšlet vlastní, které by pak kontrola nemohla znát.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="data-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

SDILENI="$HOME/netlab/sdileni"
FORMULAR="$SDILENI/formular.txt"

# ── co se losuje ──────────────────────────────────────────────────
ODDELENI=(ucetni sklad technici)
ODD="${ODDELENI[$(( $(lab_vyber 3 1 901) - 1 ))]}"
SDILENA_CESTA="/srv/sdileni/$ODD"
SKUPINA="$ODD"
KOD_KLIC="user.lab319-kod"
SOUBOR_KLIC="user.lab319-soubor"

vyrob_formular() {
  mkdir -p "$SDILENI"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# Obojí najdete ve sdílení. Na serveru je nehledejte — smyslem cvičení
# je dostat se k nim přes sdílení, ne přes sudo.
#
# kod          = kód ze souboru dokumenty.txt
# druhy-soubor = celé jméno toho druhého souboru, který ve sdílení leží
kod:
druhy-soubor:
FORM_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

doinstaluj samba:smbd || exit 1

# ── podklady ve sdíleném adresáři ─────────────────────────────────
# Kód vzniká náhodně a leží jen na serveru; žák se k němu dostane teprve
# tehdy, když sdílení opravdu rozchodí a připojí se do něj ze stanice.
KOD="$(lxc config get "$SERVER_KONT" "$KOD_KLIC" 2>/dev/null | tr -d '\r')"
if [ -z "$KOD" ]; then
  KOD="DOK-$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c5)"
  if ! lxc config set "$SERVER_KONT" "$KOD_KLIC" "$KOD" 2>/dev/null; then
    echo "  Kód se nepodařilo uložit — zavolejte vyučujícího." >&2
    exit 1
  fi
fi

# Druhý soubor má losované jméno. Je to druhá kotva: přečíst ho jde
# jedině přes fungující sdílení, na serveru ho žák hledat nemá proč.
DRUHY="$(lxc config get "$SERVER_KONT" "$SOUBOR_KLIC" 2>/dev/null | tr -d '\r')"
if [ -z "$DRUHY" ]; then
  DRUHY="smlouva-2026-$(LC_ALL=C tr -dc '0-9' </dev/urandom | head -c4).txt"
  if ! lxc config set "$SERVER_KONT" "$SOUBOR_KLIC" "$DRUHY" 2>/dev/null; then
    echo "  Podklady se nepodařilo uložit — zavolejte vyučujícího." >&2
    exit 1
  fi
fi

# Adresář a soubory se doplňují, i když už existují — je to podklad, ne
# žákova práce. Práva a vlastnictví ale nastavuje žák, tak na ně nesaháme.
lxc exec "$SERVER_KONT" -- bash -c "
  mkdir -p '$SDILENA_CESTA'
  [ -s '$SDILENA_CESTA/dokumenty.txt' ] || \
    printf 'Interni dokument oddeleni %s\nKod: %s\n' '$ODD' '$KOD' \
      > '$SDILENA_CESTA/dokumenty.txt'
  [ -e '$SDILENA_CESTA/$DRUHY' ] || \
    printf 'Smlouva oddeleni %s.\n' '$ODD' > '$SDILENA_CESTA/$DRUHY'
" >/dev/null 2>&1

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
    Adresa:     $SERVER_IP   (budete ji potřebovat pro smbclient ze stanice)

    Sdílený adresář: $SDILENA_CESTA
    Jméno sdílení:   $ODD
    Skupina:         $SKUPINA
    Formulář:        $FORMULAR   (na stanici)

  Heslo pro Sambu použijte toto:

    $SERVER_HESLO

  Je to totéž heslo, které má účet $SERVER_UCET. Samba si vede vlastní
  databázi hesel — na to, že už účet na serveru existuje, se neptá.

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/19-samba && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
