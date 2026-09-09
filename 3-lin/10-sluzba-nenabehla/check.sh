#!/bin/bash
# 3/10 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="sluzby-$ZAK2"
UCET_SLUZBY="tisk$ZAK2"
TS="$HOME/netlab/tisk"
PROTOKOL="$TS/protokol.txt"
UNIT=/etc/systemd/system/tisk.service

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

na_serveru() { lxc exec "$KONT" -- bash -c "$1" 2>/dev/null; }
LAB_KONTEJNER="$KONT"
# Seznam zavedených závad je v konfiguraci LXD, mimo kontejner.
ZAVEDENO="$(lxc config get "$KONT" user.lab310-zavedeno 2>/dev/null | tr -d '\r')"

krok 1 "Služba běží"
require_service_active  "tisk"
require_service_enabled "tisk"
require_service_user    "tisk" "$UCET_SLUZBY"

krok 2 "Závady jsou opravené"
# Kontrola říká jen KOLIK závad zbývá, ne KTERÉ. Jinak by první příkaz, který
# žák pustí, byl kompletní klíč včetně toho, kde opravovat — a z labu na
# úrovni Analýza by se stal seznam tří úkolů k odškrtnutí.
zavada_opravena() {  # zavada_opravena KÓD → 0 = opraveno
  local unit_execstart unit_wd
  case "$1" in
    A1) na_serveru "grep -q '^ExecStart=' $UNIT && ! grep -q 'ExecStrat' $UNIT" ;;
    A2) na_serveru "grep -q '^\\[Install\\]' $UNIT" ;;
    # `exec` je stejně správná oprava jako `simple` — program běží v popředí,
    # rozdíl mezi nimi je jen v tom, kdy systemd považuje start za hotový.
    A3) case "$(na_serveru "systemctl show tisk -p Type --value" | tr -d '\r')" in
          simple|exec) return 0 ;; *) return 1 ;;
        esac ;;
    B1) na_serveru "test -x /usr/local/bin/tisk.sh" ;;
    B2) [ "$(na_serveru "systemctl show tisk -p User --value" | tr -d '\r')" = "$UCET_SLUZBY" ] ;;
    B3) na_serveru "runuser -u $UCET_SLUZBY -- test -w /var/log/tisk" ;;
    C1) unit_execstart="$(na_serveru "systemctl show tisk -p ExecStart --value" \
          | sed -n 's/.*path=\([^ ;]*\).*/\1/p' | tr -d '\r')"
        [ -n "$unit_execstart" ] && na_serveru "test -f '$unit_execstart'" ;;
    # Prázdná hodnota znamená, že žák direktivu WorkingDirectory smazal.
    # To je legitimní oprava — služba ji k běhu nepotřebuje.
    C2) unit_wd="$(na_serveru "systemctl show tisk -p WorkingDirectory --value" | tr -d '\r')"
        # systemd exportuje volitelnost prefixem `!`, ne `-`.
        unit_wd="${unit_wd#!}"
        [ -z "$unit_wd" ] || na_serveru "test -d '$unit_wd'" ;;
    C3) na_serveru "! systemctl show tisk -p Requires --value | grep -q tiskarna" ;;
    *)  return 0 ;;
  esac
}

if [ -z "$ZAVEDENO" ]; then
  chyba "nepodařilo se zjistit, které závady byly zavedené"
  poznamka "spusťte ./reset.sh — prostředí se postaví znovu"
else
  ZBYVA=0
  for KOD in $ZAVEDENO; do
    zavada_opravena "$KOD" || ZBYVA=$((ZBYVA + 1))
  done
  if [ "$ZBYVA" -eq 0 ]; then
    uspech "všechny tři závady jsou opravené"
  else
    chyba "neopravené závady: $ZBYVA ze tří"
    poznamka "každá je v jiné vrstvě — v tom, co je napsané, kdo na co má právo, a co musí existovat dřív"
  fi
fi

krok 3 "Nic se neobešlo"
# Negativní kontroly: opravit službu tím, že poběží pod rootem nebo že se
# rozdají práva všem, není oprava — je to díra.
if [ "$(na_serveru "systemctl show tisk -p User --value" | tr -d '\r')" = "root" ]; then
  chyba "služba běží pod rootem — to není oprava, to je díra"
  poznamka "tisková fronta nepotřebuje práva správce"
else
  uspech "služba neběží pod rootem"
fi
PRAVA="$(na_serveru "stat -c %a /var/log/tisk" | tr -d '\r')"
case "$PRAVA" in
  "")     chyba "adresář /var/log/tisk na serveru není"
          poznamka "služba do něj má zapisovat — bez něj nemá kam" ;;
  *[2367]) chyba "adresář /var/log/tisk má práva $PRAVA — zapisovat smí kdokoli"
          poznamka "stačí, aby do něj směl psát účet služby" ;;
  *)      uspech "log služby není otevřený všem" ;;
esac

# Měkká kontrola: sáhl žák po diagnostice, než začal opravovat?
# POZOR na pořadí — musí být PŘED vynulováním LAB_KONTEJNER, jinak by
# knihovna hledala historii na stanici, kde žák nepracoval.
pouzil_diagnostiku 'systemctl (status|cat|show)|journalctl|systemd-analyze' \
  "příště začněte od 'systemctl status tisk' a 'journalctl -xeu tisk'"
HISTORIE="$(na_serveru "cat /home/$LAB_UZIVATEL/.bash_history 2>/dev/null")"

krok 4 "Protokol"
LAB_KONTEJNER=""
require_soubor_neprazdny "$PROTOKOL" \
  "protokol je na stanici" \
  "chybí ~/netlab/tisk/protokol.txt — spusťte ./start.sh, doplní ho"
POPSANO=0
for I in 1 2 3; do
  H="$(_zaznam "$PROTOKOL" "zavada-$I")"
  [ "$(printf '%s' "$H" | wc -w | tr -d ' ')" -ge 4 ] && POPSANO=$((POPSANO + 1))
done
if [ "$POPSANO" -eq 3 ]; then
  uspech "v protokolu jsou popsané všechny tři závady"
else
  chyba "v protokolu jsou popsané jen $POPSANO závady ze tří"
  poznamka "u každé napište vlastními slovy, co bylo špatně — aspoň čtyři slova"
fi

# Nestačí do `nastroje` napsat cokoli. Musí tam být aspoň dva nástroje, které
# se opravdu objevily v historii na serveru — jinak je to jen opsané slovo.
NASTROJE="$(_zaznam "$PROTOKOL" nastroje)"
DOLOZENO=0
for N in systemctl journalctl systemd-analyze ss stat ls; do
  printf '%s' "$NASTROJE" | grep -qi -- "$N" || continue
  printf '%s' "$HISTORIE"  | grep -q -- "$N"  || continue
  DOLOZENO=$((DOLOZENO + 1))
done
if [ "$DOLOZENO" -ge 2 ]; then
  uspech "v protokolu jsou nástroje, kterými jste závady našli"
elif [ -n "$NASTROJE" ]; then
  chyba "nástroje v protokolu nesedí s tím, co jste na serveru opravdu pouštěli"
  poznamka "napište aspoň dva, které jste použili — kontrola je hledá ve vaší historii"
else
  chyba "v protokolu chybí, čím jste závady našli"
fi

vypis_souhrn
