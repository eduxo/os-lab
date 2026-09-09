#!/bin/bash
# 3/14 — DNS server. Prostředí: server netlab-XX, služba na izolované síti.
#
# Server má DVĚ karty: eth0 na lxdbr0 (SSH ze stanice, apt) a eth1 na síti
# `netlab`, kde poběží DNS. Důvod je v lib/netlab-lib.sh — na lxdbr0 má LXD
# vlastní dnsmasq a žákův server by se s ním o dotazy pral.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="netlab-$ZAK2"
source "$(dirname "$0")/../../lib/netlab-lib.sh"

zaridi_sit || exit 1
SERVER_SIT2="$NETLAB_SIT"
SERVER_IP2="$NETLAB_SERVER/$NETLAB_PREFIX"   # prefix se bere ze sítě, ne natvrdo
source "$(dirname "$0")/../../lib/server-lib.sh"

DNS="$HOME/netlab/dns"
FORMULAR="$DNS/formular.txt"
ZONA="netlab.test"

# ── co se losuje ──────────────────────────────────────────────────
JMENA=(tiskarna sklad kamera)
HOST="${JMENA[$(( $(lab_vyber 3 1 601) - 1 ))]}"
HOST_OKTET=$(( 30 + $(lab_vyber 9 1 602) ))
IP_WWW="$NETLAB_PODSIT.20"
IP_HOST="$NETLAB_PODSIT.$HOST_OKTET"

vyrob_formular() {
  mkdir -p "$DNS"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# serial = sériové číslo zóny z hlavičky souboru zóny
# ttl    = číslo ve sloupci TTL, které `dig` hlásí u www.netlab.test
#          (dotaz BEZ +short, sloupec mezi jménem a slovem IN)
serial:
ttl:
FORM_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

doinstaluj bind9:named bind9-utils:named-checkzone || exit 1

# ── poslouchání zúžené na loopback ────────────────────────────────
# BIND ve výchozím stavu poslouchá na VŠECH adresách, takže krok „nastavte
# listen-on" by byl rituál bez účinku: server by ze stanice odpovídal
# i tomu, kdo ho vynechá. Předvyplněné `127.0.0.1` z toho dělá skutečnou
# úlohu — dokud žák okruh nerozšíří, zvenčí se nikdo nedovolá.
if ! lxc exec "$SERVER_KONT" -- grep -q 'listen-on' /etc/bind/named.conf.options 2>/dev/null; then
  lxc exec "$SERVER_KONT" -- sed -i \
    's/^options {/options {\n\tlisten-on { 127.0.0.1; };/' \
    /etc/bind/named.conf.options >/dev/null 2>&1
  lxc exec "$SERVER_KONT" -- systemctl restart named >/dev/null 2>&1
fi

# ── kostra zóny ───────────────────────────────────────────────────
# Guided lab: hlavička (SOA, NS) je hotová, protože její syntaxe se za
# jednu hodinu nenaučí, a záznamy si žák doplní sám. Kostra se doplní jen
# tehdy, když soubor ještě není — jinak by druhé spuštění smazalo práci.
if ! lxc exec "$SERVER_KONT" -- test -f /etc/bind/db.$ZONA; then
  # Sériové číslo a TTL se LOSUJÍ AŽ TADY, při prvním stavění zóny.
  # Vzorec z čísla žáka (dřívější `2026110$ZAK2`) byl k ničemu: start.sh
  # je ve veřejném repozitáři, který má žák naklonovaný, takže si obojí
  # spočítal — a s ním i jazykový model. Náhodná hodnota existuje jen
  # v tomhle jednom kontejneru a přečte se jedině na serveru.
  SERIAL="$(date +%Y%m%d)$(printf '%02d' $(( RANDOM % 100 )))"
  TTL_ZONY=$(( 1200 + (RANDOM % 40) * 30 ))
  lxc exec "$SERVER_KONT" -- tee /etc/bind/db.$ZONA >/dev/null <<ZONAKONEC
\$TTL    $TTL_ZONY
@       IN      SOA     ns.$ZONA. spravce.$ZONA. (
                        $SERIAL         ; Serial
                        3600            ; Refresh
                        900             ; Retry
                        604800          ; Expire
                        3600 )          ; Negative TTL
;
@       IN      NS      ns.$ZONA.
ns      IN      A       $NETLAB_SERVER

; ── sem doplňte záznamy podle zadání ──────────────────────────────
ZONAKONEC
  lxc exec "$SERVER_KONT" -- chown root:bind /etc/bind/db.$ZONA >/dev/null 2>&1
  lxc exec "$SERVER_KONT" -- chmod 644 /etc/bind/db.$ZONA >/dev/null 2>&1
fi

[ -s "$FORMULAR" ] || vyrob_formular

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP        (správa, přes lxdbr0)
    Přihlášení: $PRIHLASENI

    Síť netlab:      $NETLAB_PODSIT.0/24, brána $NETLAB_BRANA
    Adresa serveru:  $NETLAB_SERVER   (rozhraní eth1 — tady poběží DNS)

    Zóna:       $ZONA
    Soubor:     /etc/bind/db.$ZONA   (kostra je připravená)
    Formulář:   $FORMULAR   (na stanici)

  Do zóny patří tyhle záznamy:

    www          A       $IP_WWW
    $HOST        A       $IP_HOST
    intranet     CNAME   www

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/14-dns-server && ./check.sh --krok 2

  (Kontrola začíná částí 2 — Krok 1 zadání je jen prohlídka.)

EOF
