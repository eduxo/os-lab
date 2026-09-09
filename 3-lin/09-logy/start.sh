#!/bin/bash
# 3/09 — Logy: journalctl. Prostředí: server sluzby-XX přes SSH.
#
# Instaluje VLASTNÍ službu `sber`, ne `hlidac` ze sedmičky — jinak by
# spuštěním tohohle start.sh šlo splnit cvičení 7 zadarmo.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="sluzby-$ZAK2"
source "$(dirname "$0")/../../lib/server-lib.sh"

LOGY="$HOME/netlab/logy"
FORMULAR="$LOGY/formular.txt"
CHYB=$(( 2 + $(lab_vyber 4 1 390) ))     # kolik chyb služba při startu zaloguje

vyrob_formular() {
  mkdir -p "$LOGY"
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Logy — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# chyb = kolik chybových záznamů má služba sber v journalu
# cas  = čas PRVNÍHO chybového záznamu ve tvaru HH:MM:SS
chyb:
cas:
FORMULAR_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO"
fi

# ── služba, jejíž log se bude číst ────────────────────────────────
# Obsah jde přes `tee` s uvozeným heredokem, ne uvnitř `bash -c "…"` —
# jinak by se $CHYB a $(date) vyhodnotily na stanici.
if ! lxc exec "$SERVER_KONT" -- test -f /usr/local/bin/sber.sh; then
  lxc exec "$SERVER_KONT" -- tee /usr/local/bin/sber.sh >/dev/null <<'SBER'
#!/bin/bash
# Sběr dat z čidel. Píše do journalu; předřazené <N> je priorita zprávy,
# kterou systemd rozpozná — <3> je chyba, <6> běžná informace.
POCET_CHYB="${SBER_CHYB:-3}"
for i in $(seq 1 "$POCET_CHYB"); do
  echo "<3>CHYBA: cidlo $i neodpovida"
  sleep 1
done
while true; do
  echo "<6>sber probiha, vse v poradku"
  sleep 20
done
SBER
  lxc exec "$SERVER_KONT" -- chmod +x /usr/local/bin/sber.sh
fi

if ! lxc exec "$SERVER_KONT" -- test -f /etc/systemd/system/sber.service; then
  lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/sber.service >/dev/null <<UNIT
[Unit]
Description=Sběr dat z čidel

[Service]
Environment=SBER_CHYB=$CHYB
ExecStart=/usr/local/bin/sber.sh
Restart=no

[Install]
WantedBy=multi-user.target
UNIT
  lxc exec "$SERVER_KONT" -- systemctl daemon-reload >/dev/null 2>&1
fi
lxc exec "$SERVER_KONT" -- systemctl enable --now sber >/dev/null 2>&1
# Chyby se logují jen při startu. Když služba běží z minula, log už je hotový;
# když ne, chvíli počkáme, ať má žák co číst.
if ! lxc exec "$SERVER_KONT" -- bash -c "systemctl is-active --quiet sber"; then
  lxc exec "$SERVER_KONT" -- systemctl restart sber >/dev/null 2>&1
  # Čeká se jen tehdy, když se opravdu startovalo. U běžícího serveru je log
  # dávno hotový a zdržení by bylo bezdůvodné.
  sleep $(( CHYB + 2 ))
fi

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

    Služba k prozkoumání:  sber
    Formulář:              $FORMULAR   (na stanici)

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/09-logy && ./check.sh --krok 1

EOF
