#!/bin/bash
# 3/18 — „Web nejede". Prostředí: server web-XX přes SSH.
#
# Staví VLASTNÍ funkční web (objednavky.netlab.test) a zavede do něj JEDNU
# závadu z pěti vrstev. Vlastní proto, že nezávislost labů je pravidlo:
# žák, který šestnáctku ani sedmnáctku nedělal, musí mít co opravovat.
# A zároveň se tím nesahá na to, co si postavil sám.
#
# Vrstvy jsou schválně takové, že se PROJEVUJÍ RŮZNĚ:
#   L1 jméno         → odpoví výchozí web (200, ale cizí obsah)
#   L2 síť           → spojení vyprší
#   L3 služba        → spojení odmítnuto
#   L4 konfigurace   → odpoví výchozí web (jako L1, ale jiná příčina)
#   L5 obsah a práva → 403 nebo 404
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="web-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/../../lib/web-lib.sh"

WEB="$HOME/netlab/web"
PROTOKOL="$WEB/protokol-18.txt"
JMENO="objednavky.netlab.test"
ROOT="/var/www/objednavky"
SITE=objednavky
ZAVEDENO_KLIC="$WEB_VRSTVA_KLIC"

vyrob_protokol() {
  mkdir -p "$WEB"
  cat > "$PROTOKOL" <<'PROTOKOL_KONEC'
# Protokol o diagnostice — vyplňte hodnoty za dvojtečku.
# Protokol je na STANICI, práce je na serveru.
#
# Ke KAŽDÉ vrstvě napište, čím jste ji ověřili a s jakým výsledkem
# (aspoň čtyři slova) — i u těch, kde bylo všechno v pořádku. O tom
# je celé tohle cvičení: vyloučit vrstvu je stejná práce jako najít
# závadu.
#
# Do `zavada` napište ČÍSLO vrstvy (1 až 5), ve které závada byla,
# a za mezeru vlastními slovy, co konkrétně bylo špatně.
#
# Do `dukaz` opište číslo evidence, které je vidět na opravené stránce.
# Dokud web nefunguje, nemáte ho odkud vzít.
vrstva-1-jmeno:
vrstva-2-sit:
vrstva-3-sluzba:
vrstva-4-konfigurace:
vrstva-5-obsah:
zavada:
dukaz:
PROTOKOL_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

postav_apache || exit 1
doinstaluj ufw:ufw || exit 1
zaridi_kod || exit 1

ZAVEDENO="$(lxc config get "$SERVER_KONT" "$ZAVEDENO_KLIC" 2>/dev/null | tr -d '\r')"

if [ -z "$ZAVEDENO" ]; then
  # ── zdravý web ────────────────────────────────────────────────
  # Vlastní značka, ne sdílený kód pobočky: ten má i žákův web ze cvičení 16
  # a kontrola by pak uznala jeho stránku místo téhle.
  MARKER="OBJ-$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c5)"
  lxc exec "$SERVER_KONT" -- bash -c "
    mkdir -p $ROOT
    printf '<!doctype html><meta charset=\"utf-8\"><title>Objednavky</title>\n<h1>Objednavky NetLab</h1>\n<p>Cislo evidence: %s</p>\n' '$MARKER' > $ROOT/index.html
    chmod 755 $ROOT; chmod 644 $ROOT/index.html
  " >/dev/null 2>&1

  lxc exec "$SERVER_KONT" -- tee /etc/apache2/sites-available/$SITE.conf >/dev/null <<VHOST
<VirtualHost *:80>
    ServerName $JMENO
    DocumentRoot $ROOT
</VirtualHost>
VHOST

  # Firewall je součástí zdravého stavu — bez něj by druhá vrstva nebyla
  # kde. Port 22 se povoluje PŘED zapnutím, jinak by se žák odřízl.
  lxc exec "$SERVER_KONT" -- bash -c "
    ufw --force reset >/dev/null 2>&1
    ufw allow 22/tcp >/dev/null 2>&1
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    a2ensite $SITE >/dev/null 2>&1
    systemctl unmask apache2 >/dev/null 2>&1
    systemctl enable --now apache2 >/dev/null 2>&1
    systemctl reload apache2 >/dev/null 2>&1
  " >/dev/null 2>&1

  # ── jedna závada z pěti vrstev ────────────────────────────────
  # Každá položka je "KÓD@@příkaz@@ověření". Oddělovač NENÍ roura — ověření
  # druhé vrstvy samo rouru obsahuje a rozseklo by se uprostřed.
  # Ověření tu není pro parádu:
  # kdyby se závada nezavedla, žák by hledal něco, co na serveru není.
  # (Poučení z bloku C, kde právě tohle jednou nastalo.)
  FOND=(
    "L1@@sed -i 's/ServerName $JMENO/ServerName jina.netlab.test/' /etc/apache2/sites-available/$SITE.conf; systemctl reload apache2@@grep -q 'ServerName jina' /etc/apache2/sites-available/$SITE.conf"
    "L2@@ufw delete allow 80/tcp@@! (LC_ALL=C ufw status | grep -q '^80/tcp')"
    "L3@@systemctl stop apache2; systemctl mask apache2@@[ \"\$(systemctl is-enabled apache2 2>/dev/null)\" = masked ]"
    "L4@@a2dissite $SITE; systemctl reload apache2@@! a2query -s $SITE >/dev/null 2>&1"
    "L5@@chmod 000 $ROOT@@[ \"\$(stat -c %04a $ROOT)\" = 0000 ]"
  )

  # Sůl 815 je vybraná měřením: přes 40 žáků dává rozložení 8/6/8/8/10,
  # kdežto sousední soli vycházely i 13:4. U pěti vrstev na čtyřicet žáků
  # je vyváženost podstatná — jinak by třetina třídy dostala tutéž.
  VYBER=$(( $(lab_vyber 5 1 815) - 1 ))
  POLOZKA="${FOND[$VYBER]}"
  K="${POLOZKA%%@@*}"
  PRIKAZ="${POLOZKA#*@@}"; PRIKAZ="${PRIKAZ%@@*}"
  OVERENI="${POLOZKA##*@@}"
  lxc exec "$SERVER_KONT" -- bash -c "$PRIKAZ" >/dev/null 2>&1
  KOD=""
  lxc exec "$SERVER_KONT" -- bash -c "$OVERENI" >/dev/null 2>&1 && KOD="$K"

  if [ -z "$KOD" ]; then
    echo "  Prostředí se nepodařilo připravit (závadu nešlo zavést)." >&2
    echo "  Spusťte ./reset.sh a potom znovu ./start.sh." >&2
    exit 1
  fi
  if ! lxc config set "$SERVER_KONT" "$ZAVEDENO_KLIC" "$KOD $MARKER" 2>/dev/null; then
    echo "  Nepodařilo se uložit stav cvičení do konfigurace kontejneru." >&2
    echo "  Spusťte ./reset.sh a potom znovu ./start.sh." >&2
    exit 1
  fi
  NOVE=1
else
  NOVE=0
fi

[ -s "$PROTOKOL" ] || vyrob_protokol

# Zpráva se skládá PŘED heredocem. Víceřádkové `$( … )` uvnitř heredocu
# vypadá nevinně, ale zpětné lomítko se v něm chová jinak než v kódu —
# jednou napsané dvojité lomítko celou konstrukci rozbije a zůstane po ní
# prázdný řádek plus tři syrové hlášky bashe.
if [ "$NOVE" -eq 1 ]; then
  ZPRAVA="$(printf '  Web %s nefunguje. Závada je v JEDNÉ z pěti vrstev.\n  Najděte ji, opravte — a do protokolu zapište i ty vrstvy,\n  které jste vyloučili.' "$JMENO")"
else
  ZPRAVA="$(printf '  Pokračujete tam, kde jste skončili. Postavit prostředí znovu\n  umí jedině ./reset.sh.')"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI
    Adresa:     $SERVER_IP

    Nefunkční web:  http://$JMENO/
    Kořen webu:     $ROOT
    Protokol:       $PROTOKOL   (na stanici)

  Web nemá DNS záznam, takže se na něj ze stanice zeptáte takhle:

    curl -v --resolve $JMENO:80:$SERVER_IP http://$JMENO/

$ZPRAVA

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/18-web-nejede && ./check.sh --krok 1

EOF
