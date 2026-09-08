#!/bin/bash
# 3/06 — Git: verzování skriptů a konfigurací. Prostředí: server-XX přes SSH.
#
# Cvičení staví na skriptu z pětky. Podle pravidla o nezávislosti ho ale
# start.sh doplní, když chybí — žák, který na pětce nebyl, začne bez potíží.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"

VERZE="$HOME/netlab/verzovani"
FORMULAR="$VERZE/formular.txt"
EMAIL="$ZAK_UZIVATEL@netlab.test"

vyrob_formular() {
  mkdir -p "$VERZE"
  cat > "$FORMULAR" <<FORMULAR_KONEC
# Verzování skriptů — vyplňte hodnoty za dvojtečku.
# Formulář je na STANICI, práce je na serveru.
#
# commitu     = kolik commitů má váš repozitář
# prvni       = zkrácený otisk (hash) prvního commitu
# ignorovano  = jméno souboru, který jste vyloučili ze sledování
commitu:
prvni:
ignorovano:
#
# E-mail commitera nastavte na: $EMAIL
FORMULAR_KONEC
}

postav_server || exit 1
if nasad_klic_ze_stanice; then
  PRIHLASENI="klíčem (bez hesla)"
else
  PRIHLASENI="heslem: $SERVER_HESLO   (klíč jste si zatím nevyrobili — viz cvičení 4)"
fi

# ── git a materiál k verzování ────────────────────────────────────
# Vše idempotentní: doplní se jen to, co chybí. Skript z pětky se nepřepisuje,
# když už existuje — je to žákova práce.
lxc exec "$SERVER_KONT" -- bash -c "
  command -v git >/dev/null || { apt-get update -qq && apt-get install -y -qq git; }
  mkdir -p /home/$SERVER_UCET/skripty
" >/dev/null 2>&1

# Náhrada pro žáka, který chyběl na pětce. SCHVÁLNĚ je to ROZPRACOVANÝ skript —
# bez shebangu a bez práva ke spuštění. Kdyby byl hotový, stačilo by pustit
# start.sh šestky a kontrola pětky by dala čtyři PASSy zadarmo. Verzovat
# rozpracovaný soubor jde stejně dobře jako hotový.
#
# Obsah jde přes `tee` s UVOZENÝM heredokem, ne uvnitř `bash -c "…"`. Tam by
# se $HOME i $(date) vyhodnotily na stanici a zpětná lomítka by se rozpadla —
# konvence repozitáře to zakazuje právě proto.
if ! lxc exec "$SERVER_KONT" -- test -s "/home/$SERVER_UCET/skripty/stav.sh"; then
  lxc exec "$SERVER_KONT" -- tee "/home/$SERVER_UCET/skripty/stav.sh" >/dev/null <<'SKRIPT_KONEC'
# ROZPRACOVÁNO — chybí shebang i právo ke spuštění (dodělá se ve cvičení 5).
LOG="$HOME/skripty/stav.log"
printf '%s %s
' "$(date '+%Y-%m-%d %H:%M')" "$(hostname)" >> "$LOG"
SKRIPT_KONEC
fi

# Log, který do repozitáře nepatří — je to výstup, ne zdroj.
if ! lxc exec "$SERVER_KONT" -- test -s "/home/$SERVER_UCET/skripty/stav.log"; then
  lxc exec "$SERVER_KONT" -- bash -c \
    "date '+%Y-%m-%d %H:%M' | tr -d '\n' > /home/$SERVER_UCET/skripty/stav.log
     printf ' %s 0\n' \"\$(hostname)\" >> /home/$SERVER_UCET/skripty/stav.log" >/dev/null 2>&1
fi
lxc exec "$SERVER_KONT" -- chown -R "$SERVER_UCET:$SERVER_UCET" \
  "/home/$SERVER_UCET/skripty" >/dev/null 2>&1

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
    K verzování: ~/skripty/  (na serveru)
    Formulář:    $FORMULAR   (na stanici)

  E-mail commitera nastavte na:  $EMAIL

  Kontrola běží na stanici:

    cd ~/os-lab/3-lin/06-git && ./check.sh --krok 1

EOF
