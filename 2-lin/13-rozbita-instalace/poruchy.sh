#!/bin/bash
# 2/13 — katalog závad. Sdílí ho start.sh (zavádí) i check.sh (ověřuje opravu).
#
# Proč to není zakódované: plán počítal se souborem `poruchy.dat` a čitelným
# zdrojem v .gitignore. Kód, který závadu zavádí, ale ve start.sh být musí —
# takže by šifra chránila popisky, ne podstatu. Audit bloku A ukázal totéž
# u phishingu: otisky ve veřejném repozitáři neochrání nic. Odolnost tohohle
# cvičení stojí jinde — závada je v žákově běžícím systému a najít ji musí
# tam, ne v repozitáři. Kdo si katalog přečte, ušetří si hledání; kdo ne,
# naučí se to, o co jde.
#
# Každá závada má tři funkce:
#   zaved_XX    — zavede ji (běží pod sudo ze start.sh)
#   opraveno_XX — vrátí 0, když je opravená
#   popis_XX    — jednou větou, co byla; tiskne se až po opravě

# Cesty jsou přepsatelné z prostředí. Není to bezpečnostní hranice, ale šev
# pro testování — jinak by se katalog závad nedal vyzkoušet jinde než na
# stanici, kterou tím rozbijeme.
LAB_ETC_APT="${LAB_ETC_APT:-/etc/apt}"
LAB_ZALOHY="${LAB_ZALOHY:-/var/backups/netlab-lab13}"
LAB_HOSTS="${LAB_HOSTS:-/etc/hosts}"

# ══ A — zdroje balíčků ════════════════════════════════════════════
zaved_A1() { printf 'Types: deb\nURIs: http://archve.ubuntu.com/ubuntu/\nSuites: noble\nComponents: main\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' > "$LAB_ETC_APT/sources.list.d/netlab-archiv.sources"; }
opraveno_A1() { ! grep -rqs 'archve\.ubuntu\.com' "$LAB_ETC_APT/sources.list.d/"; }
popis_A1() { echo "zdroj balíčků měl překlep v adrese serveru (archve místo archive)"; }

zaved_A2() { printf 'Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/\nSuites: nobble\nComponents: main\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' > "$LAB_ETC_APT/sources.list.d/netlab-vydani.sources"; }
opraveno_A2() { ! grep -rqs 'nobble' "$LAB_ETC_APT/sources.list.d/"; }
popis_A2() { echo "zdroj balíčků odkazoval na neexistující vydání systému (nobble)"; }

zaved_A3() { printf 'Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/\nSuites: noble\nComponents: main\nSigned-By: /etc/apt/keyrings/netlab-neexistuje.gpg\n' > "$LAB_ETC_APT/sources.list.d/netlab-klic.sources"; }
opraveno_A3() { ! grep -rqs 'netlab-neexistuje\.gpg' "$LAB_ETC_APT/sources.list.d/"; }
popis_A3() { echo "zdroj balíčků odkazoval na klíč, který v systému není"; }

# ══ B — nastavení apt ═════════════════════════════════════════════
zaved_B1() { printf 'APT::Get::Assume-Yes "true"\n' > "$LAB_ETC_APT/apt.conf.d/99-netlab-syntaxe"; }
# Kotví se na konec direktivního řádku. Se samotným `grep -q ';'` by stačil
# středník kdekoli — třeba v komentáři — a syntaxe by zůstala rozbitá.
opraveno_B1() { [ ! -f "$LAB_ETC_APT/apt.conf.d/99-netlab-syntaxe" ] || grep -qE '";[[:space:]]*$' "$LAB_ETC_APT/apt.conf.d/99-netlab-syntaxe"; }
popis_B1() { echo "v nastavení apt chyběl středník na konci řádku"; }

zaved_B2() { printf 'Dir::Cache::archives "/var/cache/apt/netlab-neexistuje/";\n' > "$LAB_ETC_APT/apt.conf.d/99-netlab-cache"; }
opraveno_B2() { [ ! -f "$LAB_ETC_APT/apt.conf.d/99-netlab-cache" ]; }
popis_B2() { echo "apt měl nastavenou mezipaměť do adresáře, který neexistuje"; }

