#!/bin/bash
# disk-lib.sh — společné pro laby 4. ročníku, které pracují s disky.
#
# Použití (za lab-lib.sh):
#     source "$(dirname "$0")/../../lib/lab-lib.sh"
#     source "$(dirname "$0")/../../lib/disk-lib.sh"
#     zkontroluj_disky 2 || exit 1
#     echo "Pracovat budete na: ${LABOVE_DISKY[*]}"
#
# ── PRAVIDLO, NA KTERÉM TU STOJÍ VŠECHNO ─────────────────────────────
# Skripty smějí sáhnout JEN na labové disky. Systémový disk a projektový
# disk jsou nedotknutelné:
#   * systémový — na něm běží stanice; chyba = konec hodiny pro celou třídu,
#   * projektový — roste na něm celoroční projekt; chyba = ztráta práce
#     za měsíce, kterou nevrátí ani snímek, protože ten je starý.
# Proto se nikde nepíše „/dev/sdb" natvrdo. Disky se HLEDAJÍ a každý zápis
# jde přes `je_labovy`, která ostatní odmítne.

PROJEKT_NAZEV="PROJEKT-$ZAK2"          # návěští (label) oddílu s projektem
PROJEKT_PRIPOJ="$HOME/projekt"

# ── co je co ──────────────────────────────────────────────────────────
systemovy_disk() {
  # Kořen leží na LVM svazku, ne přímo na disku. `lsblk -s` jde závislostmi
  # dolů až k fyzickému disku — poslední řádek je on.
  local zdroj; zdroj="$(findmnt -no SOURCE / 2>/dev/null)"
  [ -n "$zdroj" ] || return 1
  lsblk -nso NAME "$zdroj" 2>/dev/null | tail -1 | tr -d ' '
}

vsechny_disky() {  # jen skutečné disky — ne oddíly, ne CD, ne loop zařízení
  lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}' | grep -v '^loop' | sort
}

projektovy_disk() {
  # 1) Když už je projektový oddíl založený, pozná se podle návěští.
  local zar disk
  zar="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
  if [ -n "$zar" ]; then
    disk="$(lsblk -nso NAME "$zar" 2>/dev/null | tail -1 | tr -d ' ')"
    [ -n "$disk" ] && { printf '%s\n' "$disk"; return 0; }
  fi
  # 2) Ještě není (před cvičením 4/00): rezervuje se NEJVĚTŠÍ nesystémový
  #    disk. Proto je projektový disk větší než labové — aby šel poznat
  #    dřív, než na něm cokoli vznikne.
  local sys; sys="$(systemovy_disk)"
  lsblk -dn -o NAME,SIZE,TYPE -b 2>/dev/null \
    | awk -v s="$sys" '$3=="disk" && $1!=s && $1 !~ /^loop/ {print $2, $1}' \
    | sort -rn | head -1 | awk '{print $2}'
}

labove_disky() {  # všechno ostatní, setříděné podle jména
  local sys pro d
  sys="$(systemovy_disk)"; pro="$(projektovy_disk)"
  for d in $(vsechny_disky); do
    [ "$d" = "$sys" ] && continue
    [ "$d" = "$pro" ] && continue
    printf '%s\n' "$d"
  done
}

je_labovy() {  # je_labovy sdb|/dev/sdb|/dev/sdb1 → 0, když se na něj SMÍ sahat
  # Rodičovský disk se HLEDÁ přes lsblk. Odseknout číslice z názvu nejde:
  # u nvme0n1p1 by z toho vzniklo „nvme".
  local vstup="${1#/dev/}" d
  [ -n "$vstup" ] || return 1
  if [ -b "/dev/$vstup" ]; then
    d="$(lsblk -nso NAME "/dev/$vstup" 2>/dev/null | tail -1 | tr -d ' ')"
  fi
  d="${d:-$vstup}"
  # Porovnává se ve smyčce, ne rourou do `grep -qx`: grep skončí hned po
  # shodě, tím shodí `labove_disky` signálem a `set -o pipefail` z toho
  # udělá nenulový návratový kód — funkce by odmítala i správné disky.
  local x
  while read -r x; do [ "$x" = "$d" ] && return 0; done < <(labove_disky)
  return 1
}

