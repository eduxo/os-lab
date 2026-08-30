#!/bin/bash
# 2/13 — úklid. Na rozdíl od ostatních cvičení tady stop.sh systém OPRAVUJE:
# nikdo nesmí odejít od stanice s rozbitou správou balíčků.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/poruchy.sh"

INST="$HOME/netlab/instalace"

if [ ! -f "$LAB_ZALOHY/zavedeno" ]; then
  echo; echo "  Žádné závady zavedené nejsou — není co uklízet."; echo; exit 0
fi

cat <<'EOF'

  Tímhle se závady odstraní a správa balíčků se vrátí do pořádku.

  Používejte to na konci hodiny, nebo když se z toho nemůžete dostat.
  POZOR: ve výpisu kontroly pak bude poznámka, že jste ho použili.

EOF
read -r -p "  Uklidit? [a/N] " o
case "$o" in
  [aA]|[aA][nN][oO]|[yY]|[yY][eE][sS]) ;;
  *) echo "  Zrušeno, stanice zůstává v současném stavu."; echo; exit 0 ;;
esac

sudo bash "$(dirname "$0")/uklid.sh" "$LAB_ETC_APT" "$LAB_HOSTS" "$LAB_ZALOHY" || {
  echo "  Úklid selhal — řekněte o tom vyučujícímu."; exit 1; }
echo
echo "  Hotovo. Správa balíčků je zpátky v pořádku."
echo "  Zkontrolujte si to:  sudo apt update"
echo
