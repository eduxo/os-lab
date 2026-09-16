# Nástroje pro stavbu prostředí

Skripty, kterými se připraví a ověří stanice. **Nejsou to cvičení** — spouští
je vyučující při stavbě šablony, ne žáci v hodině.

## Postup na čisté instalaci

Výchozí stav: **Ubuntu Server 26.04 LTS** (x86_64 na školní stanici,
arm64 na vývojové VM — postup je stejný).

> **Stavíš celou žákovskou VM od nuly?** Tenhle seznam je jen jádro postupu.
> Celá cesta — parametry VM, volby instalátoru, past s Hyper-V, úklid před
> exportem a rozdání na stanice — je ve **[VM-virtualbox.md](VM-virtualbox.md)**.

```bash
sudo apt update && sudo apt install -y git   # na čerstvém Serveru git není
git clone https://github.com/eduxo/os-lab.git ~/os-lab

bash ~/os-lab/nastroje/priprava-stanice.sh    # 1. připraví systém
# odhlásit a znovu přihlásit (skupina lxd)
bash ~/os-lab/nastroje/overeni-prostredi.sh   # 2. ověří předpoklady
```

### `priprava-stanice.sh`
Kroky: aktualizace systému · **rozšíření kořenového svazku na celý disk** ·
**prostředí MATE** (`ubuntu-mate-core`, ptá se — stahuje stovky MB) · nástroje pro
laby · **doplňky hypervizoru** · **LXD** s úložištěm btrfs · inicializace LXD ·
izolovaná síť `netlab` pro cvičení s DNS a DHCP · předstažení obrazu kontejnerů
a obrazů Dockeru do lokální cache · nastavení hesla roota.

> **Doplňky hypervizoru (krok 4b)** se řídí tím, co vrátí `systemd-detect-virt`:
> ve VirtualBoxu `virtualbox-guest-utils` + `-x11` (z **multiverse**), ve VMware
> `open-vm-tools`. Balíčky z Ubuntu jsou lepší než ISO s Guest Additions —
> nic se nepřekládá a přežijí aktualizaci jádra. Bez nich nefunguje schránka
> mezi hostitelem a hostem ani automatické rozlišení.

> **K čemu je rozšíření svazku:** instalátor Ubuntu Serveru vytvoří LVM svazek
> jen na část disku — na 100GB disku typicky 48 GB — a zbytek nechá ve skupině
> ležet. Bez rozšíření dojde místo uprostřed roku, až porostou obrazy kontejnerů
> a snapshoty. Skript to pozná a nabídne opravu; běží za provozu, bez restartu.

Je idempotentní — opakované spuštění jen doplní, co chybí.

### `balicky.txt`
Seznam balíčků, které musí být v šabloně. Čte ho `priprava-stanice.sh`.
**Nové cvičení = nový řádek sem**, i s poznámkou, který lab balíček potřebuje.
Zakomentované řádky jsou příprava na 3. a 4. ročník.

Doplnění se do už rozdaných žákovských VM dostane přes:
```bash
cd ~/os-lab && git pull && bash nastroje/priprava-stanice.sh
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

Šablonu je potřeba **před exportem uklidit** — hlavně smazat `~/.os-lab-zak`
a `~/.ssh/id_*`, jinak má celá třída stejné číslo žáka i stejný privátní klíč.
Úplný seznam je ve [VM-virtualbox.md](VM-virtualbox.md), oddíl „Úklid před
exportem".

Pak VM vypnout, exportovat do OVA a na každé stanici hned po importu udělat
snapshot `cista-sablona` — z něj se žák vrací, když si VM rozbije.
