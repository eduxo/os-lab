#!/bin/bash
# 4/00 — úklid. Rozcvička běží na stanici, není co vypínat.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"
echo
echo "  Rozcvička běžela na vaší stanici, nic se nevypíná."
echo "  Odpovědi zůstávají v ~/netlab/rozcvicka4/odpovedi.txt."
if projekt_pripojen; then
  echo "  Ročníkový projekt zůstává připojený v $PROJEKT_PRIPOJ."
fi
echo
