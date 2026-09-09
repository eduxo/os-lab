#!/bin/bash
# 3/20 — Bash: konsolidace a rozbor cizího skriptu. Server data-XX přes SSH.
#
# Plán počítal s tím, že si žák nechá skript napsat od jazykového modelu.
# To se nedá ověřit ani zaručit (ne každý má v hodině přístup), takže
# „skript od AI" dodá prostředí — se třemi vadami, které modely dělají
# nejčastěji. Učivo je totéž: číst cizí kód a nevěřit mu.
#
# Vady:
#   1. `for f in $(ls $ZDROJ)` — rozpadne se na jménech s mezerou
#   2. chybí `set -euo pipefail` — skript pokračuje po chybě
#   3. `rm -rf "$ARCHIV/$1/"*` bez ověření argumentu — prázdný $1 smaže archiv
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="data-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

BASH_DIR="$HOME/netlab/bash"
PROTOKOL="$BASH_DIR/protokol.txt"
SKRIPT=/usr/local/bin/uklid.sh
ZDROJ=/srv/podatelna
ARCHIV=/srv/archiv

vyrob_protokol() {
  mkdir -p "$BASH_DIR"
  cat > "$PROTOKOL" <<'PROTOKOL_KONEC'
# Protokol o rozboru — vyplňte hodnoty za dvojtečku.
# Protokol je na STANICI, práce je na serveru.
#
# Ke každé vadě napište vlastními slovy, CO je špatně a CO SE STANE,
# když se to nechá být (aspoň pět slov).
#
# nastroj = jméno nástroje, kterým jste si skript nechali zkontrolovat
vada-1:
vada-2:
vada-3:
nastroj:
PROTOKOL_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

# ── data, na kterých se vady projeví ──────────────────────────────
# Jméno s mezerou je tu schválně: bez něj by se první vada neprojevila
# a žák by uvěřil, že skript funguje.
# Doplňuje se PO SOUBORECH, ne podle existence adresáře. Žák si podatelnu
# skoro jistě jednou vysype — právě proto, že neopravený skript maže —
# a podklady nejsou jeho práce, takže je start.sh musí umět vrátit.
# Adresář by po prvním pokusu existoval prázdný a žák by neměl cestu zpět
# než reset.sh, který smaže i cvičení 19.
lxc exec "$SERVER_KONT" -- bash -c "
  mkdir -p '$ZDROJ' '$ARCHIV'
  [ -e '$ZDROJ/objednavka-001.txt' ] || printf 'objednavka\n'  > '$ZDROJ/objednavka-001.txt'
  [ -e '$ZDROJ/faktura 2026-11.txt' ] || printf 'faktura\n'    > '$ZDROJ/faktura 2026-11.txt'
  [ -e '$ZDROJ/dodaci list.txt' ] || printf 'dodaci list\n'    > '$ZDROJ/dodaci list.txt'
  [ -e '$ZDROJ/reklamace-042.txt' ] || printf 'reklamace\n'    > '$ZDROJ/reklamace-042.txt'
  chown -R $SERVER_UCET:$SERVER_UCET '$ZDROJ' '$ARCHIV'
" >/dev/null 2>&1

# ── skript „od AI" ────────────────────────────────────────────────
# Doplní se jen tehdy, když ještě není — jinak by druhé spuštění smazalo
# žákovy opravy.
if ! lxc exec "$SERVER_KONT" -- test -f "$SKRIPT"; then
  lxc exec "$SERVER_KONT" -- tee "$SKRIPT" >/dev/null <<'UKLID'
#!/bin/bash
# Uklid podatelny — presune dokumenty do archivu podle mesice.
#
# Pouziti:  uklid.sh <mesic>       napriklad:  uklid.sh 2026-11
#
# Tenhle skript napsal jazykovy model. Vypada rozumne a na prvni pohled
# funguje. Nez ho pustite na ostra data, prectete si ho.

ZDROJ=/srv/podatelna
ARCHIV=/srv/archiv
MESIC=$1

echo "Uklizim podatelnu do archivu $ARCHIV/$MESIC"
mkdir -p $ARCHIV/$MESIC

# Vycisteni cile, aby v nem nezustaly zbytky z minuleho behu
rm -rf "$ARCHIV/$MESIC/"*

# Presun dokumentu
for f in $(ls $ZDROJ); do
    echo "  presouvam $f"
    mv $ZDROJ/$f $ARCHIV/$MESIC/
done

echo "Hotovo."
UKLID
  lxc exec "$SERVER_KONT" -- bash -c "chmod 755 '$SKRIPT'; chown root:root '$SKRIPT'" >/dev/null 2>&1
fi

# Statická analýza je jedna pětina cvičení, ne jeho podmínka. Kdyby se
# `|| exit 1`, zůstal by žák bez skriptu k rozboru a nemohl by dělat ani
# kroky, které nástroj nepotřebují. Balík je navíc velký a třicet
# kontejnerů naráz přes síťový disk je riziko, na které karty upozorňují.
SHELLCHECK_OK=1
doinstaluj shellcheck:shellcheck || SHELLCHECK_OK=0

[ -s "$PROTOKOL" ] || vyrob_protokol

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI

    Skript k rozboru: $SKRIPT
    Podatelna:        $ZDROJ
    Archiv:           $ARCHIV
    Protokol:         $PROTOKOL   (na stanici)

  Ve skriptu jsou TŘI vady. Statická kontrola kódu vám některé ukáže
  sama — ale ne všechny. Opravte je tak, aby skript dál dělal svou práci.

$( [ "$SHELLCHECK_OK" -eq 0 ] && printf '  POZOR: statickou analýzu se nepodařilo doinstalovat. Kroky 1, 3, 4 a 5\n  dělat můžete, Krok 2 ne — řekněte o tom vyučujícímu.\n' )
  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/20-bash-konsolidace && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
