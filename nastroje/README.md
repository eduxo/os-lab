# Nástroje pro stavbu prostředí

Skripty, kterými se připraví a ověří stanice. **Nejsou to cvičení** — spouští
je vyučující při stavbě šablony, ne žáci v hodině.

## Postup na čisté instalaci

Výchozí stav: **Ubuntu Server 26.04 LTS** (x86_64 na školní stanici,
arm64 na vývojové VM — postup je stejný).

> **Stavíš celou žákovskou VM od nuly?** Tenhle seznam je jen jádro postupu.
> Celá cesta — parametry VM, volby instalátoru, past s Hyper-V, export
> a rozdání na stanice — je ve **[VM-virtualbox.md](VM-virtualbox.md)**.

```bash
curl -fsSL https://raw.githubusercontent.com/eduxo/os-lab/main/nastroje/priprava-stanice.sh -o priprava-stanice.sh
bash priprava-stanice.sh                      # 1. připraví celou stanici
# odhlásit a znovu přihlásit (skupiny lxd a docker)
bash ~/os-lab/nastroje/overeni-prostredi.sh   # 2. ověří předpoklady
```

Stahuje se **jeden soubor**. Git ani repozitář předem mít nemusíš — skript si
je obstará sám a od té chvíle pracuje z `~/os-lab`.

### `priprava-stanice.sh`
Kroky: aktualizace systému · **rozšíření kořenového svazku na celý disk** ·
**prostředí MATE** (`ubuntu-mate-core`, ptá se — stahuje stovky MB) · **vzhled
stanice eduxo** (pozadí z `img/`, motiv Yaru-blue, domovská stránka Firefoxu,
pozadí přihlašovací obrazovky) · nástroje pro
laby · **doplňky hypervizoru** · **LXD** s úložištěm btrfs · inicializace LXD ·
izolovaná síť `netlab` pro cvičení s DNS a DHCP · předstažení obrazu kontejnerů
a obrazů Dockeru do lokální cache · nastavení hesla roota.

> **Doplňky hypervizoru** se řídí tím, co vrátí `systemd-detect-virt`:
> ve VirtualBoxu `virtualbox-guest-utils` + `-x11` (z **multiverse**), ve VMware
> `open-vm-tools`. Balíčky z Ubuntu jsou lepší než ISO s Guest Additions —
> nic se nepřekládá a přežijí aktualizaci jádra. Bez nich nefunguje schránka
> mezi hostitelem a hostem ani automatické rozlišení.

> **K čemu je rozšíření svazku:** instalátor Ubuntu Serveru vytvoří LVM svazek
> jen na část disku — na 100GB disku typicky 48 GB — a zbytek nechá ve skupině
> ležet. Bez rozšíření dojde místo uprostřed roku, až porostou obrazy kontejnerů
> a snapshoty. Skript to pozná a nabídne opravu; běží za provozu, bez restartu.

**Je stavěný na opakované spouštění.** Po změně `balicky.txt` ho žáci pustí
znovu a on stanici srovná — doinstaluje, co přibylo, odinstaluje, co ze seznamu
vypadlo. Neinstaluje nic znovu. Co smí odinstalovat, si drží v
`/var/lib/os-lab/balicky.stav`, takže na cizí balíčky nesáhne.

### `balicky.txt`
Seznam balíčků, které musí být v šabloně. Čte ho `priprava-stanice.sh`.
**Nové cvičení = nový řádek sem**, i s poznámkou, který lab balíček potřebuje.
Zakomentované řádky jsou příprava na 3. a 4. ročník.

Odebrání balíčku ze seznamu ho ze stanic **taky odinstaluje** — seznam je
zdroj pravdy v obou směrech. Chráněné (`git`, `sudo`, `ca-certificates`,
`openssh-server`) zmizet nemůžou.

Změna se do už rozdaných žákovských VM dostane přes:
```bash
bash ~/os-lab/nastroje/priprava-stanice.sh
```

### `overeni-prostredi.sh`
Ověří, co ze statické analýzy nerozhodneme: který renderer řídí síť, jestli
v nepřivilegovaném kontejneru funguje WireGuard a `ufw`, jaký má LXD úložný
ovladač, jestli na `lxdbr0` běží vlastní `dnsmasq` a jestli je účet root
odemčený. Vytvoří si dočasný kontejner a na konci ho smaže.

### `test-fstab.sh`
⚠️ **Jediný destruktivní nástroj.** Záměrně rozbije `/etc/fstab`, aby se ověřilo,
že se jde dostat do nouzového shellu (předpoklad cvičení 4. ročníku).

**Nikdy přes SSH ani XRDP** bez konzolového přístupu — v nouzovém režimu neběží
síť. Skript vzdálenou relaci pozná a zastaví se. Před spuštěním udělej snapshot.

```bash
bash ~/os-lab/nastroje/test-fstab.sh stav      # co je teď v fstab
bash ~/os-lab/nastroje/test-fstab.sh rozbij    # ptá se na potvrzení
bash ~/os-lab/nastroje/test-fstab.sh oprav     # vrátí zpátky
```

## Až je hotovo

Po doběhnutí skriptu restartovat, zkontrolovat vzhled a schránku, VM vypnout
a exportovat do OVA. Nic dalšího v šabloně dělat netřeba.

**Cvičení v šabloně nezkoušej** — první spuštění uloží do stanice číslo žáka
a to by pak měla celá třída. Zkoušej na importované kopii.

Na každé stanici hned po importu udělat snapshot `cista-sablona` — z něj se
žák vrací, když si VM rozbije.
