#!/bin/bash
# 3/12 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="provoz-$ZAK2"
PROVOZ="$HOME/netlab/provoz"
PROTOKOL="$PROVOZ/protokol-12.txt"

MB_DRZENY=$(( 90 + ZAK ))

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

# Losovaná jména se NEPOČÍTAJÍ znovu — čtou se ze stavu, který zapsal
# start.sh. Dvojí výpočet téhož losu je dvojí místo, kde se to může rozejít.
# Klíč je v konfiguraci LXD, tedy mimo dosah žáka: uvnitř kontejneru má
# sudo bez hesla, ale `lxc` nemá.
# (Pozor: `set --` by tu přepsalo poziční parametry, ze kterých si lab-lib
# bere --krok. Proto read, ne set.)
ZAVEDENO="$(lxc config get "$KONT" user.lab312-zavedeno 2>/dev/null | tr -d '\r')"
read -r SLUZBA FRONTA EVID LOG_INODE _ <<< "$ZAVEDENO"
if [ -z "${SLUZBA:-}" ] || [ -z "${FRONTA:-}" ] || [ -z "${EVID:-}" ]; then
  echo; echo "  Prostředí cvičení není postavené. Spusťte ./start.sh"; echo; exit 1
fi

# Smazané, ale držené soubory. `-F sn` je strojový formát lsof: řádky
# začínající `s` nesou velikost, řádky `n` jméno. Parsuje se spolehlivěji
# než sloupce, jejichž šířka se mění podle délky jmen.
drzene_mb() {  # drzene_mb → největší držený soubor v MB (0, když žádný)
  na_serveru "lsof -nP +L1 -F sn 2>/dev/null" \
    | awk '/^s/{sz=substr($0,2)} /^n/{if (sz+0>m) m=sz+0} END{printf "%d", m/1048576}'
}

krok 1 "Místo, které du nevidělo"
# POZOR: hlášky téhle části nesmí obsahovat velikost ani jméno služby.
# Velikost drženého souboru je jediná AI-odolná kotva celého labu (žák ji
# píše do protokolu) a jméno vetřelce je půlka diagnostiky. Zadání posílá
# na `--krok 1` jako na PRVNÍ příkaz — vypsat je tady by znamenalo dát
# klíč dřív, než žák začne hledat. Do [PASS] hlášek smí, tam už je zná.
if ! na_serveru "command -v lsof >/dev/null"; then
  # Bez téhle větve by prázdný výstup lsof vyšel jako „nic nedrží" a lab
  # by se dal obejít jedním `sudo mv /usr/bin/lsof /tmp`.
  chyba "na serveru není lsof, takže nejde ověřit, co drží místo"
  poznamka "spusťte ./start.sh — doinstaluje ho; když nepomůže, řekněte o tom vyučujícímu"
else
  DRZENO="$(drzene_mb | tr -d '\r')"
  DRZENO="${DRZENO:-0}"
  if [ "$DRZENO" -lt 20 ]; then
    uspech "žádný proces už nedrží smazaný soubor"
  else
    chyba "nějaký proces pořád drží smazaný soubor"
    poznamka "zabít ho nestačí, když ho systemd hned nastartuje znovu"
  fi
fi
# Zbytek po předchůdci nesmí jen stát — po restartu serveru by naskočil zpátky.
STAV_SLUZBY="$(na_serveru "systemctl is-enabled $SLUZBA 2>/dev/null" | tr -d '\r' | tail -n1)"
if na_serveru "systemctl is-active --quiet $SLUZBA"; then
  chyba "na serveru pořád běží služba, která v dokumentaci není"
  poznamka "porovnejte výpis systemctl list-units --type=service s tím, co vypsal ./start.sh"
elif [ "$STAV_SLUZBY" = "enabled" ]; then
  chyba "ta služba je zastavená, ale po restartu serveru naskočí znovu"
  poznamka "zastavit nestačí — musí se i vypnout"
else
  uspech "služba $SLUZBA neběží a po restartu nenaskočí"
fi

krok 2 "Fronta a log"
# Ani tady se nejmenuje cesta — je to jeden ze tří symptomů, které má žák najít.
if ! na_serveru "test -d /srv/$FRONTA"; then
  # Přesunout nebo smazat celý adresář není vybrání fronty: soubory pak leží
  # jinde a místo drží dál.
  chyba "adresář s frontou na serveru není"
  poznamka "vysypat se měl obsah, adresář měl zůstat"
else
  POCET="$(na_serveru "find /srv/$FRONTA -type f 2>/dev/null | grep -c ''" | tr -d '\r')"
  POCET="${POCET:-0}"
  if [ "$POCET" -lt 100 ]; then
    uspech "fronta /srv/$FRONTA je vybraná"
  else
    chyba "jeden adresář je pořád plný drobných souborů"
    poznamka "mazat je po jednom nemusíte — find je projde jedním během"
  fi
