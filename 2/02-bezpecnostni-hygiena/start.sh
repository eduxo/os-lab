#!/bin/bash
# 2/02 — Bezpečnostní hygiena. Prostředí: žákova stanice (bez kontejneru).
# Připraví tři služební e-maily k rozboru, formulář odpovědí a klíč pro MFA.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"

HYG="$HOME/dokumentace/hygiena"
POSTA="$HYG/posta"
ODPOVEDI="$HYG/verdikty.txt"

if [ -f "$ODPOVEDI" ]; then
  echo
  echo "  Prostředí už existuje v $HYG — pokračujte, kde jste skončili."
  echo "  Chcete začít znovu?  ./reset.sh"
  echo
  exit 0
fi

# ── fond pošty ────────────────────────────────────────────────────
# Tři zprávy podvodné, tři poctivé. Každý žák dostane jinou trojici
# a v jiném pořadí, takže verdikty od souseda nesedí.

posta_P1() { cat <<'ZPRAVA'
Od: IT podpora NetLab <it-podpora@net1ab.test>
Komu: PRIJEMCE
Datum: pondělí 8. září 2026, 7:42
Předmět: Vaše schránka bude do 24 hodin zrušena

Vazeny uzivateli,

kapacita Vasi postovni schranky byla prekrocena. Pokud do 24 hodin
neprovedete overeni uctu, bude schranka trvale zrusena a veskera
posta smazana.

Overeni provedete zde:  http://net1ab.test/obnova-uctu

Dekujeme za pochopeni.
Oddeleni IT
ZPRAVA
}

posta_P2() { cat <<'ZPRAVA'
Od: Fakturace <fakturace@netlab-platby.test>
Komu: PRIJEMCE
Datum: úterý 9. září 2026, 11:05
Předmět: Neuhrazená faktura 2026/0473 — poslední upozornění

Dobry den,

evidujeme u Vas neuhrazenou fakturu po splatnosti. Podrobnosti
najdete v priloze. Pokud castku neuhradite do konce tydne, predame
pohledavku k vymahani.

Priloha: faktura_2026_0473.pdf.exe

S pozdravem
Ucetni oddeleni
ZPRAVA
}

posta_P3() { cat <<'ZPRAVA'
Od: Jiří Havel <reditel@netlab.secure-login.test>
Komu: PRIJEMCE
Datum: středa 10. září 2026, 15:58
Předmět: Rychlá prosba

Dobrý den,

jsem celé odpoledne na jednání a nemůžu telefonovat. Potřebuji, abyste
pro klienta obstaral šest dárkových karet po 5 000 Kč a poslal mi kódy
z rubu. Peníze Vám vyúčtujeme zítra.

Prosím vyřiďte to ještě dnes a nikomu to zatím neříkejte, chceme
klienta překvapit.

Děkuji
Jiří Havel, ředitel
ZPRAVA
}

posta_L1() { cat <<'ZPRAVA'
Od: Helpdesk NetLab <helpdesk@netlab.test>
Komu: PRIJEMCE
Datum: pondělí 8. září 2026, 9:15
Předmět: Odstávka tiskového serveru ve čtvrtek 11. 9.

Dobrý den,

ve čtvrtek 11. září od 16:00 do zhruba 18:00 proběhne plánovaná
odstávka tiskového serveru. Po tuto dobu nebude fungovat tisk
z kanceláří ve druhém patře.

Nic nemusíte dělat, po skončení odstávky se tiskárny připojí samy.
Kdyby po pátku ráno tisk nešel, zavolejte nám na linku 231.

Petr Sedlák, helpdesk
ZPRAVA
}

posta_L2() { cat <<'ZPRAVA'
Od: Personální oddělení <personalni@netlab.test>
Komu: PRIJEMCE
Datum: úterý 9. září 2026, 8:30
Předmět: Termíny školení BOZP pro nové zaměstnance

Dobrý den,

jako nový zaměstnanec absolvujete během prvního měsíce školení
bezpečnosti práce. Nabízíme dva termíny:

  - pondělí 15. 9. od 8:00, zasedačka A
  - středa 17. 9. od 13:00, zasedačka A

Termín si vyberte na intranetu v sekci Vzdělávání. Přihlašovat se
nikam nemusíte, intranet Vás zná.

Hana Dvořáková, personální oddělení
ZPRAVA
}

