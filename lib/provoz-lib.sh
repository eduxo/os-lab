#!/bin/bash
# provoz-lib.sh — společný nábytek serveru `provoz-XX` (blok D: 3/11–3/13).
#
# Proč to je zvlášť: cvičení 11, 12 a 13 sdílejí jeden server a platí
# pravidlo, že KAŽDÝ start.sh postaví celý stack, který jeho cvičení
# potřebuje — i žákovi, který na předchozích nebyl. Bez téhle knihovny
# by se dávkové zpracování a archiv musely opsat do každého skriptu
# a rozešly by se.
#
# Sourcuje se AŽ PO lab-lib.sh; funkce `postav_*` navíc potřebují $SERVER_KONT,
# který nastavuje volající skript před sourcováním server-lib.sh. Kontroly si
# knihovnu sourcují jen kvůli proměnným ARCHIV_* a server-lib.sh nepotřebují.

DAVKA_UCET="davka$ZAK2"

# Dávkové zpracování — legitimní služba, která na serveru patří.
# Ve cvičení 11 se jí snižuje priorita, ve 12 slouží jako protipól
# k tomu, co po sobě nechal předchůdce.
postav_zpracovani() {
  lxc exec "$SERVER_KONT" -- bash -c "
    id $DAVKA_UCET >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin $DAVKA_UCET
  " >/dev/null 2>&1

  if ! lxc exec "$SERVER_KONT" -- test -f /usr/local/bin/zpracovani.sh; then
    lxc exec "$SERVER_KONT" -- tee /usr/local/bin/zpracovani.sh >/dev/null <<'DAVKA'
#!/bin/bash
# Davkove zpracovani NetLab — prepocitava kontrolni soucty.
# Schvalne bez pauzy: ma byt videt v `top` na prvnim miste.
while true; do
  echo "$RANDOM$RANDOM$RANDOM" | sha256sum >/dev/null
done
DAVKA
    lxc exec "$SERVER_KONT" -- chmod 755 /usr/local/bin/zpracovani.sh >/dev/null 2>&1
  fi

  if ! lxc exec "$SERVER_KONT" -- test -f /etc/systemd/system/zpracovani.service; then
    lxc exec "$SERVER_KONT" -- tee /etc/systemd/system/zpracovani.service >/dev/null <<UNIT
[Unit]
Description=Davkove zpracovani NetLab

[Service]
Type=simple
User=$DAVKA_UCET
ExecStart=/usr/local/bin/zpracovani.sh
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
    lxc exec "$SERVER_KONT" -- systemctl daemon-reload >/dev/null 2>&1
  fi
  lxc exec "$SERVER_KONT" -- systemctl enable --now zpracovani >/dev/null 2>&1
}

# Archiv s jedním nápadně velkým souborem. Cesta i velikost se odvozují
# z čísla žáka — ve cvičení 11 je to hledaná odpověď, ve 12 to jsou data,
# která se při úklidu smazat NESMÍ.
#
# Soubory se plní z /dev/urandom, ne z /dev/zero: řídký soubor by měl
# nulovou skutečnou velikost a `du` by ho nenašel, což je přesně ta
# veličina, kterou má žák měřit.
ARCHIV_ROKY=(2024 2025 2026)
ARCHIV_SLOZKY=(faktury zalohy fotky)
ARCHIV_ROK="${ARCHIV_ROKY[$(( $(lab_vyber 3 1 501) - 1 ))]}"
ARCHIV_SLOZKA="${ARCHIV_SLOZKY[$(( $(lab_vyber 3 1 502) - 1 ))]}"
ARCHIV_ZROUT="$ARCHIV_ROK/$ARCHIV_SLOZKA/export.dat"
ARCHIV_MB=$(( 40 + ZAK ))

postav_archiv() {
  # Idempotence je tu POTŘEBA PO SOUBORECH, ne po adresáři.
  #
  # Dva důvody. (1) Kdyby guard visel na existenci /srv/archiv, žák, který
  # smazal jen velký soubor, by ho nedostal zpátky ani opakovaným start.sh —
  # slepá ulička, ze které vede jen reset.sh. (2) Velikosti rozptylových
  # souborů jsou náhodné a kontrola je používá jako doklad, že žák du opravdu
  # pustil. Kdyby je druhé spuštění start.sh přegenerovalo, posunul by se cíl
  # pod rukama žákovi, který si výpis uložil před přestávkou.
  lxc exec "$SERVER_KONT" -- bash -c "
    for r in 2024 2025 2026; do
      for s in faktury zalohy fotky; do
        mkdir -p /srv/archiv/\$r/\$s
        for i in 1 2 3; do
          f=/srv/archiv/\$r/\$s/data-\$i.dat
          [ -s \"\$f\" ] || dd if=/dev/urandom of=\"\$f\" \
             bs=1M count=\$(( (RANDOM % 4) + 1 )) status=none
        done
      done
    done
    [ -s /srv/archiv/$ARCHIV_ZROUT ] || \
      dd if=/dev/urandom of=/srv/archiv/$ARCHIV_ZROUT bs=1M count=$ARCHIV_MB status=none
    chown -R root:root /srv/archiv
  " >/dev/null 2>&1
}
