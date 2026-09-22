#!/bin/bash
# 4/07 — Překlep ve fstab. Prostředí: žákova stanice.
#
# Skript zanese do /etc/fstab jednu závadu, kvůli které stanice při příštím
# startu spadne do záchranného režimu. Na disky nesahá — mění výhradně
# konfiguraci.
#
# DVĚ ZÁCHRANNÉ SÍTĚ, protože tenhle lab umí stanici zastavit:
#   1) /etc/fstab.zaloha — kopie správného souboru NA KOŘENOVÉM SVAZKU,
#      tedy tam, kam se žák ze záchranného režimu dostane (domovský adresář
#      tam být připojený nemusí).
#   2) ~/netlab/emergency/fstab.pred-cvicenim — pro reset.sh za běhu.
set -uo pipefail
source "$(dirname "$0")/../../lib/lab-lib.sh"
source "$(dirname "$0")/../../lib/disk-lib.sh"

LAB="$HOME/netlab/emergency"
FORMULAR="$LAB/hlaseni.txt"
ZNACKA="$LAB/.zavada"
ZALOHA="$LAB/fstab.pred-cvicenim"
ZALOHA_SYS="/etc/fstab.zaloha"

projekt_pripoj >/dev/null 2>&1 || true

ZAR="$(blkid -L "$PROJEKT_NAZEV" 2>/dev/null)"
if [ -z "$ZAR" ]; then
  echo; echo "  Disk ročníkového projektu (návěští $PROJEKT_NAZEV) nenajdu."
  echo "  Bez něj tohle cvičení nedává smysl — řekněte o tom vyučujícímu."; echo
  exit 1
fi
UUID="$(lsblk -no UUID "$ZAR" 2>/dev/null | tr -d ' ' | head -1)"
TYP="$(lsblk -no FSTYPE "$ZAR" 2>/dev/null | tr -d ' ' | head -1)"
[ -n "$UUID" ] && [ -n "$TYP" ] || { echo "  Údaje o projektovém disku se nepodařilo přečíst."; exit 1; }

mkdir -p "$LAB" "$PROJEKT_PRIPOJ"

# ── řádek projektu musí existovat ────────────────────────────────────
# Kdo minule chyběl, ho ve fstab nemá. Lab na předchozím nesmí záviset,
# takže ho skript doplní — správně, aby bylo co rozbít.
if ! grep -vE '^[[:space:]]*(#|$)' /etc/fstab | awk -v c="$PROJEKT_PRIPOJ" '$2==c{f=1} END{exit !f}'; then
  echo "  Ve fstab zatím projektový disk nemáte — doplním správný řádek."
  # Úvodní odřádkování: kdyby soubor nekončil novým řádkem, přilepil by se
  # záznam k poslednímu a vznikl by nesmysl.
  printf '\nUUID=%s  %s  %s  defaults,nofail  0  0\n' "$UUID" "$PROJEKT_PRIPOJ" "$TYP" \
    | sudo tee -a /etc/fstab >/dev/null
fi

# Záloha SPRÁVNÉHO stavu — až po doplnění řádku, ať je kam se vrátit.
if [ ! -f "$ZNACKA" ]; then
  sudo cp /etc/fstab "$ZALOHA_SYS" \
    || { echo "  Zálohu se nepodařilo vytvořit — nic jsem neměnil."; exit 1; }
  sudo cp /etc/fstab "$ZALOHA" \
    || { echo "  Zálohu se nepodařilo vytvořit — nic jsem neměnil."; exit 1; }
  sudo chown "$(id -un):$(id -gn)" "$ZALOHA" 2>/dev/null
  cmp -s /etc/fstab "$ZALOHA_SYS" \
    || { echo "  Záloha neodpovídá originálu — nic jsem neměnil."; exit 1; }
fi
# Pojistka proti tomu, aby se závada nasadila na soubor, jehož záloha už
# rozbitá je: v záloze MUSÍ být řádek projektu. Bez něj by reset neměl
# kam vracet a stanice by zůstala nepojízdná.
grep -vE '^[[:space:]]*(#|$)' "$ZALOHA_SYS" 2>/dev/null \
  | awk -v c="$PROJEKT_PRIPOJ" '$2==c{f=1} END{exit !f}' \
  || { echo "  Záloha neobsahuje řádek projektu — odmítám nasadit závadu."; exit 1; }

# ── závada ───────────────────────────────────────────────────────────
# Kterou ze tří — odvozeno z čísla žáka, aby to check.sh uměl spočítat taky.
SCENAR="$(lab_cislo 1 3 fstab-porucha)"

if [ -f "$ZNACKA" ]; then
  echo
  echo "  Dnešní závada už je nasazená — nechávám stav, jak je."
  echo "  Chcete začít znovu?  ./reset.sh"
