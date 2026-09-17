#!/bin/bash
# Příprava stanice pro cvičení OS — JEDEN soubor, od gitu po hotovou laboratoř.
# Cíl: čistý Ubuntu Server 26.04 LTS → laboratoř s LXD, Dockerem a prostředím MATE.
#
# Na čistou stanici se stáhne takhle:
#     curl -fsSL https://raw.githubusercontent.com/eduxo/os-lab/main/nastroje/priprava-stanice.sh -o priprava-stanice.sh
#     bash priprava-stanice.sh
#
# Skript si sám doinstaluje git a stáhne repozitář — nic dalšího stahovat
# nemusíš. Když už repozitář máš, pouštěj ho odtamtud:
#     bash ~/os-lab/nastroje/priprava-stanice.sh
#
# Funguje na x86_64 (školní stanice) i arm64 (vývojová VM na Macu) — postup
# je stejný, liší se jen architektura instalačního obrazu.
#
# Spusť jako běžný uživatel (sysadmin), NE jako root. sudo si o heslo řekne samo.
#
# JE IDEMPOTENTNÍ a je určený k opakovanému spouštění: po změně balicky.txt
# ho žáci pustí znovu a on stanici srovná — doinstaluje, co přibylo, a
# odinstaluje, co ze seznamu vypadlo. Neinstaluje všechno znovu.

set -uo pipefail

# Kroky se číslují samy — jinak se při každém přidání kroku přečíslovává
# zbytek souboru a čísla se rozejdou s tím, co skript opravdu dělá.
_KROK=0
krok()  { _KROK=$((_KROK+1)); printf '\n\033[1;34m== %d. %s ==\033[0m\n' "$_KROK" "$1"; }
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$1"; }
varuj() { printf '  \033[0;33m!\033[0m %s\n' "$1"; }
chyba() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; }
info()  { printf '    %s\n' "$1"; }

REPO="https://github.com/eduxo/os-lab.git"
CIL="$HOME/os-lab"
STAV_DIR=/var/lib/os-lab
STAV="$STAV_DIR/balicky.stav"
# Tyhle se neodinstalují, ani když ze seznamu vypadnou. Bez gitu by se stanice
# už nedala aktualizovat, bez sudo a ssh by se nedalo nic.
CHRANENE=" git sudo ca-certificates openssh-server "

# ------------------------------------------------------------ kontroly
if [ "$(id -u)" = "0" ]; then
  chyba "Nespouštěj jako root — repozitář by skončil v /root a skupiny"
  info  "lxd a docker by se přidaly rootovi místo tobě."
  info  "Spusť jako sysadmin, sudo se použije uvnitř."
  exit 1
fi

VER=$(lsb_release -rs 2>/dev/null)
if [ -n "$VER" ] && [ "$VER" != "26.04" ]; then
  varuj "Očekáváno Ubuntu 26.04, nalezeno: $VER. Pokračuji, ale nemusí sedět."
fi

echo
echo "  Skript připraví tuto stanici jako laboratoř OS."
echo "  Bude potřeba heslo pro sudo."
sudo -v || { chyba "sudo selhalo"; exit 1; }
# udržet sudo naživu po celou dobu běhu
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

info "Architektura: $(dpkg --print-architecture 2>/dev/null || echo neznámá)"

# ------------------------------------------------------------ aktualizace
krok "Aktualizace systému"
info "(na pomalém síťovém disku to může trvat i 10 minut)"
sudo apt-get update -qq && ok "Seznamy balíčků aktualizovány"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq upgrade && ok "Systém aktualizován"
# Instalátor Serveru nechá UTC. Kontejnery cvičení jedou v Europe/Prague
# (server-lib.sh), stanice musí taky — jinak hodiny v panelu, časy v logu
# a časovače ukazují o hodinu nebo dvě jinak.
if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "Europe/Prague" ]; then
  ok "Časové pásmo: Europe/Prague"
else
  sudo timedatectl set-timezone Europe/Prague && ok "Časové pásmo nastaveno na Europe/Prague"
fi

# ------------------------------------------------------------ git a repozitář
krok "Repozitář os-lab"
# Slepice a vejce: seznam balíčků i všechna cvičení žijí v repozitáři, ale
# na čerstvém Serveru není git, kterým by se stáhl. Proto si ho skript
# doinstaluje sám — a proto stačí stáhnout jenom tenhle jeden soubor.
if [ -f "$(dirname "$0")/balicky.txt" ]; then
  # Skript běží ze stromu repozitáře — použij ten, ve kterém leží.
  REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
  ok "Běžím z repozitáře $REPO_DIR"
  if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$REPO_DIR" pull --ff-only >/dev/null 2>&1 \
      && ok "Repozitář aktualizován" \
      || varuj "git pull neprošel — stavím z toho, co je stažené"
  fi
