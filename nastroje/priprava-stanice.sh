#!/bin/bash
# Příprava šablony VM pro cvičení OS.
# Cíl: čistý Ubuntu Server 26.04 LTS → připravená laboratoř s LXD a prostředím MATE.
#
# Funguje na x86_64 (školní stanice) i arm64 (vývojová VM na Macu) — postup
# je stejný, liší se jen architektura instalačního obrazu.
#
# Spusť jako běžný uživatel (sysadmin), NE jako root:
#     bash ~/os-lab/nastroje/priprava-stanice.sh
# sudo si o heslo řekne samo.
#
# Skript je idempotentní — lze pustit opakovaně.

set -uo pipefail

krok()  { printf '\n\033[1;34m== %s ==\033[0m\n' "$1"; }
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$1"; }
varuj() { printf '  \033[0;33m!\033[0m %s\n' "$1"; }
chyba() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; }
info()  { printf '    %s\n' "$1"; }

# ------------------------------------------------------------ kontroly
if [ "$(id -u)" = "0" ]; then
  chyba "Nespouštěj jako root. Spusť jako sysadmin, sudo se použije uvnitř."
  exit 1
fi

VER=$(lsb_release -rs 2>/dev/null)
if [ "$VER" != "26.04" ]; then
  varuj "Očekáváno Ubuntu 26.04, nalezeno: ${VER:-neznámé}. Pokračuji, ale nemusí sedět."
fi
info "Architektura: $(dpkg --print-architecture)"

echo "Skript připraví tuto VM jako šablonu laboratoře. Bude potřeba heslo pro sudo."
sudo -v || { chyba "sudo selhalo"; exit 1; }
# udržet sudo naživu po celou dobu běhu
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

# ------------------------------------------------------------ 1. aktualizace
krok "1/8 Aktualizace systému"
info "(na pomalém síťovém disku to může trvat i 10 minut)"
sudo apt-get update -qq && ok "Seznamy balíčků aktualizovány"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade && ok "Systém aktualizován"

# ------------------------------------------------------------ 2. balíčky
krok "2/8 Grafické prostředí MATE"
if dpkg -s ubuntu-mate-core >/dev/null 2>&1 || dpkg -s mate-desktop-environment >/dev/null 2>&1; then
  ok "Prostředí MATE už je nainstalované"
