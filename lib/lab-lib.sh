#!/bin/bash
# lab-lib.sh — sdílené funkce ověřovacích skriptů.
#
# Používá se v check.sh každého cvičení:
#     source "$(dirname "$0")/../../lib/lab-lib.sh"
#     require_user "novak$ZAK"
#     vypis_souhrn
#
# Cíl kontroly: implicitně žákova stanice. Když cvičení běží v kontejneru,
# nastaví se před prvním require:
#     LAB_KONTEJNER="sluzby-$ZAK"

# ────────────────────────────────────────────────────────── nastavení
LAB_KONTEJNER="${LAB_KONTEJNER:-}"     # prázdné = kontrolujeme tuto stanici
LAB_UZIVATEL="${LAB_UZIVATEL:-sysadmin}"   # pod kým žák v kontejneru pracuje
_pass=0; _fail=0; _krok_filtr=""; _aktualni_krok=0; _radky=()

# barvy jen když píšeme do terminálu (v rouře by překážely)
if [ -t 1 ]; then
  _Z='\033[0;32m'; _C='\033[0;31m'; _M='\033[0;33m'; _0='\033[0m'; _B='\033[1m'
else
  _Z=''; _C=''; _M=''; _0=''; _B=''
fi

# ────────────────────────────────────────────────── parametry příkazu
for _a in "$@"; do
  case "$_a" in
    --krok) ;;                                    # hodnotu chytí následující iterace
    --krok=*) _krok_filtr="${_a#*=}" ;;
    [0-9]*) [ -z "$_krok_filtr" ] && _krok_filtr="$_a" ;;
    --help|-h)
      echo "Použití: ./check.sh [--krok N]"
      echo "  bez parametru  — ověří celé cvičení"
      echo "  --krok N       — ověří jen část N (průběžná kontrola)"
      exit 0 ;;
  esac
done
# "02" a "2" musí označovat tentýž krok
[ -n "$_krok_filtr" ] && _krok_filtr=$((10#$_krok_filtr))

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
  if [ -z "${ZAK:-}" ]; then
    echo
    printf "  ${_B}Zadejte své číslo v třídním výkazu${_0} (1–40): "
    read -r ZAK
    ZAK="$(printf '%s' "$ZAK" | tr -dc '0-9')"
    ZAK=$((10#${ZAK:-0}))
    if [ "$ZAK" -lt 1 ] || [ "$ZAK" -gt 40 ]; then
      printf "  ${_C}Neplatné číslo.${_0} Zkuste to znovu.\n"; exit 1
    fi
    printf '%s\n' "$ZAK" > "$_souborZak"
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

# ──────────────────────────────────────────────── spuštění v cíli
# Provede příkaz tam, kde cvičení běží — na stanici, nebo v kontejneru.
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
  _radky+=("$stav|$text")
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

require_path() {  # require_path cesta [popis]
  if v_cili "test -e '$1'"; then _zapis PASS "${2:-existuje $1}"
  else _zapis FAIL "${2:-chybí $1}"; fi
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

require_soubor_obsahuje() {  # require_soubor_obsahuje cesta vzor popis
  if v_cili "grep -qE '$2' '$1'"; then _zapis PASS "${3:-$1 obsahuje očekávaný obsah}"
  else _zapis FAIL "${3:-$1 neobsahuje očekávaný obsah}"; fi
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
  echo
  if [ "$_fail" -eq 0 ] && [ "$celkem" -gt 0 ]; then
    printf "  ${_Z}${_B}Hotovo — %d z %d.${_0}\n" "$_pass" "$celkem"
  elif [ "$celkem" -gt 0 ]; then
    printf "  ${_B}Splněno %d z %d.${_0} Zbývá %d — řádky [FAIL] výše říkají co.\n" "$_pass" "$celkem" "$_fail"
  fi

  # Otisk: obsahuje stanici, číslo žáka a čas. NENÍ to důkaz (žák má na svém
  # stroji root), ale pozná se podle něj přeposlaný cizí výsledek.
  local podklad otisk
  podklad="$(hostname)|$ZAK|$(date +%Y-%m-%dT%H:%M)|$_pass/$celkem"
  if command -v sha256sum >/dev/null; then otisk="$(printf '%s' "$podklad" | sha256sum | cut -c1-12)"
  else otisk="$(printf '%s' "$podklad" | shasum -a 256 | cut -c1-12)"; fi
  printf "  ${_M}Žák:${_0} %s · ${_M}Stanice:${_0} %s · ${_M}Čas:${_0} %s · ${_M}Otisk:${_0} %s\n\n" \
         "$ZAK" "$(hostname)" "$(date '+%d.%m. %H:%M')" "$otisk"

  [ "$_fail" -eq 0 ] && return 0 || return 1
}
