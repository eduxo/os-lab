#!/bin/bash
# lab-lib.sh — sdílené funkce ověřovacích skriptů.
#
# Používá se v check.sh každého cvičení:
#     source "$(dirname "$0")/../../lib/lab-lib.sh"
#     require_user "$ZAK_UZIVATEL"
#     vypis_souhrn
#
# Cíl kontroly: implicitně žákova stanice. Když cvičení běží v kontejneru,
# nastaví se před prvním require:
#     LAB_KONTEJNER="sluzby-$ZAK2"

# ────────────────────────────────────────────────────────── nastavení
LAB_KONTEJNER="${LAB_KONTEJNER:-}"     # prázdné = kontrolujeme tuto stanici
LAB_UZIVATEL="${LAB_UZIVATEL:-sysadmin}"   # pod kým žák v kontejneru pracuje
_pass=0; _fail=0; _krok_filtr=""; _aktualni_krok=0

# barvy jen když píšeme do terminálu (v rouře by překážely)
if [ -t 1 ]; then
  _Z='\033[0;32m'; _C='\033[0;31m'; _M='\033[0;33m'; _0='\033[0m'; _B='\033[1m'
else
  _Z=''; _C=''; _M=''; _0=''; _B=''
fi

# ────────────────────────────────────────────────── parametry příkazu
_ceka_cislo=0
for _a in "$@"; do
  # Hodnota za `--krok` přijde až v další iteraci, proto ta příznaková
  # proměnná. Bez ní by `--krok abc` tiše proběhlo jako kontrola celého
  # cvičení a žák by si myslel, že ověřil jen svoji část.
  if [ "$_ceka_cislo" -eq 1 ]; then _krok_filtr="$_a"; _ceka_cislo=0; continue; fi
  case "$_a" in
    --krok) _ceka_cislo=1 ;;
    --krok=*) _krok_filtr="${_a#*=}" ;;
    [0-9]*) [ -z "$_krok_filtr" ] && _krok_filtr="$_a" ;;
    --help|-h)
      echo "Použití: ./check.sh [--krok N]"
      echo "  bez parametru  — ověří celé cvičení"
      echo "  --krok N       — ověří jen část N (průběžná kontrola)"
      exit 0 ;;
    *) printf "  Neznámý parametr: %s. Použijte ./check.sh --help\n" "$_a"; exit 1 ;;
  esac
done
if [ "$_ceka_cislo" -eq 1 ]; then
  printf "  Za --krok chybí číslo části. Třeba: ./check.sh --krok 2\n"; exit 1