else
  info "Server nemá grafické prostředí. Doinstaluji ubuntu-mate-core."
  info "(Stahuje stovky MB — dělej to jednou při stavbě šablony, ne ve třídě.)"
  read -r -p "    Nainstalovat MATE teď? [A/n] " ODP
  if [[ ! "$ODP" =~ ^[nN]$ ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ubuntu-mate-core \
      && ok "MATE nainstalováno" || chyba "Instalace MATE selhala"
    # prohlížeč potřebují laby s certifikátem, GLPI a Grafanou
    sudo snap install firefox >/dev/null 2>&1 && ok "Firefox nainstalován"
    info "Po restartu se přihlásíš do grafického prostředí."
  else
    varuj "Přeskočeno — laby s prohlížečem (certifikát, GLPI) pak nepůjdou"
  fi
fi

krok "3/8 Nástroje pro laby"
BALICKY=(
  openssh-server        # laby 3/3, 3/4 (SSH)
  ufw                   # lab 3/13 (firewall)
  wireguard-tools       # lab 4/12 (VPN)
  git                   # lab 3/6
  curl wget             # obecně
  tree htop             # orientace, procesy
  vim nano              # lab 2/7 (editory)
  mdadm                 # lab 4/2 (RAID)
  lvm2                  # lab 4/5 (LVM)
  cryptsetup            # lab 4/4 (LUKS)
  restic                # lab 4/8 (zálohy)
  shellcheck            # lab 3/20 (Bash)
  chrony                # čas — bez něj se rozjedou logy i ověřování
)
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${BALICKY[@]}" \
  && ok "Nainstalováno ${#BALICKY[@]} balíčků"
info "Pozn.: Docker se instaluje až v labu 3/21 — je to učivo, ne infrastruktura."

# ------------------------------------------------------------ 3. LXD
krok "4/8 LXD"
if command -v lxc >/dev/null 2>&1; then
  ok "LXD už je nainstalován ($(lxc version 2>/dev/null | head -1))"
else
  sudo snap install lxd && ok "LXD nainstalován"
fi
sudo snap refresh --hold lxd >/dev/null 2>&1 \
  && ok "Automatické aktualizace LXD pozastaveny (ať se neaktualizuje uprostřed hodiny)"

if ! id -nG "$USER" | grep -qw lxd; then
  sudo usermod -aG lxd "$USER" && ok "Uživatel $USER přidán do skupiny lxd"
  ODHLASIT=1
else
  ok "Uživatel $USER už je ve skupině lxd"; ODHLASIT=0
fi

# ------------------------------------------------------------ 4. lxd init
krok "5/8 Inicializace LXD"
if sudo lxc storage list -f csv 2>/dev/null | grep -q .; then
  ok "LXD je už inicializován — přeskakuji"
else
  info "Vytvářím úložiště btrfs (rychlé klonování kontejnerů) a most lxdbr0..."
  sudo lxd init --preseed <<'PRESEED'
config: {}
networks:
- name: lxdbr0
  type: bridge
  config:
    ipv4.address: auto
    ipv6.address: none
storage_pools:
- name: default
  driver: btrfs
  config:
    size: 25GiB
profiles:
- name: default
  devices:
    eth0:
      name: eth0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
PRESEED
  [ $? -eq 0 ] && ok "LXD inicializován (btrfs, lxdbr0)" || chyba "lxd init selhal"
fi

# ------------------------------------------------------------ 5. síť netlab
krok "6/8 Izolovaná síť netlab (pro laby DNS a DHCP)"
if sudo lxc network list -f csv 2>/dev/null | grep -q '^netlab,'; then
  ok "Síť netlab už existuje"
else
  sudo lxc network create netlab \
      ipv4.address=10.10.10.1/24 ipv4.dhcp=false ipv4.nat=true ipv6.address=none \
    && ok "Síť netlab vytvořena (bez vlastního DHCP — žákův DHCP server bude jediný)"
fi

# ------------------------------------------------------------ 6. obrazy
krok "7/8 Předstažení obrazů do lokální cache"
info "Kvůli síťovému disku a 30 žákům naráz — v hodině se pak nestahuje nic."
if sudo lxc image list local: -f csv 2>/dev/null | grep -q 'ubuntu-26.04'; then
  ok "Obraz ubuntu-26.04 je už v lokální cache"
else
  info "Stahuji ubuntu:26.04 (~200 MB, chvíli to potrvá)..."
  sudo lxc image copy ubuntu:26.04 local: --alias ubuntu-26.04 --auto-update \
    && ok "Obraz uložen jako lokální alias 'ubuntu-26.04'"
  info "V labech pak: lxc launch ubuntu-26.04 <jmeno>   (bez dvojtečky = lokální)"
fi

# ------------------------------------------------------------ 7. heslo roota
krok "8/8 Heslo uživatele root"
if sudo passwd -S root 2>/dev/null | grep -qE ' (L|NP) '; then
  varuj "Účet root je zamčený."
  info "Lab 4/7 (oprava fstab z emergency shellu) na tom může ztroskotat —"
  info "sulogin si v nouzovém režimu může vyžádat heslo roota a nepustit dál."
  read -r -p "    Nastavit heslo roota teď? [a/N] " ODP
  if [[ "$ODP" =~ ^[aAyY]$ ]]; then
    sudo passwd root && ok "Heslo roota nastaveno"
  else
    varuj "Přeskočeno — lab 4/7 ověř ručně, než ho zadáš žákům"
  fi
else
  ok "Účet root má heslo — emergency shell bude přístupný"
fi

# ------------------------------------------------------------ souhrn
printf '\n\033[1;34m======== HOTOVO ========\033[0m\n'
echo
if [ "${ODHLASIT:-0}" = "1" ]; then
  printf '  \033[0;33mNEŽ BUDEŠ POKRAČOVAT:\033[0m odhlas se a znovu přihlas\n'
  printf '  (nebo restartuj VM) — jinak nebude fungovat lxc bez sudo.\n\n'
fi
echo "  Doporučeno ve VirtualBoxu (kvůli schránce a rozlišení):"
echo "     Zařízení → Připojit obraz CD s Guest Additions"
echo
echo "  Až se přihlásíš zpět, spusť ověření předpokladů plánu:"
echo "     bash ~/os-lab/nastroje/overeni-prostredi.sh"
echo
echo "  Potom VM vypni a udělej snapshot 'cista-sablona' — z něj budou"
echo "  vycházet všechny žákovské kopie."
echo
