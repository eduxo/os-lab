#!/bin/bash
# web-lib.sh — společný nábytek serveru `web-XX` (blok F: 3/16–3/18).
#
# Cvičení 16, 17 a 18 sdílejí jeden server a platí pravidlo, že KAŽDÝ
# start.sh postaví celý stack, který jeho cvičení potřebuje — i žákovi,
# který na předchozích nebyl.
#
# Sourcuje se AŽ PO lab-lib.sh a server-lib.sh.

# ── co se losuje ──────────────────────────────────────────────────
WEB_POBOCKY=(brno plzen ostrava)
WEB_POBOCKA="${WEB_POBOCKY[$(( $(lab_vyber 3 1 701) - 1 ))]}"
WEB_JMENO="$WEB_POBOCKA.netlab.test"
WEB_ROOT="/var/www/$WEB_POBOCKA"

# Kód pobočky. Vzniká NÁHODNĚ při prvním stavění a leží jen na serveru —
# vzorec z čísla žáka by byl k ničemu, protože start.sh je ve veřejném
# repozitáři (poučení z bloku E). Do LXD se ukládá proto, aby ho kontrola
# mohla přečíst, aniž by ho musela hledat v souboru, který žák může
# přepsat.
WEB_KOD_KLIC="user.lab3f-kod"
WEB_VRSTVA_KLIC="user.lab318-vrstva"   # cvičení 18: která vrstva je rozbitá
WEB_PODKLADY=/srv/podklady/obsah.txt

postav_apache() {
  doinstaluj apache2:apache2 || return 1
  # Start je SNAHA, ne podmínka. Kdyby se návratový kód propsal ven,
  # `postav_apache || exit 1` by tiše ukončilo start.sh pokaždé, když
  # Apache nejde nastartovat — a to jsou dva běžné stavy: žák má rozbitou
  # konfiguraci, nebo je služba zamaskovaná (vrstva 3 cvičení 18).
  lxc exec "$SERVER_KONT" -- systemctl enable --now apache2 >/dev/null 2>&1
  return 0
}

# Vyrobí podklady s kódem pobočky, pokud ještě nejsou. Vrací kód přes
# proměnnou WEB_KOD.
WEB_KOD=""
zaridi_kod() {
  WEB_KOD="$(lxc config get "$SERVER_KONT" "$WEB_KOD_KLIC" 2>/dev/null | tr -d '\r')"
  if [ -z "$WEB_KOD" ]; then
    # Pět znaků za prefixem, čitelných — žák je opisuje ručně do stránky.
    WEB_KOD="NET-$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c5)"
    if ! lxc config set "$SERVER_KONT" "$WEB_KOD_KLIC" "$WEB_KOD" 2>/dev/null; then
      echo "  Kód pobočky se nepodařilo uložit — zavolejte vyučujícího." >&2
      return 1
    fi
  fi
  lxc exec "$SERVER_KONT" -- bash -c "
    mkdir -p /srv/podklady
    printf 'Pobocka: %s\nKod pobocky: %s\n' '$WEB_POBOCKA' '$WEB_KOD' > $WEB_PODKLADY
    chmod 644 $WEB_PODKLADY
  " >/dev/null 2>&1
  return 0
}

# Stáhne stránku ZE STANICE pod daným jménem. `--resolve` obejde DNS:
# řekne curlu, na kterou adresu to jméno přeložit. Je to standardní
# způsob, jak zkoušet virtual host bez zásahu do /etc/hosts.
stahni_web() {  # stahni_web JMENO PORT IP [další argumenty curl…]
  local jmeno="$1" port="$2" ip="$3"; shift 3
  local schema=http; [ "$port" = "443" ] && schema=https
  curl -s -m 8 --resolve "$jmeno:$port:$ip" "$@" "$schema://$jmeno/" 2>/dev/null
}

# Totéž, ale vrací jen stavový kód (000 = nedovolal se).
stav_webu() {  # stav_webu JMENO PORT IP [další argumenty curl…]
  local jmeno="$1" port="$2" ip="$3"; shift 3
  local schema=http; [ "$port" = "443" ] && schema=https
  curl -s -m 8 -o /dev/null -w '%{http_code}' \
    --resolve "$jmeno:$port:$ip" "$@" "$schema://$jmeno/" 2>/dev/null
}
