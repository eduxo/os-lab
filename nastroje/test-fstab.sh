#!/bin/bash
# Test emergency shellu (předpoklad labu 4/7).
#
# ⚠️ JEDINÝ DESTRUKTIVNÍ TEST v sadě: záměrně rozbije /etc/fstab tak,
#    aby systém při dalším startu spadl do nouzového režimu.
#    PŘED SPUŠTĚNÍM UDĚLEJ SNAPSHOT VM.
#
# ⚠️⚠️ NIKDY NA VZDÁLENÉM STROJI, KE KTERÉMU NEMÁŠ KONZOLI.
#    V nouzovém režimu systemd NESPUSTÍ SÍŤ — SSH ani XRDP nejedou a ke shellu
#    se přes síť nedostaneš. Potřebuješ konzoli hypervizoru (Proxmox noVNC,
#    vSphere, IPMI/iDRAC) nebo fyzický monitor. Jinak stroj oživíš jen snapshotem.
#
# Použití:
#   bash ~/os-lab/nastroje/test-fstab.sh stav      — co je teď v fstab, existuje záloha?
#   bash ~/os-lab/nastroje/test-fstab.sh rozbij    — přidá vadný řádek (ptá se na potvrzení)
#   bash ~/os-lab/nastroje/test-fstab.sh oprav     — obnoví fstab ze zálohy
#
# V nouzovém shellu je kořen jen pro čtení — skript si ho sám přepne
# do zápisu, když je potřeba.

set -uo pipefail

ZALOHA=/root/fstab.pred-testem
VADNY_UUID="00000000-0000-0000-0000-000000000000"
PRIPOJ=/mnt/test-fstab
ZNACKA="# TEST-FSTAB-EDUXO"

ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$1"; }
varuj() { printf '  \033[0;33m!\033[0m %s\n' "$1"; }
chyba() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; }
info()  { printf '    %s\n' "$1"; }
nadpis(){ printf '\n\033[1;34m== %s ==\033[0m\n' "$1"; }

# Nápovědu a stav zvládneme bez roota; pro zásahy se povýšíme.
# POZOR: $0 může být relativní ("bash skript.sh") a sudo by ho hledalo v PATH,
# proto vždy absolutní cesta a explicitní bash (skript nemusí mít +x).
SKRIPT="$(readlink -f "$0")"

if [ "${1:-}" = "rozbij" ] || [ "${1:-}" = "oprav" ] || [ "${1:-}" = "stav" ]; then
  if [ "$(id -u)" != "0" ]; then
    echo "  (skript potřebuje root — volám sudo)"
    exec sudo -- bash "$SKRIPT" "$@"
  fi
fi

zajisti_zapis() {
  if findmnt -no OPTIONS / | grep -qw ro; then
    varuj "Kořenový systém je jen pro čtení — přepínám do zápisu"
    mount -o remount,rw / && ok "Přepnuto" || { chyba "Nelze přepnout"; exit 1; }
  fi
}

case "${1:-}" in

stav)
  nadpis "Stav"
  if grep -q "$ZNACKA" /etc/fstab; then
    varuj "fstab JE rozbitý (obsahuje testovací řádek)"
    grep -n "$ZNACKA" -A1 /etc/fstab | sed 's/^/    /'
  else
    ok "fstab je v pořádku (testovací řádek tam není)"
  fi
  [ -f "$ZALOHA" ] && ok "Záloha existuje: $ZALOHA" || info "Záloha zatím není"
  echo
  info "Aktuální /etc/fstab:"
  sed 's/^/      /' /etc/fstab
  ;;

