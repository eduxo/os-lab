#!/bin/bash
# 3/10 — „Služba nenaběhla". Prostředí: server sluzby-XX přes SSH.
#
# Instaluje službu `tisk` a zavede do ní TŘI závady, každou z jiné kategorie.
# Fond je 3 × 3; losuje se z čísla žáka, takže soused má jinou kombinaci.
#
# Fond je v tomhle souboru čitelný a je to vědomé: kód, který závady zavádí,
# tu být musí, takže by šifrování skrylo jen popisky, ne podstatu. Žák má
# repozitář naklonovaný — obrana je v tom, že závady jsou v běžícím systému
# a najít je znamená umět číst `systemctl status` a `journalctl`.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="sluzby-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

TS="$HOME/netlab/tisk"
PROTOKOL="$TS/protokol.txt"
SLUZBA_UCET="tisk$ZAK2"
# Seznam zavedených závad se ukládá do KONFIGURACE LXD, ne na server.
# Uvnitř kontejneru by ho žák přečetl (má tam sudo bez hesla) — takhle je
# mimo jeho dosah, protože `lxc` nemá a dovnitř chodí jen přes SSH.
ZAVEDENO_KLIC="user.lab310-zavedeno"

vyrob_protokol() {
  mkdir -p "$TS"
  cat > "$PROTOKOL" <<'PROTOKOL_KONEC'
# Protokol o opravě — vyplňte hodnoty za dvojtečku.
# Protokol je na STANICI, práce je na serveru.
#
# Do každého řádku zavada-N napište vlastními slovy, co bylo špatně
# (aspoň čtyři slova). Do nastroje napište, čím jste závady našli.
zavada-1:
zavada-2:
zavada-3:
nastroje:
PROTOKOL_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

# Prostředí se staví JEN JEDNOU. Klíč v konfiguraci LXD je zároveň dokladem,
# že závady už jsou zavedené — bez téhle podmínky by druhé spuštění start.sh
# (po restartu serveru, po stop.sh) smazalo žákovi hodinu práce a závady
# nasadilo znovu. Bourá a staví znovu výhradně reset.sh.
ZAVEDENO="$(lxc config get "$SERVER_KONT" "$ZAVEDENO_KLIC" 2>/dev/null)"

if [ -z "$ZAVEDENO" ]; then
  # ── zdravá služba ───────────────────────────────────────────────
  lxc exec "$SERVER_KONT" -- bash -c "
    id $SLUZBA_UCET >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin $SLUZBA_UCET
    mkdir -p /srv/tisk /var/log/tisk
    chown $SLUZBA_UCET:$SLUZBA_UCET /var/log/tisk /srv/tisk
  " >/dev/null 2>&1

  # Zápis do logu se kontroluje a při neúspěchu se skript ukončí. Bez toho by
  # bash jen vypsal „Permission denied" a smyčka by běžela dál — služba by
  # u závady B3 zůstala `active (running)` a nedělala svou práci, což
  # odporuje tomu, co o ní říká zadání, a bere žákovi hlavní vodítko.
  lxc exec "$SERVER_KONT" -- tee /usr/local/bin/tisk.sh >/dev/null <<'TISK'
#!/bin/bash
# Tiskova fronta NetLab — hlida adresar a hlasi, ze je pripravena.
LOG=/var/log/tisk/tisk.log
while true; do
  printf '%s tiskova fronta pripravena\n' "$(date '+%F %T')" >> "$LOG" || {
    echo "tisk: nelze zapisovat do $LOG" >&2
    exit 1
  }
  sleep 15
done
TISK
  lxc exec "$SERVER_KONT" -- chmod 755 /usr/local/bin/tisk.sh

  lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/tisk.service >/dev/null <<UNIT
[Unit]
Description=Tiskova fronta NetLab
After=network.target

[Service]
Type=simple
User=$SLUZBA_UCET
WorkingDirectory=/srv/tisk
ExecStart=/usr/local/bin/tisk.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

  # ── fond závad: 3 kategorie po 3, losují se tři, z každé jedna ──
  #
  # Každá položka je "KÓD|příkaz na serveru|ověření na serveru". Ověření tu
  # není pro parádu: kdyby se závada nezavedla (třeba proto, že jiná už
  # přepsala tentýž řádek), zapsal by se její kód do seznamu a žák by hledal
  # závadu, která na serveru není. Když se los nechytí, zkusí se v téže
  # kategorii následující varianta.
  UNIT_S=/etc/systemd/system/tisk.service

  FOND_A=(
    "A1|sed -i 's/^ExecStart=/ExecStrat=/' $UNIT_S|grep -q '^ExecStrat=' $UNIT_S"
    "A2|sed -i '/^\[Install\]/,\$d' $UNIT_S|! grep -q '^\[Install\]' $UNIT_S"
    "A3|sed -i 's/^Type=simple/Type=forking/' $UNIT_S|grep -q '^Type=forking' $UNIT_S"
  )
  FOND_B=(
    "B1|chmod 644 /usr/local/bin/tisk.sh|[ \"\$(stat -c %a /usr/local/bin/tisk.sh)\" = 644 ]"
    "B2|sed -i 's/^User=.*/User=tiskarna-neexistuje/' $UNIT_S|grep -q '^User=tiskarna-neexistuje' $UNIT_S"
    "B3|chown root:root /var/log/tisk; chmod 755 /var/log/tisk|[ \"\$(stat -c %U /var/log/tisk)\" = root ]"
  )
  FOND_C=(
    "C1|sed -i 's|^ExecStart=/usr/local/bin/tisk.sh|ExecStart=/usr/local/sbin/tisk.sh|' $UNIT_S|grep -q '^ExecStart=/usr/local/sbin/tisk.sh' $UNIT_S"
    "C2|sed -i 's|^WorkingDirectory=.*|WorkingDirectory=/srv/tisk-fronta|' $UNIT_S|grep -q '^WorkingDirectory=/srv/tisk-fronta' $UNIT_S"
    "C3|sed -i 's|^After=network.target|After=tiskarna.service\nRequires=tiskarna.service|' $UNIT_S|grep -q '^Requires=tiskarna.service' $UNIT_S"
  )

  SEZNAM=""
  zaved_z_fondu() {   # zaved_z_fondu <jméno pole> <index 1..3>
    local -n fond="$1"
    local i="$2" pokus polozka kod prikaz overeni
    for pokus in 0 1 2; do
      polozka="${fond[$(( (i - 1 + pokus) % 3 ))]}"
      kod="${polozka%%|*}"
      prikaz="${polozka#*|}"; prikaz="${prikaz%|*}"
      overeni="${polozka##*|}"
      lxc exec "$SERVER_KONT" -- bash -c "$prikaz" >/dev/null 2>&1
      if lxc exec "$SERVER_KONT" -- bash -c "$overeni" >/dev/null 2>&1; then
        SEZNAM="$SEZNAM $kod"
        return 0
      fi
    done
    return 1
  }

  # POŘADÍ JE PODSTATNÉ: kategorie C sahá na tytéž řádky unitu jako A, ale
  # hledá je v původním znění. Kdyby šlo A první, přepsalo by `ExecStart=`
  # na `ExecStrat=` a C1 by se nechytilo.
  zaved_z_fondu FOND_C "$(lab_vyber 3 1 403)" || CHYBA_FONDU=1
  zaved_z_fondu FOND_B "$(lab_vyber 3 1 402)" || CHYBA_FONDU=1
  zaved_z_fondu FOND_A "$(lab_vyber 3 1 401)" || CHYBA_FONDU=1

  if [ "${CHYBA_FONDU:-0}" -eq 1 ]; then
    echo "  Prostředí se nepodařilo připravit (závadu nešlo zavést)." >&2
    echo "  Spusťte ./reset.sh a potom znovu ./start.sh." >&2
    exit 1
  fi

  if ! lxc config set "$SERVER_KONT" "$ZAVEDENO_KLIC" "${SEZNAM# }" 2>/dev/null; then
    echo "  Nepodařilo se uložit stav cvičení do konfigurace kontejneru." >&2
    echo "  Spusťte ./reset.sh a potom znovu ./start.sh." >&2
    exit 1
  fi

  # --no-block: závada A3 (Type=forking u programu, který se nerozdvojí) by
  # jinak nechala `systemctl start` čekat celých 90 sekund TimeoutStartSec
  # a start.sh by vypadal zaseknutě.
  lxc exec "$SERVER_KONT" -- bash -c \
    "systemctl daemon-reload; systemctl enable tisk >/dev/null 2>&1; systemctl start --no-block tisk" \
    >/dev/null 2>&1
  NOVE=1
else
  NOVE=0
fi

[ -s "$PROTOKOL" ] || vyrob_protokol

cat <<EOF

  Server běží.

    Připojení:  ssh $SERVER_UCET@$SERVER_IP
    Přihlášení: $PRIHLASENI

    Nefunkční služba:  tisk
    Uživatel služby:   $SLUZBA_UCET
    Protokol:          $PROTOKOL   (na stanici)

$( [ "$NOVE" -eq 1 ] \
   && printf '  Služba tisk je nasazená a nefunguje. Jsou v ní TŘI závady, každá\n  jiného druhu. Najděte je všechny a opravte.' \
   || printf '  Pokračujete tam, kde jste skončili — závady zůstávají tak, jak jste\n  je nechali. Znovu vylosovat je umí jedině ./reset.sh.' )

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/10-sluzba-nenabehla && ./check.sh --krok 1

EOF
