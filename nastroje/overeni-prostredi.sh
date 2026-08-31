#!/bin/bash
# Ověření předpokladů plánu cvičení OS.
# Spusť v Ubuntu Desktop VM (té, která má být šablonou pro žáky).
#
# CO SKRIPT DĚLÁ: čte stav systému, vytvoří dva dočasné LXD kontejnery
# s prefixem "overeni-" a na konci je smaže. Nemění síť, nic neinstaluje
# do systému, nesahá na existující kontejnery.
#
# Použití:  bash ~/os-lab/nastroje/overeni-prostredi.sh
# Výstup:   souhrn na konci; podrobnosti průběžně.

VYSLEDKY=()
zapis() { VYSLEDKY+=("$1|$2|$3"); }   # stav|téma|poznámka

hlavicka() { printf '\n\033[1;34m== %s ==\033[0m\n' "$1"; }
ok()   { printf '  \033[0;32m[OK]\033[0m   %s\n' "$1"; }
varuj(){ printf '  \033[0;33m[!]\033[0m    %s\n' "$1"; }
chyba(){ printf '  \033[0;31m[NE]\033[0m   %s\n' "$1"; }
info() { printf '         %s\n' "$1"; }

# ---------------------------------------------------------------- 0. Kontext
hlavicka "0. Prostředí"
info "Distribuce: $(lsb_release -ds 2>/dev/null || echo neznámá)"
info "Architektura: $(dpkg --print-architecture 2>/dev/null)"
info "Jádro:      $(uname -r)"
RAM=$(free -g | awk '/^Mem:/{print $2}')
info "RAM:        ${RAM} GB"
DISK=$(df -BG --output=avail / | tail -1 | tr -d ' G')
info "Volno na /: ${DISK} GB"
if [ "$RAM" -ge 7 ]; then ok "RAM pro VM dostačuje"; else varuj "málo RAM (${RAM} GB) — kontejnery ano, druhá VM ne"; fi

# ------------------------------------------------------- 1. netplan renderer
hlavicka "1. netplan — který renderer řídí síť"
if command -v netplan >/dev/null; then
  R=$(grep -rhoP '^\s*renderer:\s*\K\w+' /etc/netplan/ 2>/dev/null | head -1)
  [ -z "$R" ] && R="(neuveden — platí výchozí)"
  info "renderer v /etc/netplan: $R"
  ls -1 /etc/netplan/ 2>/dev/null | sed 's/^/         soubor: /'
  if systemctl is-active --quiet NetworkManager; then
    varuj "Síť řídí NetworkManager (typické pro Desktop)"
    info "Lab 3/1 musí počítat s NM: 'netplan get', renderer: NetworkManager,"
    info "a s tím, že NM si zapisuje vlastní YAML. Na Serveru je to systemd-networkd."
    zapis "POZOR" "netplan" "renderer = NetworkManager, ne systemd-networkd"
  elif systemctl is-active --quiet systemd-networkd; then
    ok "Síť řídí systemd-networkd (jako na Serveru) — lab 3/1 beze změny"
    zapis "OK" "netplan" "systemd-networkd"
  else
    varuj "Nerozpoznáno, ověř ručně"
    zapis "POZOR" "netplan" "renderer nerozpoznán"
  fi
  info "Bezpečný test statické adresy: udělej ho na DRUHÉM, nepoužívaném adaptéru"
  info "  a přes 'sudo netplan try' (samo se vrátí za 120 s, když ztratíš spojení)."
else
  chyba "netplan není nainstalován"; zapis "NE" "netplan" "chybí"
fi

# ------------------------------------------------------------------ 2. LXD
hlavicka "2. LXD"
if ! command -v lxc >/dev/null; then
  chyba "LXD není nainstalován — testy 3-5 přeskočeny"
  info "Instalace: sudo snap install lxd && sudo lxd init --minimal"
  info "           sudo usermod -aG lxd \$USER   (pak se odhlas a přihlas)"
  zapis "NE" "LXD" "není nainstalován — doinstaluj a spusť skript znovu"
  LXD=0
else
  LXD=1
  info "Verze: $(lxc version 2>/dev/null | head -1)"
  SD=$(lxc storage list -f csv 2>/dev/null | awk -F, 'NR==1{print $2}')
  info "Storage driver: ${SD:-neznámý}"
  if [ "$SD" = "zfs" ]; then
    varuj "ZFS backend → Docker uvnitř kontejneru spadne do vfs (pomalé)"
    info "Doporučení plánu: Docker provozovat PŘÍMO ve VM, ne v kontejneru."
    zapis "POZOR" "LXD storage" "ZFS — Docker jen přímo ve VM"
  else
    ok "Storage driver ${SD:-?} — pro Docker v kontejneru přijatelnější než ZFS"
    zapis "OK" "LXD storage" "${SD:-?}"
  fi
  echo "  Vytvářím testovací kontejner (může chvíli trvat, stahuje obraz)..."
  if lxc launch ubuntu:24.04 overeni-test >/dev/null 2>&1; then
    ok "Kontejner overeni-test běží"
    sleep 8
  else
    chyba "Kontejner se nepodařilo spustit — zkontroluj 'lxc launch ubuntu:24.04' ručně"
    LXD=0; zapis "NE" "LXD launch" "kontejner nelze spustit"
  fi
fi

