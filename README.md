# os-lab

Prostředí pro laboratorní cvičení předmětu **Operační systémy**.

Repozitář obsahuje skripty, které vám před každým cvičením postaví pracovní
prostředí, ověří splnění úkolů a po skončení práci uklidí. Samotná **zadání
cvičení** najdete na [eduxo.cz](https://www.eduxo.cz).

---

## Co k práci potřebujete

Virtuální stroj **Ubuntu MATE 24.04 LTS** s nainstalovaným **LXD**, který dostanete
od vyučujícího. Uvnitř něj běží vaše laboratoř — jednotlivá cvičení se odehrávají
v kontejnerech, které si skripty vytvoří a zase smažou.

Ve virtuálním stroji nic neinstalujte ručně, dokud vás o to zadání nepožádá.

## První spuštění

Ve virtuálním stroji otevřete terminál a repozitář si jednou naklonujte:

```bash
git clone https://github.com/eduxo/os-lab.git ~/os-lab
```

Tím vznikne složka `~/os-lab`, se kterou budete pracovat celý školní rok.

## Před každým cvičením

**Vždy si nejdřív stáhněte aktuální verzi.** Skripty se v průběhu roku opravují
a doplňují — bez tohoto kroku můžete pracovat se starou verzí:

```bash
cd ~/os-lab && git pull
```

Zvykněte si na to. Je to přesně to, co dělá správce, který přebírá konfigurace
ze společného repozitáře.

## Práce s cvičením

Každé cvičení má tři skripty. Číslo cvičení najdete v jeho zadání — například
`3/12` je dvanácté cvičení třetího ročníku.

```bash
cd ~/os-lab/3/12-sluzba-nenabehla

./start.sh      # postaví prostředí — kontejnery, disky, účty
./check.sh      # ověří, co už máte hotové
./stop.sh       # uklidí po skončení práce
```

### Průběžná kontrola

Nemusíte čekat na konec hodiny. Po každé části cvičení si můžete ověřit,
jestli jste na správné cestě:

```bash
./check.sh --krok 2
```

Výstup vypadá takhle:

```
[PASS] uživatel novak17 existuje a je ve skupině ucetni
[FAIL] adresář /srv/data nemá nastavený setgid bit
```

Řádky `[FAIL]` říkají, co ještě chybí. **Nejsou to chyby, kterých byste se měli
bát** — jsou to vaše zbývající úkoly.

### Když si prostředí rozbijete

To se stává a je to v pořádku — od toho laboratoř je. Vrátit se do výchozího
stavu můžete kdykoli:

```bash
./reset.sh
```

U diagnostických cvičení tím dostanete **novou sadu závad**, ne hotové řešení.

## Struktura repozitáře

```
os-lab/
  2/              cvičení 2. ročníku — základy operačního systému
  3/              cvičení 3. ročníku — servery a síťové služby
  4/              cvičení 4. ročníku — správa dat a identit
  lib/            sdílené funkce pro ověřovací skripty
```

Do složky `lib/` chodit nemusíte — obsahuje jen společné funkce, které
skripty používají uvnitř.

---

## Pro vyučující

### Přidání nového cvičení

Každé cvičení je samostatná složka `<ročník>/<číslo>-<název>/` se skripty
`start.sh`, `check.sh`, `stop.sh` a `reset.sh`.

Ověřovací skripty stojí na sdílené knihovně `lib/lab-lib.sh`, takže `check.sh`
jednoho cvičení je jen seznam požadavků:

```bash
source "$(dirname "$0")/../../lib/lab-lib.sh"

require_user      "novak$ZAK"
require_member    "novak$ZAK" ucetni
require_setgid    /srv/data
negative_no_777   /srv/data

vypis_souhrn
```

Díky tomu vypadají všechna cvičení stejně a případná oprava se dělá na jednom
místě, ne v šedesáti skriptech.

### Zásady

- **`start.sh` uvede systém do výchozího stavu nezávisle na tom, co žák dělal
  minule.** Cvičení na sebe navazují látkou, ne stavem stroje — kdo chyběl,
  musí být schopen pokračovat.
- **Úkoly jsou odvozené od čísla žáka** (`$ZAK`) — jména účtů, adresy i velikosti
  se u každého liší, takže cizí řešení neprojde.
- **Sada závad u diagnostických cvičení je v repozitáři zakódovaná.** Ne kvůli
  utajení, ale aby řešení nebylo na dosah jedním pohledem do skriptu.

## Licence

MIT — viz [LICENSE](LICENSE). Použití, úpravy i sdílení jsou vítané;
pokud vám to k něčemu bude, dejte vědět.

Součást výukové platformy **eduxo** — [www.eduxo.cz](https://www.eduxo.cz)
