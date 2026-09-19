#!/bin/bash
# 4/03 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/_faktury.sh"

LAB="$HOME/netlab/degradace"
FORMULAR="$LAB/hlaseni.txt"
PRIPOJ="$HOME/netlab/raid/data"
UCTO="$PRIPOJ/ucetnictvi"

zkontroluj_disky 3 || exit 1
DISK_A="$(labovy_disk 2)"; DISK_B="$(labovy_disk 3)"
[ -n "$DISK_A" ] && [ -n "$DISK_B" ] || { echo "  Labové disky se nepodařilo určit."; exit 1; }
VADNY="$(labovy_disk "$(lab_cislo 2 3 degradace)")"

# Pole se hledá i podle JEDNOHO disku: dokud je degradované, druhý v něm
# být nemusí (scénář s vyměněným diskem ho z pole odstraní úplně).
POLE="$(pole_s_diskem "$DISK_A" "$DISK_B" || true)"
[ -n "$POLE" ] || POLE="$(pole_s_diskem "$DISK_A" || true)"
[ -n "$POLE" ] || POLE="$(pole_s_diskem "$DISK_B" || true)"

_det=""; _det_nactena=0
detail() {
  if [ "$_det_nactena" -eq 0 ]; then
    [ -n "$POLE" ] && _det="$(sudo -n mdadm --detail "/dev/$POLE" 2>/dev/null \
      || sudo mdadm --detail "/dev/$POLE" 2>/dev/null)"
    _det_nactena=1
  fi
  printf '%s' "$_det"
}
pole_hodnota() { printf '%s' "$(detail)" | awk -F': *' -v k="$1" '$0 ~ k {print $2; exit}' | tr -d ' '; }

krok 1 "Diagnóza"
require_soubor_neprazdny "$FORMULAR" \
  "hlášení je na místě" \
  "chybí ~/netlab/degradace/hlaseni.txt — spusťte ./start.sh"
# Jméno vadného disku je celá úloha kroku 1 — hláška ho proto nesmí vyslovit
# ani v případě, že sedí jen částečně.
require_zaznam "$FORMULAR" vadny_disk "$VADNY" \
  "v hlášení je správně určený vadný disk" \
  "v hlášení nesedí jméno vadného disku"
# Ukazatel stavu: jedno U a jedno podtržítko. Které z nich je vlevo, závisí
# na tom, kolikátou roli v poli vadný disk měl — obě pořadí jsou správně.
require_zaznam_tvar "$FORMULAR" stav_pole '^(\[[0-9]+/[0-9]+\] *)?\[?(U_|_U)\]?$' \
  "v hlášení je stav pole z doby poruchy" \
  "v hlášení není stav pole tak, jak ho vypisuje /proc/mdstat"

krok 2 "Pole je zase celé"
if [ -z "$POLE" ]; then
  chyba "nenašel jsem pole, ve kterém by byl některý z vašich disků"
  poznamka "co jádro o polích ví, ukáže: cat /proc/mdstat"
else
  # Pozor na to, co znamená „disk je v poli": /proc/mdstat vypíše jméno
  # člena i tehdy, když je označený jako vadný (sdc[0](F)). Samotná
  # přítomnost jména proto není důkaz opravy — rozhoduje až souhrn níž.
  CLENU="$(pole_hodnota 'Raid Devices')"
  AKTIVNI="$(pole_hodnota 'Active Devices')"
  VADNYCH="$(pole_hodnota 'Failed Devices')"
  # Jeden verdikt, ne tři. Ve scénáři, kde byl vadný disk z pole odstraněn,
  # je „Failed Devices: 0" pravda od začátku — samostatně by to byl [PASS]
  # pro žáka, který se úlohy ani nedotkl.
  if [ "${CLENU:-0}" = "2" ] && [ "${AKTIVNI:-0}" = "2" ] && [ "${VADNYCH:-1}" = "0" ]; then
    uspech "pole má dva aktivní členy a žádný vadný"
  else
    chyba "pole hlásí členů ${CLENU:-?}, aktivních ${AKTIVNI:-?}, vadných ${VADNYCH:-?} — mají být dva, dva a nula"
  fi
  # Dokud dobíhá obnova, pole běží, ale ještě nechrání — stejné pravidlo
  # jako u resyncu v 4/02.
  if awk -v p="$POLE" '$1==p{f=1} f&&/resync|recovery/{n=1} f&&/^$/{f=0} END{exit !n}' /proc/mdstat 2>/dev/null; then
    chyba "pole se ještě dosynchronizovává — počkejte, než to doběhne"
    poznamka "průběh ukáže: cat /proc/mdstat"
  else
    uspech "synchronizace je hotová"
  fi
