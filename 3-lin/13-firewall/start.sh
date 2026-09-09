#!/bin/bash
# 3/13 — Firewall (ufw). Prostředí: server provoz-XX přes SSH.
#
# Na serveru poslouchají dvě služby: `stav` na portu 80XX má zůstat zvenčí
# dostupná, `interni` na portu 90XX se má schovat. Žák to má zařídit přes
# ufw — a hlavně v takovém pořadí, aby si neusekl vlastní SSH.
#
# ZÁCHRANA: ./start.sh --odblokuj shodí firewall přes `lxc exec`, tedy
# mimo SSH. Bez toho by se žák, který zapnul ufw dřív než povolil port 22,
# už na server nedostal.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="provoz-$ZAK2"

if [ "${1:-}" = "--odblokuj" ]; then
  if ! command -v lxc >/dev/null 2>&1; then
    echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
  fi
  STAV_K="$(lxc list "^${SERVER_KONT}$" -c s --format csv 2>/dev/null)"
  if [ -z "$STAV_K" ]; then
    echo; echo "  Server $SERVER_KONT neexistuje. Spusťte ./start.sh"; echo; exit 1
  elif [ "$STAV_K" != "RUNNING" ]; then
    echo; echo "  Server $SERVER_KONT je zastavený. Nastartujte ho:  ./start.sh"; echo; exit 1
  fi
  lxc exec "$SERVER_KONT" -- bash -c "ufw --force disable" >/dev/null 2>&1
  # Tohle je jediná cesta zpátky, když se žák odřízl — nesmí hlásit úspěch,
  # který nenastal. Proto se stav po zásahu opravdu přečte.
  if lxc exec "$SERVER_KONT" -- bash -c "LC_ALL=C ufw status 2>/dev/null | head -1" \
       2>/dev/null | grep -q inactive; then
    echo
    echo "  Firewall na serveru $SERVER_KONT je vypnutý — SSH zase projde."
    echo "  Vaše pravidla zůstala uložená, jen se neuplatňují."
    echo "  Až je opravíte, zapněte firewall znovu:  sudo ufw enable"
    echo
    exit 0
  fi
  echo
  echo "  Firewall se nepodařilo vypnout. Řekněte o tom vyučujícímu —"
  echo "  do serveru se dá dostat i příkazem:  lxc exec $SERVER_KONT -- bash"
  echo
  exit 1
fi

source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/../../lib/provoz-lib.sh"

PROVOZ="$HOME/netlab/provoz"
FORMULAR="$PROVOZ/formular-13.txt"
PORT_STAV=$(( 8000 + ZAK ))
PORT_INTERNI=$(( 9000 + ZAK ))

vyrob_formular() {
  mkdir -p "$PROVOZ"
  cat > "$FORMULAR" <<'FORM_KONEC'
# Formulář — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# politika       = výchozí politika pro příchozí provoz (jedno slovo)
# pid-interniho  = číslo procesu, který naslouchá na portu interního
#                  přehledu — najdete ho v `sudo ss -tlnp`
politika:
pid-interniho:
FORM_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

postav_zpracovani

# ── dvě služby, jedna veřejná a jedna, která má zůstat doma ───────
postav_naslouchac() {  # postav_naslouchac jméno port popis
  local jmeno="$1" port="$2" popis="$3"
  lxc exec "$SERVER_KONT" -- bash -c "mkdir -p /srv/$jmeno" >/dev/null 2>&1
  lxc exec "$SERVER_KONT" -- tee /srv/$jmeno/index.html >/dev/null <<HTML
<!doctype html><meta charset="utf-8"><title>$popis</title>
<h1>$popis</h1><p>Server provoz-$ZAK2, port $port.</p>
HTML
  if ! lxc exec "$SERVER_KONT" -- test -f /etc/systemd/system/$jmeno.service; then
    lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/$jmeno.service >/dev/null <<UNIT
[Unit]
Description=$popis
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server $port --bind 0.0.0.0 --directory /srv/$jmeno
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
    lxc exec "$SERVER_KONT" -- systemctl daemon-reload >/dev/null 2>&1
  fi
  lxc exec "$SERVER_KONT" -- systemctl enable --now $jmeno >/dev/null 2>&1
}

postav_naslouchac stav     "$PORT_STAV"     "Stavova stranka NetLab"
postav_naslouchac interni  "$PORT_INTERNI"  "Interni prehled NetLab"

# ufw ani nft nejsou v cloud image samozřejmostí. `nft` potřebuje Krok 4
# zadání — bez něj by vedený krok skončil na „command not found".
doinstaluj ufw:ufw nftables:nft || exit 1

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

    Stavová stránka:  port $PORT_STAV     — má zůstat dostupná zvenčí
    Interní přehled:  port $PORT_INTERNI  — má se schovat
    Formulář:         $FORMULAR   (na stanici)

  Kdybyste se po zapnutí firewallu nemohli přihlásit, spusťte NA STANICI:

    cd ~/os-lab/3-lin/13-firewall && ./start.sh --odblokuj

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/13-firewall && ./check.sh --krok 2

EOF
