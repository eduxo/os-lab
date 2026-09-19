#!/bin/bash
# 4/03 — Degradované pole. Prostředí: žákova stanice, DRUHÝ a TŘETÍ labový
# disk, tedy totéž pole, které vzniklo ve cvičení 4/02.
#
# Skript pole NAJDE, a když neexistuje (žák minule chyběl nebo dělal reset),
# postaví ho sám — laby na sobě nesmějí záviset. Teprve do hotového pole
# zanese poruchu.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/_faktury.sh"

projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/degradace"
FORMULAR="$LAB/hlaseni.txt"
ZNACKA="$LAB/.porucha"                 # „porucha už je nasazená" — ne odpověď
PRIPOJ="$HOME/netlab/raid/data"        # pole se připojuje tam, kde v 4/02
NAZEV="RAID-$ZAK2"

zkontroluj_disky 3 || exit 1
DISK_A="$(labovy_disk 2)"; DISK_B="$(labovy_disk 3)"
[ -n "$DISK_A" ] && [ -n "$DISK_B" ] || { echo "  Labové disky se nepodařilo určit."; exit 1; }

# Který disk vypadne a jak — odvozeno z čísla žáka, aby to check.sh uměl
# spočítat taky. Značka na disku by byla odpověď položená vedle úlohy.
VADNY_INDEX="$(lab_cislo 2 3 degradace)"
VADNY="$(labovy_disk "$VADNY_INDEX")"
[ -n "$VADNY" ] || { echo "  Disk pro dnešní poruchu se nepodařilo určit."; exit 1; }
SCENAR="$(lab_cislo 1 2 scenar-degradace)"

mkdir -p "$LAB"

# ── 1. pole musí stát ────────────────────────────────────────────────
# Hledá se stejně jako v check.sh: degradované pole má jen jeden disk,
# takže dotaz na OBA by po nasazení poruchy nenašel nic — a skript by
# při druhém spuštění nabídl vyčistit disky, na kterých žák právě pracuje.
POLE="$(pole_s_diskem "$DISK_A" "$DISK_B" || true)"
[ -n "$POLE" ] || POLE="$(pole_s_diskem "$DISK_A" || true)"
[ -n "$POLE" ] || POLE="$(pole_s_diskem "$DISK_B" || true)"
if [ -z "$POLE" ]; then
  # Pole se staví znovu → případná stará značka neplatí, porucha se nasadí
  # nanovo. Jinak by vzniklo čisté pole bez poruchy a kontrola by ho uznala.
  rm -f "$ZNACKA"
  NECISTE=""
  for D in "$DISK_A" "$DISK_B"; do
    OBSAH="$(lsblk -rno NAME "/dev/$D" 2>/dev/null | tail -n +2)"
    PODPIS="$(lsblk -dno PTTYPE,FSTYPE "/dev/$D" 2>/dev/null | tr -d ' ')"
    if [ -n "$OBSAH" ] || [ -n "$PODPIS" ]; then NECISTE="$NECISTE $D"; fi
  done
  echo
  echo "  Pole z minulé hodiny na stanici není — postavím ho."
  if [ -n "$NECISTE" ]; then
    echo "  Na discích$NECISTE je ale zbytek z jiného cvičení:"
    for D in $NECISTE; do lsblk -o NAME,SIZE,FSTYPE,LABEL "/dev/$D" 2>/dev/null | sed 's/^/    /'; done
    echo
    read -r -p "  Vyčistit je? [a/N] " ODP
    if [[ "$ODP" =~ ^[aAyY]$ ]]; then
      for D in $NECISTE; do uvolni_disk "$D" || exit 1; done
    else
      echo "  Cvičení potřebuje ty dva disky. Končím."; exit 1
    fi
  fi
  printf 'y\n' | sudo mdadm --create /dev/md0 --run --level=1 --raid-devices=2 \
       "/dev/$DISK_A" "/dev/$DISK_B" >/dev/null 2>&1 \
    || { echo "  Pole se nepodařilo složit — řekněte o tom vyučujícímu."; exit 1; }
  POLE="$(pole_s_diskem "$DISK_A" "$DISK_B" || true)"
  [ -n "$POLE" ] || { echo "  Pole se nepodařilo najít ani po složení."; exit 1; }
  # -F: na čerstvě složeném poli se často objeví starý ext4 superblok
  # z minulého pole (stejný data offset), načež se mke2fs ZEPTÁ a čeká
  # na stdin — skript by se zasekl a žák by viděl jen mlčící terminál.
  sudo mkfs.ext4 -F -q -L "$NAZEV" "/dev/$POLE" >/dev/null 2>&1 \
    || { echo "  Souborový systém se na poli nepodařilo vytvořit."; exit 1; }
  # Ať se pole po restartu jmenuje pořád stejně (učivo 4/02, Krok 5).
  # Připisuje se jen tehdy, když tam pole ještě není — jinak by po každém
  # resetu přibyl další ARRAY řádek s neplatným UUID.
  POLE_UUID="$(sudo mdadm --detail "/dev/$POLE" 2>/dev/null | awk -F': *' '/^ *UUID/{print $2; exit}' | tr -d '[:space:]')"
  if [ -n "$POLE_UUID" ] && ! sudo grep -qF "$POLE_UUID" /etc/mdadm/mdadm.conf 2>/dev/null; then
    sudo mdadm --detail --scan "/dev/$POLE" 2>/dev/null | sudo tee -a /etc/mdadm/mdadm.conf >/dev/null
    sudo update-initramfs -u >/dev/null 2>&1
  fi
