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
krok "1/9 Aktualizace systému"
info "(na pomalém síťovém disku to může trvat i 10 minut)"
sudo apt-get update -qq && ok "Seznamy balíčků aktualizovány"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade && ok "Systém aktualizován"

# ------------------------------------------------------------ 2. balíčky
krok "2/9 Kořenový svazek — využít celý disk"
# Instalátor Ubuntu Serveru vytvoří LVM svazek jen na část disku (typicky
# polovinu) a zbytek nechá ve skupině nevyužitý. Bez rozšíření dojde místo
# někdy uprostřed roku — obrazy kontejnerů a snapshoty rostou.
ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null)"
ROOT_FS="$(findmnt -no FSTYPE / 2>/dev/null)"
if ! command -v lvs >/dev/null 2>&1 || ! sudo lvs "$ROOT_SRC" >/dev/null 2>&1; then
  info "Kořen neleží na LVM ($ROOT_SRC) — rozšiřovat není co, přeskakuji."
else
  VG="$(sudo lvs --noheadings -o vg_name "$ROOT_SRC" 2>/dev/null | tr -d ' ')"
  VOLNO="$(sudo vgs --noheadings -o vg_free --units g "$VG" 2>/dev/null | tr -d ' g<')"
  VOLNO_INT="${VOLNO%%.*}"
  info "Skupina svazků: $VG · volné místo: ${VOLNO:-0} GB"
  if [ "${VOLNO_INT:-0}" -lt 1 ]; then
    ok "Svazek už zabírá celý disk"
  else
    varuj "Ve skupině leží nevyužitých ${VOLNO_INT} GB."
    info "Rozšíření proběhne za provozu, bez restartu a bez ztráty dat."
    read -r -p "    Rozšířit kořenový svazek na celý disk? [A/n] " ODP
    if [[ ! "$ODP" =~ ^[nN]$ ]]; then
      sudo lvextend -l +100%FREE "$ROOT_SRC" >/dev/null 2>&1 && ok "Svazek rozšířen"
      case "$ROOT_FS" in
        ext*) sudo resize2fs "$ROOT_SRC" >/dev/null 2>&1 && ok "Souborový systém zvětšen (ext)" ;;
        xfs)  sudo xfs_growfs / >/dev/null 2>&1 && ok "Souborový systém zvětšen (xfs)" ;;
        *)    varuj "Neznámý souborový systém $ROOT_FS — zvětši ho ručně" ;;
      esac
      info "Nyní volno: $(df -h --output=avail / | tail -1 | tr -d ' ')"
    else
      varuj "Přeskočeno — počítej s tím při stavbě šablony"
    fi
  fi
fi

krok "3/9 Grafické prostředí MATE"
if dpkg -s ubuntu-mate-core >/dev/null 2>&1 || dpkg -s mate-desktop-environment >/dev/null 2>&1; then
  ok "Prostředí MATE už je nainstalované"
