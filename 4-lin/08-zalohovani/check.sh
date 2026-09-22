#!/bin/bash
# 4/08 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="zaloha-$ZAK2"   # až ZA lab-lib.sh: ZAK2 vzniká teprve tam
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/_data.sh"

LAB="$HOME/netlab/zalohy"
OSTRA="$LAB/ostra"
REPO="$LAB/repo"
HESLO="$LAB/heslo.txt"
FORMULAR="$LAB/zaloha.txt"
NAZEV="ZALOHY-$ZAK2"
OFFSITE=/srv/offsite

zkontroluj_disky 1 || exit 1
DISK="$(labovy_disk 1)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }
CAST2="$(lsblk -rno NAME,TYPE "/dev/$DISK" 2>/dev/null | awk '$2=="part"{print $1}' | sed -n 2p)"

# Heslo zná jen žák. Kontrola ho nečte ani nikam neukládá — jen ukáže
# resticu na soubor, který si žák vyrobil. Bez něj se do repozitáře
# nedostane nikdo, ani tenhle skript.
export RESTIC_PASSWORD_FILE="$HESLO"
# Bez BatchMode by se sftp při neznámém otisku serveru zeptal a kontrola
# by se zasekla uprostřed hodiny.
SFTP_OPT=(-o "sftp.args=-o BatchMode=yes -o StrictHostKeyChecking=accept-new")

restic_lze() { [ -s "$HESLO" ] && command -v restic >/dev/null 2>&1; }
pocet_snimku() {  # pocet_snimku REPOZITÁŘ → číslo (0 když se nedá přečíst)
  local r="$1" v
  v="$(restic -q -r "$r" snapshots --json 2>/dev/null | grep -o '"short_id"' | grep -c '')"
  printf '%s\n' "${v:-0}"
}

krok 1 "Úložiště pro zálohy"
require_soubor_neprazdny "$FORMULAR" \
  "formulář zaloha.txt je na místě" \
  "chybí ~/netlab/zalohy/zaloha.txt — spusťte ./start.sh"
require_prikaz restic "restic je na stanici" "restic na stanici chybí — řekněte to vyučujícímu"
if [ -z "$CAST2" ]; then
  chyba "na /dev/$DISK není druhý oddíl"
else
  FS="$(lsblk -no FSTYPE "/dev/$CAST2" 2>/dev/null | tr -d ' ' | head -1)"
  LBL="$(lsblk -no LABEL "/dev/$CAST2" 2>/dev/null | sed 's/ *$//' | head -1)"
  [ "$FS" = "ext4" ] \
    && uspech "na druhém oddílu je souborový systém ext4" \
    || chyba "na druhém oddílu je '${FS:-nic}', zadání chce ext4"
  [ "$LBL" = "$NAZEV" ] \
    && uspech "souborový systém má návěští $NAZEV" \
    || chyba "návěští je '${LBL:-žádné}', má být $NAZEV"
  CIL="$(findmnt -no TARGET "/dev/$CAST2" 2>/dev/null | head -1)"
  [ "$CIL" = "$REPO" ] \
    && uspech "oddíl je připojený v $REPO" \
    || chyba "oddíl není připojený v $REPO"
  require_zaznam "$FORMULAR" oddil "/dev/$CAST2" "ve formuláři je oddíl se zálohami"
fi
# Zálohy nepatří na tentýž svazek jako data — to je celý smysl odděleného
# oddílu. Kdyby repozitář ležel na systémovém disku, jeden výpadek vezme obojí.
ZDROJ_REPO="$(findmnt -no SOURCE "$REPO" 2>/dev/null | head -1)"
if [ -n "$CAST2" ] && [ "$ZDROJ_REPO" = "/dev/$CAST2" ]; then
  uspech "repozitář leží na vlastním oddílu, ne na systémovém disku"
else
  chyba "v $REPO není připojený váš oddíl se zálohami"
fi

krok 2 "Repozitář"
if [ ! -s "$HESLO" ]; then
  chyba "chybí soubor s heslem k repozitáři ($HESLO)"
  poznamka "bez hesla se do repozitáře nedostanete ani vy, ani tahle kontrola"
else
  uspech "soubor s heslem existuje"
  PRAVA="$(stat -c %a "$HESLO" 2>/dev/null)"
  [ "$PRAVA" = "600" ] \
    && uspech "heslo smí číst jen jeho vlastník (600)" \
    || chyba "soubor s heslem má práva ${PRAVA:-?}, má mít 600"
fi
if restic_lze && restic -q -r "$REPO" cat config >/dev/null 2>&1; then
  uspech "repozitář v $REPO je inicializovaný a heslo k němu sedí"
else
  chyba "repozitář v $REPO se nepodařilo otevřít"
  poznamka "zakládá se: restic -r $REPO init"
fi

