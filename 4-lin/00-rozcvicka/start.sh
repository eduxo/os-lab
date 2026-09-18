#!/bin/bash
# 4/00 — Rozcvička po 3. ročníku + založení ročníkového projektu.
# Prostředí: žákova stanice. Kontejnery se nestaví — na blok zbývá ~60 minut
# praxe a musí se do něj vejít i zadání projektu, takže se diagnostikuje nad
# PŘIPRAVENÝMI soubory (netplan, unit, timer, log, firewall, compose).
#
# Projektový disk zakládá tenhle skript, ne žák: dělit disky se učí až ve
# cvičení 4/01, a to na labových discích. Chyba na projektovém disku by
# stála celoroční práci.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

ROZ="$HOME/netlab/rozcvicka4"
PODKLADY="$ROZ/podklady"
FORMULAR="$ROZ/odpovedi.txt"

# ── losované hodnoty: soused má jiné odpovědi ─────────────────────────
OKTET=$(( 20 + $(lab_vyber 60 1 400) ))          # 10.40.OKTET.0/24
PORT_WEB=$(( 8000 + $(lab_vyber 900 1 401) ))    # port v compose
INTERVAL=$(( 5 + $(lab_vyber 20 1 402) ))        # OnUnitActiveSec v timeru
CHYB=$(( 4 + $(lab_vyber 7 1 403) ))             # kolik řádků ERROR je v logu
PORTU=$(( 3 + $(lab_vyber 4 1 404) ))            # kolik portů pouští firewall
KOD="$(lab_kod PRJ 405)"                         # kód zakázky do projektu

vyrob_podklady() {
  mkdir -p "$PODKLADY"

  cat > "$PODKLADY/50-sit.yaml" <<YAML
# /etc/netplan/50-sit.yaml — z pobočkového serveru
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: false
      addresses: [10.40.$OKTET.12/24]
      routes:
        - to: default
          via: 10.40.$OKTET.1
      nameservers:
        addresses: [10.40.$OKTET.1, 9.9.9.9]
YAML

  cat > "$PODKLADY/sklizen.service" <<UNIT
[Unit]
Description=Pravidelna sklizen dat z pobockovych cidel
After=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/sklizen/sklizen.sh
User=cidla
UNIT

  cat > "$PODKLADY/sklizen.timer" <<TIMER
[Unit]
Description=Casovac pravidelne sklizne

[Timer]
OnBootSec=2min
OnUnitActiveSec=${INTERVAL}min
Unit=sklizen.service

[Install]
WantedBy=timers.target
TIMER

  # Log: přesně CHYB řádků se slovem ERROR, zbytek šum.
  {
    printf 'Sep 07 07:59:58 pobocka systemd[1]: Started Pravidelna sklizen dat z pobockovych cidel.\n'
    # Časy musí růst: žák má najít POSLEDNÍ řádek a skok zpět by ho zmátl.
    local i=1
    while [ "$i" -le "$CHYB" ]; do
      printf 'Sep 07 08:%02d:%02d pobocka sklizen.sh[%d]: ERROR cidlo %d neodpovida\n' \
        "$i" $(( 10 + i )) $(( 700 + i )) "$i"
      i=$(( i + 1 ))
    done
    printf 'Sep 07 08:12:03 pobocka sklizen.sh[712]: sklizen hotova, zapsano 48 mereni\n'
    printf 'Sep 07 08:12:03 pobocka systemd[1]: sklizen.service: Deactivated successfully.\n'
  } > "$PODKLADY/sklizen.log"

  # Výpis firewallu: PORTU povolených portů (22 je vždycky mezi nimi).
  {
    printf 'Status: active\n\nTo                         Action      From\n--                         ------      ----\n'
    printf '22/tcp                     ALLOW       10.40.%s.0/24\n' "$OKTET"
    [ "$PORTU" -ge 2 ] && printf '80/tcp                     ALLOW       Anywhere\n'
    [ "$PORTU" -ge 3 ] && printf '443/tcp                    ALLOW       Anywhere\n'
    [ "$PORTU" -ge 4 ] && printf '53                         ALLOW       10.40.%s.0/24\n' "$OKTET"
    [ "$PORTU" -ge 5 ] && printf '3260/tcp                   ALLOW       10.40.%s.0/24\n' "$OKTET"
    [ "$PORTU" -ge 6 ] && printf '9100/tcp                   ALLOW       10.40.%s.10\n' "$OKTET"
  } > "$PODKLADY/firewall.txt"

  cat > "$PODKLADY/compose.yaml" <<COMPOSE
services:
  web:
    image: nginx:alpine
    ports:
      - "$PORT_WEB:80"
    volumes:
      - ./obsah:/usr/share/nginx/html:ro
    restart: unless-stopped
COMPOSE
}