posta_L3() { cat <<'ZPRAVA'
Od: Sklad <sklad@netlab.test>
Komu: PRIJEMCE
Datum: čtvrtek 11. září 2026, 13:20
Předmět: Inventura 30. 9. — sklad bude zavřený

Dobrý den,

v úterý 30. září probíhá inventura a sklad bude celý den zavřený.
Kdo potřebuje něco vyzvednout, ať si to zařídí do pondělí.

Výdej se rozjede zase ve středu ráno.

Marek Toman, vedoucí skladu
ZPRAVA
}

echo "  Připravuji služební poštu a formulář odpovědí…"
mkdir -p "$POSTA"

# Lichá čísla dostanou jednu podvodnou zprávu, sudá dvě. Bez toho by
# platilo „když nevíš, napiš phishing" a rozbor by ztratil smysl.
if [ $((ZAK % 2)) -eq 0 ]; then POCET_P=2; else POCET_P=1; fi
POCET_L=$((3 - POCET_P))

VYBER=()
for i in $(lab_vyber 3 "$POCET_P" 0);  do VYBER+=("P$i"); done
for i in $(lab_vyber 3 "$POCET_L" 7);  do VYBER+=("L$i"); done

# Pořadí zpráv ve schránce — aby podvodná nebyla vždycky první.
PORADI=($(lab_vyber 3 3 13))

# Správné verdikty se nikam neukládají a check.sh je nehodnotí — posoudit
# zprávu je úsudek, ne stav systému. Skript by správnou odpověď musel mít
# u sebe, a protože je repozitář veřejný, dal by se z něj vyčíst. Kontrola
# proto hlídá jen tvar odpovědi; správnost bere vyučující při obhajobě.
for POZICE in 1 2 3; do
  IDX=${PORADI[$((POZICE-1))]}
  ZDROJ=${VYBER[$((IDX-1))]}
  "posta_$ZDROJ" | sed "s/PRIJEMCE/novak$ZAK2@netlab.test/" > "$POSTA/$POZICE.txt"
done

# Klíč pro jednorázové kódy (TOTP). Base32 odvozená z čísla žáka —
# každý má vlastní, takže se kódy mezi žáky neshodují.
TAJEMSTVI="$(printf 'mfa-%s' "$ZAK" | _hash | cut -c1-16 | tr '0-9a-f' 'ABCDEFGHIJKLMNOP')"
cat > "$HYG/mfa-klic.txt" <<MFA
Klíč pro jednorázové kódy (TOTP) k účtu novak$ZAK2@netlab.test:

  $TAJEMSTVI

Nastavení v KeePassXC: 6 číslic, interval 30 sekund, algoritmus SHA-1.
MFA

cat > "$ODPOVEDI" <<'FORMULAR'
# Odpovědi ke cvičení Bezpečnostní hygiena.
# Vyplňte hodnoty za dvojtečku, řádky s mřížkou nechte být.
#
# U pošty pište u podvodné zprávy slovo phishing a za mezerou doménu
# odesílatele (to, co je v adrese za zavináčem). U poctivé zprávy jen ok.
# Příklady schválně s N místo čísla — kdyby tu stálo posta-1, dal by se
# vyplnit rovnou komentář a skutečný řádek by zůstal prázdný.
#   posta-N: phishing nejaka.domena.test
#   posta-N: ok
zaznamu:
mfa-kod:
mfa-cas:
posta-1:
posta-2:
posta-3:
FORMULAR

cat <<EOF

  Prostředí je připravené.

    Služební pošta:       $POSTA/1.txt  2.txt  3.txt
    Formulář odpovědí:    $ODPOVEDI
    Klíč pro MFA:         $HYG/mfa-klic.txt
    Databázi hesel založíte jako:
                          $HYG/hesla-$ZAK2.kdbx

  Průběžnou kontrolu spouštějte odsud:

    cd ~/os-lab/2/02-bezpecnostni-hygiena && ./check.sh --krok 1

EOF
