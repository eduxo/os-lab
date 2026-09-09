#!/bin/bash
# 3/16 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="web-$ZAK2"
echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Server $KONT je společný pro cvičení 16, 17 a 18."
echo "  Smažete tím i certifikáty a vlastní certifikační autoritu,"
echo "  pokud jste je už dělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      # Formulář se maže spolu se serverem: kód pobočky i otisk certifikátu
      # vzniknou nové, takže staré odpovědi by přestaly platit a kontrola
      # by je vytkla bez vysvětlení.
      rm -f "$HOME/netlab/web/formular.txt"
      echo "  Smazáno — i formulář na stanici, protože hodnoty v něm už neplatí."
      exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo." ;;
esac
echo