# ── pojistky ──────────────────────────────────────────────────────────
zkontroluj_disky() {  # zkontroluj_disky POČET → 0, když je dost labových disků
  local potreba="${1:-1}" mam d
  LABOVE_DISKY=()
  while read -r d; do [ -n "$d" ] && LABOVE_DISKY+=("$d"); done < <(labove_disky)
  mam="${#LABOVE_DISKY[@]}"
  # Dokud projektový disk nemá návěští, pozná se podle toho, že je největší.
  # Když jsou dva stejně velké, nedá se rozhodnout — a hádat se nesmí,
  # protože špatný tip znamená smazaný projekt.
  if [ -z "$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)" ]; then
    local nejvetsi; nejvetsi="$(lsblk -dn -o NAME,SIZE,TYPE -b 2>/dev/null \
      | awk -v s="$(systemovy_disk)" '$3=="disk" && $1!=s && $1 !~ /^loop/ {print $2}' \
      | sort -rn | head -2 | uniq | wc -l)"
    if [ "$nejvetsi" -lt 2 ]; then
      echo
      echo "  Nedá se poznat, který disk je projektový: dva největší mají stejnou"
      echo "  velikost. Projektový disk musí být VĚTŠÍ než labové (4 GB proti 2 GB)."
      echo "  Řekněte o tom vyučujícímu — než se to spraví, nesmí se na disky sahat."
      echo
      return 1
    fi
  fi
  if [ "$mam" -lt "$potreba" ]; then
    echo
    echo "  Tohle cvičení potřebuje $potreba prázdné disky navíc, stanice jich má $mam."
    echo "  Disky se přidávají ve VirtualBoxu u VYPNUTÉ stanice:"
    echo "    Nastavení → Úložiště → řadič SATA → přidat pevný disk (2 GB)."
    echo "  Řekněte o tom vyučujícímu."
    echo
    return 1
  fi
  export LABOVE_DISKY
  return 0
}

# ── úklid (jen reset.sh) ──────────────────────────────────────────────
uvolni_disk() {  # uvolni_disk sdb — rozebere, co na disku stojí, a smaže stopy
  local d="${1#/dev/}"
  # Pojistka je tady, ne u volajícího: tahle funkce maže data.
  if ! je_labovy "$d"; then
    printf '  Odmítám sáhnout na /dev/%s — není to labový disk.\n' "$d" >&2
    return 1
  fi
  local cast
  # odpojit vše, co z disku vychází (oddíly i to, co nad nimi stojí)
  for cast in $(lsblk -rno NAME "/dev/$d" 2>/dev/null | tail -n +2); do
    sudo umount "/dev/$cast" 2>/dev/null
    sudo umount "/dev/mapper/$cast" 2>/dev/null
  done
  # LVM nad tímhle diskem
  if command -v pvs >/dev/null 2>&1; then
    local vg
    for vg in $(sudo pvs --noheadings -o vg_name "/dev/$d"* 2>/dev/null | tr -d ' ' | sort -u); do
      [ -n "$vg" ] && sudo vgremove -f "$vg" >/dev/null 2>&1
    done
    sudo pvremove -ff -y "/dev/$d"* >/dev/null 2>&1
  fi
  # LUKS
  if command -v cryptsetup >/dev/null 2>&1; then
    for cast in $(lsblk -rno NAME,TYPE "/dev/$d" 2>/dev/null | awk '$2=="crypt"{print $1}'); do
      sudo cryptsetup close "$cast" >/dev/null 2>&1
    done
  fi
  # RAID — pole se zastaví a superblok se z oddílů smaže, jinak se pole
  # po restartu samo poskládá znovu a další lab začne s cizím zbytkem.
  if command -v mdadm >/dev/null 2>&1; then
    # Zastaví se JEN pole, ve kterých je tenhle disk — podle řádku
    # v /proc/mdstat, ne naslepo. Cizí pole se zastavit nesmí.
    local radek pole
    while read -r radek; do
      pole="${radek%% *}"
      case " $radek " in *" $d"[0-9]*|*" $d "*) sudo mdadm --stop "/dev/$pole" >/dev/null 2>&1 ;; esac
    done < <(grep -E '^md[0-9]+ :' /proc/mdstat 2>/dev/null)
    sudo mdadm --zero-superblock "/dev/$d"* >/dev/null 2>&1
  fi
  sudo wipefs -a "/dev/$d" >/dev/null 2>&1
  sudo sgdisk --zap-all "/dev/$d" >/dev/null 2>&1 || sudo dd if=/dev/zero of="/dev/$d" bs=1M count=10 status=none 2>/dev/null
  sudo partprobe "/dev/$d" >/dev/null 2>&1
  return 0
}

# ── projektový disk ───────────────────────────────────────────────────
projekt_pripojen() { mountpoint -q "$PROJEKT_PRIPOJ" 2>/dev/null; }

projekt_pripoj() {  # připojí projektový disk, když je hotový a není připojený
  local zar; zar="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
  [ -n "$zar" ] || return 1
  projekt_pripojen && return 0
  mkdir -p "$PROJEKT_PRIPOJ"
  sudo mount "$zar" "$PROJEKT_PRIPOJ" 2>/dev/null || return 1
  sudo chown "$USER:$USER" "$PROJEKT_PRIPOJ" 2>/dev/null
  projekt_pripojen
}
