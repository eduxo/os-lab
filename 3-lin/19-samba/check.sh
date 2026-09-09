#!/bin/bash
# 3/19 — ověření. Části odpovídají krokům zadání 1:1 — proto se začíná
# dvojkou: Krok 1 je jen prohlídka.
#
# Připojení se zkouší ZE STANICE. `smbclient //localhost/...` na serveru
# by prošlo i u sdílení, ke kterému se zvenčí nikdo nedostane.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="data-$ZAK2"
SDILENI="$HOME/netlab/sdileni"
FORMULAR="$SDILENI/formular.txt"

ODDELENI=(ucetni sklad technici)
ODD="${ODDELENI[$(( $(lab_vyber 3 1 901) - 1 ))]}"
SDILENA_CESTA="/srv/sdileni/$ODD"

for n in lxc smbclient; do
  if ! command -v "$n" >/dev/null 2>&1; then
    [ "$n" = lxc ] && n=LXD
    echo; echo "  Na stanici není $n. Řekněte o tom vyučujícímu."; echo; exit 1
  fi
done
STAV="$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)"
if [ -z "$STAV" ]; then
  echo; echo "  Server $KONT neexistuje. Spusťte ./start.sh"; echo; exit 1
elif [ "$STAV" != "RUNNING" ]; then
  echo; echo "  Server $KONT je zastavený — vaše práce na něm zůstala."
  echo "  Nastartujte ho:  ./start.sh"; echo; exit 1
fi

na_serveru() { lxc exec "$KONT" -- bash -c "$1" 2>/dev/null; }
LAB_KONTEJNER="$KONT"
IP="$(na_serveru "ip -4 -o addr show dev eth0 | awk '{print \$4}' | cut -d/ -f1" | tr -d '\r' | head -1)"
KOD="$(lxc config get "$KONT" user.lab319-kod 2>/dev/null | tr -d '\r')"
DRUHY="$(lxc config get "$KONT" user.lab319-soubor 2>/dev/null | tr -d '\r')"
# Heslo je totéž, které losoval server-lib.sh na stanici.
HESLO="$(cat "$HOME/.os-lab-heslo-$KONT" 2>/dev/null | tr -d '\r\n')"

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT INT TERM

# smbclient vrací nenulu i při chybě ověření, takže se dá použít přímo.
# Heslo jde přes proměnnou prostředí, ne v příkazové řádce — v `ps` by
# ho jinak viděl kdokoli na stanici. Server-lib to u `chpasswd` dělá stejně.
smb() {  # smb SDÍLENÍ PŘÍKAZ… → 0 = povedlo se
  PASSWD="$HESLO" smbclient "//$IP/$1" -U sysadmin -c "$2" >/dev/null 2>&1
}

krok 2 "Adresář a skupina na serveru"
if na_serveru "test -d '$SDILENA_CESTA'"; then
  uspech "sdílený adresář existuje"
else
  chyba "na serveru není $SDILENA_CESTA"
  poznamka "spusťte ./start.sh — adresář i podklady doplní"
fi
require_group "$ODD"
require_member "sysadmin" "$ODD"
SKUP="$(na_serveru "stat -c %G '$SDILENA_CESTA' 2>/dev/null" | tr -d '\r')"
if [ "$SKUP" = "$ODD" ]; then
  uspech "adresář patří skupině $ODD"
else
  chyba "adresář patří skupině '${SKUP:-nic}', ne $ODD"
  poznamka "chgrp nastaví skupinu, chmod g+w právo zápisu pro ni"
fi
PRAVA="$(na_serveru "stat -c %04a '$SDILENA_CESTA' 2>/dev/null" | tr -d '\r')"
case "$PRAVA" in
  "")   chyba "práva adresáře se nepodařilo přečíst" ;;
  # Poslední číslice jsou práva ostatních. Sdílení oddělení nemá být
  # otevřené celému serveru.
  *[2367]) chyba "adresář má práva $PRAVA — zapisovat do něj smí kdokoli"
           poznamka "stačí, aby do něj směla skupina $ODD" ;;
  *)    uspech "adresář není otevřený všem (práva $PRAVA)" ;;
