#!/bin/bash
# Bootstrap laboratoře — z čistého Ubuntu Serveru jedním příkazem.
#
# Řeší slepici a vejce: příprava stanice žije v tomhle repozitáři, ale na
# čerstvém Serveru není `git`, kterým by se repozitář stáhl. Tenhle skript
# doinstaluje git, stáhne os-lab a předá řízení priprava-stanice.sh.
#
# Spusť jako běžný uživatel (sysadmin), NE jako root:
#     bash bootstrap.sh
#
# Skript je idempotentní — na už postavené stanici jen doplní, co chybí.

set -uo pipefail

krok()  { printf '\n\033[1;34m== %s ==\033[0m\n' "$1"; }
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$1"; }
varuj() { printf '  \033[0;33m!\033[0m %s\n' "$1"; }
chyba() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; }
info()  { printf '    %s\n' "$1"; }

REPO="https://github.com/eduxo/os-lab.git"
CIL="$HOME/os-lab"

# ------------------------------------------------------------ kontroly
if [ "$(id -u)" = "0" ]; then
  chyba "Nespouštěj jako root — repozitář by skončil v /root a skupiny"
  info  "lxd a docker by se přidaly rootovi místo tobě."
  info  "Spusť jako sysadmin, sudo se použije uvnitř."
  exit 1
fi

echo
echo "  Bootstrap laboratoře OS. Bude potřeba heslo pro sudo."
sudo -v || { chyba "sudo selhalo"; exit 1; }
# udržet sudo naživu po celou dobu běhu
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

# ------------------------------------------------------------ 1. git
krok "1/3 Nástroje pro stažení repozitáře"
# Na čerstvém Ubuntu Serveru git chybí. ca-certificates je potřeba na
# ověření certifikátu GitHubu — bez nich `git clone` přes https spadne.
if command -v git >/dev/null 2>&1; then
  ok "git už je nainstalovaný"
else
  info "Instaluji git…"
  sudo apt-get update -qq \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git ca-certificates \
    || { chyba "Instalace gitu selhala — má stanice přístup k internetu?"; exit 1; }
  # Ověřovací příkaz se musí ověřit taky: apt skončí nulou i tehdy, když
  # balíček nakonec chybí, a `git clone` by pak spadl o krok dál.
  command -v git >/dev/null 2>&1 \
    && ok "git nainstalován ($(git --version | awk '{print $3}'))" \
    || { chyba "git se nainstalovat nepodařilo"; exit 1; }
fi

# ------------------------------------------------------------ 2. repozitář
krok "2/3 Repozitář os-lab"
if [ -d "$CIL/.git" ]; then
  info "Repozitář už tu je — aktualizuji."
  if git -C "$CIL" pull --ff-only >/dev/null 2>&1; then
    ok "os-lab aktualizován na nejnovější verzi"
  else
    varuj "git pull neprošel — máš v repozitáři vlastní změny?"
    info  "Stanice se postaví z toho, co je stažené teď."
  fi
elif [ -e "$CIL" ]; then
  chyba "$CIL existuje, ale není to repozitář."
  info  "Přejmenuj ho nebo smaž a spusť skript znovu."
  exit 1
else
  info "Stahuji $REPO…"
  git clone --depth 1 "$REPO" "$CIL" >/dev/null 2>&1 \
    && ok "os-lab stažen do $CIL" \
    || { chyba "Stažení selhalo — zkontroluj připojení k internetu"; exit 1; }
fi

PRIPRAVA="$CIL/nastroje/priprava-stanice.sh"
[ -f "$PRIPRAVA" ] || { chyba "V repozitáři chybí $PRIPRAVA"; exit 1; }

# ------------------------------------------------------------ 3. příprava
krok "3/3 Příprava stanice"
info "Předávám řízení skriptu priprava-stanice.sh."
info "Bude se ptát na doinstalování prostředí MATE a na heslo roota."
echo
# Sudo keepalive z bootstrapu už nepotřebujeme — priprava-stanice.sh si
# spouští vlastní. Bez tohohle by po doběhnutí zůstal viset na pozadí.
kill "$SUDO_KEEPALIVE" 2>/dev/null
trap - EXIT
exec bash "$PRIPRAVA"
