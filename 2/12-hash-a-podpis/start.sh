#!/bin/bash
# 2/12 — Hash a podpis. Prostředí: žákova stanice.
# Dvě „stažené" instalačky, z nichž jedna je cestou změněná, a dvě podepsané
# zprávy od dodavatele. Klíč dodavatele se vyrábí až tady na stanici —
# do repozitáře žádný soukromý klíč nepatří.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

POD="$HOME/netlab/podpisy"
DOD="$POD/dodavatel"
ODPOVEDI="$POD/odpovedi.txt"

if [ -f "$ODPOVEDI" ]; then
  echo
  echo "  Prostředí už existuje v $POD — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

command -v gpg >/dev/null || {
  echo "  Na stanici chybí gpg — řekněte o tom vyučujícímu."; exit 1; }

echo "  Stahuji instalačky a zprávy od dodavatele…"
mkdir -p "$DOD"

# Dvě „stažené" kopie téhož souboru. Jedna je poctivá, druhá cestou změněná —
# která, se odvozuje z čísla žáka.
DOBRA="$( [ "$(lab_vyber 2 1 121)" -eq 1 ] && echo a || echo b )"
ZKAZENA="$( [ "$DOBRA" = "a" ] && echo b || echo a )"

{ printf 'NetLab instalační balík\nverze 3.4\n'
  for i in $(seq 1 200); do printf 'data %05d %s\n' "$i" "$(printf '%04d' $(( (i * 7 + ZAK) % 9973 )))"; done
} > "$DOD/instalacka-$DOBRA.bin"

# Změněná kopie: jeden jediný bajt uprostřed. Na pohled se neliší.
sed "s/^data 00100 .*/data 00100 0000/" "$DOD/instalacka-$DOBRA.bin" > "$DOD/instalacka-$ZKAZENA.bin"

# Kontrolní součet, jak ho zveřejňuje dodavatel — pro jméno instalacka.bin.
OTISK="$(sha256sum "$DOD/instalacka-$DOBRA.bin" | cut -d' ' -f1)"
printf '%s  instalacka.bin\n' "$OTISK" > "$DOD/SHA256SUMS.txt"

# ── klíč dodavatele ────────────────────────────────────────────────
# Vyrábí se v dočasné klíčence, která se hned zahodí. Žák dostane jen veřejný
# klíč a podpisy; soukromý klíč nepřežije konec tohohle skriptu a v repozitáři
# nikdy nebyl.
printf 'Oznámení dodavatele\n\nVerze 3.4 je k dispozici. Kontrolní součet je v SHA256SUMS.txt.\n' \
  > "$DOD/oznameni.txt"
printf 'Oznámení dodavatele\n\nVerze 3.4 je k dispozici. Stáhněte si ji z odkazu v příloze.\n' \
  > "$DOD/oznameni-2.txt"

# Past na případ, že skript umře v půli — jinak by v /tmp zůstala klíčenka
# se soukromým klíčem dodavatele.
DOCASNA="$(mktemp -d)"
trap 'gpgconf --homedir "$DOCASNA" --kill gpg-agent >/dev/null 2>&1; rm -rf "$DOCASNA"' EXIT
GNUPGHOME="$DOCASNA" gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key "Dodavatel NetLab <dodavatel@netlab.test>" default default never \
  >/dev/null 2>&1
GNUPGHOME="$DOCASNA" gpg --armor --export dodavatel@netlab.test > "$DOD/dodavatel-verejny.asc" 2>/dev/null
GNUPGHOME="$DOCASNA" gpg --batch --pinentry-mode loopback --passphrase '' \
  --armor --detach-sign -o "$DOD/oznameni.txt.asc" "$DOD/oznameni.txt" >/dev/null 2>&1
GNUPGHOME="$DOCASNA" gpg --batch --pinentry-mode loopback --passphrase '' \
  --armor --detach-sign -o "$DOD/oznameni-2.txt.asc" "$DOD/oznameni-2.txt" >/dev/null 2>&1
# Agent, který se pro dočasnou klíčenku spustil, musí skončit taky —
# jinak drží socket a běží dál, i když klíčenka z disku zmizí.
gpgconf --homedir "$DOCASNA" --kill gpg-agent >/dev/null 2>&1
rm -rf "$DOCASNA"
trap - EXIT

# Druhou zprávu po podepsání změníme — podpis tím přestane sedět.
printf 'Oznámení dodavatele\n\nVerze 3.4 je k dispozici. Stáhněte si ji z http://netlab-update.test/3.4\n' \
  > "$DOD/oznameni-2.txt"

if [ ! -s "$DOD/dodavatel-verejny.asc" ]; then
  echo "  Podpisy se nepodařilo vyrobit — řekněte o tom vyučujícímu."; exit 1
fi

printf 'Hlášení o kontrole instalačky.\nProvedl: novak%s\n' "$ZAK2" > "$POD/moje-hlaseni.txt"

cat > "$ODPOVEDI" <<'FORMULAR'
# Odpovědi — vyplňte hodnoty za dvojtečku.
# otisk-a, otisk-b = otisky obou stažených instalaček (celé, 64 znaků)
# dobra            = písmeno instalačky, která sedí s kontrolním součtem (a nebo b)
# podpis-2         = platny nebo neplatny — u zprávy oznameni-2.txt
otisk-a:
otisk-b:
dobra:
podpis-2:
FORMULAR

echo
echo "  Prostředí je připravené."
echo
echo "    Stažené instalačky:  $DOD"
echo "    Formulář:            $ODPOVEDI"
echo

# Cvičení navazuje na klíč z cvičení 2/02. Tam byl mimo Minimum, takže ho
# část třídy mít nebude — poradíme, ne spadneme.
if gpg --list-secret-keys "novak$ZAK2@netlab.test" >/dev/null 2>&1; then
  echo "    Váš klíč GPG: nalezen (novak$ZAK2@netlab.test)"
else
  echo "    POZOR: nemáte vlastní klíč GPG z cvičení Bezpečnostní hygiena."
  echo "    Vyrobte si ho, dnes ho budete potřebovat:"
  echo
  echo "      gpg --quick-generate-key \"Novak $ZAK2 <novak$ZAK2@netlab.test>\" default default 2y"
fi
echo
echo "  Průběžnou kontrolu spouštějte odsud:"
echo
echo "    cd ~/os-lab/2/12-hash-a-podpis && ./check.sh --krok 1"
echo