else
  if ! command -v git >/dev/null 2>&1; then
    info "Instaluji git…"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git ca-certificates \
      || { chyba "Instalace gitu selhala — má stanice přístup k internetu?"; exit 1; }
    # Ověřovací příkaz se musí ověřit taky: apt skončí nulou i tehdy, když
    # balíček nakonec chybí, a git clone by spadl až o krok dál.
    command -v git >/dev/null 2>&1 || { chyba "git se nainstalovat nepodařilo"; exit 1; }
  fi
  ok "git je k dispozici ($(git --version | awk '{print $3}'))"

  if [ -d "$CIL/.git" ]; then
    git -C "$CIL" pull --ff-only >/dev/null 2>&1 \
      && ok "Repozitář v $CIL aktualizován" \
      || varuj "git pull neprošel — stavím z toho, co je stažené"
  elif [ -e "$CIL" ]; then
    chyba "$CIL existuje, ale není to repozitář. Přejmenuj ho nebo smaž."
    exit 1
  else
    info "Stahuji $REPO…"
    git clone "$REPO" "$CIL" >/dev/null 2>&1 \
      && ok "Repozitář stažen do $CIL" \
      || { chyba "Stažení selhalo — zkontroluj připojení k internetu"; exit 1; }
  fi
  REPO_DIR="$CIL"
fi

SEZNAM="$REPO_DIR/nastroje/balicky.txt"
[ -f "$SEZNAM" ] || { chyba "V repozitáři chybí $SEZNAM"; exit 1; }

# ------------------------------------------------------------ kořenový svazek
krok "Kořenový svazek — využít celý disk"
# Instalátor Ubuntu Serveru vytvoří LVM svazek jen na část disku (na 100GB
# disku typicky 48 GB) a zbytek nechá ve skupině nevyužitý. Bez rozšíření
# dojde místo někdy uprostřed roku — obrazy kontejnerů a snapshoty rostou.
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

# ------------------------------------------------------------ MATE
krok "Grafické prostředí MATE"
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

# ------------------------------------------------------------ klávesnice
krok "Klávesnice — česká, druhá anglická"
# Ve třídě jsou české klávesnice, výchozí rozložení je proto české — sedí
# s popisky kláves. Anglické (US) je druhé: ajťák na něj narazí u konzolí
# serverů. Přepíná se Alt+Shift jako ve Windows. Nastaví se BEZ OHLEDU na to,
# co se zvolilo v instalátoru, a platí pro plochu, přihlašovací obrazovku
# i textovou konzoli (nouzový režim) — ty všechny čtou /etc/default/keyboard.
KBD=/etc/default/keyboard
if grep -qx 'XKBLAYOUT="cz,us"' "$KBD" 2>/dev/null \
   && grep -qx 'XKBOPTIONS="grp:alt_shift_toggle"' "$KBD" 2>/dev/null; then
  ok "Klávesnice už je česká s anglickou jako druhou"
else
  printf '%s\n' \
    '# Klávesnice stanice — zapsal priprava-stanice.sh (eduxo).' \
    '# Výchozí česká, druhá anglická (US), přepínání Alt+Shift.' \
    'XKBMODEL="pc105"' \
    'XKBLAYOUT="cz,us"' \
    'XKBVARIANT=","' \
    'XKBOPTIONS="grp:alt_shift_toggle"' \
    'BACKSPACE="guess"' | sudo tee "$KBD" >/dev/null
  # textová konzole hned, plocha a přihlašovací obrazovka po restartu
  sudo setupcon --force --save >/dev/null 2>&1
  sudo udevadm trigger --subsystem-match=input --action=change >/dev/null 2>&1
  grep -qx 'XKBLAYOUT="cz,us"' "$KBD" \
    && ok "Klávesnice: česká výchozí, anglická (US) druhá, přepínání Alt+Shift (plně po restartu)" \
    || chyba "Nastavení klávesnice se nepodařilo zapsat"
fi
# MATE bere rozložení ze systému, dokud ho uživatel nemá uložené v profilu.
# Kdyby si ho sysadmin při stavbě uložil bez češtiny (třeba jen US), plocha
# by systémové nastavení nepřevzala. Rozložení, které češtinu obsahuje,
# zůstane — to si mohl nastavit žák sám.
if command -v gsettings >/dev/null 2>&1 && command -v dbus-run-session >/dev/null 2>&1; then
  ULOZENE="$(dbus-run-session -- gsettings get org.mate.peripherals-keyboard-xkb.kbd layouts 2>/dev/null)"
  case "$ULOZENE" in
    ''|'@as []'|*"'cz'"*) ;;
    *) dbus-run-session -- gsettings set org.mate.peripherals-keyboard-xkb.kbd layouts "['cz', 'us']" >/dev/null 2>&1 \
         && ok "Rozložení v profilu MATE srovnáno (bylo $ULOZENE)" ;;
  esac
fi

# ------------------------------------------------------------ síť stanice
krok "Síť stanice"
# Stanice je Ubuntu Server a síť na ní řídí systemd-networkd — tak s ní počítá
# cvičení 3/01. Rozhraní, kterým stanice vidí ven, se čte podle výchozí trasy.
IF_VEN="$(ip route show default 2>/dev/null \
  | awk '/^default/{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"