vyrob_formular() {
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Rozcvička po 3. ročníku — vyplňte hodnoty za dvojtečku.
# NENÍ TO PÍSEMKA. Kontrola ukáže, které téma vypadlo a kam se pro něj vrátit.
# Podklady leží v ~/netlab/rozcvicka4/podklady.
#
# ── síť ────────────────────────────────────────────────────────
# adresa    = IP adresa serveru i s prefixem, jak ji má 50-sit.yaml
# brana     = adresa výchozí brány
# renderer  = který program podle toho souboru řídí síť
adresa:
brana:
renderer:

# ── systemd ────────────────────────────────────────────────────
# interval  = jak často se sklizeň opakuje (číslo v minutách)
# ucet      = pod kterým účtem služba běží
# cil       = jméno cíle, do kterého se timer instaluje (WantedBy)
interval:
ucet:
cil:

# ── logy ───────────────────────────────────────────────────────
# chyb      = kolik řádků logu obsahuje slovo ERROR
# mereni    = kolik měření sklizeň nakonec zapsala
# posledni  = čas posledního řádku logu (tvar HH:MM:SS)
chyb:
mereni:
posledni:

# ── firewall ───────────────────────────────────────────────────
# pravidel  = kolik pravidel firewall vypisuje
# ssh-odkud = z jakého rozsahu smí přijít SSH
# web       = pustí firewall port 80 odkudkoli? napište ano/ne
pravidel:
ssh-odkud:
web:

# ── kontejnery ─────────────────────────────────────────────────
# port      = na kterém portu stanice web zveřejňuje
# obraz     = jméno obrazu i se značkou
# svazek    = jak je připojený obsah: napište ro, nebo rw
port:
obraz:
svazek:
FORMULAR_KONEC
}

# ── projektový disk ───────────────────────────────────────────────────
zaloz_projekt() {
  local disk cast
  disk="$(projektovy_disk)"
  if [ -z "$disk" ]; then
    varovani_disk; return 1
  fi
  if [ -n "$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)" ]; then
    return 0                       # už existuje — nikdy znovu
  fi
  # Pojistka: na projektový disk se smí psát jen tady, a jen když je prázdný.
  if [ -n "$(lsblk -rno NAME "/dev/$disk" 2>/dev/null | tail -n +2)" ]; then
    echo
    echo "  Na disku /dev/$disk už něco je, ale není to projekt. Nechávám ho být."
    echo "  Řekněte o tom vyučujícímu."
    echo
    return 1
  fi
  echo "  Zakládám disk pro ročníkový projekt (/dev/$disk)…"
  sudo sgdisk --zap-all "/dev/$disk" >/dev/null 2>&1
  sudo sgdisk --new=1:0:0 --typecode=1:8300 --change-name=1:projekt "/dev/$disk" >/dev/null 2>&1 \
    || { echo "  Oddíl se nepodařilo vytvořit — řekněte o tom vyučujícímu."; return 1; }
  sudo partprobe "/dev/$disk" >/dev/null 2>&1; sleep 1
  cast="$(lsblk -rno NAME "/dev/$disk" | tail -n +2 | head -1)"
  [ -n "$cast" ] || { echo "  Oddíl nevznikl — řekněte o tom vyučujícímu."; return 1; }
  sudo mkfs.ext4 -q -L "$PROJEKT_NAZEV" "/dev/$cast" >/dev/null 2>&1 \
    || { echo "  Souborový systém se nepodařilo vytvořit."; return 1; }
  return 0
}
varovani_disk() {
  echo
  echo "  Nenašel jsem disk pro ročníkový projekt. Stanice má mít kromě"
  echo "  systémového ještě čtyři labové disky po 2 GB a jeden 4GB projektový."
  echo "  Řekněte o tom vyučujícímu."
  echo
}

# ── běh ───────────────────────────────────────────────────────────────
mkdir -p "$ROZ"
DOPLNENO=""
[ -d "$PODKLADY" ] || { vyrob_podklady; DOPLNENO="$DOPLNENO podklady"; }
[ -s "$FORMULAR" ] || { vyrob_formular;  DOPLNENO="$DOPLNENO formulář"; }

zkontroluj_disky 1 >/dev/null 2>&1 || true      # hlášku vypíše až zaloz_projekt
if zaloz_projekt && projekt_pripoj >/dev/null 2>&1; then
  # Až TEĎ se smí zakládat obsah: kdyby se disk nepřipojil, vznikly by
  # adresáře v domovském adresáři a žák by si myslel, že projekt má.
  mkdir -p "$PROJEKT_PRIPOJ/dokumentace" 2>/dev/null
  if [ ! -s "$PROJEKT_PRIPOJ/zadani.txt" ]; then
    cat > "$PROJEKT_PRIPOJ/zadani.txt" <<ZADANI 2>/dev/null
Ročníkový projekt — pobočkový server NetLab s.r.o.
Kód zakázky: $KOD
Zadáno: $(date '+%Y-%m-%d')

Tenhle disk je VÁŠ. Skripty cvičení se ho nikdy nedotknou — ani reset.sh.
Všechno, co k projektu vznikne, patří sem.
ZADANI
  fi
fi

echo
if [ -n "$DOPLNENO" ]; then
  echo "  Prostředí rozcvičky:$DOPLNENO"
else
  echo "  Prostředí rozcvičky už existuje — pokračujete, kde jste skončili."
fi
cat <<EOF

    Podklady:  $PODKLADY
    Formulář:  $FORMULAR
EOF
if projekt_pripojen; then
  cat <<EOF
    Projekt:   $PROJEKT_PRIPOJ   (kód zakázky $KOD)
EOF
fi
cat <<EOF

  Průběžná kontrola:

    cd ~/os-lab/4-lin/00-rozcvicka && ./check.sh --krok 1

EOF
