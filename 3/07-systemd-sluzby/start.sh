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
  echo "    ssh sysadmin@$(lxc list "$KONT" -c4 --format csv | cut -d' ' -f1)"
  echo
  exit 0
fi

echo "  Stavím server $KONT…"
lxc launch "$OBRAZ" "$KONT" >/dev/null 2>&1 || {
  echo "  Server se nepodařilo spustit. Zkontrolujte, že LXD běží: lxc list"; exit 1; }

# počkáme, až kontejner nabootuje a chytne adresu
for _ in $(seq 1 30); do
  lxc exec "$KONT" -- systemctl is-system-running >/dev/null 2>&1 && break
  sleep 1
done

# ── přístup přes SSH (žák lxc nepoužívá) ────────────────────────────
lxc exec "$KONT" -- bash -c "
  useradd -m -s /bin/bash sysadmin 2>/dev/null
  usermod -aG sudo sysadmin
  # historie se zapisuje průběžně, ne až při odhlášení
  grep -q 'history -a' /home/sysadmin/.bashrc || \
    echo \"PROMPT_COMMAND='history -a'\" >> /home/sysadmin/.bashrc
  apt-get install -y -qq openssh-server >/dev/null 2>&1
  systemctl enable --now ssh >/dev/null 2>&1
  mkdir -p /home/sysadmin/.ssh && chmod 700 /home/sysadmin/.ssh
" >/dev/null 2>&1

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
  PRIHLASENI="heslem: $HESLO"
fi

# ── program, který má žák rozběhnout jako službu ────────────────────
# Poslouchá na portu a zároveň píše do logu — obojí pak jde ověřit.
lxc exec "$KONT" -- bash -c "
  useradd -r -s /usr/sbin/nologin hlidac$ZAK2 2>/dev/null
  mkdir -p /opt/hlidac /var/log/hlidac
  chown hlidac$ZAK2:hlidac$ZAK2 /var/log/hlidac
  cat > /opt/hlidac/hlidac.sh <<'EOF'
#!/bin/bash
# Hlídač NAKOLENI — hlásí stav na portu a zapisuje do logu.
PORT="${HLIDAC_PORT:-9000}"
LOG=/var/log/hlidac/hlidac.log
( while true; do echo "$(date '+%F %T') hlidac bezi" >> "$LOG"; sleep 10; done ) &
exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory /opt/hlidac
EOF
  chmod +x /opt/hlidac/hlidac.sh
"

IP="$(lxc list "$KONT" -c4 --format csv | cut -d' ' -f1)"

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

  Průběžná kontrola:  ./check.sh --krok 1

EOF
