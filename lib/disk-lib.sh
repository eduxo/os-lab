#!/bin/bash
# disk-lib.sh — společné pro laby 4. ročníku, které pracují s disky.
#
# Použití (za lab-lib.sh):
#     source "$(dirname "$0")/../../lib/lab-lib.sh"
#     source "$(dirname "$0")/../../lib/disk-lib.sh"
#     zkontroluj_disky 3 || exit 1
#     DISK="$(labovy_disk 1)"
#
# ── PRAVIDLO, NA KTERÉM TU STOJÍ VŠECHNO ─────────────────────────────
# Skripty smějí sáhnout JEN na labové disky. Systémový disk (nese `/`)
# a projektový disk (celoroční práce žáka) jsou nedotknutelné.
#
# Z toho plyne druhé pravidlo: **co se nepodaří rozpoznat, to se považuje
# za nedotknutelné.** Když knihovna neví, který disk je systémový nebo
# projektový, NEVRÁTÍ žádné labové disky a skript skončí. Prázdný výsledek
# nikdy neznamená „všechno je labové".

PROJEKT_NAZEV="PROJEKT-$ZAK2"          # návěští (label) oddílu s projektem
PROJEKT_PRIPOJ="$HOME/projekt"
DISKY_MAPA="$HOME/.os-lab-disky"       # trvalé přiřazení labových disků

# Jen holé jméno zařízení projde dál. Cokoli jiného (prázdno, znaky stromu
# z `lsblk`, cesta) se zahodí — jinak by se porovnání se seznamem disků
# nepovedlo a nedotknutelný disk by propadl mezi labové.
_jen_jmeno() { grep -xE '[a-z][a-z0-9]*' || true; }

# ── co je co ──────────────────────────────────────────────────────────
systemovy_disk() {
  # Kořen leží na LVM svazku, ne přímo na disku. `lsblk -s` jde závislostmi
  # dolů až k fyzickému disku — poslední řádek je on.
  # POZOR na `-r`: strom je u lsblk VÝCHOZÍ a `-s` ho nevypíná. Bez `-r`
  # by poslední řádek byl „└─sda", porovnání by nesedlo a systémový disk
  # by se tvářil jako labový.
  local zdroj; zdroj="$(findmnt -no SOURCE / 2>/dev/null)"
  [ -n "$zdroj" ] || return 1
  lsblk -nsro NAME "$zdroj" 2>/dev/null | tail -1 | _jen_jmeno
}

vsechny_disky() {  # skutečné disky — ne oddíly, ne CD, ne loop, ne zram
  lsblk -dnro NAME,TYPE 2>/dev/null \
    | awk '$2=="disk"{print $1}' | grep -vE '^(loop|zram|sr)' | sort
}

projektovy_disk() {
  # 1) Když je projektový oddíl založený, pozná se podle návěští.
  local zar disk
  zar="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
  if [ -n "$zar" ]; then
    disk="$(lsblk -nsro NAME "$zar" 2>/dev/null | tail -1 | _jen_jmeno)"
    [ -n "$disk" ] && { printf '%s\n' "$disk"; return 0; }
  fi
  # 2) Ještě není (před cvičením 4/00): je to NEJVĚTŠÍ nesystémový disk.
  #    Proto je projektový disk větší než labové — aby šel poznat dřív,
  #    než na něm cokoli vznikne. Při rovnosti se nevrací nic (viz níž).
  local sys; sys="$(systemovy_disk)" || return 1
  [ -n "$sys" ] || return 1
  local velikosti; velikosti="$(lsblk -dnrbo NAME,SIZE,TYPE 2>/dev/null \
    | awk -v s="$sys" '$3=="disk" && $1!=s && $1 !~ /^(loop|zram|sr)/ {print $2, $1}' | sort -rn)"
  [ -n "$velikosti" ] || return 1
  local prvni druha
  prvni="$(printf '%s\n' "$velikosti" | sed -n 1p | awk '{print $1}')"
  druha="$(printf '%s\n' "$velikosti" | sed -n 2p | awk '{print $1}')"
  [ -n "$druha" ] && [ "$prvni" = "$druha" ] && return 1     # nerozhodnutelné
  printf '%s\n' "$velikosti" | sed -n 1p | awk '{print $2}' | _jen_jmeno
}

labove_disky() {  # všechno ostatní; při nejistotě NIC
  local sys pro d
  sys="$(systemovy_disk)" || return 1
  pro="$(projektovy_disk)" || return 1
  [ -n "$sys" ] && [ -n "$pro" ] || return 1
  for d in $(vsechny_disky); do
    [ "$d" = "$sys" ] && continue
    [ "$d" = "$pro" ] && continue
    printf '%s\n' "$d"
  done
}

