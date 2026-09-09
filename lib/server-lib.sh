#!/bin/bash
# server-lib.sh — stavba a údržba serveru pro blok B 3. ročníku (cvičení 3–6).
#
# Používá se ve start.sh:
#     source "$(dirname "$0")/../../lib/lab-lib.sh"
#     source "$(dirname "$0")/../../lib/server-lib.sh"
#     postav_server || exit 1
#     echo "$SERVER_IP $SERVER_HESLO"
#
# Proč knihovna: cvičení 3 až 6 sdílejí jeden server `server-XX` a každé z nich
# ho podle pravidla o nezávislosti musí umět postavit CELÝ samo. Bez sdílené
# funkce by týž kód žil ve čtyřech kopiích a ty by se časem rozešly.
#
# Vše je idempotentní — funkce se pouští i na server, který už stojí, a doplní
# jen to, co chybí. Nikdy nespoléhá na to, že proběhlo předchozí cvičení.

# Jméno kontejneru se dá přepsat PŘED sourcováním — blok B používá
# `server-XX`, rodina systemd (cvičení 7–10) `sluzby-XX`.
SERVER_KONT="${SERVER_KONT:-server-$ZAK2}"
SERVER_OBRAZ="${SERVER_OBRAZ:-ubuntu-26.04}"   # lokální alias ze šablony VM
SERVER_UCET="sysadmin"
SERVER_IP=""
SERVER_HESLO=""
SERVER_NOVY=0

# Heslo se losuje NA STANICI a zůstává na ní. Do repozitáře nesmí heslo ani
# vzorec, ze kterého by se dalo spočítat — jinak si heslo k účtu kteréhokoli
# spolužáka odvodí kdokoli. Uložené je proto, aby druhé spuštění ukázalo totéž.
_server_heslo() {
  # Soubor je per kontejner — dva různé servery mají různá hesla a druhé
  # spuštění start.sh musí ukázat totéž heslo, ne nové.
  local soubor="$HOME/.os-lab-heslo-$SERVER_KONT"
  # Přechod ze staršího jména: kdo dělal blok B před přejmenováním, má heslo
  # v ~/.os-lab-server-heslo. Převezme se, aby mu start.sh neukázal nové.
  local stary="$HOME/.os-lab-server-heslo"
  if [ ! -s "$soubor" ] && [ -s "$stary" ]; then
    install -m 600 /dev/null "$soubor"
    cat "$stary" > "$soubor"
    rm -f "$stary"
  fi
  if [ ! -s "$soubor" ]; then
    # Práva se nastavují PŘED zápisem — jinak je mezi vytvořením a chmod
    # krátké okno, kdy soubor s heslem má práva podle umask.
    install -m 600 /dev/null "$soubor"
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-12 > "$soubor"
  fi
  cat "$soubor"
}

server_bezi() { [ "$(lxc list "^${SERVER_KONT}$" -c s --format csv 2>/dev/null)" = "RUNNING" ]; }

