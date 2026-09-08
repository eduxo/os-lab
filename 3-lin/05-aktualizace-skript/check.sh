#!/bin/bash
# 3/05 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="server-$ZAK2"
UCET="sysadmin"
SPRAVA="$HOME/netlab/sprava"
FORMULAR="$SPRAVA/formular.txt"
SKRIPT="/home/$UCET/skripty/stav.sh"
LOG="/home/$UCET/skripty/stav.log"

if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
STAV="$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)"
if [ -z "$STAV" ]; then
  echo; echo "  Server $KONT neexistuje. Spusťte ./start.sh"; echo; exit 1
elif [ "$STAV" != "RUNNING" ]; then
  echo; echo "  Server $KONT je zastavený — vaše práce na něm zůstala."
  echo "  Nastartujte ho:  ./start.sh"; echo; exit 1
fi

na_serveru()   { lxc exec "$KONT" -- bash -c "$1" 2>/dev/null; }
# LAB_KONTEJNER přepíná, KDE se kontroly ptají. Formulář je na stanici,
# všechno ostatní na serveru — prázdná hodnota znamená stanici.
LAB_KONTEJNER=""

krok 1 "Odkud server bere balíčky"
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/sprava/formular.txt — spusťte ./start.sh, doplní ho"
# Závorky jsou nutné: `A || B && C` je levoasociativní, takže bez nich
# se po úspěšném lsb_release vypíše ještě prázdný řádek z druhé větve.
VYDANI="$(na_serveru '{ lsb_release -cs 2>/dev/null; } || { . /etc/os-release && echo "$VERSION_CODENAME"; }' | tr -d '\r' | head -1)"
if [ -z "$VYDANI" ]; then
  chyba "nepodařilo se zjistit vydání serveru"
fi

krok 2 "Automatické bezpečnostní aktualizace"
# Ověřuje se KONFIGURACE, ne přítomnost balíčku — ten je v Ubuntu často
# nainstalovaný, aniž by cokoli dělal.
AUTO="$(na_serveru 'cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null')"
if [ -z "$AUTO" ]; then
  chyba "automatické aktualizace nejsou nastavené"
  poznamka "konfigurace vzniká v /etc/apt/apt.conf.d/20auto-upgrades"
elif printf '%s' "$AUTO" | grep -qE 'Unattended-Upgrade"?[[:space:]]+"1"' \
     && printf '%s' "$AUTO" | grep -qE 'Update-Package-Lists"?[[:space:]]+"1"'; then
  uspech "automatické bezpečnostní aktualizace jsou zapnuté"
else
  chyba "automatické aktualizace jsou nastavené jen zpola"
  poznamka "zapnout se musí stahování seznamů i samotná instalace"
fi

krok 3 "První skript"
require_path "$SKRIPT" \
  "skript stav.sh je na serveru" \
  "na serveru chybí ~/skripty/stav.sh — má vzniknout tam, ne na stanici"
