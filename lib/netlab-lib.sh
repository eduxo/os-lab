#!/bin/bash
# netlab-lib.sh — izolovaná síť `netlab` pro blok E (3/14 DNS, 3/15 DHCP).
#
# PROČ VLASTNÍ SÍŤ. Výchozí most `lxdbr0` má svůj `dnsmasq`, který na něm
# rozdává adresy a odpovídá na DNS dotazy. Kdyby žák postavil vlastní DNS
# nebo DHCP server tam, pral by se s ním o tytéž dotazy a výsledek by závisel
# na tom, kdo odpoví dřív. Na `netlab` je LXD rozdávání adres vypnuté,
# takže jediný server v té síti je ten žákův.
#
# PROČ DVĚ KARTY. Server má správu na `lxdbr0` (SSH ze stanice, `apt`)
# a službu na `netlab`. Kdyby byl jen na `netlab`, neměl by DNS pro `apt`
# — a vypnout LXD rozdávání adres a zároveň na něm záviset nejde.
# Je to i realistické: produkční servery mívají oddělenou správu od provozu.
#
# Sourcuje se AŽ PO lab-lib.sh (potřebuje $ZAK).

NETLAB_SIT="netlab"
# Každý žák má vlastní stanici, takže si podsítě nekolidují — číslo v adrese
# je tu proto, aby se lišily ODPOVĚDI, ne kvůli provozu.
NETLAB_PODSIT="10.20.$ZAK"
NETLAB_BRANA="$NETLAB_PODSIT.1"
NETLAB_PREFIX="24"
NETLAB_SERVER="$NETLAB_PODSIT.10"

# Vytvoří síť, když ještě není. Když už je, PŘEČTE si z ní skutečnou adresu —
# kdyby ji někdo založil ručně nebo s jiným rozsahem, musí se zbytek skriptů
# řídit tím, co je, ne tím, co jsme chtěli.
zaridi_sit() {
  # Guard tu musí být znovu: `zaridi_sit` běží DŘÍV než `postav_server`,
  # takže bez něj by stanice bez LXD hlásila „síť se nepodařilo vytvořit"
  # místo pravdy.
  if ! command -v lxc >/dev/null 2>&1; then
    echo
    echo "  Na téhle stanici není LXD, takže síť ani server nejdou postavit."
    echo "  Řekněte o tom vyučujícímu — patří do obrazu VM."
    echo
    return 1
  fi

  if ! lxc network show "$NETLAB_SIT" >/dev/null 2>&1; then
    lxc network create "$NETLAB_SIT" \
      ipv4.address="$NETLAB_BRANA/24" \
      ipv4.nat=true \
      ipv4.dhcp=false \
      ipv6.address=none >/dev/null 2>&1 || {
        echo "  Síť $NETLAB_SIT se nepodařilo vytvořit — zavolejte vyučujícího."
        return 1; }
  fi

  local adresa
  adresa="$(lxc network get "$NETLAB_SIT" ipv4.address 2>/dev/null | tr -d '\r')"
  # Ověřuje se TVAR, ne jen neprázdnost: síť založená ručně může mít
  # `ipv4.address=none` a z toho by se dál rozlezlo `none.10`.
  case "$adresa" in
    [0-9]*.[0-9]*.[0-9]*.[0-9]*/[0-9]*) ;;
    *) echo "  Síť $NETLAB_SIT nemá použitelnou adresu (je '${adresa:-prázdná}')."
       echo "  Smažte ji příkazem, který vám dá vyučující, a spusťte ./start.sh znovu."
       return 1 ;;
  esac
  NETLAB_BRANA="${adresa%/*}"
  NETLAB_PREFIX="${adresa#*/}"
  NETLAB_PODSIT="${NETLAB_BRANA%.*}"
  NETLAB_SERVER="$NETLAB_PODSIT.10"

  # Rozdávání adres musí být vypnuté, i kdyby síť vznikla dřív a jinak —
  # jinak by se LXD pral se žákovým DHCP serverem ve cvičení 15.
  if [ "$(lxc network get "$NETLAB_SIT" ipv4.dhcp 2>/dev/null | tr -d '\r')" != "false" ]; then
    if ! lxc network set "$NETLAB_SIT" ipv4.dhcp false >/dev/null 2>&1; then
      # Bez tohohle nastavení se LXD pere se žákovým DHCP serverem a nikdo
      # by se to nedozvěděl — cvičení 15 by dávalo náhodné výsledky.
      echo "  Na síti $NETLAB_SIT se nepodařilo vypnout rozdávání adres."
      echo "  Řekněte o tom vyučujícímu — cvičení 15 by jinak nefungovalo."
      return 1
    fi
  fi
  return 0
}

