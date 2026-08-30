#!/bin/bash
# 2/13 — vrácení systému do původního stavu. Běží pod správcem, volá ho
# stop.sh i reset.sh. Samostatně ho žák spouštět nemá.
#
# Cesty se dají předat argumenty, aby se úklid dal vyzkoušet jinde než na
# ostrém /etc. Pod sudo se proměnné prostředí neprotáhnou, proto argumenty.
set -uo pipefail
LAB_ETC_APT="${1:-/etc/apt}"
LAB_HOSTS="${2:-/etc/hosts}"
LAB_ZALOHY="${3:-/var/backups/netlab-lab13}"

rm -f "$LAB_ETC_APT/sources.list.d/netlab-"*.sources
rm -f "$LAB_ETC_APT/apt.conf.d/99-netlab-"*
rm -f "$LAB_ETC_APT/preferences.d/99-netlab-"*
[ -f "$LAB_ZALOHY/ubuntu.sources" ] && cp -a "$LAB_ZALOHY/ubuntu.sources" "$LAB_ETC_APT/sources.list.d/ubuntu.sources"
[ -f "$LAB_ZALOHY/hosts" ] && cp -a "$LAB_ZALOHY/hosts" "$LAB_HOSTS"
# Starý formát zdrojů: řádek doplněný závadou D1 se odstraní, zbytek zůstane.
[ -f "$LAB_ETC_APT/sources.list" ] && sed -i '/noble-netlab/d' "$LAB_ETC_APT/sources.list"
# Podržené balíčky vrátit do stavu, v jakém byly před cvičením.
if [ -f "$LAB_ZALOHY/hold" ] && command -v apt-mark >/dev/null 2>&1; then
  for b in $(apt-mark showhold 2>/dev/null); do
    grep -qx "$b" "$LAB_ZALOHY/hold" || apt-mark unhold "$b" >/dev/null 2>&1
  done
fi
# Značka pro check.sh: závady odstranil skript, ne žák. Leží u zálohy, tedy
# pod rootem — smazat ji jde jen vědomým sudo, ne omylem.
rm -f "$LAB_ZALOHY/zavedeno"
date +%Y-%m-%dT%H:%M > "$LAB_ZALOHY/uklizeno"
exit 0
