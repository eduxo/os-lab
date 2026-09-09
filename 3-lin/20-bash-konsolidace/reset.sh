#!/bin/bash
# 3/20 — návrat do výchozího stavu (smaže server i vaši práci na něm)
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
KONT="data-$ZAK2"
echo
if ! command -v lxc >/dev/null 2>&1; then
  echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
echo "  Server $KONT je společný pro cvičení 19 a 20."
echo "  Smažete tím i sdílení ze cvičení 19, pokud jste ho už dělali."
read -r -p "  Opravdu začít znovu? [a/N] " o
case "$o" in
  [aAyY])
    if lxc delete -f "$KONT" >/dev/null 2>&1; then
      # Formulář se maže spolu se serverem: kód i jméno souboru vzniknou
      # nové, takže staré odpovědi by přestaly platit.
      # Server je společný: se smazáním zaniknou i podklady devatenáctky,
      # takže její formulář na stanici přestane platit.
      rm -f "$HOME/netlab/sdileni/formular.txt"
      echo "  Smazáno. Skript se postaví znovu i s vadami."
      echo "  Smazán i formulář ze cvičení 19 — hodnoty v něm už neplatí."
      exec "$(dirname "$0")/start.sh"
    else
      echo "  Server se nepodařilo smazat — zavolejte vyučujícího."; echo; exit 1
    fi ;;
  *) echo "  Zrušeno, nic se nezměnilo."; echo ;;
esac
