#!/bin/bash
# 3/07 — systemd: služby. Prostředí: LXD kontejner, přístup přes SSH.
#
# Server `sluzby-XX` sdílí celá rodina systemd (cvičení 7 až 10) a každé z nich
# ho umí postavit samo — pravidlo o nezávislosti na předchozím stavu.
# Stavbu drží lib/server-lib.sh; dřív tu byla vlastní kopie, ve které mimo jiné
# uvízla vada s pořadím drop-inů sshd (99-lab.conf se nikdy neuplatnil).
set -uo pipefail
# Pořadí je podstatné: lab-lib.sh dá $ZAK2, teprve pak se dá pojmenovat
# kontejner, a až potom se načte server-lib.sh, která to jméno použije.
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="sluzby-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi
KONT="$SERVER_KONT"
IP="$SERVER_IP"

# ── program, který má žák rozběhnout jako službu ────────────────────
# Poslouchá na portu a zároveň píše do logu — obojí pak jde ověřit.
# POZOR: obsah skriptu se posílá přes `tee` s uvozeným heredokem, ne uvnitř
# `bash -c "…"`. V dvojitých uvozovkách by se $PORT, $LOG i $(date) vyhodnotily
# na téhle stanici a se `set -u` by skript rovnou spadl.
lxc exec "$KONT" -- bash -c "
  useradd -r -s /usr/sbin/nologin 'hlidac$ZAK2' 2>/dev/null
  mkdir -p /opt/hlidac /var/log/hlidac /srv/stav
  chown 'hlidac$ZAK2:hlidac$ZAK2' /var/log/hlidac /srv/stav
"

lxc exec "$KONT" -- tee /opt/hlidac/hlidac.sh >/dev/null <<'HLIDAC'
#!/bin/bash
# Hlídač NetLab — hlásí stav na portu a zapisuje do logu.
# Port se předává proměnnou prostředí HLIDAC_PORT.
PORT="${HLIDAC_PORT:-9000}"
LOG=/var/log/hlidac/hlidac.log
( while true; do echo "$(date '+%F %T') hlidac bezi" >> "$LOG"; sleep 10; done ) &
exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory /srv/stav
HLIDAC
lxc exec "$KONT" -- chmod +x /opt/hlidac/hlidac.sh

if [ "$SERVER_NOVY" -eq 0 ]; then
  echo
  echo "  Server $SERVER_KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
fi

cat <<EOF

  Server je připravený.

    Jméno serveru:  $KONT
    Adresa:         $IP
    Přihlášení:     ssh sysadmin@$IP
                    $PRIHLASENI

  Na serveru najdete program /opt/hlidac/hlidac.sh, který zatím nikdo
  nespouští. Vaším úkolem je udělat z něj službu.

    Uživatel služby:  hlidac$ZAK2
    Port:             $ZAK_PORT
                      (program si ho bere z proměnné HLIDAC_PORT)

  Průběžná kontrola — ve druhém okně, na této stanici (ne na serveru):

    cd ~/os-lab/3-lin/07-systemd-sluzby && ./check.sh --krok 2

EOF