fi

mkdir -p "$PRIPOJ"
mountpoint -q "$PRIPOJ" || sudo mount "/dev/$POLE" "$PRIPOJ" 2>/dev/null
if [ "$(findmnt -no SOURCE "$PRIPOJ" 2>/dev/null)" != "/dev/$POLE" ]; then
  echo "  Pole se nepodařilo připojit do $PRIPOJ — řekněte o tom vyučujícímu."
  exit 1
fi
sudo chown "$(id -un):$(id -gn)" "$PRIPOJ" 2>/dev/null

# ── 2. data, která má výpadek přežít ─────────────────────────────────
# Vyrábějí se JEN spolu s poruchou (níž je podmínka na značku). Kdyby je
# start.sh doplňoval při každém spuštění, zakryl by přesně tu chybu, kterou
# má lab naučit rozpoznat: kdo pole „opraví" příkazem mdadm --create, o data
# přijde a nesmí se to ztratit v šumu.
UCTO="$PRIPOJ/ucetnictvi"

# ── 3. porucha ───────────────────────────────────────────────────────
if [ -f "$ZNACKA" ]; then
  echo
  echo "  Dnešní porucha už je nasazená — nechávám stav, jak je."
  echo "  Chcete začít znovu (a dostat ji znovu)?  ./reset.sh"
else
  # Do rozsynchronizovaného pole se disk vyhazovat nedá rozumně — počkat.
  if awk -v p="$POLE" '$1==p{f=1} f&&/resync|recovery/{n=1} f&&/^$/{f=0} END{exit !n}' /proc/mdstat 2>/dev/null; then
    printf '\n  Pole se ještě synchronizuje, počkám si na něj'
    for _ in $(seq 1 90); do
      awk -v p="$POLE" '$1==p{f=1} f&&/resync|recovery/{n=1} f&&/^$/{f=0} END{exit !n}' /proc/mdstat 2>/dev/null || break
      printf '.'; sleep 4
    done
    printf '\n'
    # Vzdát se po šesti minutách se smí, mlčet u toho ne: do běžící
    # synchronizace se disk vyhazovat nedá a porucha by se nenasadila.
    if awk -v p="$POLE" '$1==p{f=1} f&&/resync|recovery/{n=1} f&&/^$/{f=0} END{exit !n}' /proc/mdstat 2>/dev/null; then
      echo "  Synchronizace pořád běží. Dnešní porucha se nasadí, až doběhne —"
      echo "  spusťte ./start.sh znovu za chvíli. Průběh: cat /proc/mdstat"
      exit 1
    fi
  fi
  mkdir -p "$UCTO"
  for I in $(seq 1 "$FAKTUR"); do
    faktura_obsah "$I" > "$UCTO/$(faktura_jmeno "$I")"
  done
  ( cd "$UCTO" && sha256sum faktura-*.txt > SHA256SUMS ) 2>/dev/null
  sync

  sudo mdadm --manage "/dev/$POLE" --fail "/dev/$VADNY" >/dev/null 2>&1
  if [ "$SCENAR" = "2" ]; then
    # „Disk odešel a technik ho vyměnil za prázdný" — v poli po něm nezbude nic.
    sudo mdadm --manage "/dev/$POLE" --remove "/dev/$VADNY" >/dev/null 2>&1
    sudo mdadm --zero-superblock "/dev/$VADNY" >/dev/null 2>&1
  fi
  # Značka až TEĎ a jen když porucha opravdu sedí. Kdyby se zapsala i po
  # neúspěšném --fail, zůstalo by na stanici zdravé pole, které by kontrola
  # uznala jako opravené — [PASS] za úlohu, která se nikdy nezadala.
  AKT="$(sudo mdadm --detail "/dev/$POLE" 2>/dev/null | awk -F': *' '/Active Devices/{print $2; exit}' | tr -d '[:space:]')"
  if [ "${AKT:-2}" = "1" ]; then
    date '+%Y-%m-%d %H:%M' > "$ZNACKA"
  else
    echo "  Poruchu se nepodařilo nasadit — řekněte o tom vyučujícímu."
    exit 1
  fi
fi

if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Hlášení o výpadku disku — vyplňte hodnoty za dvojtečku.
#
# vadny_disk = jméno zařízení, které z pole vypadlo (např. sdc, bez /dev/)
# stav_pole  = ukazatel stavu členů z /proc/mdstat (ten v hranatých závorkách
#              s písmeny U) ve chvíli, kdy jste pole našli
# doba_obnovy = jak dlouho trvalo, než se pole dosynchronizovalo
#               (číslo a jednotka, např. "40 s" nebo "2 min")
# faktura    = číslo kterékoli faktury, kterou máte na poli (tvar FA-nnnn)
# zaver      = vlastní věta: co by výpadek toho disku znamenal pro pobočku,
#              kdyby pole nebylo zrcadlené
vadny_disk:
stav_pole:
doba_obnovy:
faktura:
zaver:
FORMULAR_KONEC
fi

cat <<EOF

  Připraveno.

    Pole:             /dev/$POLE
    Disky pole:       /dev/$DISK_A  a  /dev/$DISK_B
    Data pobočky:     $UCTO
    Hlášení:          $FORMULAR

  Pole hlásí potíže. Zjistěte co a uveďte ho do pořádku — data na něm
  musí zůstat.

  Průběžná kontrola:

    cd ~/os-lab/4-lin/03-degradovane-pole && ./check.sh --krok 1

EOF