# 1) Instalátor zapíše síťovku podle MAC adresy (match: macaddress + set-name).
#    Po importu OVA s novými MAC adresami by se nenašla a stanice by zůstala
#    bez sítě. Přepíše se proto na JMÉNO rozhraní, ať žák nic neřeší. Sahá se
#    jen na soubor, který přesně odpovídá tomu, co instalátor zapisuje —
#    jedna síťovka, DHCP, vazba na MAC — nikdy na soubory od žáka.
for F in /etc/netplan/*.yaml; do
  [ -f "$F" ] && sudo grep -q 'macaddress:' "$F" 2>/dev/null || continue
  JMENO="$(basename "$F")"
  if [ -z "$IF_VEN" ] \
     || [ "$(sudo grep -c 'macaddress:' "$F")" != "1" ] \
     || [ "$(sudo grep -c 'set-name:' "$F")" != "1" ] \
     || ! sudo grep -qE "set-name:[[:space:]]*$IF_VEN[[:space:]]*$" "$F" \
     || ! sudo grep -qE 'dhcp4:[[:space:]]*true' "$F"; then
    varuj "$F váže síťovku na MAC adresu, ale nevypadá jako soubor od instalátoru — nechávám ho"
    continue
  fi
  DHCP6="$(sudo awk '/dhcp6:/{print $2; exit}' "$F")"
  sudo mkdir -p /var/backups/netplan
  sudo cp -p "$F" "/var/backups/netplan/$JMENO.puvodni"
  printf '%s\n' \
    "# Síť stanice — zapsal priprava-stanice.sh (eduxo)." \
    "# Síťovka je podle JMÉNA, ne podle MAC adresy: po importu OVA s novými" \
    "# MAC adresami by se jinak nenašla a stanice by zůstala bez sítě." \
    "# Původní soubor od instalátoru: /var/backups/netplan/$JMENO.puvodni" \
    "network:" \
    "  version: 2" \
    "  ethernets:" \
    "    $IF_VEN:" \
    "      dhcp4: true" \
    "      dhcp6: ${DHCP6:-false}" | sudo tee "$F" >/dev/null
  sudo chmod 600 "$F"
  # Ověřovací příkaz se musí ověřit taky: rozbitá konfigurace sítě by se
  # projevila až po restartu, a to už u žáka.
  if sudo netplan generate >/dev/null 2>&1; then
    ok "Síťovka $IF_VEN je v $JMENO podle jména, ne podle MAC adresy"
  else
    sudo cp -p "/var/backups/netplan/$JMENO.puvodni" "$F"
    chyba "Nová konfigurace sítě neprošla kontrolou — vrácen původní $JMENO"
  fi
done
# Aby cloud-init soubor s MAC adresou po restartu nezapsal znovu.
if [ -d /etc/cloud/cloud.cfg.d ] && ! sudo grep -rqsE 'config:[[:space:]]*disabled' /etc/cloud/cloud.cfg.d/; then
  printf 'network: {config: disabled}\n' | sudo tee /etc/cloud/cloud.cfg.d/99-eduxo-sit.cfg >/dev/null \
    && ok "cloud-init už konfiguraci sítě nepřepíše"
fi

# 2) S MATE přibude NetworkManager. Síťovku neřídí (nmcli ji hlásí jako
#    „unmanaged"), jen běží a jeho ikona v panelu ukazuje „nepřipojeno", i když
#    síť funguje. Vypíná se, aby síť měl na starosti jediný program. Pro
#    ubuntu-mate-core je jen doporučený, MATE tím nijak nepřijde.
#    Vypne se ale JEN když síť opravdu řídí networkd — to, že služba běží,
#    nic nedokazuje (na tom se kdysi spletlo ověření prostředí).
RIDI_NETWORKD=0
[ -n "$IF_VEN" ] && networkctl list --no-legend 2>/dev/null \
  | awk -v i="$IF_VEN" '$2==i && $5=="configured"{f=1} END{exit !f}' && RIDI_NETWORKD=1
if [ "$RIDI_NETWORKD" != "1" ]; then
  varuj "Rozhraní ${IF_VEN:-?} neřídí systemd-networkd — NetworkManager nechávám být"
  info  "Stanice neodpovídá tomu, s čím počítá cvičení 3/01. Ověř: networkctl"
else
  ok "Síť řídí systemd-networkd (rozhraní $IF_VEN)"
  # 3) dracut (vyrábí zaváděcí obraz Ubuntu 26.04) nechává při startu v /run
  #    záložní „DHCP na všechno" (zzzz-dracut-default.network). networkd pak
  #    nastavuje i druhou síťovku, která má pro cvičení 3/01 zůstat volná,
  #    čeká na DHCP, který na vnitřní síti nepřijde, a může zdržet start.
  #    Soubor stejného jména v /etc odkazující na /dev/null ho vypne
  #    (systemd.network: /etc má přednost před /run). Jen když rozhraní ven
  #    nastavuje netplan — jinak by stanice po restartu zůstala bez sítě.
  DRACUT_SIT=zzzz-dracut-default.network
  if [ ! -e "/etc/systemd/network/$DRACUT_SIT" ]; then
    NF="$(networkctl status "$IF_VEN" 2>/dev/null | awk -F': ' '/Network File:/{print $2; exit}')"
    case "$NF" in
      */10-netplan-*)
        sudo mkdir -p /etc/systemd/network
        sudo ln -s /dev/null "/etc/systemd/network/$DRACUT_SIT" \
          && sudo networkctl reload >/dev/null 2>&1
        [ -L "/etc/systemd/network/$DRACUT_SIT" ] \
          && ok "Záložní DHCP od dracutu vypnuto — další síťovky zůstanou volné (po restartu)" \
          || varuj "Záložní DHCP od dracutu se vypnout nepodařilo"
        ;;
      *)
        varuj "Rozhraní $IF_VEN nenastavuje netplan (${NF:-?}) — záložní DHCP od dracutu nechávám" ;;
    esac
  fi
  if systemctl is-active --quiet NetworkManager || systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
    sudo systemctl disable --now NetworkManager >/dev/null 2>&1
    sudo systemctl disable NetworkManager-wait-online >/dev/null 2>&1
    systemctl is-active --quiet NetworkManager \
      && varuj "NetworkManager se vypnout nepodařilo" \
      || ok "NetworkManager vypnut — síť má na starosti jen networkd"
  fi
  if dpkg -s network-manager-gnome >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq network-manager-gnome >/dev/null 2>&1 \
      && ok "Ikona NetworkManageru odebrána — hlásila „nepřipojeno\", i když síť běží"
  fi
