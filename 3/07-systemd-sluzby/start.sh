#!/bin/bash
# 3/07 — systemd: služby. Prostředí: LXD kontejner, přístup přes SSH.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="sluzby-$ZAK2"
OBRAZ="ubuntu-24.04"          # lokální alias z šablony VM (bez stahování)

if lxc info "$KONT" >/dev/null 2>&1; then
  STAV="$(lxc info "$KONT" | awk '/^Status/{print tolower($2)}')"
  [ "$STAV" != "running" ] && lxc start "$KONT" >/dev/null 2>&1
  echo
  echo "  Server $KONT už existuje — pokračujete tam, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  echo "    ssh sysadmin@$(lxc list "^${KONT}$" -c4 --format csv | cut -d' ' -f1)"
  echo
  exit 0
fi

echo "  Stavím server $KONT…"
lxc launch "$OBRAZ" "$KONT" >/dev/null 2>&1 || {
  echo "  Server se nepodařilo spustit. Zkontrolujte, že LXD běží: lxc list"; exit 1; }

# Čekáme na adresu, ne na `systemctl is-system-running` — ten v kontejneru
# obvykle skončí na "degraded" a smyčka by vždy vyčerpala celý timeout.
IP=""
for _ in $(seq 1 60); do
  IP="$(lxc list "^${KONT}$" -c4 --format csv | cut -d' ' -f1)"
  [ -n "$IP" ] && break
  sleep 1
done
[ -z "$IP" ] && { echo "  Server nedostal IP adresu — zavolejte vyučujícího."; exit 1; }

# ── přístup přes SSH (žák lxc nepoužívá) ────────────────────────────
lxc exec "$KONT" -- bash -c "
  useradd -m -s /bin/bash sysadmin 2>/dev/null
  usermod -aG sudo sysadmin
  # historie se zapisuje průběžně, ne až při odhlášení
  grep -q 'history -a' /home/sysadmin/.bashrc || \
    echo \"PROMPT_COMMAND='history -a'\" >> /home/sysadmin/.bashrc
  mkdir -p /home/sysadmin/.ssh && chmod 700 /home/sysadmin/.ssh
  # sudo bez hesla: účet z useradd žádné heslo nemá, takže by se k rootu
  # nedostal žák s klíčem — a na zápisu do /etc/systemd/system stojí celý lab
  echo 'sysadmin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-sysadmin
  chmod 440 /etc/sudoers.d/90-sysadmin
" >/dev/null 2>&1

# ── B4: SSH je jediná cesta dovnitř — když chybí, musí to skript říct
lxc exec "$KONT" -- bash -c \
  "command -v sshd >/dev/null || { apt-get update -qq && apt-get install -y -qq openssh-server; }" \
  || { echo "  SSH server se nepodařilo nainstalovat — zavolejte vyučujícího."; exit 1; }
lxc exec "$KONT" -- systemctl enable --now ssh >/dev/null 2>&1
# Ubuntu 24.04 může mít SSH socket-aktivované (ssh.socket místo ssh.service)
lxc exec "$KONT" -- bash -c "systemctl is-active --quiet ssh || systemctl is-active --quiet ssh.socket" \
  || { echo "  SSH na serveru neběží — zavolejte vyučujícího."; exit 1; }

# Přihlášení klíčem (žák si ho vyrobil v cvičení 3/04). Když klíč nemá,
# nastavíme jednorázové heslo a vypíšeme ho — do repozitáře žádné nepatří.
KLIC="$(ls "$HOME"/.ssh/id_*.pub 2>/dev/null | head -1)"
if [ -n "$KLIC" ]; then
  lxc file push "$KLIC" "$KONT/home/sysadmin/.ssh/authorized_keys" >/dev/null 2>&1
  lxc exec "$KONT" -- chown -R sysadmin:sysadmin /home/sysadmin/.ssh
  PRIHLASENI="klíčem (bez hesla)"
else
  HESLO="hlidac$(( (ZAK * 137) % 900 + 100 ))"
  lxc exec "$KONT" -- bash -c "echo 'sysadmin:$HESLO' | chpasswd"
  # cloud image Ubuntu má PasswordAuthentication no — bez tohohle by heslo nefungovalo
  lxc exec "$KONT" -- bash -c \
    "printf 'PasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/99-lab.conf; systemctl restart ssh" >/dev/null 2>&1
  PRIHLASENI="heslem: $HESLO"
fi

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

    cd ~/os-lab/3/07-systemd-sluzby && ./check.sh --krok 1

EOF
