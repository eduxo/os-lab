#!/bin/bash
# 3/07 — ověření (běží na stanici, kontroluje kontejner)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

LAB_KONTEJNER="sluzby-$ZAK2"

if ! lxc info "$LAB_KONTEJNER" >/dev/null 2>&1; then
  echo; echo "  Server $LAB_KONTEJNER neběží. Spusťte nejdřív ./start.sh"; echo; exit 1
fi

krok 1 "Unit soubor"
require_path "/etc/systemd/system/hlidac.service" "unit hlidac.service existuje"
require_unit_valid "hlidac.service"

krok 2 "Služba běží a nastartuje po restartu"
require_service_active  "hlidac"
require_service_enabled "hlidac"

krok 3 "Běží správně"
require_service_user "hlidac" "hlidac$ZAK2"
require_port_listening "$ZAK_PORT"
require_soubor_obsahuje "/var/log/hlidac/hlidac.log" "hlidac bezi" "služba zapisuje do logu"

# obchvaty, ne dovednosti
negative_service_not_root "hlidac"

vypis_souhrn
