#!/bin/bash
# 2/15 — návrat do výchozího stavu: smaže účty, které cvičení zadává
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
UCTY="$HOME/netlab/ucty"
JMENA=(jnovak jhrabal pkusek smala tsimakova apolaskova pmezek dhlavata)
ODDELENI=(sklad ucetni vedeni)
VYBER=($(lab_vyber 8 3 151))

echo
echo "  Tím smažete účty, které jste v tomhle cvičení zakládali,"
echo "  včetně jejich domovských adresářů, a začnete znovu."
echo "  Účty, které v zadání nejsou, ani skupiny oddělení se to nedotkne."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo; exit 0 ;;
esac

for N in "${VYBER[@]}"; do
  U="${JMENA[$((N-1))]}"
  id "$U" >/dev/null 2>&1 && sudo userdel -r "$U" 2>/dev/null
done
# Skupiny se NEMAŽOU. Stojí na nich cvičení o oprávněních, o rozšířených
# oprávněních i diagnostické — smazat je tady by znamenalo, že si žák
# resetem jednoho cvičení rozbije tři další.
echo "  Skupiny oddělení zůstávají — navazují na ně další cvičení."
rm -rf "${UCTY:?}"
echo "  Smazáno."
exec "$(dirname "$0")/start.sh"
