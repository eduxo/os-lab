#!/bin/bash
# 3/20 — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 je jen prohlídka.
#
# Opravy se ověřují CHOVÁNÍM, ne čtením kódu. Skript se ale nepouští
# na ostrá data: kontrola si z něj udělá kopii, přesměruje v ní cesty
# do pískoviště a zkouší tam. Tím je bezpečné i to, že třetí vada
# v neopraveném stavu maže.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="data-$ZAK2"
BASH_DIR="$HOME/netlab/bash"
PROTOKOL="$BASH_DIR/protokol.txt"
SKRIPT=/usr/local/bin/uklid.sh
PISK=/tmp/lab320

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

# Kopie skriptu s cestami přesměrovanými do pískoviště.
#
# TŘI POJISTKY, protože neopravený skript maže rekurzivně a kontrola ho
# pouští:
#   1. oba řádky s cestami se musely opravdu přepsat,
#   2. v kopii nesmí zůstat ŽÁDNÁ zmínka o ostrých cestách — přepsat
#      `^ZDROJ=` nestačí, když si žák (nebo model) cestu jinde odvodí
#      do další proměnné,
#   3. pouští se pod účtem `nobody`, který na /srv nemá právo zápisu.
# Když kterákoli neprojde, kontrola RADĚJI NETESTUJE.
KOPIE="$PISK/uklid-test.sh"
priprav_kopii() {
  na_serveru "
    rm -rf $PISK && mkdir -p $PISK
    sed -e 's|^ZDROJ=.*|ZDROJ=$PISK/podatelna|' \
        -e 's|^ARCHIV=.*|ARCHIV=$PISK/archiv|' '$SKRIPT' > '$KOPIE'
    chmod 755 '$KOPIE'
    grep -q '^ZDROJ=$PISK/podatelna' '$KOPIE' \
      && grep -q '^ARCHIV=$PISK/archiv' '$KOPIE' \
      && ! grep -qE '/srv/(podatelna|archiv)' '$KOPIE'
  "
}
uklid_piskoviste() { na_serveru "rm -rf $PISK" >/dev/null 2>&1; }
# Pouští se pod `nobody`, ne pod účtem žáka: kdyby některá pojistka
# selhala, nemá ten účet na /srv co smazat. A ne pod rootem — ten by
# práva ignoroval a druhá zkouška by nic nedokázala.
# `cd` do pískoviště kvůli tomu, aby vnitřní shell měl kam ukazovat;
# `lxc exec` startuje v /root, kam nobody nevidí.
v_piskovisti() { na_serveru "runuser -u nobody -- bash -c \"cd $PISK && $1\""; }

KOPIE_OK=0
if krok_aktivni 3 || krok_aktivni 4; then
  priprav_kopii >/dev/null 2>&1 && KOPIE_OK=1
fi

krok 2 "Skript prošel nástrojem"
if ! na_serveru "test -f '$SKRIPT'"; then
  chyba "na serveru není $SKRIPT"
  poznamka "spusťte ./start.sh — doplní ho"
else
  # BEZ `-S warning`: žák pouští `shellcheck` bez přepínačů a vidí i nálezy
  # úrovně info (neuzavřené proměnné). Kdyby kontrola měřila jen varování,
  # dala by PASS skriptu, nad kterým nástroj žákovi pořád něco vypisuje —
  # a Minimum přitom slibuje „bez výhrad".
  VYSTUP="$(na_serveru "shellcheck '$SKRIPT' 2>&1")"
  if [ -z "$VYSTUP" ]; then
    uspech "shellcheck nemá ke skriptu výhrady"
  else
    POCET="$(printf '%s' "$VYSTUP" | grep -c '^In .* line ')"
    [ "${POCET:-0}" -gt 0 ] || POCET="několik"
    chyba "shellcheck má ke skriptu výhrady (nálezů: $POCET)"
    poznamka "spusťte shellcheck $SKRIPT na serveru — u každého nálezu napíše i proč"
  fi
fi

krok 3 "Skript zvládne jména s mezerou"
if ! krok_aktivni 3; then :
elif [ "$KOPIE_OK" -eq 0 ]; then
  chyba "skript se nepodařilo bezpečně vyzkoušet"
  poznamka "nechte na začátku skriptu řádky ZDROJ= a ARCHIV= — kontrola je používá, aby ho vyzkoušela nanečisto"