else
  info "Server nemá grafické prostředí. Doinstaluji ubuntu-mate-core."
  info "(Stahuje stovky MB — dělej to jednou při stavbě šablony, ne ve třídě.)"
  read -r -p "    Nainstalovat MATE teď? [A/n] " ODP
  if [[ ! "$ODP" =~ ^[nN]$ ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ubuntu-mate-core \
      && ok "MATE nainstalováno" || chyba "Instalace MATE selhala"
    # prohlížeč potřebují laby s certifikátem a Grafanou
    sudo snap install firefox >/dev/null 2>&1 && ok "Firefox nainstalován"
    info "Po restartu se přihlásíš do grafického prostředí."
  else
    varuj "Přeskočeno — laby s prohlížečem (certifikát, Grafana) pak nepůjdou"
  fi
fi

krok "4/9 Nástroje pro laby"
# Seznam je v nastroje/balicky.txt — tam se doplňuje při psaní nových labů.
SEZNAM="$(dirname "$0")/balicky.txt"
if [ ! -f "$SEZNAM" ]; then
  chyba "Chybí $SEZNAM — bez něj nevím, co instalovat."; exit 1
fi
mapfile -t BALICKY < <(sed 's/#.*//' "$SEZNAM" | tr -s ' ' '\n' | grep -v '^$')
info "Ze seznamu: ${#BALICKY[@]} balíčků"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${BALICKY[@]}" \
  && ok "Nainstalováno ${#BALICKY[@]} balíčků" || chyba "Instalace balíčků selhala"
# Docker je v balicky.txt jako všechno ostatní: instalace není učivo labu
# 3/21 (ten je o obrazech, portech a svazcích) a 30 žáků instalujících
# naráz přes síťový disk je týž problém jako stahování obrazů.
if command -v docker >/dev/null 2>&1; then
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    ok "Docker je nainstalovaný a $USER je ve skupině docker"
  else
    sudo usermod -aG docker "$USER" \
      && ok "Uživatel $USER přidán do skupiny docker" \
      && varuj "Projeví se to až po novém přihlášení — odhlaste se a přihlaste."
  fi
fi
info "Nové balíčky se přidávají do nastroje/balicky.txt, ne sem."

# --------------------------------------------- 4b. doplňky hypervizoru
krok "4b/9 Doplňky hypervizoru (schránka, rozlišení)"
# Bez nich se ve VM nedá kopírovat mezi hostitelem a hostem a okno nemění
# rozlišení — na to žáci narazí hned první hodinu. Balíčky z Ubuntu jsou
# lepší než ISO s Guest Additions: nic se nepřekládá (moduly vboxguest,
# vboxsf a vboxvideo jsou přímo v jádře Ubuntu) a přežije to aktualizaci
# jádra. Hypervizor se pozná sám, ať skript sedí na VirtualBox i na VMware.
HV="$(systemd-detect-virt 2>/dev/null || echo none)"
case "$HV" in
  oracle)
    info "Běžíme ve VirtualBoxu"
    # virtualbox-guest-* je v multiverse — na Serveru bývá zapnuté, ale
    # ověřit se to musí, jinak apt jen řekne „nemá kandidáta".
    if ! apt-cache policy virtualbox-guest-utils 2>/dev/null | grep -q 'Candidate: [0-9]'; then
      varuj "virtualbox-guest-utils není dostupný — chybí nejspíš multiverse"
      info "Zapni ho:  sudo add-apt-repository multiverse && sudo apt-get update"
    else
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq         virtualbox-guest-utils virtualbox-guest-x11         && ok "Doplňky VirtualBoxu nainstalovány"         || chyba "Instalace doplňků VirtualBoxu selhala"
      # Ověřovací příkaz se musí ověřit taky: balíček se nainstaluje i tehdy,
      # když modul v jádře není, a schránka pak beze slova nefunguje.
      if modinfo vboxguest >/dev/null 2>&1; then
        ok "Modul vboxguest je v jádře k dispozici"
      else
        varuj "Modul vboxguest v jádře není — schránka ani rozlišení fungovat nebudou"
        info "Doinstaluj:  sudo apt-get install linux-modules-extra-\$(uname -r)"
      fi
    fi ;;
  vmware)
    info "Běžíme ve VMware (cylab)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq       open-vm-tools open-vm-tools-desktop       && ok "open-vm-tools nainstalovány"       || chyba "Instalace open-vm-tools selhala" ;;
  none)
    info "Neběžíme ve virtuálu — doplňky hypervizoru přeskakuji" ;;
  *)
    info "Hypervizor '$HV' neznám — doplňky nech na sobě" ;;
esac

# ------------------------------------------------------------ 3. LXD
krok "5/9 LXD"
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
krok "6/9 Inicializace LXD"
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
krok "7/9 Izolovaná síť netlab (pro laby DNS a DHCP)"
if sudo lxc network list -f csv 2>/dev/null | grep -q '^netlab,'; then
  ok "Síť netlab už existuje"
else
  sudo lxc network create netlab \
      ipv4.address=10.10.10.1/24 ipv4.dhcp=false ipv4.nat=true ipv6.address=none \
    && ok "Síť netlab vytvořena (bez vlastního DHCP — žákův DHCP server bude jediný)"
fi

