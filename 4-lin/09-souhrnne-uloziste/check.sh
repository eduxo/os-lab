#!/bin/bash
# 4/09 — ověření souhrnné práce. Části odpovídají úkolům A–F zadání.
#
# Je to OVĚŘOVACÍ cvičení: hlášky říkají, který POŽADAVEK ze zadání není
# splněný (ten je veřejný), ale neradí, jak ho splnit.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/_data.sh"

LAB="$HOME/netlab/souhrn"
PODKLADY="$LAB/podklady"
FORMULAR="$LAB/zakazka.txt"
PRIPOJ="$HOME/netlab/ucto"
REPO="$HOME/netlab/zalohy/repo"
HESLO="$HOME/netlab/zalohy/heslo.txt"
SKUPINA="data-$ZAK2"
SVAZEK="ucetnictvi"
NAZEV="UCTO-$ZAK2"
CESTA_LV="/dev/$SKUPINA/$SVAZEK"
VELIKOST="$(svazek_velikost)"
MILNIK="$PROJEKT_PRIPOJ/dokumentace/zalohovaci-plan.md"
export RESTIC_PASSWORD_FILE="$HESLO"
projekt_pripoj >/dev/null 2>&1 || true

lvm_dotaz() {
  local p="$1" s="$2"; local -a cil=(); [ -n "${3:-}" ] && cil=("$3")
  { sudo -n "$p" --noheadings --units m --nosuffix -o "$s" "${cil[@]}" 2>/dev/null \
    || sudo "$p" --noheadings --units m --nosuffix -o "$s" "${cil[@]}" 2>/dev/null; } \
    | sed 's/^ *//; s/ *$//'
}
restic_lze() { [ -s "$HESLO" ] && command -v restic >/dev/null 2>&1; }

krok 1 "A — logický svazek"
require_soubor_neprazdny "$FORMULAR" \
  "formulář zakazka.txt je na místě" \
  "chybí ~/netlab/souhrn/zakazka.txt — spusťte ./start.sh"
LV_MIB="$(lvm_dotaz lvs lv_size "$CESTA_LV" | cut -d. -f1)"
if [ -z "$LV_MIB" ]; then
  chyba "logický svazek $SVAZEK ve skupině $SKUPINA neexistuje"
else
  uspech "logický svazek $SVAZEK existuje"
  ROZDIL=$(( LV_MIB - VELIKOST )); [ "$ROZDIL" -lt 0 ] && ROZDIL=$(( -ROZDIL ))
  [ "$ROZDIL" -le 8 ] \
    && uspech "svazek má zadanou velikost (${LV_MIB} MiB)" \
    || chyba "svazek má ${LV_MIB} MiB, zadání chce $VELIKOST MiB"
fi
# Svazek musí ležet UVNITŘ šifrovaného kontejneru — jinak zakázka sice
# funguje, ale data nejsou chráněná a celý loňský blok byl k ničemu.
PV="$( { sudo -n pvs --noheadings -o pv_name --select "vg_name=$SKUPINA" 2>/dev/null \
          || sudo pvs --noheadings -o pv_name --select "vg_name=$SKUPINA" 2>/dev/null; } | tr -d ' ')"
if printf '%s' "$PV" | grep -q '/dev/mapper/'; then
  uspech "skupina svazků leží uvnitř šifrovaného kontejneru"
else
  chyba "skupina svazků neleží uvnitř šifrovaného kontejneru"
fi
FS="$(lsblk -no FSTYPE "$CESTA_LV" 2>/dev/null | tr -d ' ' | head -1)"
LBL="$(lsblk -no LABEL "$CESTA_LV" 2>/dev/null | sed 's/ *$//' | head -1)"
[ "$FS" = "ext4" ] && uspech "na svazku je ext4" || chyba "na svazku není ext4"
[ "$LBL" = "$NAZEV" ] \
  && uspech "souborový systém má návěští $NAZEV" \
  || chyba "návěští není $NAZEV"
require_zaznam "$FORMULAR" svazek "$CESTA_LV" "ve formuláři je cesta ke svazku"

krok 2 "B — trvalé připojení"
RADEK="$(grep -vE '^[[:space:]]*(#|$)' /etc/fstab 2>/dev/null \
  | awk -v c="$PRIPOJ" '$2==c {print; exit}')"
if [ -z "$RADEK" ]; then
  chyba "v /etc/fstab není záznam, který by připojoval $PRIPOJ"