fi
# "02" a "2" musí označovat tentýž krok; nesmysl musí spadnout hlasitě
if [ -n "$_krok_filtr" ]; then
  case "$_krok_filtr" in
    ''|*[!0-9]*) printf "  Neznámá část: %s. Použijte třeba --krok 2\n" "$_krok_filtr"; exit 1 ;;
    *) _krok_filtr=$((10#$_krok_filtr)) ;;
  esac
fi

# ─────────────────────────────────────────────────────── číslo žáka
# Ptáme se jednou a pamatujeme si. Žák o té hodnotě ví a umí ji opravit,
# když dostane stanici po někom jiném.
_souborZak="$HOME/.os-lab-zak"
zjisti_zaka() {
  if [ -f "$_souborZak" ]; then
    ZAK="$(tr -dc '0-9' < "$_souborZak")"
    # 10# vynutí desítkovou soustavu — bez toho bash čte "08" jako osmičkovou
    # konstantu a skript spadne. Zadání používá dvouciferné XX, takže "08" přijde.
    ZAK=$((10#${ZAK:-0}))
    if [ "$ZAK" -lt 1 ] || [ "$ZAK" -gt 40 ]; then
      printf "  ${_C}V %s je neplatné číslo.${_0} Smažte ho a spusťte skript znovu.\n" "$_souborZak"
      exit 1
    fi
  fi
  # Když ZAK přijde z prostředí (export ZAK=abc), projde jinak bez kontroly
  # a `printf %02d` spadne. Necháme ho projít touž branou jako ruční zadání.
  if [ -n "${ZAK:-}" ]; then
    ZAK="$(printf '%s' "$ZAK" | tr -dc '0-9')"
    ZAK=$((10#${ZAK:-0}))
    if [ "$ZAK" -lt 1 ] || [ "$ZAK" -gt 40 ]; then ZAK=""; fi
  fi
  if [ -z "${ZAK:-}" ]; then
    echo
    printf "  ${_B}Zadejte své číslo v třídním výkazu${_0} (1–40): "
    read -r ZAK
    ZAK="$(printf '%s' "$ZAK" | tr -dc '0-9')"
    ZAK=$((10#${ZAK:-0}))
    if [ "$ZAK" -lt 1 ] || [ "$ZAK" -gt 40 ]; then
      printf "  ${_C}Neplatné číslo.${_0} Zkuste to znovu.\n"; exit 1
    fi
    printf '%02d\n' "$ZAK" > "$_souborZak"   # dvouciferně — zadání odkazují na XX
    printf "  Uloženo do %s — příště se už ptát nebudu.\n" "$_souborZak"
    printf "  (Kdyby se číslo někdy neshodovalo s výkazem, soubor smažte.)\n\n"
  fi
  export ZAK
}
zjisti_zaka

# Dvouciferný tvar čísla — v zadáních se píše jako XX (05, 17…), takže
# jména i porty jsou stejně dlouhé a dosazení je jednoznačné.
ZAK2="$(printf '%02d' "$ZAK")"

# odvozené hodnoty — stejná konvence ve všech cvičeních
ZAK_UZIVATEL="novak$ZAK2"          # novak05
ZAK_IP="10.10.10.1$ZAK2"           # 10.10.10.105
ZAK_PORT="90$ZAK2"                 # 9005
export ZAK2 ZAK_UZIVATEL ZAK_IP ZAK_PORT

# Kód odvozený z čísla žáka. Používá start.sh i check.sh — musí být na jednom
# místě, jinak se při změně vzorce rozejdou.
lab_kod() {  # lab_kod PREFIX [sůl]
  # Sůl odlišuje kódy různých cvičení. Bez ní by měl žák ve všech cvičeních
  # tytéž čtyři číslice a druhý kód by uhodl, aniž by ho hledal.
  printf '%s-%d' "${1:-NET}" $(( (ZAK * 7919 + ${2:-0} * 104729) % 9000 + 1000 ))
}

# Deterministický výběr K položek z N podle čísla žáka. Používá ho start.sh
# i check.sh, takže vzorec musí být na jednom místě — jinak se rozejdou
# a žák dostane jiné zadání, než jaké se mu kontroluje.
lab_vyber() {  # lab_vyber N K [posun]  → vypíše K různých indexů 1..N, po jednom na řádek
  local n="$1" k="$2" posun="${3:-0}" i j t
  local -a p=()
  for ((i=1; i<=n; i++)); do p+=("$i"); done
  # Míchání řídí otisk, ne lineární generátor. První pokus stavěl na LCG
  # a měl dvě vady naráz: nejnižší bit má periodu 2 (výběr se rozpadl na
  # sudé a liché žáky) a různé soli daly korelované posloupnosti, protože
  # LCG je afinní — posun v semínku se propsal do celé řady. Otisk obojí
  # řeší a je dost rychlý, skript běží jednou za hodinu.
  for ((i=n-1; i>0; i--)); do
    j=$(( 0x$(printf '%s-%s-%s' "$ZAK" "$posun" "$i" | _hash | cut -c1-7) % (i+1) ))
    t="${p[i]}"; p[i]="${p[j]}"; p[j]="$t"
  done
  printf '%s\n' "${p[@]:0:k}"
}

# ──────────────────────────────────────────────── spuštění v cíli
# Provede příkaz tam, kde cvičení běží — na stanici, nebo v kontejneru.
# Pozor: argumenty se sem vkládají do jednoduchých uvozovek uvnitř `bash -c`.
# Apostrof ve vzoru nebo v cestě příkaz rozbije, a protože polykáme stderr,
# rozbije ho tiše. Vzory pište bez apostrofů.
v_cili() {
  if [ -n "$LAB_KONTEJNER" ]; then
    lxc exec "$LAB_KONTEJNER" -- bash -c "$*" 2>/dev/null
  else
    bash -c "$*" 2>/dev/null
  fi
}

# ──────────────────────────────────────────────────── výpis výsledků
_zapis() {  # _zapis PASS|FAIL text
  local stav="$1"; shift
  local text="$*"
  # filtrujeme podle kroku, pokud si žák vyžádal jen část
  if [ -n "$_krok_filtr" ] && [ "$_aktualni_krok" != "$_krok_filtr" ]; then return; fi
  if [ "$stav" = "PASS" ]; then
    _pass=$((_pass+1)); printf "  ${_Z}[PASS]${_0} %s\n" "$text"
  else
    _fail=$((_fail+1)); printf "  ${_C}[FAIL]${_0} %s\n" "$text"
  fi
}
# %b, ne %s — jinak by se escape sekvence vypsaly jako text
poznamka() { [ -n "$_krok_filtr" ] && [ "$_aktualni_krok" != "$_krok_filtr" ] && return; printf "         %b\n" "$*"; }

# Pro případy, které nepokrývá žádná require_* funkce.
uspech() { _zapis PASS "$*"; }
chyba()  { _zapis FAIL "$*"; }

krok() {  # krok N "Název části"
  _aktualni_krok="$1"; shift
  if [ -n "$_krok_filtr" ] && [ "$_aktualni_krok" != "$_krok_filtr" ]; then return; fi
  printf "\n${_B}── Část %s — %s${_0}\n" "$_aktualni_krok" "$*"
}

# ═══════════════════════════════════════════════ kontrolní funkce
# Každá: když sedí → PASS, jinak FAIL s vysvětlením, co chybí.

require_user() {  # require_user jmeno
  if v_cili "id '$1'" >/dev/null; then _zapis PASS "uživatel $1 existuje"
  else _zapis FAIL "uživatel $1 neexistuje"; fi
}

require_group() {
  if v_cili "getent group '$1'" >/dev/null; then _zapis PASS "skupina $1 existuje"
  else _zapis FAIL "skupina $1 neexistuje"; fi
}

require_member() {  # require_member uzivatel skupina
  if v_cili "id -nG '$1' | tr ' ' '\n' | grep -qx '$2'"; then
    _zapis PASS "$1 je ve skupině $2"
  else _zapis FAIL "$1 není ve skupině $2"; fi
}

require_path() {  # require_path cesta [popis_pass] [popis_fail]
  # Pozor: PASS a FAIL potřebují různý text. Se společným popisem by FAIL
  # tvrdil „adresář existuje" a žák by nevěděl, co po něm chceme.
  if v_cili "test -e '$1'"; then _zapis PASS "${2:-existuje $1}"
  else _zapis FAIL "${3:-${2:+chybí: }${2:-chybí $1}}"; fi
}

require_mode() {  # require_mode cesta prava   (např. 2770)
  local m; m="$(v_cili "stat -c %a '$1'")"
  if [ "$m" = "$2" ]; then _zapis PASS "$1 má práva $2"
  else _zapis FAIL "$1 má práva ${m:-?}, očekáváno $2"; fi
}

require_owner() {  # require_owner cesta vlastnik:skupina
  local o; o="$(v_cili "stat -c %U:%G '$1'")"
  if [ "$o" = "$2" ]; then _zapis PASS "$1 patří $2"
  else _zapis FAIL "$1 patří ${o:-?}, očekáváno $2"; fi
}

require_setgid() {
  # setgid = bit 2 v prvním oktalu (2,3,6,7). Pozor na prioritu && a || —
  # bez složených závorek by prázdný výstup prošel jako úspěch.
  local m; m="$(v_cili "stat -c %a '$1'")"
  if [ "${#m}" -eq 4 ] && (( (${m:0:1} & 2) != 0 )); then
    _zapis PASS "$1 má nastavený setgid bit"
  else _zapis FAIL "$1 nemá setgid bit (práva ${m:-?})"; fi
}

require_service_active() {
  if v_cili "systemctl is-active --quiet '$1'"; then _zapis PASS "služba $1 běží"
  else _zapis FAIL "služba $1 neběží"; fi
}

require_service_enabled() {
  if v_cili "systemctl is-enabled --quiet '$1'"; then _zapis PASS "služba $1 se spustí po startu (enabled)"
  else _zapis FAIL "služba $1 není enabled — po restartu nenaběhne"; fi
}

require_unit_valid() {
  # Pozor: systemd-analyze verify vypisuje i neškodná varování se stavem 0.
  # Rozhoduje návratový kód, text slouží jen jako nápověda.
  local vystup rc
  vystup="$(v_cili "systemd-analyze verify '/etc/systemd/system/$1' 2>&1")"; rc=$?
  if [ "$rc" -eq 0 ]; then
    _zapis PASS "unit $1 je syntakticky v pořádku"
  else
    _zapis FAIL "unit $1 má chyby"
    [ -n "$vystup" ] && poznamka "$(printf '%s' "$vystup" | head -3)"
  fi
}

require_port_listening() {
  if v_cili "ss -tlnH | grep -q ':$1 '"; then _zapis PASS "něco poslouchá na portu $1"
  else _zapis FAIL "na portu $1 nic neposlouchá"; fi
}

require_service_user() {  # require_service_user sluzba uzivatel
  local u; u="$(v_cili "systemctl show '$1' -p User --value")"
  [ -z "$u" ] && u="root"
  if [ "$u" = "$2" ]; then _zapis PASS "$1 běží pod uživatelem $2"
  else _zapis FAIL "$1 běží pod '$u', očekáváno $2"; fi
}

require_pkg() {
  if v_cili "dpkg -s '$1' >/dev/null 2>&1"; then _zapis PASS "balíček $1 je nainstalovaný"
  else _zapis FAIL "balíček $1 chybí"; fi
}

require_soubor_obsahuje() {  # cesta vzor [popis_pass] [popis_fail]
  if v_cili "grep -qE '$2' '$1'"; then _zapis PASS "${3:-$1 obsahuje očekávaný obsah}"
  else _zapis FAIL "${4:-${3:-$1 neobsahuje očekávaný obsah}}"; fi
}

# ── odpovědi žáka ve tvaru „klíč: hodnota" ───────────────────────
# Zadání nechávají žáka zapisovat odpovědi na řádky `klic: hodnota`.
# Kontrola pak porovnává buď přesnou hodnotu (když ji umíme přečíst ze
# stanice), nebo jen tvar odpovědi. Nikdy pouhý výskyt znaku — na ten
# by náhodou trefil kdokoli.
_zaznam() {  # _zaznam soubor klic  → vypíše hodnotu bez okolních mezer
  v_cili "grep -im1 -E '^[[:space:]]*$2[[:space:]]*:' '$1'" \
    | sed -E 's/^[[:space:]]*[^:]*:[[:space:]]*//; s/[[:space:]]+$//'
}

require_zaznam() {  # require_zaznam soubor klic hodnota [popis] [popis_fail]
  # Hláška [FAIL] nikdy nevypisuje očekávanou hodnotu. Průběžná kontrola je
  # checkpoint, ne nápověda — jinak by stačilo spustit check.sh a odpovědi
  # z něj opsat. Co má žák hledat, patří do zadání, ne sem.
  local h; h="$(_zaznam "$1" "$2")"
  # Nevyplněný řádek nesmí projít ani tehdy, když je prázdná i očekávaná
  # hodnota (třeba když se ji nepodařilo přečíst ze stanice).
  if [ -n "$h" ] && [ "$h" = "$3" ]; then _zapis PASS "${4:-$2: $3}"
  else _zapis FAIL "${5:-zatím nesedí — ${4:-řádek '$2:'}} (máte '${h:-nic}')"; fi
}

require_zaznam_tvar() {  # soubor klic regulární_výraz [popis] [popis_fail]
  local h; h="$(_zaznam "$1" "$2")"
  if [ -n "$h" ] && printf '%s' "$h" | grep -qE "$3"; then
    _zapis PASS "${4:-$2: $h}"
  else _zapis FAIL "${5:-zatím nesedí — ${4:-řádek '$2:'}} (máte '${h:-nic}')"; fi
}

# Otisk textu. Používá ho i vypis_souhrn — na macOS a v minimálních
# obrazech nemusí být sha256sum, ale shasum bývá.
_hash() {
  if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

require_zaznam_cesta() {  # soubor klic cesta_relativne zaklad [popis] [popis_fail]
  # Cestu žák opisuje z výpisu `find`, takže začíná tečkou a lomítkem. Někdo
  # napíše absolutní, někdo bez tečky — uznáváme všechny tři podoby. Smysl
  # úkolu je soubor najít, ne trefit zápis. (Kde na zápisu záleží, protože
  # se učí rozdíl absolutní/relativní, se použije require_zaznam.)
  local h n
  h="$(_zaznam "$1" "$2")"
  # Uznáváme i zápis s vlnovkou — zadání ji používá všude, takže ji žák
  # přirozeně napíše i do odpovědi.
  n="${h#./}"; n="${n#"$HOME"/}"; n="${n#\~/}"; n="${n#"$4"/}"
  n="${n#"${4#"$HOME"/}"/}"
  if [ -n "$h" ] && [ "$n" = "$3" ]; then _zapis PASS "${5:-$2: nalezeno}"
  else _zapis FAIL "${6:-zatím nesedí — ${5:-cesta u klíče $2}} (máte '${h:-nic}')"; fi
}

require_soubor_neprazdny() {  # cesta [popis_pass] [popis_fail]
  if v_cili "test -s '$1'"; then _zapis PASS "${2:-$1 existuje a není prázdný}"
  else _zapis FAIL "${3:-chybí nebo je prázdný: $1}"; fi
}

require_min_radku() {  # soubor N [popis]
  local n; n="$(v_cili "grep -c '' '$1'")"; n="${n:-0}"
  if [ "$n" -ge "$2" ]; then _zapis PASS "${3:-$1 má aspoň $2 řádků}"
  else _zapis FAIL "${3:-$1 má mít aspoň $2 řádků} (má $n)"; fi
}

require_pocet_souboru() {  # adresar vzor N [popis]
  local n; n="$(v_cili "ls -1d '$1'/$2 | grep -c ''")"; n="${n:-0}"
  if [ "$n" -eq "$3" ]; then _zapis PASS "${4:-v $1 je $3 položek typu $2}"
  else _zapis FAIL "${4:-v $1 má být $3 položek typu $2} (je jich $n)"; fi
}

require_prikaz() {  # jmeno [popis_pass] [popis_fail]
  # FAIL má vlastní výchozí text. Se sdíleným popisem by hláška zněla
  # „[FAIL] nástroj git je nainstalovaný", což je oznamovací věta, a navíc lež.
  if v_cili "command -v '$1' >/dev/null"; then _zapis PASS "${2:-nástroj $1 je k dispozici}"
  else _zapis FAIL "${3:-nástroj $1 na stanici chybí — řekněte o tom vyučujícímu}"; fi
}

require_hostname() {  # ocekavane_jmeno
  local h; h="$(v_cili "hostname")"
  if [ "$h" = "$1" ]; then _zapis PASS "stanice se jmenuje $1"
  else _zapis FAIL "stanice se jmenuje '${h:-?}', očekáváno $1"; fi
}

require_soubor_min_velikost() {  # cesta bajtů [popis]
  # Doplněk k require_soubor_magie: samotná hlavička se dá napsat ručně,
  # skutečný soubor s obsahem má velikost. Práh volte podle nejmenšího
  # poctivého výsledku, ne podle typického.
  local v; v="$(v_cili "wc -c < '$1'" | tr -dc '0-9')"; v="${v:-0}"
  if [ "$v" -ge "$2" ]; then _zapis PASS "${3:-$1 má aspoň $2 B}"
  else _zapis FAIL "${3:-$1 je menší, než odpovídá zadání} (má ${v} B)"; fi
}

require_soubor_magie() {  # soubor hexadecimální_prefix [popis]
  # Ověří první bajty souboru. Používá se tam, kde obsah přečíst nejde
  # (zašifrovaná databáze), ale musíme poznat, že jde o skutečný soubor
  # daného formátu, a ne o prázdnou schránku se správným jménem.
  local m; m="$(v_cili "head -c 8 '$1' | od -An -tx1 | tr -d ' \n'")"
  case "$m" in
    "$2"*) _zapis PASS "${3:-$1 je soubor očekávaného formátu}" ;;
    *)     _zapis FAIL "${3:-$1 chybí, nebo není soubor očekávaného formátu}" ;;
  esac
}

require_gpg_klic() {  # vzor [popis]
  if v_cili "gpg --list-keys 2>/dev/null | grep -qF '$1'"; then
    _zapis PASS "${2:-v klíčence je klíč pro $1}"
  else _zapis FAIL "${2:-v klíčence není klíč pro $1}"; fi
}

# ── negativní kontroly: hlídají obchvaty, ne dovednosti ──────────
negative_no_777() {
  if v_cili "find '$1' -maxdepth 1 -perm -0002 | grep -q ."; then
    _zapis FAIL "$1 je zapisovatelný pro všechny — 'chmod 777' není řešení"
  else _zapis PASS "$1 není otevřený pro všechny"; fi
}

negative_service_not_root() {
  local u; u="$(v_cili "systemctl show '$1' -p User --value")"
  if [ -z "$u" ] || [ "$u" = "root" ]; then
    _zapis FAIL "$1 běží pod rootem — službu není nutné pouštět s plnými právy"
  else _zapis PASS "$1 neběží pod rootem"; fi
}

pouzil_diagnostiku() {  # měkká kontrola: sáhl žák po diagnostice, než začal opravovat?
  # v_cili běží v kontejneru jako root, takže ~ je /root — historii žáka
  # musíme hledat v jeho domovském adresáři
  local hist h
  if [ -n "$LAB_KONTEJNER" ]; then hist="/home/$LAB_UZIVATEL/.bash_history"
  else hist="$HOME/.bash_history"; fi
  h="$(v_cili "cat '$hist' 2>/dev/null")"
  if printf '%s' "$h" | grep -qE 'systemctl (status|cat)|journalctl|systemd-analyze'; then
    _zapis PASS "před opravou jste sáhli po diagnostice"
  else
    poznamka "${_M}tip:${_0} příště začněte od 'systemctl status' a 'journalctl -xeu' —"
    poznamka "     rychleji uvidíte, kde je příčina"
  fi
}

# ═══════════════════════════════════════════════════════ souhrn
vypis_souhrn() {
  local celkem=$((_pass + _fail))
  if [ "$celkem" -eq 0 ] && [ -n "$_krok_filtr" ]; then
    printf "\n  Část %s v tomto cvičení není.\n\n" "$_krok_filtr"; return 1
  fi
  echo
  if [ "$_fail" -eq 0 ] && [ "$celkem" -gt 0 ]; then
    printf "  ${_Z}${_B}Hotovo — %d z %d.${_0}\n" "$_pass" "$celkem"
  elif [ "$celkem" -gt 0 ]; then
    printf "  ${_B}Splněno %d z %d.${_0} Zbývá %d — řádky [FAIL] výše říkají co.\n" "$_pass" "$celkem" "$_fail"
  fi

  # Otisk: obsahuje stanici, číslo žáka a čas. NENÍ to důkaz (žák má na svém
  # stroji root), ale pozná se podle něj přeposlaný cizí výsledek.
  local podklad otisk cas
  cas="$(date +%Y-%m-%dT%H:%M)"          # jednou — jinak se hašuje jiný čas, než se vypíše
  podklad="$(hostname)|$ZAK|$cas|$_pass/$celkem"
  otisk="$(printf '%s' "$podklad" | _hash | cut -c1-12)"
  printf "  ${_M}Žák:${_0} %s · ${_M}Stanice:${_0} %s · ${_M}Čas:${_0} %s · ${_M}Otisk:${_0} %s\n\n" \
         "$ZAK2" "$(hostname)" "$cas" "$otisk"

  [ "$_fail" -eq 0 ] && return 0 || return 1
}