fi

# ------------------------------------------------------------ vzhled
krok "Vzhled stanice eduxo"
# Pozadí, motiv, domovská stránka Firefoxu a přihlašovací obrazovka.
# Nastavuje se jako VÝCHOZÍ hodnota pro všechny účty (gschema override), ne
# do profilu jednoho uživatele: při první stavbě skript běží dřív, než
# existuje grafické sezení, a uživatelské gsettings bez něj zapsat nejdou.
# Kdo si vzhled změní sám, tomu zůstane jeho.
POZADI_ZDROJ="$REPO_DIR/img/eduxo_wallpaper.jpg"
POZADI=/usr/share/backgrounds/eduxo/eduxo_wallpaper.jpg
MOTIV=Yaru-blue
DOMOVSKA=https://www.eduxo.cz

# Pozadí musí ležet MIMO domovské složky: přihlašovací obrazovka běží pod
# účtem lightdm a do /home/sysadmin nevidí.
if [ -f "$POZADI_ZDROJ" ]; then
  sudo install -D -m 644 "$POZADI_ZDROJ" "$POZADI" && ok "Pozadí zkopírováno do $POZADI"
else
  varuj "V repozitáři chybí $POZADI_ZDROJ — pozadí se nenastaví"
  POZADI=""
fi

# Firefox (snap i deb) čte podnikové politiky z /etc/firefox/policies.
# Locked=false: žák si domovskou stránku smí změnit.
sudo mkdir -p /etc/firefox/policies
printf '{\n  "policies": {\n    "Homepage": { "URL": "%s", "StartPage": "homepage", "Locked": false }\n  }\n}\n' \
  "$DOMOVSKA" | sudo tee /etc/firefox/policies/policies.json >/dev/null \
  && ok "Firefox: domovská stránka $DOMOVSKA"

# Pozadí a motiv plochy
SCHEMATA=/usr/share/glib-2.0/schemas
OVR="$SCHEMATA/99_eduxo.gschema.override"
if ! command -v glib-compile-schemas >/dev/null 2>&1 || [ ! -f "$SCHEMATA/org.mate.background.gschema.xml" ]; then
  varuj "MATE není nainstalované — pozadí a motiv plochy přeskakuji"
else
  OBSAH=""
  [ -n "$POZADI" ] && OBSAH+="[org.mate.background]
picture-filename='$POZADI'
picture-options='zoom'

"
  # Motiv se skládá z několika částí (ovládací prvky, okna, ikony, kurzor).
  # Když má metamotiv index.theme, vezmou se odtud přesně jako v dialogu
  # Vzhled; jinak se použije totéž jméno všude, kde takový motiv existuje.
  META="/usr/share/themes/$MOTIV/index.theme"
  cast() { [ -f "$META" ] && sed -n "s/^$1=//p" "$META" | head -1; }
  GTK="$(cast GtkTheme)";      GTK="${GTK:-$MOTIV}"
  OKNA="$(cast MetacityTheme)"; [ -z "$OKNA" ] && [ -d "/usr/share/themes/$MOTIV/metacity-1" ] && OKNA="$MOTIV"
  IKONY="$(cast IconTheme)";   [ -z "$IKONY" ] && [ -d "/usr/share/icons/$MOTIV" ] && IKONY="$MOTIV"
  KURZOR="$(cast CursorTheme)"
  if [ -d "/usr/share/themes/$GTK" ]; then
    OBSAH+="[org.mate.interface]
gtk-theme='$GTK'
"
    [ -n "$IKONY" ] && OBSAH+="icon-theme='$IKONY'
"
    [ -n "$OKNA" ] && OBSAH+="
[org.mate.Marco.general]
theme='$OKNA'
"
    [ -n "$KURZOR" ] && OBSAH+="
