#!/bin/bash
# 2/14 — Uživatelská podpora: GLPI. Prostředí: žákova stanice + kontejner GLPI.
# Jediné cvičení 2. ročníku, které potřebuje kontejner. Nestaví ho — očekává
# ho hotový v šabloně VM. Stavět v hodině zásobník LAMP nemá smysl.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

PODPORA="$HOME/netlab/podpora"
ODPOVEDI="$PODPORA/tikety.txt"
KONTEJNER="glpi"

# ── kontejner musí být připravený ─────────────────────────────────
if ! command -v lxc >/dev/null 2>&1; then
  cat <<'EOF'

  Na téhle stanici není LXD, takže kontejner s GLPI nejde spustit.
  Řekněte o tom vyučujícímu — patří do obrazu VM.

EOF
  exit 1
fi

STAV="$(lxc list "^$KONTEJNER\$" -c s --format csv 2>/dev/null | head -1)"
if [ -z "$STAV" ]; then
  cat <<'EOF'

  Kontejner s GLPI na téhle stanici není.

  Nestaví se v hodině — má být hotový v obrazu VM, protože instalace
  webového a databázového serveru zabere víc času než celé cvičení.

  Řekněte o tom vyučujícímu.

EOF
  exit 1
fi

if [ "$STAV" != "RUNNING" ]; then
  echo "  Spouštím kontejner s GLPI…"
  lxc start "$KONTEJNER" >/dev/null 2>&1
  for i in $(seq 1 30); do
    sleep 1
    lxc list "^$KONTEJNER\$" -c 4 --format csv 2>/dev/null | grep -q '[0-9]' && break
  done
fi

IP="$(lxc list "^$KONTEJNER\$" -c 4 --format csv 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){3}' | head -1)"
if [ -z "$IP" ]; then
  echo "  Kontejner běží, ale nedostal adresu. Zkuste to za chvíli znovu,"
  echo "  nebo o tom řekněte vyučujícímu."
  exit 1
fi

# ── situace k posouzení ───────────────────────────────────────────
# Čtyři z osmi, u každého žáka jiné. Odpovědi se nikam neukládají: hodnotí
# se, jestli si žák sám se sebou neodporuje (viz check.sh), ne jestli trefil
# můj názor na dopad.
SITUACE=(
"Účetní hlásí, že jí nejde vytisknout fakturu. Tiskárna ve druhém patře nereaguje, ostatní na patře tisknou normálně."
"Nefunguje internet v celé budově. Nikdo se nedostane ke sdíleným dokumentům ani k e-mailu."
"Kolegovi ze skladu se špatně zobrazuje ikona na ploše. Program funguje, jen ikona je bílá."
"Obchodnímu zástupci nejde přihlášení do systému objednávek. Za dvě hodiny jede k zákazníkovi a potřebuje si vytisknout nabídku."
"Server, na kterém běží docházkový systém, má zaplněný disk na 92 %. Systém zatím funguje."
"Vedoucí skladu hlásí, že mu čtečka čárových kódů občas přeskočí znak. Inventura je za tři týdny."
"Personální oddělení nemůže otevřít sdílenou složku se smlouvami. Jsou tam tři lidé a všichni na ní dnes potřebují pracovat."
"Jednomu z brigádníků nejde přehrát video na firemním intranetu. Je to školicí video, které má zhlédnout do konce měsíce."
)

if [ -f "$ODPOVEDI" ]; then
  echo
  echo "  Prostředí už existuje — pokračujte, kde jste skončili."
  echo "  GLPI běží na adrese:  http://$IP/"
  echo
  exit 0
fi

mkdir -p "$PODPORA"
{
  echo "# Posouzení situací — vyplňte hodnoty za dvojtečku."
  echo "#"
  echo "# dopad      = vysoky | stredni | nizky      (kolika lidí se to týká)"
  echo "# nalehavost = vysoka | stredni | nizka      (jak moc to spěchá)"
  echo "# priorita   = odvodíte z tabulky v zadání"
  echo "#"
  echo "# tiket = číslo tiketu, který jste v GLPI založili a uzavřeli"
  echo
  I=1
  for N in $(lab_vyber 8 4 145); do
    printf '# Situace %d: %s\n' "$I" "${SITUACE[$((N-1))]}"
    printf 'situace-%d-dopad:\n' "$I"
    printf 'situace-%d-nalehavost:\n' "$I"
    printf 'situace-%d-priorita:\n\n' "$I"
    I=$((I+1))
  done
  echo "tiket:"
} > "$ODPOVEDI"

cat <<EOF

  Prostředí je připravené.

    GLPI běží na adrese:  http://$IP/
    Formulář:             $ODPOVEDI

  Přihlašovací údaje do GLPI dostanete od vyučujícího.
  Situace k posouzení jsou přímo ve formuláři — máte čtyři z osmi.

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/14-uzivatelska-podpora && ./check.sh --krok 1

EOF