krok 3 "Zálohy a snímky"
SNIMKU=0
if restic_lze; then SNIMKU="$(pocet_snimku "$REPO")"; fi
if [ "$SNIMKU" -ge 2 ]; then
  uspech "v repozitáři jsou aspoň dva snímky (máte $SNIMKU)"
else
  chyba "v repozitáři jsou snímky: $SNIMKU — zadání chce aspoň dva"
fi
if restic_lze && restic -q -r "$REPO" snapshots 2>/dev/null | grep -qF "$OSTRA"; then
  uspech "snímky obsahují cestu s ostrými daty"
else
  chyba "mezi snímky nevidím zálohu $OSTRA"
fi
require_zaznam_tvar "$FORMULAR" snimku '^[0-9]+$' \
  "ve formuláři je počet snímků" \
  "ve formuláři chybí počet snímků"

krok 4 "Obnova a ověření"
# Tohle je jádro celého labu: záloha, kterou nikdo nezkusil obnovit, není
# záloha. Obsah se počítá z čísla žáka, takže se pozná i soubor, který se
# sice jmenuje správně, ale vznikl znovu místo obnovy.
if [ ! -d "$OSTRA/smlouvy" ]; then
  chyba "adresář se smlouvami na stanici není"
else
  CHYBI=0; JINAK=0
  for I in $(seq 1 "$SMLUV"); do
    S="$OSTRA/smlouvy/$(smlouva_jmeno "$I")"
    if [ ! -f "$S" ]; then CHYBI=$(( CHYBI + 1 )); continue; fi
    O="$(smlouva_obsah "$I" | sha256sum | cut -d' ' -f1)"
    A="$(sha256sum < "$S" | cut -d' ' -f1)"
    [ "$O" = "$A" ] || JINAK=$(( JINAK + 1 ))
  done
  if [ "$CHYBI" = "0" ] && [ "$JINAK" = "0" ]; then
    uspech "všech $SMLUV smluv je zpátky a nepoškozených"
  else
    chyba "smluv chybí: $CHYBI, poškozených: $JINAK (z $SMLUV)"
  fi
  # Samotná přítomnost smluv není důkaz obnovy — leží tam od start.sh.
  # Důkazem je STAV, který vznikne jedině smazáním a obnovou z PRVNÍHO
  # snímku: dodatek.txt byl až ve druhém, takže se vrátit nesmí.
  if [ -e "$OSTRA/smlouvy/dodatek.txt" ]; then
    chyba "obnova zatím neproběhla tak, jak ji zadání popisuje"
    poznamka "obnovuje se z PRVNÍHO snímku — ten, ve kterém dodatek ještě nebyl"
  else
    uspech "data odpovídají obnově z prvního snímku"
  fi
fi
require_zaznam_tvar "$FORMULAR" obnoveno '^[0-9]+$' \
  "ve formuláři je počet obnovených souborů" \
  "ve formuláři chybí počet obnovených souborů"

krok 5 "Offsite kopie"
if ! krok_aktivni 5; then :
elif ! server_bezi; then
  chyba "kontejner $SERVER_KONT neběží"
  poznamka "postaví ho: ./start.sh"
else
  uspech "kontejner $SERVER_KONT běží"
  SERVER_IP="$(lxc exec "$SERVER_KONT" -- bash -c \
    "ip -4 -o addr show dev eth0 2>/dev/null | awk '{print \$4}' | cut -d/ -f1" \
    2>/dev/null | tr -d '\r' | head -1)"
  VZDALENY="sftp:$SERVER_UCET@${SERVER_IP:-nic}:$OFFSITE"
  if restic_lze && restic -q "${SFTP_OPT[@]}" -r "$VZDALENY" cat config >/dev/null 2>&1; then
    uspech "vzdálený repozitář v kontejneru je dostupný"
    VS="$(restic -q "${SFTP_OPT[@]}" -r "$VZDALENY" snapshots --json 2>/dev/null | grep -o '"short_id"' | grep -c '')"
    [ "${VS:-0}" -ge 1 ] \
      && uspech "v offsite kopii je aspoň jeden snímek (máte ${VS:-0})" \
      || chyba "offsite repozitář existuje, ale je prázdný"
  else
    chyba "vzdálený repozitář se nepodařilo otevřít"
    poznamka "zakládá se: restic -r sftp:$SERVER_UCET@ADRESA:$OFFSITE init"
  fi
  [ -n "$SERVER_IP" ] && require_zaznam "$FORMULAR" offsite "$SERVER_IP" \
    "ve formuláři je adresa offsite kontejneru"
fi

krok 6 "Celistvost"
if krok_aktivni 6; then
# Poslední návyk, který má lab předat: o záloze se nemluví jako o hotové,
# dokud ji nástroj sám neoznačí za neporušenou.
if restic_lze && restic -q -r "$REPO" check >/dev/null 2>&1; then
  uspech "restic check: místní repozitář je neporušený"
else
  chyba "restic check na místním repozitáři neprošel"
  poznamka "spusťte: restic -r $REPO check"
fi
fi

vypis_souhrn
