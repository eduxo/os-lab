#!/bin/bash
# 4/06 — úklid. Dnes se nic neodpojuje: projektový disk má od téhle hodiny
# zůstat připojený i po restartu, o to v cvičení šlo.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
echo
if projekt_pripojen; then
  echo "  Projekt je připojený v $PROJEKT_PRIPOJ a zůstane tam."
  echo "  Od příště ho připojuje /etc/fstab, ne start.sh."
else
  echo "  Pozor: projekt teď připojený NENÍ."
  echo "  Zkontrolujte si záznam ve /etc/fstab: findmnt --verify"
fi
echo