[org.mate.peripherals-mouse]
cursor-theme='$KURZOR'
"
  else
    varuj "Motiv $MOTIV na stanici není — motiv se nenastaví"
  fi

  printf '%s' "$OBSAH" | sudo tee "$OVR" >/dev/null
  # Rozbité schéma by rozbilo nastavení celého prostředí — kompilace se
  # proto ověřuje, a když selže, náš soubor jde pryč.
  if sudo glib-compile-schemas "$SCHEMATA" 2>/dev/null; then
    # Ověřovací příkaz se musí ověřit taky: čte se výchozí hodnota mimo
    # profil uživatele (paměťový backend), tedy to, co dostane nový účet.
    SKUT="$(GSETTINGS_BACKEND=memory gsettings get org.mate.interface gtk-theme 2>/dev/null)"
    [ "$SKUT" = "'$GTK'" ] && ok "Motiv plochy: $GTK" || varuj "Motiv se neprojevil (výchozí je $SKUT)"
    if [ -n "$POZADI" ]; then
      SKUT="$(GSETTINGS_BACKEND=memory gsettings get org.mate.background picture-filename 2>/dev/null)"
      [ "$SKUT" = "'$POZADI'" ] && ok "Pozadí plochy nastaveno" || varuj "Pozadí se neprojevilo (výchozí je $SKUT)"
    fi
  else
    sudo rm -f "$OVR"; sudo glib-compile-schemas "$SCHEMATA" 2>/dev/null
    chyba "Nastavení vzhledu nešlo zkompilovat — vráceno do původního stavu"
  fi
fi

# Přihlašovací obrazovka. Ubuntu MATE přihlašovací program mezi verzemi
# měnil (slick-greeter ↔ arctica-greeter) a nastavení toho druhého se pak
# tiše ignoruje — proto se nejdřív zjistí, který je opravdu nastavený.
GREETER="$(grep -rhs '^greeter-session' /usr/share/lightdm/lightdm.conf.d/ /etc/lightdm/lightdm.conf.d/ /etc/lightdm/lightdm.conf 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')"
if [ -z "$POZADI" ]; then
  :
elif [ "$GREETER" = "slick-greeter" ] || { [ -z "$GREETER" ] && [ -f /usr/share/xgreeters/slick-greeter.desktop ]; }; then
  # Doplnit klíče do [Greeter], ostatní nastavení v souboru nechat být.
  sudo python3 - "$POZADI" <<'PY'
import os, sys
cesta = "/etc/lightdm/slick-greeter.conf"
chci = {"background": sys.argv[1], "draw-user-backgrounds": "false"}
radky = open(cesta, encoding="utf-8").read().splitlines() if os.path.exists(cesta) else []
ven, v_sekci, bylo, hotovo = [], False, False, set()
def dopln():
    for k, v in chci.items():
        if k not in hotovo: ven.append(f"{k}={v}")
for r in radky:
    s = r.strip()
    if s.startswith("["):
        if v_sekci: dopln()
        v_sekci = (s == "[Greeter]"); bylo = bylo or v_sekci
        ven.append(r); continue
    k = s.split("=", 1)[0].strip()
    if v_sekci and k in chci:
        ven.append(f"{k}={chci[k]}"); hotovo.add(k); continue
    ven.append(r)
if v_sekci: dopln()
if not bylo:
    ven.append("[Greeter]"); dopln()
open(cesta, "w", encoding="utf-8").write("\n".join(ven) + "\n")
PY
  [ $? -eq 0 ] && ok "Přihlašovací obrazovka: pozadí eduxo (projeví se po odhlášení)" \
               || chyba "Nastavení přihlašovací obrazovky selhalo"
else
  varuj "Přihlašovací program je '${GREETER:-neznámý}', ne slick-greeter — pozadí přihlášení se nenastaví"
fi

# ------------------------------------------------------------ balíčky
krok "Balíčky pro cvičení"
# balicky.txt je ZDROJ PRAVDY. Skript stanici podle něj SROVNÁ: doinstaluje,
# co přibylo, a odinstaluje, co ze seznamu vypadlo. Aby se dalo poznat, co
# odinstalovat, pamatuje si v $STAV, co podle seznamu nainstaloval minule —
# nikdy nesáhne na nic, co si nainstaloval někdo jiný.
# Bez `mapfile`, aby se tahle úvaha dala vyzkoušet i mimo cílový systém.
BALICKY=()
while read -r B; do BALICKY+=("$B"); done \
  < <(sed 's/#.*//' "$SEZNAM" | tr -s ' \t' '\n' | grep -v '^$' | sort -u)
if [ "${#BALICKY[@]}" -eq 0 ]; then
  chyba "V $SEZNAM nejsou žádné balíčky — to nevypadá správně."; exit 1
fi
info "Seznam říká: ${#BALICKY[@]} balíčků"

# Co chybí
CHYBI=()
for B in "${BALICKY[@]}"; do
  dpkg -s "$B" >/dev/null 2>&1 || CHYBI+=("$B")
done

if [ "${#CHYBI[@]}" -eq 0 ]; then
  ok "Všechny balíčky ze seznamu už jsou nainstalované"
else
  info "Doinstaluji ${#CHYBI[@]}: ${CHYBI[*]}"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${CHYBI[@]}" \
    && ok "Doinstalováno ${#CHYBI[@]} balíčků" \
    || chyba "Instalace balíčků selhala — zkus ji ručně, ať vidíš proč"
fi

# Co přebývá — jen to, co skript sám podle seznamu kdysi nainstaloval
PREBYVA=()
if [ -f "$STAV" ]; then
  while read -r B; do
    [ -n "$B" ] || continue
    printf '%s\n' "${BALICKY[@]}" | grep -qxF "$B" && continue
    case "$CHRANENE" in *" $B "*) info "Vypadl ze seznamu, ale je chráněný: $B"; continue ;; esac
    dpkg -s "$B" >/dev/null 2>&1 && PREBYVA+=("$B")
  done < "$STAV"