else
  uspech "v /etc/fstab je záznam pro $PRIPOJ"
  Z="$(printf '%s' "$RADEK" | awk '{print $1}')"
  case "$Z" in
    UUID=*|LABEL=*|/dev/mapper/*|"/dev/$SKUPINA/"*)
      uspech "záznam stojí na označení, které přesun disků nerozhodí" ;;
    *)
      chyba "záznam neodpovídá požadavku na označení svazku" ;;
  esac
  V="$(printf '%s' "$RADEK" | awk '{print $4}')"
  case ",$V," in *,nofail,*) uspech "záznam má nofail" ;;
    *) chyba "záznam nemá nofail — výpadek svazku by zastavil start stanice" ;;
  esac
fi
if sudo -n findmnt --verify 2>&1 | grep -qF '[E]' || findmnt --verify 2>&1 | grep -qF '[E]'; then
  chyba "findmnt --verify hlásí v /etc/fstab chybu"
else
  uspech "findmnt --verify na /etc/fstab nic nenamítá"
fi
# Nestačí „něco je připojené" — musí to být TEN svazek. Jinak by prošel
# i prostý adresář na systémovém disku, do kterého žák dávky zkopíruje.
SRC="$(findmnt -no SOURCE "$PRIPOJ" 2>/dev/null | head -1)"
SVAZEK_PRIPOJEN=0
if [ -n "$SRC" ] && [ "$(readlink -f "$SRC" 2>/dev/null)" = "$(readlink -f "$CESTA_LV" 2>/dev/null)" ]; then
  uspech "v $PRIPOJ je připojený svazek $SVAZEK"
  SVAZEK_PRIPOJEN=1
else
  chyba "v $PRIPOJ není připojený svazek ze zadání"
fi

krok 3 "C — data zakázky"
if [ "${SVAZEK_PRIPOJEN:-0}" != "1" ]; then
  chyba "dávky se kontrolují až na připojeném svazku"
  poznamka "nejdřív splňte úkol B"
else
CHYBI=0; JINAK=0
for I in $(seq 1 "$DAVEK"); do
  S="$PRIPOJ/$(davka_jmeno "$I")"
  if [ ! -f "$S" ]; then CHYBI=$(( CHYBI + 1 )); continue; fi
  O="$(davka_obsah "$I" | sha256sum | cut -d' ' -f1)"
  A="$(sha256sum < "$S" | cut -d' ' -f1)"
  [ "$O" = "$A" ] || JINAK=$(( JINAK + 1 ))
done
if [ "$CHYBI" = "0" ] && [ "$JINAK" = "0" ]; then
  uspech "všech $DAVEK dávek je na svazku a nezměněných"
else
  chyba "dávek chybí: $CHYBI, změněných: $JINAK (z $DAVEK)"
fi
fi

krok 4 "D — záloha"
if ! restic_lze; then
  chyba "repozitář ze cvičení 8 není použitelný (chybí heslo nebo restic)"
elif ! restic -q -r "$REPO" cat config >/dev/null 2>&1; then
  chyba "repozitář v $REPO se nepodařilo otevřít"
else
  uspech "repozitář ze cvičení 8 je dostupný"
  if restic -q -r "$REPO" snapshots --tag ucetnictvi 2>/dev/null | grep -qF "$PRIPOJ"; then
    uspech "v repozitáři je snímek zakázky označený značkou ucetnictvi"
  else
    chyba "v repozitáři není snímek $PRIPOJ se značkou ucetnictvi"
  fi
fi

krok 5 "E — doklad o obnově"
if krok_aktivni 5; then
PREVZETI="$PRIPOJ/prevzeti.txt"
SNIMEK="$(_zaznam "$FORMULAR" snimek)"
if [ -z "$SNIMEK" ]; then
  chyba "ve formuláři chybí ID snímku, ze kterého jste obnovovali"
elif ! restic_lze; then
  chyba "repozitář není použitelný, snímek nelze ověřit"
elif restic -q -r "$REPO" snapshots 2>/dev/null | grep -qF "$SNIMEK"; then
  uspech "snímek $SNIMEK v repozitáři opravdu je"
else
  chyba "snímek z formuláře v repozitáři nenajdu"
fi
# Porovnávají se TŘI věci: co je v záloze, co leží na svazku a co je
# ve formuláři. Nic z toho se nedá dopočítat od stolu — soubor vyrobil žák.
if [ ! -s "$PREVZETI" ]; then
  chyba "na svazku chybí převzetí, které má zadání doložit"
else
  NA_DISKU="$(sha256sum < "$PREVZETI" | cut -d' ' -f1)"
  ZE_ZALOHY=""
  if restic_lze && [ -n "$SNIMEK" ]; then
    ZE_ZALOHY="$(restic -q -r "$REPO" dump "$SNIMEK" "$PREVZETI" 2>/dev/null | sha256sum | cut -d' ' -f1)" \
      || ZE_ZALOHY=""
    # Otisk prázdného vstupu není důkaz: když dump selže, sha256sum stejně
    # něco vypíše. Prázdný výsledek se musí poznat.
    [ "$ZE_ZALOHY" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ] && ZE_ZALOHY=""
  fi
  if [ -n "$ZE_ZALOHY" ] && [ "$ZE_ZALOHY" = "$NA_DISKU" ]; then
    uspech "soubor na svazku sedí s tím, co je ve snímku"
  else
    chyba "soubor na svazku neodpovídá tomu, co je ve snímku"
  fi
  require_zaznam "$FORMULAR" otisk "$NA_DISKU" \
    "otisk ve formuláři sedí s obnoveným souborem" \
    "otisk ve formuláři neodpovídá souboru na svazku"
fi
fi

krok 6 "F — zálohovací plán"
require_soubor_neprazdny "$MILNIK" \
  "zálohovací plán leží v dokumentaci projektu" \
  "chybí $MILNIK"
require_min_radku "$MILNIK" 12 \
  "plán je rozepsaný" \
  "plán je zatím moc stručný"
# Plán má popisovat TUHLE stanici. Cesty a jména, která jinde neexistují.
# Cesta se uznává v obou podobách: zadání i tipy píšou ~/netlab/…,
# kdežto proměnné jsou absolutní. Trvat na jedné z nich by znamenalo
# FAIL za plán, který je napsaný správně.
ma_cestu() { grep -qF "$1" "$MILNIK" 2>/dev/null || grep -qF "~${1#$HOME}" "$MILNIK" 2>/dev/null; }
if ma_cestu "$PRIPOJ" && ma_cestu "$REPO"; then
  uspech "plán jmenuje konkrétní data i úložiště zálohy"
else
  chyba "z plánu není poznat, co přesně se zálohuje a kam"
fi
if grep -qE 'offsite|mimo stanici|kontejner' "$MILNIK" 2>/dev/null \
   && grep -qE 'obnov|restore|ověř|overi' "$MILNIK" 2>/dev/null; then
  uspech "plán řeší kopii mimo stanici i ověření obnovy"
else
  chyba "v plánu chybí kopie mimo stanici, nebo ověřování obnovy"
fi

vypis_souhrn