zaved_B3() { printf 'Acquire::http::Proxy "http://127.0.0.1:9";\n' > "$LAB_ETC_APT/apt.conf.d/99-netlab-proxy"; }
opraveno_B3() { [ ! -f "$LAB_ETC_APT/apt.conf.d/99-netlab-proxy" ]; }
popis_B3() { echo "apt měl nastavenou proxy na adresu, kde nic neposlouchá"; }

# ══ C — priority a zámky balíčků ══════════════════════════════════
zaved_C1() { printf 'Package: %s\nPin: release *\nPin-Priority: -1\n' "$1" > "$LAB_ETC_APT/preferences.d/99-netlab-blok"; }
opraveno_C1() { [ ! -f "$LAB_ETC_APT/preferences.d/99-netlab-blok" ]; }
popis_C1() { echo "balíček měl v prioritách nastavené záporné číslo, takže ho apt odmítal"; }

zaved_C2() { apt-mark hold "$1" >/dev/null 2>&1; }
opraveno_C2() { ! apt-mark showhold 2>/dev/null | grep -qx "$1"; }
popis_C2() { echo "balíček byl podržený příkazem apt-mark hold"; }

zaved_C3() { printf 'Package: %s\nPin: version 0.0.1-neexistuje\nPin-Priority: 1001\n' "$1" > "$LAB_ETC_APT/preferences.d/99-netlab-verze"; }
opraveno_C3() { [ ! -f "$LAB_ETC_APT/preferences.d/99-netlab-verze" ]; }
popis_C3() { echo "priority vynucovaly u balíčku verzi, která neexistuje"; }

# ══ D — systém okolo ══════════════════════════════════════════════
# Původně tu bylo `chmod 000` na hlavní soubor zdrojů. Nefungovalo to:
# apt běží pod sudo, tedy jako root, a root práva souborů obchází — závada
# by se nijak neprojevila a žák by ji neměl podle čeho najít. Navíc by ji
# opravoval příkazem chmod, který se učí až ve cvičení 2/16.
# Nová varianta míří na starý formát zdrojů: apt čte i /etc/apt/sources.list,
# ale žák ho po cvičení 2/11 hledá jinde.
zaved_D1() { printf '# doplněno podle návodu z internetu\ndeb http://archive.ubuntu.com/ubuntu noble-netlab main\n' >> "$LAB_ETC_APT/sources.list"; }
opraveno_D1() { ! grep -qs 'noble-netlab' "$LAB_ETC_APT/sources.list"; }
popis_D1() { echo "ve starém souboru /etc/apt/sources.list byl zdroj s neexistujícím vydáním"; }

zaved_D2() { : > "$LAB_ETC_APT/sources.list.d/ubuntu.sources"; }
opraveno_D2() { [ -s "$LAB_ETC_APT/sources.list.d/ubuntu.sources" ]; }
popis_D2() { echo "hlavní soubor se zdroji byl prázdný"; }

zaved_D3() { printf '127.0.0.1 archive.ubuntu.com cz.archive.ubuntu.com # netlab-lab13\n' >> "$LAB_HOSTS"; }
opraveno_D3() { ! grep -qs 'netlab-lab13' "$LAB_HOSTS"; }
popis_D3() { echo "v /etc/hosts byl záznam, který posílal archiv Ubuntu na místní adresu"; }

# ── výběr tří závad, každá z jiné kategorie ───────────────────────
# Kategorie se vybírají tři ze čtyř, v každé pak jedna ze tří variant.
# Bez pravidla „každá z jiné kategorie" by se závady maskovaly: chyba
# v syntaxi nastavení přebije všechno a žák se k ostatním nedostane.
lab13_vyber() {
  local kategorie=(A B C D) k v
  for k in $(lab_vyber 4 3 131); do
    v=$(lab_vyber 3 1 $(( 140 + k )))
    printf '%s%s\n' "${kategorie[$((k-1))]}" "$v"
  done
}