else
  na_serveru "
    mkdir -p $PISK/podatelna $PISK/archiv
    printf 'a\n' > '$PISK/podatelna/faktura 2026-11.txt'
    printf 'b\n' > '$PISK/podatelna/objednavka-001.txt'
    printf 'c\n' > '$PISK/podatelna/dodaci list.txt'
    chown -R nobody:nogroup $PISK
    chmod 755 $PISK
  " >/dev/null 2>&1
  HLASKA_OK="$(v_piskovisti "$KOPIE 2026-11 2>&1")"
  ZBYLO="$(na_serveru "find $PISK/podatelna -type f | grep -c ''" | tr -d '\r')"
  PRESUNUTO="$(na_serveru "find $PISK/archiv/2026-11 -type f 2>/dev/null | grep -c ''" | tr -d '\r')"
  if [ "${ZBYLO:-9}" -eq 0 ] && [ "${PRESUNUTO:-0}" -eq 3 ]; then
    uspech "skript přesunul všechny tři soubory včetně těch s mezerou"
    # Hláška o dokončení je součástí kontraktu: bez ní by šlo zkoušku
    # „zastavil se po chybě" splnit tím, že se ten řádek prostě smaže.
    if printf '%s' "$HLASKA_OK" | grep -q 'Hotovo'; then
      uspech "po úspěšném běhu skript ohlásí, že je hotovo"
    else
      chyba "po úspěšném běhu skript neohlásí, že je hotovo"
      poznamka "hlášku o dokončení ve skriptu nechte — patří k němu"
    fi
  elif [ "${PRESUNUTO:-0}" -gt 0 ]; then
    chyba "skript ze tří souborů přesunul jen tolik: ${PRESUNUTO}"
    poznamka "na jménech s mezerou se rozpadá — podívejte se, jak prochází seznam"
  else
    chyba "skript nepřesunul nic"
  fi
fi

krok 4 "Skript se zastaví, když má"
if ! krok_aktivni 4; then :
elif [ "$KOPIE_OK" -eq 0 ]; then
  chyba "skript se nepodařilo bezpečně vyzkoušet"
else
  # (a) Když selže příprava cíle, nemá se pokračovat a hlásit „Hotovo".
  na_serveru "
    rm -rf $PISK/podatelna $PISK/archiv
    mkdir -p $PISK/podatelna $PISK/archiv
    printf 'a\n' > '$PISK/podatelna/doklad.txt'
    chown -R nobody:nogroup $PISK/podatelna $PISK/archiv
    chmod 500 $PISK/archiv
  " >/dev/null 2>&1
  HLASKA="$(v_piskovisti "$KOPIE 2026-11 2>&1")"
  na_serveru "chmod 755 $PISK/archiv" >/dev/null 2>&1
  if printf '%s' "$HLASKA" | grep -q 'Hotovo'; then
    chyba "skript ohlásil Hotovo, přestože se mu nepovedlo připravit cíl"
    poznamka "bez zastavení po chybě jede skript dál a tváří se, že uklidil"
  else
    uspech "skript se po chybě zastavil a Hotovo neohlásil"
  fi

  # (b) Prázdný argument nesmí vymazat archiv. Tady se to smí zkoušet —
  # je to pískoviště, ne ostrá data.
  na_serveru "
    rm -rf $PISK/podatelna $PISK/archiv
    mkdir -p $PISK/podatelna $PISK/archiv/2026-10
    printf 'stara faktura\n' > '$PISK/archiv/2026-10/faktura.txt'
    printf 'dulezite\n' > '$PISK/archiv/kanarek.txt'
    chown -R nobody:nogroup $PISK
    chmod 755 $PISK
  " >/dev/null 2>&1
  v_piskovisti "$KOPIE" >/dev/null 2>&1
  PREZILO="$(na_serveru "test -s $PISK/archiv/kanarek.txt && test -s $PISK/archiv/2026-10/faktura.txt && echo ano" | tr -d '\r')"
  if [ "$PREZILO" = "ano" ]; then
    uspech "spuštění bez argumentu archiv nesmazalo"
  else
    chyba "spuštění bez argumentu smazalo obsah archivu"
    poznamka "prázdná proměnná uprostřed cesty je mina — skript se musí zeptat, jestli argument vůbec dostal"
  fi
fi
uklid_piskoviste

krok 5 "Protokol"
LAB_KONTEJNER=""
require_soubor_neprazdny "$PROTOKOL" \
  "protokol je na stanici" \
  "chybí ~/netlab/bash/protokol.txt — spusťte ./start.sh, doplní ho"
POPSANO=0
for V in vada-1 vada-2 vada-3; do
  H="$(_zaznam "$PROTOKOL" "$V")"
  [ "$(printf '%s' "$H" | wc -w | tr -d ' ')" -ge 5 ] && POPSANO=$((POPSANO + 1))
done
if [ "$POPSANO" -eq 3 ]; then
  uspech "v protokolu jsou popsané všechny tři vady"
else
  chyba "v protokolu jsou popsané jen $POPSANO vady ze tří"
  poznamka "u každé napište, co je špatně A co se stane, když se to nechá být"
fi
ODP_N="$(_zaznam "$PROTOKOL" nastroj | tr 'A-Z' 'a-z')"
case "$ODP_N" in
  *shellcheck*) uspech "v protokolu je nástroj, který na vady upozornil sám" ;;
  '')           chyba "v protokolu chybí, čím jste si skript nechali zkontrolovat" ;;
  *)            chyba "nástroj v protokolu nesedí (máte '$ODP_N')"
                poznamka "na některé z vad upozorní statická kontrola kódu" ;;
esac

vypis_souhrn
