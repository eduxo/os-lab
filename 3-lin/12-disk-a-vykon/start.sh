#!/bin/bash
# 3/12 — „Místo mizí a nikdo neví kam". Prostředí: server provoz-XX přes SSH.
#
# Tři symptomy, každý jiného druhu. Na rozdíl od 3/10 se NELOSUJE, které
# symptomy tam jsou — jsou tam všechny tři. Losují se jména a velikosti,
# takže odpovědi se nedají opsat a čísla si žák musí naměřit sám.
#
# Pozn. k prostředí: kontejner sdílí úložiště s hostitelem, takže `df`
# neukáže „disk plný na 100 %". Cvičení proto stojí na ROZDÍLU mezi tím,
# co hlásí `df`, a tím, co najde `du` — což je stejně ta dovednost,
# o kterou jde.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="provoz-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/../../lib/provoz-lib.sh"

PROVOZ="$HOME/netlab/provoz"
PROTOKOL="$PROVOZ/protokol-12.txt"
ZAVEDENO_KLIC="user.lab312-zavedeno"

# ── co se losuje ──────────────────────────────────────────────────
SLUZBY=(prenos sync replikace)
FRONTY=(fronta spool vystup)
EVIDENCE=(evidence ucetnictvi sklad)
SLUZBA="${SLUZBY[$(( $(lab_vyber 3 1 511) - 1 ))]}"
FRONTA="${FRONTY[$(( $(lab_vyber 3 1 512) - 1 ))]}"
EVID="${EVIDENCE[$(( $(lab_vyber 3 1 513) - 1 ))]}"
MB_DRZENY=$(( 90 + ZAK ))    # smazaný, ale držený soubor
MB_LOG=$(( 150 + ZAK ))      # nerotovaný log
POCET_FRONTA=20000