# ------------------------------------------------------------ 6. obrazy
krok "8/9 Předstažení obrazů do lokální cache"
info "Kvůli síťovému disku a 30 žákům naráz — v hodině se pak nestahuje nic."
if sudo lxc image list local: -f csv 2>/dev/null | grep -q 'ubuntu-26.04'; then
  ok "Obraz ubuntu-26.04 je už v lokální cache"
else
  info "Stahuji ubuntu:26.04 (~200 MB, chvíli to potrvá)..."
  sudo lxc image copy ubuntu:26.04 local: --alias ubuntu-26.04 --auto-update \
    && ok "Obraz uložen jako lokální alias 'ubuntu-26.04'"
  info "V labech pak: lxc launch ubuntu-26.04 <jmeno>   (bez dvojtečky = lokální)"
fi

# ------------------------------------------------------------ 6b. obrazy Dockeru
krok "8b/9 Obrazy Dockeru do lokální cache"
# Docker Hub má limity pro anonymní stahování z jedné adresy a 30 žáků
# za jedním NATem je spolehlivě trefí. Obrazy se proto stáhnou jednou při
# stavbě šablony a uloží i jako .tar — kdyby se na rozdané VM ztratily
# z úložiště Dockeru, laby si je načtou odtamtud a nesahají na síť.
OBRAZY_DIR=/opt/os-lab/obrazy
if ! command -v docker >/dev/null 2>&1; then
  varuj "Docker není nainstalovaný — obrazy pro 3/21 se nepřipraví"
elif ! sudo docker info >/dev/null 2>&1; then
  varuj "Docker je nainstalovaný, ale démon neběží — obrazy se nepřipraví"
  info "Zkuste: sudo systemctl start docker"
else
  sudo mkdir -p "$OBRAZY_DIR"
  for OBRAZ in nginx:alpine alpine:latest; do
    SOUBOR="$OBRAZY_DIR/$(printf '%s' "$OBRAZ" | tr ':/' '--').tar"
    if sudo docker image inspect "$OBRAZ" >/dev/null 2>&1; then
      ok "Obraz $OBRAZ je v lokální cache"
    elif [ -f "$SOUBOR" ]; then
      sudo docker load -i "$SOUBOR" >/dev/null 2>&1 \
        && ok "Obraz $OBRAZ načten ze zálohy" \
        || varuj "Obraz $OBRAZ se nepodařilo načíst ze zálohy"
    else
      info "Stahuji $OBRAZ (jednorázově, při stavbě šablony)..."
      sudo docker pull "$OBRAZ" >/dev/null 2>&1 \
        && ok "Obraz $OBRAZ stažen" \
        || varuj "Obraz $OBRAZ se nepodařilo stáhnout — laby 3/21 a 3/21b bez něj nepojedou"
    fi
    if [ ! -f "$SOUBOR" ]; then
      sudo docker save -o "$SOUBOR" "$OBRAZ" >/dev/null 2>&1 \
        || varuj "Zálohu obrazu $OBRAZ se nepodařilo uložit do $SOUBOR"
    fi
  done
  sudo chmod -R a+rX "$OBRAZY_DIR" 2>/dev/null
  # Plugin Compose je SAMOSTATNÝ balíček (docker-compose-v2) a je jediné
  # místo, kde se dá zjistit, jestli doskočil. Instalace balíčků je jedno
  # volání apt, takže při jednom nedostupném balíčku padne celé pole.
  if docker compose version >/dev/null 2>&1; then
    ok "Plugin docker compose je k dispozici"
  else
    varuj "Plugin 'docker compose' chybí — lab 3/21b bez něj nepojede"
    info "Balíček se jmenuje docker-compose-v2 a je v nastroje/balicky.txt"
  fi
fi

# ------------------------------------------------------------ 7. heslo roota
krok "9/9 Heslo uživatele root"
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
echo "  Schránku a rozlišení řeší krok 4b sám (balíčky z Ubuntu)."
echo "  ISO s Guest Additions připojuj jen tehdy, když 4b ohlásil potíž."
echo
echo "  Až se přihlásíš zpět, spusť ověření předpokladů plánu:"
echo "     bash ~/os-lab/nastroje/overeni-prostredi.sh"
echo
echo "  Potom VM vypni a udělej snapshot 'cista-sablona' — z něj budou"
echo "  vycházet všechny žákovské kopie."
echo