fi

krok 3 "Data pobočky"
# Nejdřív: leží ten adresář vůbec na poli? Kdyby se pole nepřipojilo, je to
# obyčejný adresář na systémovém disku a „data přežila výpadek" by bylo
# tvrzení o něčem, co na poli nikdy nebylo.
ZDROJ="$(findmnt -no SOURCE "$PRIPOJ" 2>/dev/null)"
if [ -n "$POLE" ] && [ "$ZDROJ" = "/dev/$POLE" ]; then
  uspech "data leží na poli /dev/$POLE"
else
  chyba "v $PRIPOJ není připojené vaše pole"
  poznamka "připojí se: sudo mount /dev/POLE $PRIPOJ"
fi
if [ ! -d "$UCTO" ]; then
  chyba "adresář s daty pobočky na poli není"
  poznamka "když pole vzniklo znovu, data jsou pryč — nové zadání dá ./reset.sh"
else
  CHYBI=0; JINAK=0
  for I in $(seq 1 "$FAKTUR"); do
    SOUBOR="$UCTO/$(faktura_jmeno "$I")"
    if [ ! -f "$SOUBOR" ]; then CHYBI=$(( CHYBI + 1 )); continue; fi
    OCEKAVANY="$(faktura_obsah "$I" | sha256sum | cut -d' ' -f1)"
    SKUTECNY="$(sha256sum < "$SOUBOR" | cut -d' ' -f1)"
    [ "$OCEKAVANY" = "$SKUTECNY" ] || JINAK=$(( JINAK + 1 ))
  done
  if [ "$CHYBI" = "0" ] && [ "$JINAK" = "0" ]; then
    uspech "všech $FAKTUR souborů pobočky je na poli a nezměněných"
  else
    chyba "souborů pobočky chybí: $CHYBI, poškozených: $JINAK (z $FAKTUR)"
    poznamka "pole, které se postavilo znovu, přišlo o data — začít se dá ./reset.sh"
  fi
  require_soubor_neprazdny "$UCTO/SHA256SUMS" \
    "seznam otisků je na poli" \
    "na poli chybí SHA256SUMS"
  # Data přežijí výpadek sama — to je vlastnost zrcadla, ne žákova zásluha.
  # Měkká kontrola se proto ptá na to, co je jeho: že si je skutečně ověřil.
  pouzil_diagnostiku 'sha256sum|md5sum' \
    "ověřit data po výpadku patří k opravě: sha256sum -c SHA256SUMS"
fi

krok 4 "Hlášení pro vedení"
# Číslo faktury je jediná hodnota v hlášení, kterou nejde vymyslet od stolu:
# žák ji musí přečíst z dat, která leží na poli.
FAKT="$(_zaznam "$FORMULAR" faktura)"
SEDI=0
for I in $(seq 1 "$FAKTUR"); do
  [ "$FAKT" = "$(lab_kod FA "faktura$I")" ] && SEDI=1
done
[ "$SEDI" = "1" ] \
  && uspech "v hlášení je číslo jedné z vašich faktur" \
  || chyba "v hlášení nesedí číslo faktury z pole (máte '${FAKT:-nic}')"
require_zaznam_tvar "$FORMULAR" doba_obnovy '^[0-9]+([.,][0-9]+)? *(s|sec|sekund[ay]?|min|minut[ay]?|m)\.?$' \
  "v hlášení je doba obnovy" \
  "v hlášení chybí doba obnovy i s jednotkou (např. 40 s)"
require_zaznam_tvar "$FORMULAR" zaver '^.{30,}$' \
  "v hlášení je vlastní závěr" \
  "závěr v hlášení chybí nebo je kratší než věta"

vypis_souhrn