if na_serveru "test -f '$SKRIPT'"; then
  na_serveru "head -1 '$SKRIPT'" | grep -q '^#!' \
    && uspech "skript má na prvním řádku shebang" \
    || { chyba "skript nemá na prvním řádku shebang"; poznamka "bez něj se spustí jiným interpretem, než čekáte"; }
  na_serveru "test -x '$SKRIPT'" \
    && uspech "skript je spustitelný" \
    || { chyba "skript není spustitelný"; poznamka "práva se přidávají příkazem chmod +x"; }

  # Nejtvrdší kontrola celého cvičení: skript se opravdu spustí a musí
  # přibýt řádek. Existence souboru sama o sobě nic nedokládá.
  #
  # Pouští se ale STRANOU — s HOME v dočasném adresáři. Kdyby kontrola psala
  # do žákova logu, posunula by mu při každém běhu hodnoty `radku` i `hodnota`
  # ve formuláři a závěrečné ověření by po úspěšné průběžné kontrole spadlo.
  # `cd` je nutný: lxc exec startuje v /root, kam sysadmin nesmí, takže skript
  # s relativní cestou k logu by jinak selhal. `timeout` chrání kontrolu před
  # skriptem, který čeká na vstup.
  TMPH="/tmp/lab305-$ZAK2"
  PRED_REAL="$(na_serveru "grep -c '' '$LOG' 2>/dev/null")"; PRED_REAL="${PRED_REAL:-0}"
  na_serveru "rm -rf $TMPH; mkdir -p $TMPH/skripty; chown -R $UCET:$UCET $TMPH" >/dev/null 2>&1
  na_serveru "runuser -u $UCET -- env HOME=$TMPH timeout 20 bash -c 'cd $TMPH && bash \"$SKRIPT\"'" >/dev/null 2>&1
  ZAPSAL="$(na_serveru "grep -c '' $TMPH/skripty/stav.log 2>/dev/null")"; ZAPSAL="${ZAPSAL:-0}"
  PO_REAL="$(na_serveru "grep -c '' '$LOG' 2>/dev/null")"; PO_REAL="${PO_REAL:-0}"
  if [ "$ZAPSAL" -gt 0 ] || [ "$PO_REAL" -gt "$PRED_REAL" ]; then
    uspech "skript se spustil a zapsal řádek do logu"
  else
    chyba "spuštění skriptu nepřidalo do logu žádný řádek"
    poznamka "skript má při každém běhu PŘIPOJIT řádek, ne přepsat soubor"
  fi
  VZOREK="$(na_serveru "tail -1 $TMPH/skripty/stav.log 2>/dev/null")"
  [ -n "$VZOREK" ] || VZOREK="$(na_serveru "tail -1 '$LOG' 2>/dev/null")"
  na_serveru "rm -rf $TMPH" >/dev/null 2>&1
  HOSTNAME_SRV="$(na_serveru 'hostname' | tr -d '\r')"
  if [ -n "$HOSTNAME_SRV" ] && printf '%s' "$VZOREK" | grep -qF "$HOSTNAME_SRV"; then
    uspech "v logu je jméno serveru — skript běžel tam, kde má"
  else
    chyba "v posledním řádku logu není jméno serveru"
  fi
fi

krok 4 "Formulář"
LAB_KONTEJNER=""
require_zaznam "$FORMULAR" vydani "${VYDANI:-}" \
  "ve formuláři je kódové jméno vydání serveru"
# Žákův log kontrola nehýbe (skript se pouští stranou), takže se porovnává
# proti jeho skutečnému stavu. Tolerance o jedna kryje skript, který má
# cestu k logu napsanou natvrdo a zapsal si i při běhu kontroly.
RADKU="$(lxc exec "$KONT" -- bash -c "grep -c '' '$LOG' 2>/dev/null" 2>/dev/null | tr -d '\r')"
RADKU="${RADKU:-0}"
ODP_RADKU="$(_zaznam "$FORMULAR" radku)"
if [ -n "$ODP_RADKU" ] && { [ "$ODP_RADKU" = "$RADKU" ] || [ "$ODP_RADKU" = "$(( RADKU - 1 ))" ]; }; then
  uspech "ve formuláři je počet řádků logu"
else
  chyba "počet řádků logu ve formuláři nesedí (máte '${ODP_RADKU:-nic}')"
fi
HODNOTA="$(lxc exec "$KONT" -- bash -c "tail -1 '$LOG' 2>/dev/null | awk '{print \$NF}'" 2>/dev/null | tr -d '\r')"
if [ -n "$HODNOTA" ]; then
  require_zaznam "$FORMULAR" hodnota "$HODNOTA" \
    "ve formuláři je poslední hodnota z logu"
else
  chyba "z logu se nepodařilo přečíst poslední hodnotu"
fi

vypis_souhrn