rozbij)
  nadpis "Rozbití fstab"
  if grep -q "$ZNACKA" /etc/fstab; then
    varuj "fstab už rozbitý je. Nejdřív 'oprav'."; exit 1
  fi
  echo
  printf '  \033[0;31mTOHLE ZPŮSOBÍ, ŽE SYSTÉM PŘÍŠTĚ NENABĚHNE NORMÁLNĚ.\033[0m\n'
  info "Přesně to chceme otestovat — ale jen když máš snapshot VM."
  echo
  # Jsme na vzdálené session? Pak hrozí, že se ke stroji už nedostaneme.
  VZDALENE=0
  [ -n "${SSH_CONNECTION:-}" ] && VZDALENE=1
  [ -n "${XRDP_SESSION:-}" ] && VZDALENE=1
  loginctl show-session "${XDG_SESSION_ID:-}" -p Remote 2>/dev/null | grep -q "Remote=yes" && VZDALENE=1

  if [ "$VZDALENE" = "1" ]; then
    echo
    printf '  \033[0;31m╔═══════════════════════════════════════════════════════════╗\033[0m\n'
    printf '  \033[0;31m║  PRACUJEŠ PŘES SÍŤ (SSH / XRDP)                           ║\033[0m\n'
    printf '  \033[0;31m╚═══════════════════════════════════════════════════════════╝\033[0m\n'
    info "V nouzovém režimu systemd NESPUSTÍ síťové služby."
    info "Po restartu ztratíš SSH i XRDP a ke shellu se přes síť NEDOSTANEŠ."
    echo
    info "Pokračuj jen tehdy, když máš JISTÝ konzolový přístup:"
    info "  • webová konzole hypervizoru (Proxmox noVNC, vSphere, Hyper-V)"
    info "  • IPMI / iDRAC / iLO"
    info "  • fyzický monitor a klávesnice"
    info "Samotný snapshot stačí taky — ale jen když ho umíš obnovit bez konzole."
    echo
    read -r -p "  Napiš MAM KONZOLI (nebo Enter pro zrušení): " K
    [ "$K" = "MAM KONZOLI" ] || { info "Zrušeno, nic se nezměnilo. Rozumné rozhodnutí."; exit 0; }
  fi

  read -r -p "  Máš hotový snapshot? Napiš ROZBIT pro pokračování: " ODP
  [ "$ODP" = "ROZBIT" ] || { info "Zrušeno, nic se nezměnilo."; exit 0; }

  zajisti_zapis
  cp /etc/fstab "$ZALOHA"           && ok "Záloha: $ZALOHA"
  cp /etc/fstab /etc/fstab.pred-testem && ok "Kopie zálohy: /etc/fstab.pred-testem"
  mkdir -p "$PRIPOJ"
  {
    echo ""
    echo "$ZNACKA  (smaž tenhle a následující řádek)"
    echo "UUID=$VADNY_UUID  $PRIPOJ  ext4  defaults  0  2"
  } >> /etc/fstab
  ok "Vadný řádek přidán"

  cat <<'POSTUP'

  ── CO SE MÁ STÁT ──────────────────────────────────────────────
  Po restartu systém nenajde zařízení s tím UUID, počká na timeout
  (~90 s) a spadne do nouzového režimu (emergency mode).

  ÚSPĚCH testu = dostaneš se ke shellu.
     • Když se objeví výzva "Give root password for maintenance"
       a heslo roota funguje → OK, lab 4/7 je proveditelný.
     • Když projde bez hesla → taky OK.
     • Když tě to nepustí dál → lab 4/7 se musí přepsat.

  ── OPRAVA (v nouzovém shellu) ─────────────────────────────────
  Skript:
      bash /cesta/k/test-fstab.sh oprav

  Nebo ručně, kdyby skript nebyl po ruce:
      mount -o remount,rw /
      nano /etc/fstab          (smaž poslední dva řádky se značkou)
      reboot

  Nouzová varianta, kdyby ani to nešlo: obnovit snapshot VM.
  ───────────────────────────────────────────────────────────────

POSTUP
  read -r -p "  Restartovat teď? [a/N] " R
  [[ "$R" =~ ^[aAyY]$ ]] && { info "Restartuji..."; sleep 2; reboot; } \
                         || info "Restartuj sám, až budeš připraven: sudo reboot"
  ;;

oprav)
  nadpis "Oprava fstab"
  zajisti_zapis
  if [ -f "$ZALOHA" ]; then
    cp "$ZALOHA" /etc/fstab && ok "fstab obnoven ze zálohy $ZALOHA"
  elif [ -f /etc/fstab.pred-testem ]; then
    cp /etc/fstab.pred-testem /etc/fstab && ok "fstab obnoven z /etc/fstab.pred-testem"
  else
    varuj "Záloha nenalezena — odstraňuji testovací řádky přímo"
    sed -i "/$ZNACKA/,+1d" /etc/fstab && ok "Testovací řádky odstraněny"
  fi
  rmdir "$PRIPOJ" 2>/dev/null
  if findmnt --verify --verbose >/dev/null 2>&1; then
    ok "findmnt --verify: fstab je v pořádku"
  else
    varuj "findmnt hlásí výhrady — zkontroluj ručně: cat /etc/fstab"
  fi
  echo
  info "Teď restartuj: reboot"
  ;;

*)
  cat <<'NAPOVEDA'
Test emergency shellu (lab 4/7).

  bash ~/os-lab/nastroje/test-fstab.sh stav      — co je teď v fstab
  bash ~/os-lab/nastroje/test-fstab.sh rozbij    — přidá vadný řádek (ptá se na potvrzení)
  bash ~/os-lab/nastroje/test-fstab.sh oprav     — obnoví fstab ze zálohy

⚠️ Před 'rozbij' udělej snapshot VM. Systém po restartu nenaběhne normálně,
   a to je záměr — testuje se, jestli se dostaneš do nouzového shellu.

⚠️ NIKDY přes SSH ani XRDP bez konzolového přístupu k hypervizoru:
   v nouzovém režimu neběží síť, takže se ke stroji přes síť nepřipojíš.
NAPOVEDA
  ;;
esac
