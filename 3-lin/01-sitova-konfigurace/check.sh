#!/bin/bash
# 3/01 — ověření
# Části odpovídají krokům zadání 1:1 (Krok 3 = --krok 3).
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

SIT="$HOME/netlab/sit"
FORMULAR="$SIT/formular.txt"
PRIMARNI="$SIT/.primarni-adapter"
VOLNA="$SIT/.volna-rozhrani"
ADRESA="$ZAK_IP/24"          # 10.10.10.1XX/24, odvozeno z čísla žáka

# `netplan get` chce práva správce. Čte se proto LÍNĚ — jen když to daná
# část opravdu potřebuje, aby `--krok 2` nevyžadoval heslo bez důvodu.
_konf=""; _konf_nactena=0
netplan_konfigurace() {
  if [ "$_konf_nactena" -eq 0 ]; then
    _konf="$(sudo -n netplan get 2>/dev/null || sudo netplan get 2>/dev/null)"
    _konf_nactena=1
  fi
  printf '%s' "$_konf"
}
# Když netplan renderer neuvádí, platí výchozí networkd — tak je to na stanici
# ze serverového obrazu. Prázdná hodnota se proto vrací jen tehdy, když se
# konfigurace nedala přečíst vůbec.
renderer_ze_stanice() {
  local k r; k="$(netplan_konfigurace)"
  [ -n "$k" ] || return 0
  r="$(printf '%s\n' "$k" | awk '/renderer:/{print $2; exit}')"
  printf '%s' "${r:-networkd}"
}
# Podle klíčového slova, ne podle pozice — trasa bez `via` má jiné pořadí polí.
primarni_rozhrani() {
  ip route show default 2>/dev/null \
    | awk '/^default/{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}

krok 1 "Kdo řídí síť"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na místě" \
  "chybí ~/netlab/sit/formular.txt — spusťte ./start.sh, doplní ho"
require_prikaz netplan \
  "netplan je k dispozici" \
  "netplan na stanici chybí — řekněte o tom vyučujícímu"
if [ -z "$(netplan_konfigurace)" ]; then
  chyba "nepodařilo se přečíst konfiguraci netplanu"
  poznamka "kontrola potřebuje práva správce — zadejte heslo, až se zeptá"
else
  uspech "konfigurace netplanu jde přečíst"
fi

krok 2 "Které rozhraní je volné"
IF_PRIM="$(cat "$PRIMARNI" 2>/dev/null)"
IF_DNES="$(primarni_rozhrani)"
if [ -z "$IF_PRIM" ]; then
  chyba "chybí poznámka o původním rozhraní"
  poznamka "spusťte ./start.sh — doplní ji, aniž by cokoli smazal"
elif [ -z "$IF_DNES" ]; then
  chyba "stanice nemá výchozí trasu — sáhli jste na rozhraní, kterým vidí ven"
  poznamka "nechte netplan změnu vrátit, nebo spusťte ./reset.sh"
elif [ "$IF_DNES" != "$IF_PRIM" ]; then
  chyba "výchozí trasa vede jinudy než na začátku ($IF_PRIM → $IF_DNES)"
else
  uspech "rozhraní, kterým stanice vidí ven, zůstalo nedotčené"
fi

krok 3 "Adresa v konfiguraci"
# `ip addr add` by adresu nasadilo, ale jen do restartu — to není nastavení sítě.
KONF="$(netplan_konfigurace)"
if [ -z "$KONF" ]; then
  chyba "konfiguraci netplanu se nepodařilo přečíst"
elif printf '%s' "$KONF" | grep -q "$ZAK_IP/24"; then
  uspech "adresa je zapsaná v konfiguraci netplanu"
else
  chyba "adresa z tiketu v konfiguraci netplanu není"
  poznamka "zapisuje se příkazem netplan set, ne ip addr add"
fi

krok 4 "Adresa nasazená"
IF_LAB="$(ip -br a 2>/dev/null | awk -v a="$ZAK_IP/" '$0 ~ a {print $1; exit}')"
if [ -n "$IF_LAB" ]; then
  uspech "rozhraní $IF_LAB má adresu $ADRESA"
else
  chyba "žádné rozhraní adresu z tiketu nemá"
  poznamka "zapsat ji do konfigurace nestačí — musí se ještě nasadit"
fi
if [ -n "$IF_LAB" ] && [ -n "$IF_PRIM" ] && [ "$IF_LAB" = "$IF_PRIM" ]; then
  chyba "adresa sedí na rozhraní, kterým stanice vidí ven"
  poznamka "to je přesně to, na které se sahat nemá"
elif [ -n "$IF_LAB" ] && [ -s "$VOLNA" ]; then
  # Adresa musí být na rozhraní, které bylo na začátku volné — ne na `lo`
  # ani na virtuálním rozhraní, které si žák vyrobil.
  if grep -qx "$IF_LAB" "$VOLNA"; then
    uspech "adresa je na rozhraní, které bylo na začátku volné"
  else
    chyba "rozhraní $IF_LAB nebylo na začátku mezi volnými fyzickými"
    poznamka "adresa patří na nepoužívanou síťovou kartu, ne na lo"
  fi
fi

krok 5 "Formulář"
# Všechny čtyři kontroly se volají VŽDY. Když se očekávaná hodnota nedá
# přečíst, ověří se aspoň tvar — vypustit kontrolu by znamenalo, že zmizí
# i ze jmenovatele a žák dostane „Hotovo" za nevyplněný formulář.
REND="$(renderer_ze_stanice)"
if [ -n "$REND" ]; then
  # networkd se píše i celým jménem služby — obojí je správně.
  case "$REND" in
    networkd) VZOR='^(systemd-)?networkd$' ;;
    *)        VZOR="^${REND}\$" ;;
  esac
  require_zaznam_tvar "$FORMULAR" renderer "$VZOR" \
    "ve formuláři je program, který řídí síť" \
    "ve formuláři není program, který na téhle stanici řídí síť"
else
  require_zaznam_tvar "$FORMULAR" renderer '^(NetworkManager|networkd)$' \
    "ve formuláři je program, který řídí síť (přesnou shodu ověří závěrečný běh)" \
    "ve formuláři chybí renderer"
fi
if [ -n "$IF_LAB" ]; then
  require_zaznam "$FORMULAR" adapter "$IF_LAB" \
    "ve formuláři je rozhraní se statickou adresou"
else
  require_zaznam_tvar "$FORMULAR" adapter '^[a-z][a-z0-9]+$' \
    "ve formuláři je rozhraní se statickou adresou (ověří se, až adresu nasadíte)" \
    "ve formuláři chybí rozhraní se statickou adresou"
fi
require_zaznam "$FORMULAR" adresa "$ADRESA" \
  "ve formuláři je nastavená adresa i s prefixem"
if [ -n "$IF_PRIM" ]; then
  require_zaznam "$FORMULAR" primarni "$IF_PRIM" \
    "ve formuláři je rozhraní, kterým stanice vidí ven"
else
  require_zaznam_tvar "$FORMULAR" primarni '^[a-z][a-z0-9]+$' \
    "ve formuláři je rozhraní, kterým stanice vidí ven" \
    "ve formuláři chybí rozhraní, kterým stanice vidí ven"
fi

vypis_souhrn
