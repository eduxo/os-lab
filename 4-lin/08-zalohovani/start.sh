#!/bin/bash
# 4/08 — Zálohování restic (DVA BLOKY). Prostředí: žákova stanice + kontejner.
#
# Blok 1 je celý na stanici: repozitář na druhém oddílu PRVNÍHO labového disku
# (ten, který 4/01 schválně nechalo prázdný). Blok 2 přidá „offsite" kopii
# do kontejneru přes SFTP.
#
# Skript staví obojí hned. Kontejner stojí pár set MB a vteřiny, kdežto
# čekat s jeho stavbou na druhou hodinu by znamenalo, že se druhý blok
# začíná minutovým čekáním.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
SERVER_KONT="zaloha-$ZAK2"   # až ZA lab-lib.sh: ZAK2 vzniká teprve tam
source "$(dirname "$0")/../../lib/disk-lib.sh"
source "$(dirname "$0")/../../lib/server-lib.sh"
source "$(dirname "$0")/_data.sh"

projekt_pripoj >/dev/null 2>&1 || true

LAB="$HOME/netlab/zalohy"
OSTRA="$LAB/ostra"                 # data, která se zálohují
REPO="$LAB/repo"                   # sem se připojí oddíl s repozitářem
FORMULAR="$LAB/zaloha.txt"
NAZEV="ZALOHY-$ZAK2"

zkontroluj_disky 1 || exit 1
DISK="$(labovy_disk 1)"
[ -n "$DISK" ] || { echo "  Labový disk se nepodařilo určit."; exit 1; }

mkdir -p "$LAB" "$OSTRA" "$REPO"

# ── druhý oddíl musí existovat ───────────────────────────────────────
# Normálně ho vyrobil žák ve cvičení 1. Kdo chyběl, dostane rozvržení tady —
# lab na předchozím záviset nesmí. Existující práci to nechá být.
# Počítají se ODDÍLY, ne potomci: lsblk vypisuje rekurzivně i LUKS,
# svazky LVM a členy pole, takže „druhý řádek" nemusí být oddíl.
CASTI="$(lsblk -rno NAME,TYPE "/dev/$DISK" 2>/dev/null | awk '$2=="part"' | grep -c '')"
if [ "$CASTI" -lt 2 ]; then
  if [ "$CASTI" = "0" ] && [ -z "$(lsblk -dno PTTYPE "/dev/$DISK" 2>/dev/null | tr -d ' ')" ]; then
    echo "  Disk /dev/$DISK je prázdný — dělám rozvržení jako ve cvičení 1."
    sudo parted "/dev/$DISK" --script mklabel gpt \
      && sudo parted "/dev/$DISK" --script mkpart data ext4 1MiB 851MiB \
      && sudo parted "/dev/$DISK" --script mkpart zaloha ext4 851MiB 100% \
      || { echo "  Rozvržení disku se nepodařilo."; exit 1; }
    sudo partprobe "/dev/$DISK" >/dev/null 2>&1
    PRVNI="$(lsblk -rno NAME,TYPE "/dev/$DISK" 2>/dev/null | awk '$2=="part"{print $1; exit}')"
    [ -n "$PRVNI" ] && sudo mkfs.ext4 -F -q -L "DATA-$ZAK2" "/dev/$PRVNI" >/dev/null 2>&1
    echo "  Pozor: je to NÁHRADNÍ rozvržení, ne to, které vám vylosovalo cvičení 1."
    echo "  Kdybyste se k cvičení 1 vraceli, spusťte tam ./reset.sh."
  else
    echo "  Na /dev/$DISK chybí druhý oddíl — dodělávám ho ve volném místě."
    sudo parted "/dev/$DISK" --script mkpart zaloha ext4 851MiB 100% \
      || { echo "  Druhý oddíl se nepodařilo vytvořit."; exit 1; }
    sudo partprobe "/dev/$DISK" >/dev/null 2>&1
  fi
  command -v udevadm >/dev/null 2>&1 && sudo udevadm settle >/dev/null 2>&1
fi
CAST2="$(lsblk -rno NAME,TYPE "/dev/$DISK" 2>/dev/null | awk '$2=="part"{print $1}' | sed -n 2p)"
[ -n "$CAST2" ] || { echo "  Druhý oddíl na /dev/$DISK se nepodařilo najít."; exit 1; }

