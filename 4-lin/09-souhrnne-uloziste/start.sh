#!/bin/bash
# 4/09 — Souhrnná práce: úložiště a zálohy. Prostředí: žákova stanice.
#
# Ověřovací cvičení: prostředí NIC nestaví ani nepředpřipravuje kromě
# podkladů zakázky. Všechno ostatní skládá žák z toho, co umí — šifrovaný
# svazek (4/04), LVM (4/05), fstab (4/06), restic (4/08).
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/_data.sh"

projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/souhrn"
PODKLADY="$LAB/podklady"
FORMULAR="$LAB/zakazka.txt"
PRIPOJ="$HOME/netlab/ucto"
MAPPER="sejf-$ZAK2"
SKUPINA="data-$ZAK2"
SVAZEK="ucetnictvi"
NAZEV="UCTO-$ZAK2"
VELIKOST="$(svazek_velikost)"

mkdir -p "$LAB" "$PODKLADY" "$PRIPOJ"
# Záloha fstab MIMO $LAB (ten reset.sh maže). Žák do něj dnes zapisuje
# bez návodu a musí být kam se vrátit.
[ -f /etc/fstab.zaloha-09 ] || sudo cp /etc/fstab /etc/fstab.zaloha-09 2>/dev/null
if projekt_pripojen; then
  mkdir -p "$PROJEKT_PRIPOJ/dokumentace" 2>/dev/null || true
else
  echo "  Projektový disk není připojený — zálohovací plán zatím nemá kam."
  echo "  Připojte si ho (cvičení 6) dřív, než začnete psát milník."
fi

# ── podklady, na kterých zakázka stojí ───────────────────────────────
# Normálně je žák má z cvičení 4, 5 a 8. Kdo chyběl, by se sem nedostal
# vůbec — a pravidlo o nezávislosti labů platí i pro ověřovací cvičení.
# Staví se JEN to, co chybí; na hotovou práci se nesahá.
zkontroluj_disky 4 || exit 1
DISK4="$(labovy_disk 4)"
# ZÁMĚRNĚ mimo $LAB: ten reset.sh maže, a s ním by zmizelo jediné heslo
# k sejfu, který si prostředí samo založilo. Disk by pak nešlo otevřít.
SEJF_HESLO="$HOME/.os-lab-sejf-$ZAK2"
PODPIS4="$(lsblk -dno PTTYPE,FSTYPE "/dev/${DISK4:-nic}" 2>/dev/null | tr -d ' ')"
OBSAH4="$(lsblk -rno NAME "/dev/${DISK4:-nic}" 2>/dev/null | tail -n +2)"
if [ -n "$DISK4" ] && [ "$PODPIS4" != "crypto_LUKS" ]; then
  if [ -n "$OBSAH4" ] || [ -n "$PODPIS4" ]; then
    echo
    echo "  Na /dev/$DISK4 má být šifrovaný kontejner ze cvičení 4, ale je tam tohle:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL "/dev/$DISK4" 2>/dev/null | sed 's/^/    /'
    echo
    read -r -p "  Smazat to a založit kontejner znovu? [a/N] " ODP4
    if [[ ! "$ODP4" =~ ^[aAyY]$ ]]; then
      echo "  Nechávám disk být. Otevřete si svůj kontejner sami, nebo to řekněte vyučujícímu."
      echo
      exit 1
    fi
    uvolni_disk "$DISK4" || exit 1
  fi
  # Pojistka patří k destruktivní operaci, ne k volajícímu.
  je_labovy "$DISK4" || { echo "  Odmítám sáhnout na /dev/$DISK4 — není to labový disk."; exit 1; }
  echo "  Šifrovaný kontejner na /dev/$DISK4 nenajdu — zakládám ho."
  echo "  Heslo si losuji a nechávám ho v $SEJF_HESLO. V ostrém provozu"
  echo "  by heslo takhle vedle disku neleželo, tady je to nouzová cesta."
  # Práva se nastavují PŘED zápisem: umask platí jen při vzniku souboru,
  # takže na už existující (a čitelný) by neměla vliv.
  # Bez odřádkování na konci — cryptsetup čte klíčový soubor celý včetně
  # nového řádku, takže by se heslo nedalo napsat rukou.
  install -m 600 /dev/null "$SEJF_HESLO" 2>/dev/null
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20 > "$SEJF_HESLO"
  if sudo cryptsetup luksFormat --batch-mode --key-file "$SEJF_HESLO" "/dev/$DISK4" >/dev/null 2>&1 &&
     sudo cryptsetup open --key-file "$SEJF_HESLO" "/dev/$DISK4" "$MAPPER" >/dev/null 2>&1; then
    echo "  Kontejner založen a otevřen."
  else
    echo "  Kontejner se nepodařilo založit — řekněte to vyučujícímu."
  fi