fi

if [ "${#PREBYVA[@]}" -gt 0 ]; then
  varuj "Ze seznamu vypadlo ${#PREBYVA[@]}: ${PREBYVA[*]}"
  sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq "${PREBYVA[@]}" >/dev/null 2>&1 \
    && ok "Odinstalováno ${#PREBYVA[@]} balíčků" \
    || varuj "Odinstalace neprošla celá — zkontroluj ručně"
  sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq >/dev/null 2>&1
fi

# Stav se zapisuje AŽ TEĎ — kdyby instalace spadla, ať se nezapamatuje
# seznam, který na stanici není.
sudo mkdir -p "$STAV_DIR"
printf '%s\n' "${BALICKY[@]}" | sudo tee "$STAV" >/dev/null
info "Nové balíčky se přidávají do nastroje/balicky.txt, ne sem."

# Docker: skupina. Instalace není učivo labu 3/21 (ten je o obrazech, portech
# a svazcích) a 30 žáků instalujících naráz přes síťový disk je týž problém
# jako stahování obrazů.
if command -v docker >/dev/null 2>&1; then
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    ok "Docker je nainstalovaný a $USER je ve skupině docker"
  else
    sudo usermod -aG docker "$USER" \
      && ok "Uživatel $USER přidán do skupiny docker" \
      && ODHLASIT=1
  fi
fi

# ------------------------------------------------------------ hypervizor
krok "Doplňky hypervizoru (schránka, rozlišení)"
# Bez nich se ve VM nedá kopírovat mezi hostitelem a hostem a okno nemění
# rozlišení — na to žáci narazí hned první hodinu. Balíčky z Ubuntu jsou
# lepší než ISO s Guest Additions: nic se nepřekládá (moduly vboxguest,
# vboxsf a vboxvideo jsou přímo v jádře Ubuntu) a přežije to aktualizaci
# jádra. Hypervizor se pozná sám, ať skript sedí na VirtualBox i na VMware.
HV="$(systemd-detect-virt 2>/dev/null || echo none)"
case "$HV" in
  oracle)
    info "Běžíme ve VirtualBoxu"
    # virtualbox-guest-* je v multiverse. Skript ho zapne SÁM — dřív jen radil
    # a pokračoval dál, takže po „připravené" stanici zbyl ruční krok, na který
    # se přišlo až podle nefunkční schránky.
    # Kandidát se čte do proměnné, ne rourou do `grep -q`: s pipefail by
    # předčasně ukončený grep mohl apt-cache shodit SIGPIPE a podmínka by lhala.
    kandidat() { LC_ALL=C apt-cache policy virtualbox-guest-utils 2>/dev/null; }
    if [[ "$(kandidat)" != *"Candidate: "[0-9]* ]]; then
      info "Balíček není k dispozici — zapínám repozitář multiverse."
      command -v add-apt-repository >/dev/null 2>&1 \
        || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq software-properties-common
      sudo add-apt-repository -y multiverse >/dev/null 2>&1 \
        && sudo apt-get update -qq \
        && ok "Multiverse zapnuté" \
        || chyba "Multiverse se zapnout nepodařilo"
    fi
    if [[ "$(kandidat)" != *"Candidate: "[0-9]* ]]; then
      chyba "virtualbox-guest-utils ani po zapnutí multiverse není k dispozici"
      info  "Ověř ručně:  apt-cache policy virtualbox-guest-utils"
    else
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        virtualbox-guest-utils virtualbox-guest-x11 \
        && { ok "Doplňky VirtualBoxu nainstalovány"; RESTART=1; } \
        || chyba "Instalace doplňků VirtualBoxu selhala"
      # Ověřovací příkaz se musí ověřit taky: balíček se nainstaluje i tehdy,
      # když modul v jádře není, a schránka pak beze slova nefunguje.
      if dpkg -s virtualbox-guest-utils >/dev/null 2>&1; then
        ok "virtualbox-guest-utils je opravdu nainstalovaný"
      else
        chyba "virtualbox-guest-utils po instalaci v systému není"
      fi
      if modinfo vboxguest >/dev/null 2>&1; then
        ok "Modul vboxguest je v jádře k dispozici"
      else
        varuj "Modul vboxguest v jádře není — schránka ani rozlišení fungovat nebudou"
        info "Doinstaluj:  sudo apt-get install linux-modules-extra-\$(uname -r)"
      fi
      info "Schránku je potřeba zapnout i ve VirtualBoxu — ve výchozím stavu je vypnutá:"
      info "Zařízení → Sdílená schránka → Obousměrná"

      # Automatické přizpůsobení obrazovky. S hostitelem VirtualBox 7.1 a
      # doplňky 7.2 z Ubuntu nová velikost okna do stanice DORAZÍ (xrandr ji
      # ukáže jako doporučený režim „+"), ale nikdo ji nepoužije. Hlídač
      # v sezení ji použije, když se doporučený režim ZMĚNÍ — na rozlišení,
      # které si žák nastaví ručně, nesahá. Až se verze srovnají a začne to
      # fungovat samo, hlídač nemá co dělat a neškodí.
      sudo tee /usr/local/bin/eduxo-obrazovka >/dev/null <<'HLIDAC'
