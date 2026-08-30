#!/bin/bash
# 2/13 — odstupňovaná nápověda. Plán ji u diagnostických cvičení vyžaduje
# a chce, aby její použití hlásil check.sh — proto se nedává do zadání, ale
# sem: skript si zaznamená, kterou úroveň jste si vyžádali.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

INST="$HOME/netlab/instalace"
mkdir -p "$INST"
UROVEN="${1:-1}"
case "$UROVEN" in 1|2|3) ;; *) echo "  Použití: ./napoveda.sh [1|2|3]"; exit 1 ;; esac

echo "$UROVEN" >> "$INST/.napoveda"

echo
case "$UROVEN" in
1)
  cat <<'TEXT'
  ── Nápověda 1 ze 3 — čím se dá zkoušet ─────────────────────────

  Metodu máte v zadání. Tohle jsou nástroje, které v něm nejsou
  a při hledání ušetří nejvíc času — žádný z nich nic nemění:

    apt-get -s install JMENO     nanečisto zkusí instalaci a vypíše,
                                 co by jí bránilo. Nepotřebuje sudo.
    apt-config dump              vypíše, co má apt doopravdy nastavené,
                                 včetně toho, co mu přidal někdo jiný.
    apt-cache policy JMENO       ukáže, odkud by se balíček bral
                                 a jakou má prioritu.

  Pozor: `sudo apt update` proběhne bez chyby i tehdy, když zdroje
  nejsou v pořádku — třeba když v nich nic není. Že update mlčí,
  ještě neznamená, že je hotovo.
TEXT
  ;;
2)
  cat <<'TEXT'
  ── Nápověda 2 ze 3 — kde se co nastavuje ───────────────────────

  Správu balíčků ovlivňují čtyři oblasti a každá má své místo:

    zdroje balíčků     /etc/apt/sources.list.d/
    nastavení apt      /etc/apt/apt.conf.d/
    priority a zámky   /etc/apt/preferences.d/  a  apt-mark showhold
    systém okolo       /etc/hosts, práva souborů

  Užitečné příkazy, které nic nemění:

    apt-config dump | grep -i proxy      co má apt nastavené
    apt-cache policy JMENO_BALICKU       jaké má balíček priority
    apt-mark showhold                    co je podržené
    ls -l /etc/apt/sources.list.d/       co tam přibylo a s jakými právy

  Soubory, které do systému přidalo tohle cvičení, poznáte podle
  jména — začínají na netlab- nebo 99-netlab-.
TEXT
  ;;
3)
  cat <<'TEXT'
  ── Nápověda 3 ze 3 — vaše oblasti ──────────────────────────────

  Tohle jsou oblasti, ve kterých máte závadu. Konkrétní chybu
  v nich musíte najít sami.
TEXT
  echo
  # Seznam zavedených závad čte jen root — z kódů by se řešení vyčetlo jedním
  # `cat` a katalog je ve veřejném repozitáři.
  SEZNAM="$(sudo cat "$LAB_ZALOHY/zavedeno" 2>/dev/null)"
  if [ -n "$SEZNAM" ]; then
    printf '%s\n' "$SEZNAM" | while read -r Z; do
      [ -n "$Z" ] || continue
      case "${Z:0:1}" in
        A) echo "    · zdroje balíčků (/etc/apt/sources.list.d/)" ;;
        B) echo "    · nastavení apt (/etc/apt/apt.conf.d/)" ;;
        C) echo "    · priority a zámky balíčků" ;;
        D) echo "    · okolí zdrojů — jejich obsah, starý formát, překlad jmen" ;;
      esac
    done
  else
    echo "    (závady nejsou zavedené — spusťte ./start.sh)"
  fi
  ;;
esac
echo
echo "  Použití nápovědy se objeví ve výpisu kontroly."
echo