else
  echo
  printf '  \033[0;31mTÍMHLE SE STANICE PŘÍŠTÍ START ZASTAVÍ.\033[0m\n'
  echo "  Přesně o to dnes jde — ale jen když máte hotový snímek."
  echo "  Snímek se dělá ve VirtualBoxu: stroj → Snímky → Vytvořit."
  echo
  read -r -p "  Máte hotový snímek? Napište ROZBIT pro pokračování: " ODP
  if [ "$ODP" != "ROZBIT" ]; then
    echo "  Zrušeno, nic se nezměnilo. Udělejte si snímek a spusťte start.sh znovu."
    echo
    exit 0
  fi

  # Mění se JEN řádek projektu. Kořenový svazek ani /boot se nedotknou —
  # stanice musí zůstat opravitelná ze záchranného režimu.
  case "$SCENAR" in
    1) # překlep v UUID: poslední znak jinak
       POSL="${UUID: -1}"; NOVY="0"; [ "$POSL" = "0" ] && NOVY="1"
       VADNE="UUID=${UUID:0:${#UUID}-1}$NOVY"
       awk -v c="$PROJEKT_PRIPOJ" -v v="$VADNE" \
         '$2==c && $0 !~ /^[[:space:]]*#/ {$1=v; sub(/,?nofail/,"",$4); sub(/^,/,"",$4); if ($4=="") $4="defaults"; print; next} {print}' \
         /etc/fstab > "$LAB/fstab.nove" ;;
    2) # překlep ve volbách — mount neznámou volbu odmítne
       awk -v c="$PROJEKT_PRIPOJ" \
         '$2==c && $0 !~ /^[[:space:]]*#/ {sub(/,?nofail/,"",$4); sub(/^,/,"",$4); if ($4=="") $4="defaults"; $4=$4 ",noatme"; print; next} {print}' \
         /etc/fstab > "$LAB/fstab.nove" ;;
    *) # typ souborového systému, který na disku není
       awk -v c="$PROJEKT_PRIPOJ" \
         '$2==c && $0 !~ /^[[:space:]]*#/ {$3="xfs"; sub(/,?nofail/,"",$4); sub(/^,/,"",$4); if ($4=="") $4="defaults"; print; next} {print}' \
         /etc/fstab > "$LAB/fstab.nove" ;;
  esac
  if [ ! -s "$LAB/fstab.nove" ]; then
    echo "  Závadu se nepodařilo nasadit — nic jsem neměnil."; exit 1
  fi
  # Atomicky: zapsat vedle a přejmenovat. `cp` by cíl nejdřív zkrátil.
  sudo cp "$LAB/fstab.nove" /etc/fstab.novy \
    && sudo chmod 644 /etc/fstab.novy && sudo chown root:root /etc/fstab.novy \
    && sudo mv /etc/fstab.novy /etc/fstab && rm -f "$LAB/fstab.nove"
  # Ověřit, že závada opravdu sedí. Neptáme se findmnt --verify: špatný TYP
  # souborového systému (scénář 3) nástroj vidět nemusí a skript by závadu
  # sám vrátil zpět — žák by pak neměl co opravovat. Ptáme se na to, co je
  # jisté: řádek projektu se oproti záloze změnil a přišel o nofail.
  NOVY_R="$(grep -vE '^[[:space:]]*(#|$)' /etc/fstab | awk -v c="$PROJEKT_PRIPOJ" '$2==c {print; exit}')"
  STARY_R="$(grep -vE '^[[:space:]]*(#|$)' "$ZALOHA_SYS" | awk -v c="$PROJEKT_PRIPOJ" '$2==c {print; exit}')"
  if [ -n "$NOVY_R" ] && [ "$NOVY_R" != "$STARY_R" ] && ! printf '%s' "$NOVY_R" | grep -q nofail; then
    date '+%Y-%m-%d %H:%M' > "$ZNACKA"
  else
    sudo cp "$ZALOHA_SYS" /etc/fstab
    echo "  Závadu se nepodařilo nasadit, fstab jsem vrátil. Řekněte to vyučujícímu."
    exit 1
  fi
fi

if [ ! -s "$FORMULAR" ]; then
  cat > "$FORMULAR" <<'FORMULAR_KONEC'
# Hlášení o výpadku serveru — vyplňte hodnoty za dvojtečku.
#
# chyba_v_poli = kolikáté pole řádku mělo ŠPATNOU HODNOTU (číslo 1 až 6).
#                Pojistku, která z řádku navíc zmizela, sem nepočítejte —
#                tu řešíte zvlášť na řádku prevence.
# jednotka     = jméno systemd jednotky, která při startu selhala
#                (najdete ho v journalctl -xb, končí na .mount)
# projev       = co stanice při startu udělala, vlastními slovy
# postup       = jak jste se k souboru dostali a jak jste ho opravili
# prevence     = co je na tom řádku od teď navíc, aby výpadek disku
#                nezastavil start stanice
chyba_v_poli:
jednotka:
projev:
postup:
prevence:
FORMULAR_KONEC
fi

cat <<EOF

  Připraveno — a tentokrát to znamená „rozbito".

    Zálohu správného fstab máte na DVOU místech:
      $ZALOHA_SYS   (na kořenovém svazku — dosáhnete na ni i ze záchranného režimu)
      $ZALOHA

    Hlášení:  $FORMULAR

  Server po restartu nenaběhne. Zjistěte proč a spravte to.

  Průběžná kontrola (až se stanice zase rozjede):

    cd ~/os-lab/4-lin/07-fstab-porucha && ./check.sh --krok 1

EOF