#!/bin/bash
# eduxo: přizpůsobí obrazovku velikosti okna VirtualBoxu.
# Spouští se při přihlášení do MATE (/etc/xdg/autostart/eduxo-obrazovka.desktop).
[ "$(systemd-detect-virt 2>/dev/null)" = "oracle" ] || exit 0
command -v xrandr >/dev/null 2>&1 || exit 0
predchozi=""
while sleep 2; do
  vystup="$(xrandr 2>/dev/null)" || exit 0          # X skončilo → konec sezení
  vystup_jmeno="$(printf '%s\n' "$vystup" | awk '/ connected/{print $1; exit}')"
  doporuceny="$(printf '%s\n' "$vystup" | awk '/ connected/{f=1; next} f && /^[^ ]/{exit} f && /\+/{print $1; exit}')"
  [ -n "$vystup_jmeno" ] && [ -n "$doporuceny" ] || continue
  if [ -n "$predchozi" ] && [ "$doporuceny" != "$predchozi" ]; then
    xrandr --output "$vystup_jmeno" --auto
  fi
  predchozi="$doporuceny"
done
HLIDAC
      sudo chmod 755 /usr/local/bin/eduxo-obrazovka
      sudo tee /etc/xdg/autostart/eduxo-obrazovka.desktop >/dev/null <<'SPUSTENI'
[Desktop Entry]
Type=Application
Name=eduxo — přizpůsobení obrazovky
Exec=/usr/local/bin/eduxo-obrazovka
NoDisplay=true
OnlyShowIn=MATE;
SPUSTENI
      ok "Přizpůsobení obrazovky velikosti okna (projeví se po přihlášení)"
    fi ;;
  vmware)
    info "Běžíme ve VMware (cylab)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      open-vm-tools open-vm-tools-desktop \
      && ok "open-vm-tools nainstalovány" \
      || chyba "Instalace open-vm-tools selhala" ;;
  none)
    info "Neběžíme ve virtuálu — doplňky hypervizoru přeskakuji" ;;
  *)
    info "Hypervizor '$HV' neznám — doplňky nech na sobě" ;;
esac

# Bluetooth ve VM není. blueman-applet (správce Bluetoothu v MATE) se přesto
# spouští při každém přihlášení, spadne a Ubuntu pak žákovi ukáže hlášku
# „Ubuntu 26.04 has experienced an internal error". Pro ubuntu-mate-core je
# blueman jen doporučený (Recommends), takže odinstalace MATE nenaruší.
if [ "$HV" != "none" ]; then
  if dpkg -s blueman >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq blueman >/dev/null 2>&1 \
      && ok "Správce Bluetoothu (blueman) odinstalován — ve VM jen padal" \
      || varuj "blueman se odinstalovat nepodařilo"
  else
    ok "Správce Bluetoothu (blueman) na stanici není"
  fi
  # Uložený záznam o pádu by jinak hlášku ukázal po prvním přihlášení znovu
  sudo rm -f /var/crash/_usr_bin_blueman-applet.*
  # fwupd-refresh.timer stahuje seznam aktualizací FIRMWARU (BIOS, disky).
  # Ve VM není co aktualizovat; ze školní sítě se k serveru navíc nedostal,
  # fwupdmgr spadl a Ubuntu pak žákovi ukázalo „System program problem
  # detected". Časovač se vypne a zamaskuje, aby ho nezapnula aktualizace.
  if systemctl list-unit-files fwupd-refresh.timer >/dev/null 2>&1 \
     && [ "$(systemctl is-enabled fwupd-refresh.timer 2>/dev/null)" != "masked" ]; then
    sudo systemctl disable --now fwupd-refresh.timer >/dev/null 2>&1
    sudo systemctl mask fwupd-refresh.timer >/dev/null 2>&1 \
      && ok "Stahování aktualizací firmwaru (fwupd-refresh) vypnuto — ve VM jen padalo"
  fi
fi

# ------------------------------------------------------------ LXD
krok "LXD"
if snap list lxd >/dev/null 2>&1; then
  ok "LXD už je nainstalovaný"
else
  sudo snap install lxd && ok "LXD nainstalován"
fi
sudo snap refresh --hold lxd >/dev/null 2>&1 \
  && ok "Automatické aktualizace LXD pozastaveny (ať se neaktualizuje uprostřed hodiny)"

if ! id -nG "$USER" | grep -qw lxd; then
  sudo usermod -aG lxd "$USER" && ok "Uživatel $USER přidán do skupiny lxd"
  ODHLASIT=1
else
  ok "Uživatel $USER už je ve skupině lxd"
fi

# ------------------------------------------------------------ lxd init
krok "Inicializace LXD"
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

# ------------------------------------------------------------ síť netlab
krok "Izolovaná síť netlab (pro laby DNS a DHCP)"
if sudo lxc network list -f csv 2>/dev/null | grep -q '^netlab,'; then
  ok "Síť netlab už existuje"
else
  sudo lxc network create netlab \
      ipv4.address=10.10.10.1/24 ipv4.dhcp=false ipv4.nat=true ipv6.address=none \
    && ok "Síť netlab vytvořena (bez vlastního DHCP — žákův DHCP server bude jediný)"
fi

