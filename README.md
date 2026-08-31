# os-lab

Prostředí pro laboratorní cvičení předmětu **Operační systémy**.

Repozitář obsahuje skripty, které vám před každým cvičením postaví pracovní
prostředí, ověří splnění úkolů a po skončení práci uklidí. Samotná **zadání
cvičení** najdete na [eduxo.cz](https://www.eduxo.cz).

---

## Co k práci potřebujete

Virtuální stroj **Ubuntu Server 26.04 LTS** (s prostředím MATE) a nainstalovaným **LXD**, který dostanete
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

Každé cvičení má čtyři skripty. Číslo cvičení najdete v jeho zadání —
například `3/12` je dvanácté cvičení třetího ročníku.

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

U diagnostických cvičení tím dostanete **tutéž sadu závad znovu**, ne hotové
řešení — sada se odvozuje z vašeho čísla, takže je pro vás pokaždé stejná.

## Windowsová cvičení

Některá cvičení běží ve **windowsové virtuální stanici**, kde není bash ani
tenhle repozitář naklonovaný. Skripty se tam proto stahují jednotlivě.
Poznáte je podle písmene v čísle — `2/14a`, `2/18a`.

V PowerShellu **spuštěném jako správce**:

```powershell
mkdir C:\os-lab -Force
cd C:\os-lab
Invoke-WebRequest -UseBasicParsing `
  -Uri https://raw.githubusercontent.com/eduxo/os-lab/main/stahni.ps1 `
  -OutFile stahni.ps1
```

Než skript spustíte, **přečtěte si ho** (`notepad stahni.ps1`) — stahujete kód
z internetu a chystáte se ho pustit s právy správce. Pak:

```powershell
powershell -ExecutionPolicy Bypass -File .\stahni.ps1 -Cvic W1
cd C:\os-lab\2\14a-windows-start
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

Průběžná kontrola se spouští `-Krok N` místo `--krok N`:

```powershell
powershell -ExecutionPolicy Bypass -File .\check.ps1 -Krok 2
```

## Struktura repozitáře

```
os-lab/
  2/              cvičení 2. ročníku — základy operačního systému
  3/              cvičení 3. ročníku — servery a síťové služby
  4/              cvičení 4. ročníku — správa dat a identit
  lib/            sdílené funkce pro ověřovací skripty
                  lab-lib.sh   pro linuxová cvičení
                  lab-lib.ps1  pro windowsová cvičení
  stahni.ps1      stahovač skriptů do windowsové stanice
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
- **Sada závad u diagnostických cvičení je v repozitáři čitelná** (`poruchy.sh`).
  Zakódovat ji nemá smysl: kód, který závadu zavádí, tu být musí, takže by
  šifra chránila popisky, ne podstatu. Odolnost dělá to, že závada je v žákově
  běžícím systému a najít se musí tam. Seznam **zavedených** závad konkrétního
  žáka je proti tomu root-only.
- **Windowsová cvičení mají vlastní knihovnu** `lib/lab-lib.ps1` se stejným
  chováním i výstupem. Cílem je **Windows PowerShell 5.1**, ne PowerShell 7 —
  na Windows 11 je ve výchozím stavu jen ta první.

## Licence

MIT — viz [LICENSE](LICENSE). Použití, úpravy i sdílení jsou vítané;
pokud vám to k něčemu bude, dejte vědět.

Součást výukové platformy **eduxo** — [www.eduxo.cz](https://www.eduxo.cz)
