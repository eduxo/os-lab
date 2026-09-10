#!/bin/bash
# 3/22 — Souborná práce IntraWeb. Assessment na DVA bloky.
#
# Server intraweb-XX je JEN na lxdbr0, ne na síti netlab. Důvod: blok E
# tam má server na adrese .10 a kdyby si tenhle vzal totéž, kolidovaly by
# si. Žádný úkol souborné práce izolovanou síť nepotřebuje — DNS se
# ověřuje dotazem na konkrétní adresu, ne tím, kdo odpoví jako první.
#
# Prostředí dodává hotovou FIREMNÍ AUTORITU. Vyrobit vlastní CA umí žák
# ze cvičení 17 a trvalo by to půl bloku; realističtější i levnější je,
# že autorita ve firmě existuje a on od ní jen vystaví certifikát.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="intraweb-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

PRACE="$HOME/netlab/intraweb"
PROTOKOL="$PRACE/protokol.txt"
JMENO="intraweb.netlab.test"
ROOT=/var/www/intraweb
CA_DIR=/srv/ca
PODKLADY=/srv/podklady/zadani.txt
KOD_KLIC="user.lab322-kod"
ZBYTEK_PORT=$(( 9000 + ZAK ))
# Interval obnovy stavové stránky. Losuje se jako v cvičení 8, aby si
# ho žáci neopsali navzájem — a aby timer stihl v hodině vystřelit.
INTERVAL=$(( 2 + $(lab_vyber 4 1 950) ))

vyrob_protokol() {
  mkdir -p "$PRACE"
  cat > "$PROTOKOL" <<'PROTOKOL_KONEC'
# Předávací protokol — vyplňte hodnoty za dvojtečku.
# Protokol je na STANICI, práce je na serveru.
#
# kod        = kód zakázky z podkladů na serveru
# otisk      = otisk SHA-256 certifikátu, který server posílá
# interval   = jak často se stavová stránka obnovuje (v minutách, číslo)
# zbytek     = co jste našli poslouchat na portu, který tam nemá co dělat
#              (jméno programu)
kod:
otisk:
interval:
zbytek:
PROTOKOL_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

doinstaluj apache2:apache2 bind9:named bind9-utils:named-checkzone ufw:ufw || exit 1

# ── kód zakázky ───────────────────────────────────────────────────
KOD="$(lxc config get "$SERVER_KONT" "$KOD_KLIC" 2>/dev/null | tr -d '\r')"
if [ -z "$KOD" ]; then
  KOD="ZAK-$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c5)"
  lxc config set "$SERVER_KONT" "$KOD_KLIC" "$KOD" 2>/dev/null || {
    echo "  Kód zakázky se nepodařilo uložit — zavolejte vyučujícího." >&2; exit 1; }
fi
lxc exec "$SERVER_KONT" -- bash -c "
  mkdir -p /srv/podklady
  [ -s '$PODKLADY' ] || printf 'Zakazka IntraWeb\nKod zakazky: %s\n' '$KOD' > '$PODKLADY'
" >/dev/null 2>&1

# ── firemní certifikační autorita ─────────────────────────────────
# Dodává ji prostředí. Klíč patří rootovi — žák k němu má přístup přes
# sudo, ale nemá důvod ho kamkoli kopírovat, a protokol se na něj neptá.
if ! lxc exec "$SERVER_KONT" -- test -s "$CA_DIR/ca.crt"; then
  lxc exec "$SERVER_KONT" -- bash -c "
    mkdir -p $CA_DIR && chmod 750 $CA_DIR
    openssl req -x509 -newkey rsa:4096 -sha256 -days 1825 -noenc \\
      -keyout $CA_DIR/ca.key -out $CA_DIR/ca.crt \\
      -subj '/C=CZ/O=NetLab s.r.o./CN=NetLab Interni CA' \\
      -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \\
      -addext 'keyUsage=critical,keyCertSign,cRLSign' >/dev/null 2>&1
    chmod 600 $CA_DIR/ca.key
    chown -R $SERVER_UCET:$SERVER_UCET $CA_DIR
    chmod 600 $CA_DIR/ca.key
  " >/dev/null 2>&1
fi

# ── zbytek po předchůdci ──────────────────────────────────────────
# Něco, co na serveru poslouchá a nemá tam co dělat. Úkol E ho má
# schovat firewallem (ne vypnout — to je práce pro jinou hodinu).
if ! lxc exec "$SERVER_KONT" -- test -f /etc/systemd/system/prehledy.service; then
  lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/prehledy.service >/dev/null <<UNIT
[Unit]
Description=Prehledy NetLab (zbytek po predchudci)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server $ZBYTEK_PORT --bind 0.0.0.0 --directory /srv/podklady
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
  lxc exec "$SERVER_KONT" -- bash -c \
    "systemctl daemon-reload; systemctl enable --now prehledy" >/dev/null 2>&1
fi

lxc exec "$SERVER_KONT" -- bash -c "mkdir -p $ROOT" >/dev/null 2>&1

[ -s "$PROTOKOL" ] || vyrob_protokol

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Mezi bloky ho NEMAŽTE. Když se stanice vypnula, ./start.sh ho"
  echo "  jen nastartuje a vaši práci nechá být."
fi

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI
    Adresa:     $SERVER_IP

    Jméno webu:       $JMENO
    Kořen dokumentů:  $ROOT
    Podklady:         $PODKLADY   (na serveru)
    Firemní autorita: $CA_DIR/ca.crt
    Protokol:         $PROTOKOL   (na stanici)

    Stavová stránka se má obnovovat každé $INTERVAL minuty.

  Zadání má šest částí A až F. Průběžná kontrola:

    cd ~/os-lab/3-lin/22-souborna-prace && ./check.sh --krok 1

EOF