esac
# Tiket žádá adresář, KAM SE DÁ UKLÁDAT. Bez práva zápisu pro skupinu je
# to jen čítárna — a zápis je zároveň jediné místo, kde se dvouvrstvá
# oprávnění vůbec projeví.
case "$PRAVA" in
  ""|*[!0-9]*) : ;;
  *[2367]?) uspech "skupina $ODD smí do adresáře zapisovat" ;;
  *)        chyba "skupina $ODD do adresáře zapisovat nesmí"
            poznamka "sdílení má být k ukládání, ne jen ke čtení" ;;
esac
require_setgid "$SDILENA_CESTA" \
  "adresář nemá setgid — soubory v něm nezdědí skupinu oddělení"

krok 3 "Konfigurace Samby"
require_service_active "smbd"
if na_serveru "testparm -s >/dev/null 2>&1"; then
  uspech "konfigurace Samby je syntakticky v pořádku"
else
  chyba "konfigurace Samby má chybu"
  poznamka "testparm ji vypíše i s číslem řádku"
fi
# `testparm -s` vypíše konfiguraci tak, jak jí Samba rozumí — včetně
# výchozích hodnot. Je to spolehlivější zdroj než čtení smb.conf.
KONF="$(na_serveru "testparm -s 2>/dev/null")"
if printf '%s' "$KONF" | grep -q "^\[$ODD\]"; then
  uspech "Samba zná sdílení [$ODD]"
else
  chyba "Samba o sdílení [$ODD] neví"
  poznamka "sekce v smb.conf se musí jmenovat přesně tak, a po změně reload"
fi
CESTA_KONF="$(printf '%s' "$KONF" | awk -v s="[$ODD]" '
  $0==s {v=1; next} /^\[/ {v=0} v && /path[[:space:]]*=/ {gsub(/.*=[[:space:]]*/,""); print; exit}')"
if [ "$CESTA_KONF" = "$SDILENA_CESTA" ]; then
  uspech "sdílení ukazuje na správný adresář"
else
  chyba "sdílení ukazuje na '${CESTA_KONF:-nic}', ne na $SDILENA_CESTA"
fi
# Výchozí hodnota je `read only = Yes`, takže kdo ten řádek vynechá,
# má sdílení jen ke čtení — a tiket žádal opak.
JEN_CTENI="$(printf '%s' "$KONF" | awk -v s="[$ODD]" '
  $0==s {v=1; next} /^\[/ {v=0} v && tolower($0) ~ /read only[[:space:]]*=/ {print; exit}')"
case "$(printf '%s' "$JEN_CTENI" | tr 'A-Z' 'a-z')" in
  *"= no"*) uspech "sdílení dovoluje zápis" ;;
  "")       chyba "sdílení je jen ke čtení (chybí read only = no)"
            poznamka "výchozí hodnota je Yes, takže se to musí napsat" ;;
  *)        chyba "sdílení je jen ke čtení" ;;
esac

krok 4 "Připojení ze stanice"
# Filtr --krok potlačuje výpis, ne provádění. Bez téhle podmínky by
# `--krok 2` — první kontrola, na kterou start.sh posílá — navazoval tři
# spojení ke sdílení, které v tu chvíli ještě neexistuje.
if ! krok_aktivni 4; then :
elif [ -z "$IP" ]; then
  chyba "adresu serveru se nepodařilo zjistit"
elif [ -z "$HESLO" ]; then
  chyba "heslo pro Sambu se na stanici nenašlo"
  poznamka "spusťte ./start.sh — vypíše ho"