# Testovací klient — je JEN na netlab a adresu si musí vyžádat. Dokud žákův
# DHCP server nefunguje, nemá klient adresu žádnou; `lxc exec` na něj ale
# funguje pořád, protože nejde přes síť.
NETLAB_KLIENT="klient-$ZAK2"

postav_klienta() {
  if ! lxc info "$NETLAB_KLIENT" >/dev/null 2>&1; then
    lxc launch "$SERVER_OBRAZ" "$NETLAB_KLIENT" \
      --network "$NETLAB_SIT" >/dev/null 2>&1 || {
        echo "  Testovacího klienta se nepodařilo spustit — zavolejte vyučujícího."
        return 1; }
  elif [ "$(lxc list "^${NETLAB_KLIENT}$" -c s --format csv 2>/dev/null)" != "RUNNING" ]; then
    lxc start "$NETLAB_KLIENT" >/dev/null 2>&1
  fi

  # Kontejner potřebuje chvíli, než v něm běží systemd. `postav_server` čeká
  # na adresu, tady čekat na co nejde (klient ji dostat nemá), takže se čeká
  # na to, že je systemd nastartovaný.
  local i
  for i in $(seq 1 30); do
    lxc exec "$NETLAB_KLIENT" -- test -d /run/systemd/system >/dev/null 2>&1 && break
    sleep 1
  done

  # Klient má na eth0 čekat na DHCP. Obraz to tak sice má, ale explicitní
  # soubor je jistota — a `optional: true` zabrání tomu, aby start systému
  # čekal dvě minuty na adresu, kterou zatím nikdo nerozdává.
  local novy stary
  novy="$(printf 'network:\n  version: 2\n  ethernets:\n    eth0:\n      dhcp4: true\n      optional: true\n')"
  stary="$(lxc exec "$NETLAB_KLIENT" -- cat /etc/netplan/60-klient.yaml 2>/dev/null | tr -d '\r')"
  if [ "$novy" != "$stary" ]; then
    printf '%s' "$novy" | lxc exec "$NETLAB_KLIENT" -- tee /etc/netplan/60-klient.yaml >/dev/null
    lxc exec "$NETLAB_KLIENT" -- chmod 600 /etc/netplan/60-klient.yaml >/dev/null 2>&1
    lxc exec "$NETLAB_KLIENT" -- netplan apply >/dev/null 2>&1
  fi
  return 0
}

# Vypíše adresu, kterou klient na eth0 doopravdy má (prázdné = žádnou).
klient_adresa() {
  lxc exec "$NETLAB_KLIENT" -- bash -c \
    "ip -4 -o addr show dev eth0 2>/dev/null | awk '{print \$4}' | cut -d/ -f1" \
    2>/dev/null | tr -d '\r' | head -1
}

# Přinutí klienta požádat o adresu znovu. Používá to `./start.sh --klient`
# i kontrola — proto je to tady, a ne opsané na dvou místech.
klient_znovu() {
  # Uložená zápůjčka se musí SMAZAT. `netplan apply` sám o sobě jen znovu
  # nasadí adresu, kterou má systemd-networkd v paměti — bez jediného
  # DHCP paketu. Kontrola by pak na starých datech uznala i prostředí,
  # ve kterém žák DHCP mezitím rozbil.
  lxc exec "$NETLAB_KLIENT" -- bash -c \
    "ip -4 addr flush dev eth0
     rm -f /run/systemd/netif/leases/*
     systemctl restart systemd-networkd" >/dev/null 2>&1
  # netplan apply se vrací hned, ale DORA výměna chvíli trvá
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -n "$(klient_adresa)" ] && return 0
    sleep 1
  done
  return 1
}
