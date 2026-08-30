#!/bin/bash
# 2/13 — ověření
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

INST="$HOME/netlab/instalace"
NALEZY="$INST/nalezy.txt"

# Cíl se čte ze souboru, který zapsal start.sh — ne přepočítává z čísla žáka.
# Kdyby si žák mezitím číslo opravil, rozešel by se cíl se zavedeným stavem
# a kontrola by testovala hold na jiném balíčku.
CIL="$(sudo -n cat "$LAB_ZALOHY/cil" 2>/dev/null || cat "$LAB_ZALOHY/cil" 2>/dev/null)"
if [ -z "$CIL" ]; then
  VSE=(tree ncdu figlet sl jq htop)
  Z11="${VSE[$(( $(lab_vyber 6 1 111) - 1 ))]}"
  ZBYTEK=()
  for b in "${VSE[@]}"; do [ "$b" = "$Z11" ] || ZBYTEK+=("$b"); done
  CIL="${ZBYTEK[$(( $(lab_vyber 5 1 132) - 1 ))]}"
fi

krok 1 "Prostředí"
require_soubor_neprazdny "$NALEZY" \
  "formulář nalezy.txt je na místě" \
  "chybí ~/netlab/instalace/nalezy.txt — spusťte ./start.sh"
if [ -f "$LAB_ZALOHY/zavedeno" ]; then
  uspech "závady jsou zavedené a systémové soubory zazálohované"
elif [ -f "$LAB_ZALOHY/uklizeno" ]; then
  chyba "závady na téhle stanici odstranil ./stop.sh, ne vy"
  poznamka "je to legitimní pojistka, ale cvičení tím splněné není —"
  poznamka "spusťte ./reset.sh a zkuste to znovu"
else
  chyba "závady nejsou zavedené — spusťte ./start.sh"
fi
poznamka "balíček, který máte nainstalovat: ${_B}$CIL${_0}"

krok 2 "Odstranění závad"
if [ -f "$LAB_ZALOHY/zavedeno" ]; then
  HOTOVO=0; CELKEM=0
  while read -r Z; do
    [ -n "$Z" ] || continue
    CELKEM=$((CELKEM + 1))
    if "opraveno_$Z" "$CIL"; then
      HOTOVO=$((HOTOVO + 1))
      uspech "závada $CELKEM je odstraněná — $("popis_$Z")"
    else
      # Co přesně je špatně, se neříká. Od toho je diagnostika.
      chyba "závada $CELKEM pořád trvá"
    fi
  done < "$LAB_ZALOHY/zavedeno"
  [ "$HOTOVO" -lt "$CELKEM" ] && \
    poznamka "začněte od 'sudo apt update' — chybová hláška říká, kterým směrem hledat"
else
  chyba "závady nejsou zavedené, není co kontrolovat"
fi

krok 3 "Zprovozněná instalace"
# Simulace instalace projde jen tehdy, když je nastavení apt v pořádku
# a balíček je dosažitelný. Nepotřebuje práva správce.
if apt-get -s install "$CIL" >/dev/null 2>&1; then
  uspech "apt umí balíček $CIL nainstalovat — nastavení je v pořádku"
else
  chyba "apt zatím balíček $CIL nainstalovat neumí"
fi
require_pkg "$CIL"

# ── negativní kontroly: obchvat místo opravy ──────────────────────
ZDROJE="/etc/apt/sources.list.d/ubuntu.sources"
if [ -r "$ZDROJE" ] && [ -s "$ZDROJE" ]; then
  uspech "hlavní zdroje balíčků jsou na místě a čitelné"
else
  chyba "hlavní zdroje balíčků chybí, jsou prázdné nebo nečitelné"
  poznamka "buď je to jedna ze závad, nebo jste je smazali — obojí se řeší"
  poznamka "obnovením souboru, ne odstraněním. Jak vypadá, jste viděli ve"
  poznamka "cvičení o instalaci softwaru; nouzově ho vrátí ./reset.sh"
fi
# Obchvaty se hledají i ve zdrojích: `Trusted: yes` v deb822 (nebo
# `[trusted=yes]` ve starém formátu) obejde chybějící klíč stejně účinně
# jako vypnuté ověřování v nastavení.
if grep -rqs -E 'AllowUnauthenticated|AllowInsecureRepositories' /etc/apt/apt.conf.d/ /etc/apt/apt.conf 2>/dev/null \
   || grep -rqsi -E 'Trusted:[[:space:]]*yes|trusted=yes' /etc/apt/sources.list.d/ /etc/apt/sources.list 2>/dev/null; then
  chyba "v nastavení apt je vypnuté ověřování podpisů — to není oprava, ale díra"
else
  uspech "ověřování podpisů zůstalo zapnuté"
fi

# ── nálezy: podklad pro obhajobu ──────────────────────────────────
for N in 1 2 3; do
  require_zaznam_tvar "$NALEZY" "zavada-$N" '.{20,}' \
    "u závady $N je popsané, co bylo špatně"
done

# Nápověda se nehodnotí, ale je vidět — je to informace pro vyučujícího
# o tom, kde se třída zasekla.
if [ -f "$INST/.napoveda" ]; then
  UROVEN=$(sort -n "$INST/.napoveda" | tail -1)
  poznamka "${_M}pozn.:${_0} použili jste nápovědu až po úroveň $UROVEN ze 3"
fi

if [ -f "$INST/.stop-pouzit" ]; then
  poznamka "${_M}pozn.:${_0} na téhle stanici byl použit ./stop.sh, který závady odstraní sám"
fi

pouzil_diagnostiku

vypis_souhrn