else
  if PASSWD="$HESLO" smbclient -L "//$IP" -U sysadmin 2>/dev/null | grep -q "$ODD"; then
    uspech "sdílení $ODD je ze stanice vidět"
  else
    chyba "sdílení $ODD ze stanice vidět není"
    poznamka "smbclient -L //$IP -U sysadmin ukáže, co server nabízí"
  fi
  if smb "$ODD" "ls"; then
    uspech "do sdílení se ze stanice dá připojit"
  else
    chyba "připojení do sdílení ze stanice selhalo"
    poznamka "má účet sysadmin heslo i v databázi Samby? smbpasswd -a"
  fi
  # Zápis přes Sambu je to, co žádal tiket — a projde jedině tehdy, když
  # sedí OBĚ vrstvy oprávnění: Samba i práva na souborovém systému.
  printf 'zkouska zapisu\n' > "$TMPD/proba.txt"
  if smb "$ODD" "put $TMPD/proba.txt proba-kontrola.txt"; then
    uspech "do sdílení se dá ze stanice i zapisovat"
    # Nahraný soubor musí zdědit skupinu oddělení — to je setgid v praxi.
    SKUP_NOVY="$(na_serveru "stat -c %G '$SDILENA_CESTA/proba-kontrola.txt' 2>/dev/null" | tr -d '\r')"
    if [ "$SKUP_NOVY" = "$ODD" ]; then
      uspech "nahraný soubor zdědil skupinu $ODD"
    else
      chyba "nahraný soubor má skupinu '${SKUP_NOVY:-nic}', ne $ODD"
      poznamka "od toho je setgid na adresáři — bez něj zdědí skupinu toho, kdo zapsal"
    fi
    smb "$ODD" "rm proba-kontrola.txt" >/dev/null 2>&1 || true
  else
    chyba "do sdílení se ze stanice nedá zapisovat"
    poznamka "projít musí obě vrstvy: read only v smb.conf i práva adresáře"
  fi
  # Sdílení oddělení nesmí být otevřené bez přihlášení. Ptáme se dvakrát:
  # konfigurace je spolehlivější (návratové kódy smbclientu nejsou
  # dokumentované), spojení zase měří skutečnost.
  HOST_OK="$(printf '%s' "$KONF" | awk -v s="[$ODD]" '
    $0==s {v=1; next} /^\[/ {v=0} v && tolower($0) ~ /guest ok[[:space:]]*=/ {print; exit}')"
  case "$(printf '%s' "$HOST_OK" | tr 'A-Z' 'a-z')" in
    *"= yes"*) chyba "sdílení má guest ok = yes — je otevřené bez přihlášení"
               poznamka "dokumenty oddělení nejsou veřejné" ;;
    *)         if smbclient "//$IP/$ODD" -N -c "ls" >/dev/null 2>&1; then
                 chyba "do sdílení se dá dostat i bez hesla"
                 poznamka "podívejte se na guest ok a na valid users"
               else
                 uspech "bez hesla se do sdílení nikdo nedostane"
               fi ;;
  esac
fi

krok 5 "Formulář"
LAB_KONTEJNER=""
require_soubor_neprazdny "$FORMULAR" \
  "formulář je na stanici" \
  "chybí ~/netlab/sdileni/formular.txt — spusťte ./start.sh, doplní ho"
# Obojí je losované per kontejner, takže v repozitáři to není a soused má
# jiné. POZOR: žák má na serveru sudo, takže si to přečíst umí i mimo
# sdílení — zadání to proto zakazuje a skutečný důkaz nese část 4,
# kterou si kontrola dělá sama.
ODP_KOD="$(_zaznam "$FORMULAR" kod | tr -d ' ' | tr 'a-z' 'A-Z')"
if [ -z "$KOD" ]; then
  chyba "kód se nepodařilo přečíst — spusťte ./reset.sh"
elif [ "$ODP_KOD" = "$KOD" ]; then
  uspech "kód ve formuláři sedí"
else
  chyba "kód ve formuláři nesedí (máte '${ODP_KOD:-nic}')"
  poznamka "je v souboru dokumenty.txt ve sdílení"
fi
ODP_SOUB="$(_zaznam "$FORMULAR" druhy-soubor | tr -d ' ')"
if [ -z "$DRUHY" ]; then
  chyba "jméno druhého souboru se nepodařilo přečíst"
elif [ "$ODP_SOUB" = "$DRUHY" ]; then
  uspech "jméno druhého souboru ve formuláři sedí"
else
  chyba "jméno druhého souboru ve formuláři nesedí (máte '${ODP_SOUB:-nic}')"
  poznamka "vypíše ho smbclient příkazem ls po připojení do sdílení"
fi

vypis_souhrn