je_labovy() {  # je_labovy sdb|/dev/sdb|/dev/sdb1 → 0, když se na něj SMÍ sahat
  # Rodičovský disk se HLEDÁ přes lsblk. Odseknout číslice z názvu nejde:
  # u nvme0n1p1 by z toho vzniklo „nvme".
  local vstup="${1#/dev/}" d x
  [ -n "$vstup" ] || return 1
  if [ -b "/dev/$vstup" ]; then
    d="$(lsblk -nsro NAME "/dev/$vstup" 2>/dev/null | tail -1 | _jen_jmeno)"
  fi
  d="${d:-$(printf '%s' "$vstup" | _jen_jmeno)}"
  [ -n "$d" ] || return 1
  # Porovnává se ve smyčce, ne rourou do `grep -qx`: grep skončí hned po
  # shodě, tím shodí `labove_disky` signálem a `set -o pipefail` z toho
  # udělá nenulový návratový kód — funkce by odmítala i správné disky.
  while read -r x; do [ "$x" = "$d" ] && return 0; done < <(labove_disky)
  return 1
}

# ── trvalé přiřazení disků labům ──────────────────────────────────────
# Jména sd* přiděluje jádro v pořadí, ve kterém disky najde. Kdyby se
# pořadí změnilo (přidaný disk, jiný start), „první labový disk" by ukázal
# na cizí práci. Přiřazení se proto jednou uloží podle /dev/disk/by-id,
# což je jméno vázané na zařízení, ne na pořadí.
_by_id() {  # _by_id sdb → trvalá cesta, nebo nic
  local d="$1" p
  for p in /dev/disk/by-id/*; do
    [ -e "$p" ] || continue
    case "$p" in *-part*) continue ;; esac
    [ "$(basename "$(readlink -f "$p" 2>/dev/null)")" = "$d" ] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}
_zapis_mapu() {
  local i=1 d p
  : > "$DISKY_MAPA"
  while read -r d; do
    p="$(_by_id "$d")" || p=""
    printf '%s\t%s\t%s\n' "$i" "$d" "$p" >> "$DISKY_MAPA"
    i=$(( i + 1 ))
  done < <(labove_disky)
}
labovy_disk() {  # labovy_disk N → jméno N-tého labového disku (1 = první)
  local n="${1:-1}" d p akt
  [ -s "$DISKY_MAPA" ] || _zapis_mapu
  IFS=$'\t' read -r _ d p < <(awk -F'\t' -v n="$n" '$1==n' "$DISKY_MAPA" 2>/dev/null)
  if [ -n "${p:-}" ] && [ -e "$p" ]; then
    akt="$(basename "$(readlink -f "$p")")"        # disk se mohl přejmenovat
    je_labovy "$akt" && { printf '%s\n' "$akt"; return 0; }
  fi
  if [ -n "${d:-}" ] && je_labovy "$d"; then printf '%s\n' "$d"; return 0; fi
  # Mapa nesedí se skutečností (disk ubyl nebo přibyl) — přepsat a zkusit znovu.
  _zapis_mapu
  awk -F'\t' -v n="$n" '$1==n{print $2}' "$DISKY_MAPA" 2>/dev/null | _jen_jmeno
}

# ── pojistky ──────────────────────────────────────────────────────────
zkontroluj_disky() {  # zkontroluj_disky POČET → 0, když je dost labových disků
  local potreba="${1:-1}" mam d sys pro navic
  sys="$(systemovy_disk)"
  if [ -z "$sys" ]; then
    echo; echo "  Nepodařilo se zjistit, na kterém disku běží systém."
    echo "  Než se to vyjasní, nesmí se na disky sahat — řekněte to vyučujícímu."; echo
    return 1
  fi
  # Nejdřív: je vůbec co rozlišovat? (Jinak by se hlásila nerozhodnutelná
  # velikost i na stanici, která žádné disky navíc nemá.)
  navic="$(vsechny_disky | grep -vx "$sys" | grep -c '' )"
  if [ "$navic" -lt $(( potreba + 1 )) ]; then
    echo
    echo "  Tohle cvičení potřebuje $potreba labových disků a k tomu projektový."
    echo "  Stanice má kromě systémového disků navíc: $navic."
    echo "  Disky se přidávají ve VirtualBoxu u VYPNUTÉ stanice:"
    echo "    Nastavení → Úložiště → řadič SATA → přidat pevný disk."
    echo "  Labové mají 2 GB, projektový 4 GB. Řekněte o tom vyučujícímu."
    echo
    return 1
  fi
  pro="$(projektovy_disk)"
  if [ -z "$pro" ]; then
    echo
    echo "  Nedá se poznat, který disk je projektový: dva největší mají stejnou"
    echo "  velikost. Projektový disk musí být VĚTŠÍ než labové (4 GB proti 2 GB)."
    echo "  Řekněte o tom vyučujícímu — než se to spraví, nesmí se na disky sahat."
    echo
    return 1
  fi
  LABOVE_DISKY=()
  while read -r d; do [ -n "$d" ] && LABOVE_DISKY+=("$d"); done < <(labove_disky)
  mam="${#LABOVE_DISKY[@]}"
  if [ "$mam" -lt "$potreba" ]; then
    echo
    echo "  Tohle cvičení potřebuje labových disků: $potreba, stanice jich má $mam."
    echo "  Řekněte o tom vyučujícímu."
    echo
    return 1
  fi
  return 0
}

# ── pole RAID ─────────────────────────────────────────────────────────
pole_s_diskem() {  # pole_s_diskem sdc [sdd] → jméno pole (md0/md127), nebo nic
  # Hledá se podle ČLENSTVÍ, ne podle jména: jádro pole po restartu běžně
  # přejmenuje na md127. Vzor sedí na celý disk (sdc[0]) i na oddíl
  # (sdc1[0]) — pole se dá složit z obojího.
  local a="$1" b="${2:-}" radek pole
  while read -r radek; do
    pole="${radek%% *}"
    printf '%s' "$radek" | grep -qE "(^| )${a}[0-9]*\[" || continue
    if [ -n "$b" ]; then
      printf '%s' "$radek" | grep -qE "(^| )${b}[0-9]*\[" || continue
    fi
    printf '%s\n' "$pole"; return 0
  done < <(grep -E '^md[0-9]+ :' /proc/mdstat 2>/dev/null)
  return 1
}

# ── úklid (jen reset.sh) ──────────────────────────────────────────────
uvolni_disk() {  # uvolni_disk sdb — rozebere, co na disku stojí, a smaže stopy
  local d="${1#/dev/}" cast
  # Pojistka je tady, ne u volajícího: tahle funkce maže data.
  if ! je_labovy "$d"; then
    printf '  Odmítám sáhnout na /dev/%s — není to labový disk.\n' "$d" >&2
    return 1
  fi
  # odpojit vše, co z disku vychází
  for cast in $(lsblk -rno NAME "/dev/$d" 2>/dev/null | tail -n +2); do
    sudo umount "/dev/$cast" 2>/dev/null
    sudo umount "/dev/mapper/$cast" 2>/dev/null
  done
  # Pořadí je dané zásobníkem disk → RAID → LUKS → LVM: rozebírá se odshora.
  # Nástroje leží v /usr/sbin, který v PATH žáka být nemusí — volá se proto
  # rovnou přes sudo a rozhoduje výsledek, ne `command -v`.
  for cast in $(lsblk -rno NAME,TYPE "/dev/$d" 2>/dev/null | awk '$2=="lvm"{print $1}'); do
    sudo lvchange -an "/dev/mapper/$cast" >/dev/null 2>&1
  done
  local vg pv vse_moje
  while read -r vg; do
    [ -n "$vg" ] || continue
    # VG se ruší, JEN když všechny její disky jsou labové — jinak by se
    # smazala i část ležící jinde.
    vse_moje=1
    while read -r pv; do
      [ -n "$pv" ] || continue
      je_labovy "$pv" || vse_moje=0
    done < <(sudo pvs --noheadings -o pv_name --select "vg_name=$vg" 2>/dev/null | tr -d ' ')
    if [ "$vse_moje" = "1" ]; then
      sudo vgremove -f "$vg" >/dev/null 2>&1
    else
      printf '  Skupina svazků %s leží i mimo labové disky — nechávám ji být.\n' "$vg" >&2
    fi
  done < <(sudo pvs --noheadings -o vg_name "/dev/$d"* 2>/dev/null | tr -d ' ' | sort -u)
  sudo pvremove -ff -y "/dev/$d"* >/dev/null 2>&1
  for cast in $(lsblk -rno NAME,TYPE "/dev/$d" 2>/dev/null | awk '$2=="crypt"{print $1}'); do
    sudo cryptsetup close "$cast" >/dev/null 2>&1
  done
  # RAID: zastaví se jen pole, ve kterých je tenhle disk (celý i oddílem).
  local pole
  while pole="$(pole_s_diskem "$d")" && [ -n "$pole" ]; do
    sudo mdadm --stop "/dev/$pole" >/dev/null 2>&1 || break
  done
  sudo mdadm --zero-superblock "/dev/$d"* >/dev/null 2>&1
  # wipefs i na oddíly — jinak po novém rozdělení prosvítá starý podpis.
  for cast in $(lsblk -rno NAME "/dev/$d" 2>/dev/null | tail -n +2); do
    sudo wipefs -a "/dev/$cast" >/dev/null 2>&1
  done
  sudo wipefs -a "/dev/$d" >/dev/null 2>&1
  sudo sgdisk --zap-all "/dev/$d" >/dev/null 2>&1 \
    || sudo dd if=/dev/zero of="/dev/$d" bs=1M count=10 status=none 2>/dev/null
  sudo partprobe "/dev/$d" >/dev/null 2>&1
  command -v udevadm >/dev/null 2>&1 && sudo udevadm settle >/dev/null 2>&1
  # Ověřovací příkaz se musí ověřit taky: když na disku něco zbylo (třeba
  # běžící pole, které nešlo zastavit), nesmí se hlásit „hotovo".
  if [ -n "$(lsblk -rno NAME "/dev/$d" 2>/dev/null | tail -n +2)" ] \
     || [ -n "$(lsblk -dnro PTTYPE,FSTYPE "/dev/$d" 2>/dev/null | tr -d ' ')" ]; then
    printf '  Na /dev/%s něco zůstalo — nepodařilo se ho uvolnit.\n' "$d" >&2
    return 1
  fi
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
  sudo chown "$(id -un):$(id -gn)" "$PROJEKT_PRIPOJ" 2>/dev/null
  projekt_pripojen
}