# ------------------------------------------------------------ obrazy LXD
krok "Předstažení obrazů kontejnerů"
info "Kvůli síťovému disku a 30 žákům naráz — v hodině se pak nestahuje nic."
if sudo lxc image list local: -f csv 2>/dev/null | grep -q 'ubuntu-26.04'; then
  ok "Obraz ubuntu-26.04 je už v lokální cache"
else
  info "Stahuji ubuntu:26.04 (~200 MB, chvíli to potrvá)..."
  sudo lxc image copy ubuntu:26.04 local: --alias ubuntu-26.04 --auto-update \
    && ok "Obraz uložen jako lokální alias 'ubuntu-26.04'"
  info "V labech pak: lxc launch ubuntu-26.04 <jmeno>   (bez dvojtečky = lokální)"
fi

# ------------------------------------------------------------ obrazy Dockeru
krok "Obrazy Dockeru do lokální cache"
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
      # Docker Hub bývá ze školní sítě nedostupný (ověřeno 2026-09-16: spojení
      # vyprší, GitHub přitom odpoví hned). Oficiální obrazy jsou i na
      # zrcadle Googlu; stažený obraz se přejmenuje na jméno, které čekají
      # cvičení (nginx:alpine, alpine:latest), a jméno ze zrcadla se odebere.
      ZRCADLO="mirror.gcr.io/library/$OBRAZ"
      if sudo docker pull "$OBRAZ" >/dev/null 2>&1; then
        ok "Obraz $OBRAZ stažen"
      elif sudo docker pull "$ZRCADLO" >/dev/null 2>&1 \
           && sudo docker tag "$ZRCADLO" "$OBRAZ" >/dev/null 2>&1; then
        sudo docker rmi "$ZRCADLO" >/dev/null 2>&1
        ok "Obraz $OBRAZ stažen ze zrcadla mirror.gcr.io (Docker Hub neodpověděl)"
      else
        varuj "Obraz $OBRAZ se nepodařilo stáhnout z Docker Hubu ani ze zrcadla"
        info  "Laby 3/21 a 3/21b bez něj nepojedou. Zkus skript pustit znovu později."
      fi
    fi
    if [ ! -f "$SOUBOR" ]; then
      sudo docker save -o "$SOUBOR" "$OBRAZ" >/dev/null 2>&1 \
        || varuj "Zálohu obrazu $OBRAZ se nepodařilo uložit do $SOUBOR"
    fi
  done
  sudo chmod -R a+rX "$OBRAZY_DIR" 2>/dev/null
  # Plugin Compose je SAMOSTATNÝ balíček (docker-compose-v2) a je jediné
  # místo, kde se dá zjistit, jestli doskočil.
  if docker compose version >/dev/null 2>&1; then
    ok "Plugin docker compose je k dispozici"
  else
    varuj "Plugin 'docker compose' chybí — lab 3/21b bez něj nepojede"
    info "Balíček se jmenuje docker-compose-v2 a je v nastroje/balicky.txt"
  fi
fi

# ------------------------------------------------------------ heslo roota
krok "Heslo uživatele root"
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

# ------------------------------------------------------------ záznamy o pádech
# Když během stavby cokoli spadne, Apport uloží záznam do /var/crash a hlášku
# „…has experienced an internal error" pak po přihlášení ukáže každému, kdo
# stanici dostane — i když program už nikdy znovu nespadne. Záznamy z přípravy
# proto pryč; příčiny známých pádů řeší kroky výše.
if ls /var/crash/*.crash >/dev/null 2>&1; then
  sudo rm -f /var/crash/*.crash /var/crash/*.upload /var/crash/*.uploaded
  ok "Záznamy o pádech z přípravy smazány — žák je po přihlášení neuvidí"
fi

# ------------------------------------------------------------ souhrn
printf '\n\033[1;34m======== HOTOVO ========\033[0m\n'
echo
if [ "${RESTART:-0}" = "1" ]; then
  printf '  \033[0;33mZměny se projeví po dalším startu.\033[0m Restartuj VM (sudo reboot),\n'
  printf '  nebo ji rovnou vypni (sudo poweroff) a exportuj.\n\n'
elif [ "${ODHLASIT:-0}" = "1" ]; then
  printf '  \033[0;33mZměny se projeví po dalším přihlášení.\033[0m Odhlas se, restartuj VM,\n'
  printf '  nebo ji rovnou vypni (sudo poweroff) a exportuj.\n\n'
fi
echo "  Ověření předpokladů:"
echo "     bash $REPO_DIR/nastroje/overeni-prostredi.sh"
echo
echo "  Příště pouštěj skript rovnou z repozitáře — je tam vždy nejnovější:"
echo "     bash ~/os-lab/nastroje/priprava-stanice.sh"
echo

# Kopie stažená curlem mimo repozitář už není potřeba — v šabloně by jen
# zbyla ležet v domovské složce. Soubor, ze kterého bash právě čte, smazat
# jde: otevřený zůstane, dokud skript nedoběhne.
SKRIPT="$(realpath "$0" 2>/dev/null || echo "$0")"
case "$SKRIPT" in
  "$REPO_DIR"/*) ;;
  *) if [ "$(basename "$SKRIPT")" = "priprava-stanice.sh" ] && rm -f "$SKRIPT"; then
       info "Stažená kopie $SKRIPT smazána."
       echo
     fi ;;
esac