# ── oddíl se zálohami připojit zpět ──────────────────────────────────
# stop.sh ho na konci hodiny odpojí a ve fstab zapsaný není (trvalé
# připojení je učivo cvičení 6, tohle je jiný oddíl). Druhý blok by proto
# začínal prázdným adresářem a chybou „is there a repository at …".
if ! mountpoint -q "$REPO" 2>/dev/null; then
  ZAR_ZAL="$(blkid -L "$NAZEV" 2>/dev/null)"
  if [ -n "$ZAR_ZAL" ] && [ "$ZAR_ZAL" = "/dev/$CAST2" ]; then
    [ -z "$(ls -A "$REPO" 2>/dev/null)" ] \
      || echo "  Pozor: v $REPO něco leží, a přitom to není připojený oddíl."
    sudo mount "$ZAR_ZAL" "$REPO" 2>/dev/null \
      && sudo chown "$(id -un):$(id -gn)" "$REPO" 2>/dev/null \
      && echo "  Oddíl se zálohami jsem připojil zpět do $REPO."
  elif [ -n "$ZAR_ZAL" ]; then
    echo "  Návěští $NAZEV nese $ZAR_ZAL, ale dnešní oddíl je /dev/$CAST2 — nepřipojuji."
  fi
fi

# ── ostrá data, která se budou zálohovat ─────────────────────────────
if [ ! -f "$OSTRA/.hotovo" ]; then
  mkdir -p "$OSTRA/smlouvy"
  for I in $(seq 1 "$SMLUV"); do
    smlouva_obsah "$I" > "$OSTRA/smlouvy/$(smlouva_jmeno "$I")"
  done
  printf 'Pobocka Kolin — ostra data\nSpravce: %s\n' "$ZAK_UZIVATEL" > "$OSTRA/README.txt"
  : > "$OSTRA/.hotovo"
fi

# ── kontejner pro „offsite" kopii (blok 2) ───────────────────────────
# Kontejner potřebuje až DRUHÝ blok. Když se nepostaví, první blok tím
# nesmí padnout — je celý na stanici.
KONTEJNER_STOJI=0
if postav_server; then
  KONTEJNER_STOJI=1
  # ssh-keygen se ptá na přepsání existujícího klíče a s umlčeným výstupem
  # by skript tiše čekal na stdin. Zakládá se proto jen, když žádný není.
  if [ -z "$(ls "$HOME"/.ssh/id_*.pub 2>/dev/null)" ]; then
    echo "  Na stanici zatím nemáte SSH klíč — vyrábím ho (jako ve cvičení 3/04)."
    ssh-keygen -q -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" </dev/null >/dev/null 2>&1
  fi
  nasad_klic_ze_stanice || echo "  Klíč se nepodařilo nasadit, heslo: $SERVER_HESLO"
  # restic potřebuje na druhé straně jen adresář a SSH — žádnou službu.
  lxc exec "$SERVER_KONT" -- bash -c \
    "install -d -o $SERVER_UCET -g $SERVER_UCET -m 700 /srv/offsite" >/dev/null 2>&1
else
  echo
  echo "  Kontejner pro druhý blok se nepodařilo postavit. První blok na něm"
  echo "  nestojí — pokračujte, a řekněte o tom vyučujícímu."
fi

if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Zálohování — vyplňte hodnoty za dvojtečku.
#
# oddil     = zařízení, na kterém leží repozitář (celá cesta, např. /dev/sdb2)
# snimku    = kolik snímků měl repozitář po druhé záloze (číslo)
# obnoveno  = kolik souborů restic obnovil (číslo z jeho výpisu)
# offsite   = adresa kontejneru, do kterého kopírujete zálohu
oddil:
snimku:
obnoveno:
offsite:
FORMULAR_KONEC
fi

cat <<EOF

  Připraveno.

    Disk se zálohami:  /dev/$DISK   (druhý oddíl: /dev/$CAST2)
    Kam ho připojit:   $REPO
    Návěští:           $NAZEV
    Ostrá data:        $OSTRA
    Formulář:          $FORMULAR

    Kontejner (2. blok): ${SERVER_KONT}${SERVER_IP:+   adresa: $SERVER_IP}
    Účet v kontejneru:   $SERVER_UCET   cíl: /srv/offsite

  Heslo k repozitáři si zvolíte sami a uložíte do souboru — restic bez něj
  data nepřečte a jiná cesta dovnitř neexistuje.

  Průběžná kontrola:

    cd ~/os-lab/4-lin/08-zalohovani && ./check.sh --krok 1

EOF