# ------------------------------------------------- 3. WireGuard v kontejneru
hlavicka "3. WireGuard v nepřivilegovaném kontejneru (lab 4/12)"
if [ "$LXD" = "1" ]; then
  modprobe wireguard 2>/dev/null
  if lsmod | grep -q '^wireguard'; then info "Modul wireguard je na hostiteli zaveden"
  else varuj "Modul wireguard není zaveden — zkus 'sudo modprobe wireguard'"; fi
  lxc exec overeni-test -- bash -c "apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq wireguard-tools >/dev/null 2>&1"
  if lxc exec overeni-test -- ip link add wg0 type wireguard >/dev/null 2>&1; then
    ok "WireGuard rozhraní v kontejneru VZNIKLO → lab 4/12 pojede v LXD"
    lxc exec overeni-test -- ip link del wg0 >/dev/null 2>&1
    zapis "OK" "WireGuard" "funguje v nepřivilegovaném kontejneru"
  else
    chyba "WireGuard rozhraní NELZE vytvořit (Operation not supported)"
    info "Náhradní scénář z plánu: VPN mezi Ubuntu VM a kontejnerem,"
    info "nebo kontejner privilegovaný / s /dev/net/tun."
    zapis "NE" "WireGuard" "nutný náhradní scénář (VM ↔ kontejner)"
  fi
else info "přeskočeno (LXD nedostupný)"; fi

# ------------------------------------------------------- 4. ufw v kontejneru
hlavicka "4. ufw v kontejneru (lab 3/13)"
if [ "$LXD" = "1" ]; then
  lxc exec overeni-test -- bash -c "apt-get install -y -qq ufw >/dev/null 2>&1"
  if lxc exec overeni-test -- bash -c "ufw --force enable >/dev/null 2>&1 && ufw status" 2>/dev/null | grep -qi active; then
    ok "ufw se v kontejneru zapnul a hlásí status → lab 3/13 pojede v LXD"
    zapis "OK" "ufw" "funguje v kontejneru"
  else
    varuj "ufw v kontejneru nefunguje — lab 3/13 přesunout na samotnou VM"
    info "(na pracovní stanici je firewall stejně přirozenější)"
    zapis "POZOR" "ufw" "přesunout na VM"
  fi
else info "přeskočeno (LXD nedostupný)"; fi

# ------------------------------------------- 5. Konflikt dnsmasq na lxdbr0
hlavicka "5. Vlastní dnsmasq na lxdbr0 (proč je potřeba síť netlab)"
if [ "$LXD" = "1" ]; then
  if pgrep -af dnsmasq | grep -q lxdbr0; then
    varuj "LXD skutečně provozuje dnsmasq na lxdbr0 — DHCP/DNS laby by se s ním praly"
    info "Řešení podle plánu:"
    info "  lxc network create netlab ipv4.address=10.10.10.1/24 ipv4.dhcp=false ipv4.nat=true"
    zapis "POZOR" "dnsmasq/lxdbr0" "potvrzeno — nutná síť netlab pro laby 3/14, 3/15"
  else
    ok "dnsmasq na lxdbr0 neběží — konflikt nehrozí (přesto síť netlab doporučena)"
    zapis "OK" "dnsmasq/lxdbr0" "neběží"
  fi
else info "přeskočeno (LXD nedostupný)"; fi

# ---------------------------------------------------- 6. Emergency shell
hlavicka "6. Emergency shell — dostane se do něj žák? (lab 4/7)"
if sudo passwd -S root 2>/dev/null | grep -qE ' (L|NP) '; then
  varuj "Účet root je ZAMČENÝ"
  info "Riziko: sulogin může v emergency režimu chtít heslo a nepustit dál."
  info "Pojistka podle plánu: v šabloně VM nastavit heslo roota (sudo passwd root)."
  zapis "POZOR" "emergency shell" "root zamčen — nastav heslo v šabloně"
else
  ok "Účet root má heslo → emergency shell bude přístupný"
  zapis "OK" "emergency shell" "root má heslo"
fi
info "Plný test uděláš jen ručně: rozbij /etc/fstab (neexistující UUID) a restartuj."

# --------------------------------------------------------------- 7. PHP/GLPI
hlavicka "7. PHP pro GLPI (lab 2/14)"
PHPV=$(apt-cache policy php 2>/dev/null | awk '/Candidate/{print $2}')
info "Kandidát balíčku php: ${PHPV:-nezjištěn}"
info "Plán doporučuje GLPI jako HOTOVÝ kontejner, ne stavět zásobník v hodině —"
info "pak je verze PHP starost image, ne tvoje."
zapis "INFO" "GLPI/PHP" "${PHPV:-nezjištěn} — doporučen hotový kontejner"

# ------------------------------------------------------------------ Úklid
hlavicka "Úklid"
if [ "$LXD" = "1" ]; then
  lxc delete -f overeni-test >/dev/null 2>&1 && ok "Testovací kontejner smazán"
fi

# ------------------------------------------------------------------ Souhrn
printf '\n\033[1;34m======== SOUHRN ========\033[0m\n'
for r in "${VYSLEDKY[@]}"; do
  IFS='|' read -r stav tema pozn <<< "$r"
  case "$stav" in
    OK)    printf '  \033[0;32m%-6s\033[0m %-18s %s\n' "$stav" "$tema" "$pozn" ;;
    POZOR) printf '  \033[0;33m%-6s\033[0m %-18s %s\n' "$stav" "$tema" "$pozn" ;;
    NE)    printf '  \033[0;31m%-6s\033[0m %-18s %s\n' "$stav" "$tema" "$pozn" ;;
    *)     printf '  %-6s %-18s %s\n' "$stav" "$tema" "$pozn" ;;
  esac
done
echo
