#!/bin/bash
# 3/01 — návrat do výchozího stavu: smaže konfiguraci, kterou žák vyrobil
set -uo pipefail
SIT="$HOME/netlab/sit"
echo
echo "  Tím smažete konfiguraci /etc/netplan/90-lab.yaml, kterou jste vyrobili,"
echo "  a vrátíte síť do stavu před cvičením."
echo "  Vyplněný formulář ZŮSTANE — přijdete jen o síťovou konfiguraci."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo; exit 0 ;;
esac
sudo rm -f /etc/netplan/90-lab.yaml
# `netplan apply` po smazání souboru vrátí adaptér tam, kde byl.
sudo netplan apply 2>/dev/null || echo "  netplan apply neproběhl — zkontrolujte síť ručně."
# Formulář se NEMAŽE. Reset se spouští typicky ve chvíli, kdy se žák odřízl
# od sítě — přijít při tom o vyplněné odpovědi by byl trest za správný postup.
# Poznámku o výchozím stavu ani formulář nemažeme — nejsou to výsledky
# žákovy práce a bez poznámky by kontrola poslala zpátky na reset.
echo "  Hotovo. Formulář i poznámka o výchozím stavu zůstaly, síť je zpátky."
exec "$(dirname "$0")/start.sh"
