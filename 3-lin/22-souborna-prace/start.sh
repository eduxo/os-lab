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
CA_ZALOHA=/opt/lab-ca
CA_KLIC="user.lab322-ca"
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
# otisk      = otisk SHA-256 certifikátu, který server posílá TEĎ
#              (vystavíte-li certifikát znovu, otisk se změní)
# interval   = jak často se stavová stránka obnovuje (v minutách, číslo)
# zbytek     = co jste našli poslouchat na portu, který tam nemá co dělat
#              (jméno programu)
kod:
otisk:
interval:
zbytek:
PROTOKOL_KONEC
}

# Byl server před spuštěním zastavený? Časovač z úkolu D pak začíná
# odznova a kontrola u D chvíli hlásí nečerstvou stránku — žák má vědět,
# že to není jeho chyba.
BYL_ZASTAVENY=0
if lxc info "$SERVER_KONT" >/dev/null 2>&1 \
   && [ "$(lxc list "^${SERVER_KONT}$" -c s --format csv 2>/dev/null)" != "RUNNING" ]; then
  BYL_ZASTAVENY=1
fi

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

doinstaluj apache2:apache2 bind9:named bind9-utils:named-checkzone \
           ufw:ufw python3:python3 || exit 1

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
# Adresář /srv/ca patří ŽÁKOVI: cvičení 17 v něm učí pracovat bez sudo
# (žádost, soubor s příponami, -CAcreateserial zapisuje ca.srl). Proto
# tam ale žák může autoritu i přepsat nebo smazat — a rozejít dvojici
# ca.crt/ca.key, což by ho na dvě hodiny zavřelo do slepé uličky.
# Pravý pár drží prostředí zvlášť v $CA_ZALOHA (jen root) a odsud ho
# vrací zpátky. Otisk pravé autority je v konfiguraci kontejneru a
# slouží kontrole jako kotva důvěry.
lxc exec "$SERVER_KONT" -- bash -c "
  set -e
  mkdir -p $CA_ZALOHA && chmod 700 $CA_ZALOHA
  if [ ! -s $CA_ZALOHA/ca.crt ] || [ ! -s $CA_ZALOHA/ca.key ]; then
    openssl req -x509 -newkey rsa:4096 -sha256 -days 1825 -noenc \\
      -keyout $CA_ZALOHA/ca.key -out $CA_ZALOHA/ca.crt \\
      -subj '/C=CZ/O=NetLab s.r.o./CN=NetLab Interni CA' \\
      -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \\
      -addext 'keyUsage=critical,keyCertSign,cRLSign' >/dev/null 2>&1
    chmod 600 $CA_ZALOHA/ca.key
  fi
  mkdir -p $CA_DIR
  ZAL=\$(openssl x509 -in $CA_ZALOHA/ca.crt -noout -fingerprint -sha256 2>/dev/null)
  AKT=\$(openssl x509 -in $CA_DIR/ca.crt   -noout -fingerprint -sha256 2>/dev/null || true)
  if [ \"\$ZAL\" != \"\$AKT\" ] || [ ! -s $CA_DIR/ca.key ]; then
    cp $CA_ZALOHA/ca.crt $CA_ZALOHA/ca.key $CA_DIR/
  fi
  chown -R $SERVER_UCET:$SERVER_UCET $CA_DIR
  chmod 755 $CA_DIR; chmod 644 $CA_DIR/ca.crt; chmod 600 $CA_DIR/ca.key
" >/dev/null 2>&1
# Ověřovací příkaz se musí ověřit taky: bez autority je úkol B neřešitelný
# a žák by to poznal až z hlášky, která ukazuje na jeho práci.
CA_OTISK="$(lxc exec "$SERVER_KONT" -- bash -c \
  "openssl x509 -in $CA_DIR/ca.crt -noout -fingerprint -sha256 2>/dev/null" \
  | cut -d= -f2 | tr -d ' :\r' | tr 'a-f' 'A-F')"
if [ -z "$CA_OTISK" ] \
   || ! lxc exec "$SERVER_KONT" -- test -s "$CA_DIR/ca.key"; then
  echo "  Firemní autoritu se na serveru nepodařilo připravit —" >&2
  echo "  bez ní nejde splnit úkol B. Zavolejte vyučujícího." >&2
  exit 1
fi
lxc config set "$SERVER_KONT" "$CA_KLIC" "$CA_OTISK" 2>/dev/null || true

# ── zbytek po předchůdci ──────────────────────────────────────────
# Něco, co na serveru poslouchá a nemá tam co dělat. Úkol E ho má
# schovat firewallem (ne vypnout — to je práce pro jinou hodinu).
# Strážce hlídá STAV SLUŽBY, ne existenci souboru: kdo ji v úkolu E
# vypne, by ji jinak už nikdy nedostal zpátky a zůstal by mu trvalý
# [FAIL] u úkolu, který má jinak hotový.
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
fi
if ! lxc exec "$SERVER_KONT" -- systemctl is-active --quiet prehledy; then
  lxc exec "$SERVER_KONT" -- bash -c \
    "systemctl daemon-reload; systemctl enable --now prehledy" >/dev/null 2>&1
  if ! lxc exec "$SERVER_KONT" -- systemctl is-active --quiet prehledy; then
    echo "  Službu po předchůdci se nepodařilo nastartovat —" >&2
    echo "  úkol E by se nedal splnit. Zavolejte vyučujícího." >&2
    exit 1
  fi
fi

lxc exec "$SERVER_KONT" -- bash -c "mkdir -p $ROOT" >/dev/null 2>&1

[ -s "$PROTOKOL" ] || vyrob_protokol

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Mezi bloky ho NEMAŽTE. Když se stanice vypnula, ./start.sh ho"
  echo "  jen nastartuje a vaši práci nechá být."
  if [ "$BYL_ZASTAVENY" -eq 1 ]; then
    echo
    echo "  Server byl zastavený, takže časovač z úkolu D začíná odznova."
    echo "  Než poprvé vystřelí, hlásí kontrola u D starou stavovou stránku."
    echo "  Není to vaše chyba — počkejte jeden interval."
  fi
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

    Stavová stránka se má obnovovat v intervalu $INTERVAL minut.

  Zadání má šest částí A až F. Průběžná kontrola:

    cd ~/os-lab/3-lin/22-souborna-prace && ./check.sh --krok 1

EOF