fi
if [ ! -b "/dev/mapper/$MAPPER" ] && [ -s "$SEJF_HESLO" ]; then
  sudo cryptsetup open --key-file "$SEJF_HESLO" "/dev/$DISK4" "$MAPPER" >/dev/null 2>&1
fi
if [ -b "/dev/mapper/$MAPPER" ] && ! sudo pvs "/dev/mapper/$MAPPER" >/dev/null 2>&1; then
  # Zakládá se JEN na zařízení, kde žádný fyzický svazek není. `pvcreate -ff`
  # by přepsal i svazek patřící jiné skupině — třeba té, kterou si žák
  # ve cvičení 5 pojmenoval po svém.
  echo "  Na sejfu zatím není fyzický svazek — zakládám ho i se skupinou $SKUPINA."
  sudo pvcreate -y "/dev/mapper/$MAPPER" >/dev/null 2>&1 \
    && sudo vgcreate "$SKUPINA" "/dev/mapper/$MAPPER" >/dev/null 2>&1
elif [ -b "/dev/mapper/$MAPPER" ] && ! sudo vgs "$SKUPINA" >/dev/null 2>&1; then
  echo "  Na sejfu je skupina svazků s jiným jménem než $SKUPINA — nechávám ji být."
  echo "  Svazek si v ní vytvořte, nebo si ji přejmenujte (vgrename)."
fi

if [ ! -f "$PODKLADY/.hotovo" ]; then
  for I in $(seq 1 "$DAVEK"); do
    davka_obsah "$I" > "$PODKLADY/$(davka_jmeno "$I")"
  done
  : > "$PODKLADY/.hotovo"
fi

if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Souhrnná práce — vyplňte hodnoty za dvojtečku.
#
# svazek  = celá cesta k logickému svazku, který jste vytvořili
# snimek  = ID snímku, ze kterého jste obnovovali (zkrácené, jak ho vypisuje restic)
# otisk   = sha256 obnoveného souboru, který po vás zadání chce (jen otisk, bez jména)
svazek:
snimek:
otisk:
FORMULAR_KONEC
fi

# Repozitář ze cvičení 8 leží na odděleném oddílu, který jeho stop.sh
# odpojuje a fstab ho nepřipojuje. Bez něj jsou úkoly D a E neproveditelné
# a hláška o „nepodařilo se otevřít repozitář" by mířila mimo.
REPO8="$HOME/netlab/zalohy/repo"
ZAR8="$(blkid -L "ZALOHY-$ZAK2" 2>/dev/null)"
if [ -n "$ZAR8" ] && ! mountpoint -q "$REPO8" 2>/dev/null; then
  mkdir -p "$REPO8"
  sudo mount "$ZAR8" "$REPO8" 2>/dev/null \
    && sudo chown "$(id -un):$(id -gn)" "$REPO8" 2>/dev/null \
    && echo "  Oddíl se zálohami ze cvičení 8 jsem připojil do $REPO8."
fi

VOLNO="$( { sudo -n vgs --noheadings --units m --nosuffix -o vg_free "$SKUPINA" 2>/dev/null \
            || sudo vgs --noheadings --units m --nosuffix -o vg_free "$SKUPINA" 2>/dev/null; } \
          | tr -d ' ' | cut -d. -f1)"

cat <<EOF

  Zadání zakázky je na webu. Tohle jsou jen podklady a cíle.

    Podklady zakázky:  $PODKLADY
    Formulář:          $FORMULAR

    Požadované parametry:
      logický svazek:   $SVAZEK  ve skupině  $SKUPINA
      velikost svazku:  $VELIKOST MiB
      návěští:          $NAZEV
      bod připojení:    $PRIPOJ
      volné místo ve skupině: ${VOLNO:-?} MiB

  Šifrovaný svazek musí být otevřený. Když ho prostředí neotevřelo,
  otevřete si ho sami — heslo znáte jen vy:

    sudo cryptsetup open /dev/$DISK4 $MAPPER

  Průběžná kontrola:

    cd ~/os-lab/4-lin/09-souhrnne-uloziste && ./check.sh --krok 1

EOF