vyrob_protokol() {
  mkdir -p "$PROVOZ"
  cat > "$PROTOKOL" <<'PROTOKOL_KONEC'
# Protokol o úklidu — vyplňte hodnoty za dvojtečku.
# Protokol je na STANICI, práce je na serveru.
#
# Do řádků symptom-N napište vlastními slovy, co jste našli a čím
# (aspoň pět slov).
# drzel       = jméno programu, který držel místo, jež `du` nevidělo
# drzenych-mb = kolik MB ten program držel (celé číslo, bez jednotky)
symptom-1:
symptom-2:
symptom-3:
drzel:
drzenych-mb:
PROTOKOL_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

postav_zpracovani
postav_archiv

ZAVEDENO="$(lxc config get "$SERVER_KONT" "$ZAVEDENO_KLIC" 2>/dev/null)"

if [ -z "$ZAVEDENO" ]; then
  # lsof není v cloud image; bez něj se smazaný otevřený soubor nedá najít
  # a celý první symptom by neměl řešení. `doinstaluj` udělá i apt-get update
  # (obraz nemá zaručeně naplněné seznamy) a po instalaci ověří, že tam
  # balíček opravdu je — tiché selhání by lab rozbilo až u žáka.
  doinstaluj lsof:lsof || exit 1

  # ── symptom 1: místo, které du nevidí ──────────────────────────
  # Program si soubor otevře, naplní, smaže — a drží ho otevřený dál.
  # Dokud proces žije, jádro místo neuvolní, ale `du` ho nenajde:
  # v adresáři už žádný takový soubor není.
  lxc exec "$SERVER_KONT" -- tee /usr/local/bin/$SLUZBA.sh >/dev/null <<DRZAK
#!/bin/bash
# Prenos dat NetLab — pracovni soubor si drzi otevreny.
D=/var/lib/$SLUZBA
mkdir -p "\$D"
exec 3> "\$D/prubeh.tmp"
dd if=/dev/urandom bs=1M count=$MB_DRZENY status=none >&3
rm -f "\$D/prubeh.tmp"
while true; do date >&3; sleep 60; done
DRZAK
  # 700, ne 755: v těle skriptu stojí `count=<MB>`, tedy přesně ta hodnota,
  # kterou má žák naměřit přes lsof. Systemd ho pouští jako root, takže mu
  # přísnější práva nevadí, a `systemctl cat` → `cat skript` přestane být
  # zkratkou k odpovědi.
  lxc exec "$SERVER_KONT" -- chmod 700 /usr/local/bin/$SLUZBA.sh

  lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/$SLUZBA.service >/dev/null <<UNIT
[Unit]
Description=Prenos dat NetLab

[Service]
Type=simple
ExecStart=/usr/local/bin/$SLUZBA.sh
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

  # ── symptom 2: fronta, kterou nikdo nevybírá ───────────────────
  # Každá položka je vycpaná na ~4 KB. Prázdné soubory by se na btrfs mohly
  # uložit inline do metadat a `du` by adresář skoro neviděl — přitom právě
  # na `du` zadání posílá. 20 000 × 4 KB = ~80 MB, tedy zřetelně.
  # printf je builtin, takže se kvůli tomu nic neforkuje.
  lxc exec "$SERVER_KONT" -- bash -c "
    mkdir -p /srv/$FRONTA
    for i in \$(seq 1 $POCET_FRONTA); do
      printf 'polozka %s%4000s\n' \"\$i\" '' > /srv/$FRONTA/uloha-\$i.job
    done
    # Fronta patří účtu, který ji v provozu plní — a žák tak nepotřebuje
    # sudo na to, aby ji vysypal.
    chown -R $SERVER_UCET:$SERVER_UCET /srv/$FRONTA
  " >/dev/null 2>&1

  # ── symptom 3: log, který nikdo nerotuje ───────────────────────
  # Služba si log drží otevřený. Kdo ho smaže místo zkrácení, vyrobí si
  # tím symptom 1 — a kontrola to pozná.
  lxc exec "$SERVER_KONT" -- tee /usr/local/bin/$EVID.sh >/dev/null <<EVIDS
#!/bin/bash
# Evidence NetLab — pise do sveho logu, ktery si drzi otevreny.
LOG=/var/log/$EVID/$EVID.log
mkdir -p "\$(dirname "\$LOG")"
exec 3>> "\$LOG"
while true; do date >&3; sleep 10; done
EVIDS
  lxc exec "$SERVER_KONT" -- chmod 755 /usr/local/bin/$EVID.sh

  lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/$EVID.service >/dev/null <<UNIT
[Unit]
Description=Evidence NetLab

[Service]
Type=simple
ExecStart=/usr/local/bin/$EVID.sh
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

  # Log se předplní DŘÍV, než se služba spustí — jinak by si ho otevřela
  # prázdný a zápis na pozici 0 by velikost jen přepisoval.
  lxc exec "$SERVER_KONT" -- bash -c "
    mkdir -p /var/log/$EVID
    dd if=/dev/urandom of=/var/log/$EVID/$EVID.log bs=1M count=$MB_LOG status=none
  " >/dev/null 2>&1

  lxc exec "$SERVER_KONT" -- bash -c "
    systemctl daemon-reload
    systemctl enable --now $SLUZBA >/dev/null 2>&1
    systemctl enable --now $EVID >/dev/null 2>&1
  " >/dev/null 2>&1

  # Číslo i-uzlu logu. Zkrácení ho zachová, smazání ne — díky tomu kontrola
  # pozná „zkrátil" od „smazal a nechal službu vyrobit nový".
  LOG_INODE="$(lxc exec "$SERVER_KONT" -- stat -c %i "/var/log/$EVID/$EVID.log" 2>/dev/null | tr -d '\r')"

  if ! lxc config set "$SERVER_KONT" "$ZAVEDENO_KLIC" "$SLUZBA $FRONTA $EVID ${LOG_INODE:-0}" 2>/dev/null; then
    echo "  Nepodařilo se uložit stav cvičení do konfigurace kontejneru." >&2
    echo "  Spusťte ./reset.sh a potom znovu ./start.sh." >&2
    exit 1
  fi
  NOVE=1
else
  NOVE=0
fi

[ -s "$PROTOKOL" ] || vyrob_protokol

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI

    Protokol:   $PROTOKOL   (na stanici)

    Podle dokumentace mají na serveru běžet dvě vlastní služby:
      zpracovani   dávkové zpracování (ze cvičení 11)
      $EVID   evidence
    Cokoli dalšího po sobě nechal předchůdce.

$( [ "$NOVE" -eq 1 ] \
   && printf '  Na serveru ubývá místo a nikdo neví kam. Jsou tam TŘI příčiny,\n  každá jiného druhu. Najděte je a ukliďte.' \
   || printf '  Pokračujete tam, kde jste skončili — co jste uklidili, zůstalo\n  uklizené. Postavit prostředí znovu umí jedině ./reset.sh.' )

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/12-disk-a-vykon && ./check.sh --krok 1

EOF