fi
# Log má zůstat NA MÍSTĚ a jen se zkrátit. Kdo ho smazal, vyrobil si tím
# první symptom znovu — a to už krok 1 vytkl.
LOG_MB="$(na_serveru "du -m /var/log/$EVID/$EVID.log 2>/dev/null | cut -f1" | tr -d '\r')"
if [ -z "$LOG_MB" ]; then
  chyba "log /var/log/$EVID/$EVID.log na serveru není"
  poznamka "smazat ho nebyla oprava — služba ho drží otevřený a místo drží dál"
elif [ "$LOG_MB" -lt 5 ]; then
  # Zkrácení zachová i-uzel, smazání ne. Bez tohohle porovnání by prošlo
  # i „smazal jsem log a restartoval službu" — tedy přesně ta oprava,
  # před kterou lab varuje.
  INODE_TED="$(na_serveru "stat -c %i /var/log/$EVID/$EVID.log 2>/dev/null" | tr -d '\r')"
  if [ -n "${LOG_INODE:-}" ] && [ "$LOG_INODE" != "0" ] && [ "$INODE_TED" != "$LOG_INODE" ]; then
    chyba "log je nový, ne zkrácený — původní jste smazal a službu restartoval"
    poznamka "smazaný log drží místo dál, dokud ho služba nezavře; zkrácení ho uvolní hned"
  else
    uspech "log evidence je zkrácený a zůstal na svém místě"
  fi
else
  chyba "jeden log je pořád velký"
  poznamka "zkrátit ho jde bez mazání — soubor přitom zůstane na svém místě"
fi
require_service_active "$EVID"

krok 3 "Nic se neobešlo"
# Dávkové zpracování je busy loop na sto procentech procesoru, takže je to
# to nejpodezřelejší, co na serveru je — a přitom tam podle dokumentace
# patří. Zadání ho vyžaduje běžící, tak se to musí i ověřovat.
require_service_active "zpracovani"
# Evidence je legitimní služba. Vypnout ji, aby „přestal růst log",
# je obejití zadání, ne úklid.
STAV_EVID="$(na_serveru "systemctl is-enabled $EVID 2>/dev/null" | tr -d '\r' | tail -n1)"
if [ "$STAV_EVID" = "enabled" ]; then
  uspech "evidence zůstala zapnutá"
else
  chyba "evidence je vypnutá — to není úklid, to je vypnutá evidence"
  poznamka "ta služba tam podle dokumentace patří"
fi
if na_serveru "test -d /srv/archiv"; then
  uspech "archiv ze cvičení 11 zůstal netknutý"
else
  chyba "zmizel /srv/archiv — to nebyla jedna z příčin"
  poznamka "mazat se má to, co přebývá, ne to, co je něčí data"
fi

pouzil_diagnostiku 'lsof|du |du$|df |df$' \
  "smazaný, ale otevřený soubor najde jedině lsof +L1"
HISTORIE="$(na_serveru "cat /home/$LAB_UZIVATEL/.bash_history 2>/dev/null")"

krok 4 "Protokol"
LAB_KONTEJNER=""
require_soubor_neprazdny "$PROTOKOL" \
  "protokol je na stanici" \
  "chybí ~/netlab/provoz/protokol-12.txt — spusťte ./start.sh, doplní ho"
POPSANO=0
for I in 1 2 3; do
  H="$(_zaznam "$PROTOKOL" "symptom-$I")"
  [ "$(printf '%s' "$H" | wc -w | tr -d ' ')" -ge 5 ] && POPSANO=$((POPSANO + 1))
done
if [ "$POPSANO" -eq 3 ]; then
  uspech "v protokolu jsou popsané všechny tři příčiny"
else
  chyba "v protokolu jsou popsané jen $POPSANO příčiny ze tří"
  poznamka "u každé napište vlastními slovy, co bylo špatně — aspoň pět slov"
fi
DRZEL="$(_zaznam "$PROTOKOL" drzel)"
if printf '%s' "$DRZEL" | grep -qi -- "$SLUZBA"; then
  uspech "v protokolu je, který program místo držel"
else
  chyba "v protokolu není správně, který program místo držel"
fi
# Velikost drženého souboru je jediný údaj, který se jinde na serveru
# nedá přečíst — `du` ho nevidí a v unitu nestojí. Doloží běh lsof.
ODP_MB="$(_zaznam "$PROTOKOL" drzenych-mb | grep -oE '^[0-9]+')"
if [ -z "$ODP_MB" ]; then
  chyba "v protokolu chybí, kolik MB ten program držel"
  poznamka "velikost ukáže lsof +L1 — v bajtech, přepočtěte na MB"
elif [ "$ODP_MB" -ge $(( MB_DRZENY - 3 )) ] && [ "$ODP_MB" -le $(( MB_DRZENY + 3 )) ]; then
  uspech "velikost drženého souboru sedí"
else
  chyba "velikost drženého souboru nesedí (máte $ODP_MB MB)"
  poznamka "lsof +L1 ji vypíše v bajtech; 1 MB = 1048576 bajtů"
fi
if printf '%s' "$HISTORIE" | grep -q "lsof"; then
  uspech "lsof je ve vaší historii na serveru"
else
  chyba "lsof se ve vaší historii na serveru neobjevil"
  poznamka "bez něj se držený soubor najít nedá — hodnota v protokolu není vaše"
fi

vypis_souhrn
