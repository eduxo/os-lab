#!/bin/bash
# 3/04 — ověření. Části odpovídají krokům zadání 1:1.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

KONT="server-$ZAK2"
UCET="sysadmin"
PRENOS="$HOME/netlab/prenos"
ODCHOZI="$PRENOS/odchozi"
STAZENE="$PRENOS/stazene"
FORMULAR="$PRENOS/formular.txt"
POCET=$(( 3 + $(lab_vyber 4 1 340) ))
HLAVNI="protokol-$(printf '%02d' "$(lab_vyber "$POCET" 1 341)").txt"
ZAZNAM="zaznam-$ZAK2.txt"

if ! command -v lxc >/dev/null 2>&1; then
  echo; echo "  Na stanici není LXD. Řekněte o tom vyučujícímu."; echo; exit 1
fi
STAV="$(lxc list "^${KONT}$" -c s --format csv 2>/dev/null)"
if [ -z "$STAV" ]; then
  echo; echo "  Server $KONT neexistuje. Spusťte ./start.sh"; echo; exit 1
elif [ "$STAV" != "RUNNING" ]; then
  echo; echo "  Server $KONT je zastavený — vaše práce na něm zůstala."
  echo "  Nastartujte ho:  ./start.sh"; echo; exit 1
fi
IP="$(lxc list "^${KONT}$" -c4 --format csv 2>/dev/null | cut -d' ' -f1)"

# Obsah souboru na serveru — čte se přes lxc, ne přes ssh, aby kontrola
# nezávisela na tom, jestli žák klíč nasadil správně.
na_serveru() { lxc exec "$KONT" -- cat "$1" 2>/dev/null; }

krok 1 "Klíč"
KLIC_PUB="$(ls "$HOME"/.ssh/id_*.pub 2>/dev/null | head -1)"
if [ -z "$KLIC_PUB" ]; then
  chyba "na stanici není žádný veřejný klíč"
  poznamka "vyrobí se příkazem ssh-keygen; privátní klíč zůstává na stanici"
else
  uspech "na stanici je pár klíčů ($(basename "$KLIC_PUB"))"
  # Porovnává se samotný klíč, ne celý řádek — ten má na konci komentář,
  # který se při kopírování běžně mění.
  CAST="$(awk '{print $2}' "$KLIC_PUB")"
  if [ -n "$CAST" ] && na_serveru "/home/$UCET/.ssh/authorized_keys" | grep -qF "$CAST"; then
    uspech "váš veřejný klíč je na serveru v authorized_keys"
  else
    chyba "váš veřejný klíč na serveru není"
    poznamka "nasazuje se ze stanice, privátní klíč se nikam nekopíruje"
  fi
fi
# Přihlášení bez hesla. BatchMode vypne dotaz na heslo, takže když klíč
# nefunguje, příkaz selže místo toho, aby se ptal.
# UserKnownHostsFile=/dev/null je tu schválně: bez něj by kontrola sama
# zapsala klíč serveru do known_hosts na stanici — a tím by prošla kotva
# cvičení 3 i žákovi, který se nikdy nepřipojil.
if [ -n "$IP" ] && ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
     -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
     "$UCET@$IP" true >/dev/null 2>&1; then
  uspech "přihlášení bez hesla funguje"
else
  chyba "přihlásit se bez hesla zatím nejde"
  poznamka "zkontrolujte práva: ~/.ssh musí být 700 a authorized_keys 600"
fi

krok 2 "Nahrání přes scp"
if [ ! -f "$ODCHOZI/$HLAVNI" ]; then
  chyba "na stanici chybí soubor k odeslání — spusťte ./start.sh"
elif na_serveru "/home/$UCET/prijate/$HLAVNI" | cmp -s - "$ODCHOZI/$HLAVNI"; then
  uspech "soubor je na serveru v ~/prijate a je bajtově shodný"
else
  chyba "v ~/prijate na serveru není shodná kopie souboru"
  poznamka "cíl se u scp píše za dvojtečku: ucet@adresa:~/prijate/"
fi

krok 3 "Stažení a rsync"
if na_serveru "/home/$UCET/dokumenty/$ZAZNAM" | cmp -s - "$STAZENE/$ZAZNAM" 2>/dev/null; then
  uspech "servisní záznam je stažený na stanici a je bajtově shodný"
else
  chyba "stažený servisní záznam na stanici nesedí"
  poznamka "stahuje se do ~/netlab/prenos/stazene/"
fi
# rsync: na serveru musí být všechno z odchozi, obsahem i počtem
CHYBI=""; POROVNANO=0
if [ -d "$ODCHOZI" ]; then
  for f in "$ODCHOZI"/*; do
    [ -f "$f" ] || continue
    POROVNANO=$((POROVNANO + 1))
    na_serveru "/home/$UCET/zaloha/$(basename "$f")" | cmp -s - "$f" || CHYBI="$CHYBI $(basename "$f")"
  done
fi
# Bez počtu porovnaných by prázdný adresář prošel jako splněný — prázdná
# množina totiž vyhoví každé podmínce.
if [ "$POROVNANO" -eq 0 ]; then
  chyba "na stanici nejsou žádné protokoly k porovnání — spusťte ./start.sh"
elif [ -z "$CHYBI" ]; then
  uspech "v ~/zaloha na serveru je celý obsah adresáře odchozi"
else
  chyba "v ~/zaloha na serveru chybí nebo nesedí:$CHYBI"
  poznamka "rsync se chová jinak s lomítkem na konci zdroje a bez něj"
fi

krok 4 "Formulář"
if [ -n "$KLIC_PUB" ]; then
  OTISK="$(ssh-keygen -lf "$KLIC_PUB" 2>/dev/null | awk '{print $2}')"
  if [ -n "$OTISK" ]; then
    require_zaznam "$FORMULAR" otisk-klice "$OTISK" \
      "ve formuláři je otisk vašeho veřejného klíče"
  else
    chyba "otisk vašeho klíče se nepodařilo spočítat"
  fi
else
  chyba "bez klíče na stanici nejde ověřit jeho otisk"
fi
if [ -f "$ODCHOZI/$HLAVNI" ]; then
  require_zaznam "$FORMULAR" velikost "$(wc -c < "$ODCHOZI/$HLAVNI" | tr -d ' ')" \
    "ve formuláři je velikost odeslaného souboru v bajtech"
fi
require_zaznam "$FORMULAR" podruhe 0 \
  "ve formuláři je, kolik souborů přenesl rsync podruhé"

vypis_souhrn