postav_server() {
  if ! command -v lxc >/dev/null 2>&1; then
    echo
    echo "  Na téhle stanici není LXD, takže server nejde postavit."
    echo "  Řekněte o tom vyučujícímu — patří do obrazu VM."
    echo
    return 1
  fi

  if lxc info "$SERVER_KONT" >/dev/null 2>&1; then
    server_bezi || lxc start "$SERVER_KONT" >/dev/null 2>&1
  else
    echo "  Stavím server $SERVER_KONT…"
    lxc launch "$SERVER_OBRAZ" "$SERVER_KONT" >/dev/null 2>&1 || {
      echo "  Server se nepodařilo spustit. Zkontrolujte, že LXD běží: lxc list"
      return 1; }
    SERVER_NOVY=1
  fi

  # Čekáme na adresu, ne na `systemctl is-system-running` — ten v kontejneru
  # obvykle skončí na „degraded" a smyčka by vždy vyčerpala celý timeout.
  local i
  for i in $(seq 1 60); do
    SERVER_IP="$(lxc list "^${SERVER_KONT}$" -c4 --format csv 2>/dev/null | cut -d' ' -f1)"
    [ -n "$SERVER_IP" ] && break
    sleep 1
  done
  if [ -z "$SERVER_IP" ]; then
    echo "  Server nedostal IP adresu — zavolejte vyučujícího."
    return 1
  fi

  SERVER_HESLO="$(_server_heslo)"

  # ── účet, sudo, historie ────────────────────────────────────────
  lxc exec "$SERVER_KONT" -- bash -c "
    id $SERVER_UCET >/dev/null 2>&1 || useradd -m -s /bin/bash $SERVER_UCET
    usermod -aG sudo $SERVER_UCET
    # `adm` a `systemd-journal` kvůli journalu: systémový log smí bez sudo číst
    # jen root a členové těchto skupin (viz journalctl(1)). Bez nich by
    # `journalctl -u <sluzba>` mlčel a cvičení 3/09 by nemělo co ukázat.
    # Správce serveru do `adm` patří i v reálném provozu.
    usermod -aG adm,systemd-journal $SERVER_UCET
    # Časové pásmo serveru = pásmo učebny. Bez toho běží kontejner v UTC
    # a žák ve cvičení o logech porovnává čas v journalu s hodinami na zdi,
    # které se liší o dvě hodiny. Locale se nechává anglické — generovat
    # cs_CZ.UTF-8 by znamenalo instalaci navíc a výpisy v zadání se drží
    # toho, co server opravdu vypíše.
    timedatectl set-timezone Europe/Prague 2>/dev/null || \
      ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
    # historie se zapisuje průběžně, ne až při odhlášení — kontrola i vyučující
    # se na ni dívají dřív, než se žák odhlásí
    grep -q 'history -a' /home/$SERVER_UCET/.bashrc 2>/dev/null || \
      echo \"PROMPT_COMMAND='history -a'\" >> /home/$SERVER_UCET/.bashrc
    mkdir -p /home/$SERVER_UCET/.ssh && chmod 700 /home/$SERVER_UCET/.ssh
    chown -R $SERVER_UCET:$SERVER_UCET /home/$SERVER_UCET/.ssh
    # sudo bez hesla: účet z useradd žádné heslo nemá a od cvičení 4 se
    # přihlašuje klíčem, takže by se k rootu jinak nedostal
    echo '$SERVER_UCET ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-$SERVER_UCET
    chmod 440 /etc/sudoers.d/90-$SERVER_UCET
  " >/dev/null 2>&1

  # ── SSH ─────────────────────────────────────────────────────────
  # rsync musí být na OBOU koncích přenosu (cvičení 3/04). Bez něj dostane
  # žák hlášku „connection unexpectedly closed", ze které příčinu nevyčte.
  lxc exec "$SERVER_KONT" -- bash -c \
    "command -v sshd >/dev/null && command -v rsync >/dev/null \
       || { apt-get update -qq && apt-get install -y -qq openssh-server rsync; }" \
    >/dev/null 2>&1 || {
      echo "  SSH server se nepodařilo nainstalovat — zavolejte vyučujícího."; return 1; }
  lxc exec "$SERVER_KONT" -- systemctl enable --now ssh >/dev/null 2>&1
  # Novější Ubuntu má SSH socket-aktivované (ssh.socket místo ssh.service)
  lxc exec "$SERVER_KONT" -- bash -c \
    "systemctl is-active --quiet ssh || systemctl is-active --quiet ssh.socket" || {
      echo "  SSH na serveru neběží — zavolejte vyučujícího."; return 1; }

  # Heslo je učivo cvičení 3. Zůstává i potom — kdo si smaže klíč, dostane se
  # dál dovnitř. cloud image má PasswordAuthentication no, proto ten drop-in.
  # Heslo jde přes stdin, ne v příkazové řádce — jinak ho vidí `ps`.
  printf '%s:%s\n' "$SERVER_UCET" "$SERVER_HESLO" \
    | lxc exec "$SERVER_KONT" -- chpasswd >/dev/null 2>&1
  # POZOR na číslo souboru. sshd čte /etc/ssh/sshd_config.d/*.conf lexikálně
  # a platí PRVNÍ nalezená hodnota, ne poslední. Cloud image Ubuntu má
  # 60-cloudimg-settings.conf s `PasswordAuthentication no`, takže drop-in
  # s číslem 99 by se nikdy neuplatnil a přihlášení heslem by nefungovalo —
  # a na něm stojí celé cvičení 3/03 i `ssh-copy-id` ve 3/04.
  lxc exec "$SERVER_KONT" -- bash -c \
    "printf 'PasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/10-lab.conf
     systemctl restart ssh 2>/dev/null || systemctl restart ssh.socket 2>/dev/null" >/dev/null 2>&1

  return 0
}

# Nasadí veřejný klíč ze stanice, pokud nějaký je. Volá se jen tam, kde má
# klíčové přihlášení být předpokladem (cvičení 5 a 6) — ve cvičení 4 si ho
# nasazuje žák sám, to je jeho učivo.
nasad_klic_ze_stanice() {
  local klic obsah
  klic="$(ls "$HOME"/.ssh/id_*.pub 2>/dev/null | head -1)"
  [ -n "$klic" ] || return 1
  obsah="$(cat "$klic")"
  [ -n "$obsah" ] || return 1
  # Klíč se PŘIPOJUJE, nepřepisuje. `lxc file push` by přepsal to, co si žák
  # nasadil sám ve cvičení 4 — a tím by mu smazal výsledek jeho práce.
  # Návratový kód se odvozuje od skutečného výsledku, ne natvrdo z nuly:
  # když nasazení selže, volající musí vypsat heslo, jinak žák zůstane venku.
  printf '%s\n' "$obsah" | lxc exec "$SERVER_KONT" -- bash -c "
    AUTH=/home/$SERVER_UCET/.ssh/authorized_keys
    touch \"\$AUTH\"
    KLIC=\"\$(cat)\"
    grep -qF \"\$KLIC\" \"\$AUTH\" || printf '%s\n' \"\$KLIC\" >> \"\$AUTH\"
    chown $SERVER_UCET:$SERVER_UCET \"\$AUTH\"
    chmod 600 \"\$AUTH\"
  " >/dev/null 2>&1 || return 1
  return 0
}
