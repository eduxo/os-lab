# Šablona VM pro VirtualBox

Postup, kterým vznikne žákovská VM pro laby OS. Staví se **jednou**, exportuje
se do OVA a ten se importuje na každou stanici.

**Cílový stav:** Ubuntu Server 26.04 LTS (amd64) + prostředí MATE + LXD + Docker,
s předstaženými obrazy, aby hodina nezačínala stahováním.

> **Platí pro VirtualBox na školních x86 stanicích s Windows.** VM zůstává
> žákovi mezi hodinami (škola to drží přes profil), čistí se jen hostitelská
> stanice. Díky tomu funguje dvoubloková souborná práce 3/22 tak, jak je
> napsaná, a číslo žáka v `~/.os-lab-zak` přežije.

---

## 0. Než začneš — dvě věci, které umí zabít celý den

### Hyper-V na Windows

Když je na stanici zapnutý Hyper-V, VirtualBox **poběží, ale několikanásobně
pomaleji** — nepřebírá procesor, jen se veze na cizím hypervizoru. Nepozná se to
podle chybové hlášky, jen podle toho, že je všechno pomalé; ve stavovém řádku
okna VM se objeví ikona želvy.

Zapíná ho i to, co jako virtualizace nevypadá: **WSL2**, **Windows Sandbox**,
**Virtual Machine Platform**, **Memory Integrity** (Zabezpečení Windows →
Zabezpečení zařízení → Izolace jádra) a **Credential Guard**.

Ověř na stanici (`Win+R` → `msinfo32`), řádek úplně dole:

| Co tam stojí | Znamená |
|---|---|
| „Byl zjištěn hypervizor. Funkce…" | ❌ Hyper-V běží, VirtualBox bude pomalý |
| „Virtualizace povolena ve firmwaru: Ano" | ✅ tohle je to, co chceš vidět |

Vypnout se to dá takhle (vyžaduje restart):

```powershell
bcdedit /set hypervisorlaunchtype off
dism /Online /Disable-Feature:Microsoft-Hyper-V-All /NoRestart
```

Memory Integrity se vypíná v GUI, `bcdedit` na ni nestačí.

> Tohle je věc pro správce školní sítě, ne pro tebe v hodině. **Zjisti to dřív,
> než rozdáš třicet OVA souborů.**

### Virtualizace v BIOSu

VT-x / AMD-V musí být v BIOSu zapnuté, jinak VirtualBox 64bitového hosta
vůbec nenabídne.

**Vnořená virtualizace (nested VT-x) potřeba NENÍ.** LXD i Docker jsou
kontejnery — sdílejí jádro hostitele a vlastní procesor nepotřebují. Kdyby
někdo tvrdil opak, mýlí se.

---

## 1. Parametry VM

| Položka | Hodnota | Proč |
|---|---|---|
| Název | `eduxo Ubuntu` | |
| Typ | Linux / Ubuntu (64-bit) | |
| Paměť | **6144 MB** | MATE ~800 MB + dva kontejnery + Docker, s rezervou |
| Procesory | **2** | |
| Disk | **100 GB, VDI, dynamicky alokovaný** | viz níže |
| Grafika | VMSVGA, **128 MB** videopaměti | MATE s 16 MB nenaběhne pořádně |
| 3D akcelerace | **vypnutá** | s MATE dělá artefakty, k ničemu tu není |
| Síť — Adaptér 1 | **NAT** | vše se děje uvnitř VM; nezatěžuje školní síť třiceti adresami |
| Síť — Adaptér 2 | **Vnitřní síť** | pro cvičení 3/01: druhá síťovka bez adresy, na kterou žák nastaví statickou adresu. Bez DHCP, takže zůstane volná |
| Adresa VM | `10.0.2.15/24` z DHCP | tu dává NAT engine VirtualBoxu, je stejná na všech stanicích a je to v pořádku |
| Paravirtualizace | KVM | |

**Proč 100 GB:** samotné úložiště LXD je btrfs **v souboru o 25 GiB**
(`lxd init` ho zakládá s `size: 25GiB`), k tomu Ubuntu Server ~3 GB, MATE
~2,5 GB, obraz kontejnerů, obrazy Dockeru a místo na růst. Minimum je 60 GB,
100 dává rezervu na celý rok.

> **Pozor na past instalátoru:** na 100GB disku vyrobí LVM svazek jen asi
> **48 GB** a zbytek nechá ve skupině ležet ladem. `priprava-stanice.sh` to
> v kroku 2 pozná a rozšíří na celý disk za provozu, bez restartu. Nemusíš
> s tím nic dělat — jen se nelekni, když `df -h` hned po instalaci ukáže půlku.

> ⚠️ **Dynamický disk roste, ale sám se nezmenší.** Po stavbě má soubor VDI
> zhruba 14–18 GB a během roku poroste. Když VM leží v žákovském profilu,
> **ověř se správcem, že se to do kvóty vejde** — je to jediná věc v celé
> stavbě, kterou nevyřešíš sám a která se projeví až za pár měsíců.

---

## 2. Instalace Ubuntu Serveru

Stáhni **Ubuntu Server 26.04 LTS, amd64** (ne Desktop — MATE doinstaluje
skript, Desktop by přitáhl balík věcí navíc).

Volby v instalátoru:

| Krok | Nastav |
|---|---|
| Jazyk instalátoru | English |
| Rozložení klávesnice | cokoli — skript nastaví češtinu + US, viz poznámka |
| Typ instalace | Ubuntu Server (ne minimized) |
| Síť | nechat na DHCP |
| Proxy, zrcadlo | nechat prázdné / výchozí |
| Disk | **Use an entire disk** + **Set up this disk as an LVM group** |
| Šifrování disku (LUKS) | **nezaškrtávat** — chtělo by heslo při každém startu |
| Jméno serveru | `ubuntu` |
| Uživatel | **`sysadmin`** — `priprava-stanice.sh` s tím jménem počítá |
| Upgrade to Ubuntu Pro | Skip |
| OpenSSH server | **nezaškrtávat** — doinstaluje ho `priprava-stanice.sh` ze `balicky.txt` |
| Featured snaps | nic |

> **Heslo stanice** si zvol jaké chceš, ale **nikdy ho nepiš do repozitáře** —
> platí pro něj totéž pravidlo jako pro všechno ostatní. Hesla do kontejnerů
> se losují na stanici a zůstávají na ní, v `os-labu` po nich není stopa.

> **Účet `sysadmin` je na stanici i v kontejnerech.** Není to nedopatření:
> odlišuje je jméno stroje v promptu (`sysadmin@ubuntu` proti
> `sysadmin@web-07`) a přesně tohle má 3. ročník žáky učit sledovat —
> každý krok zadání říká, na kterém stroji se provádí.

> **Klávesnici ani jazyk v instalátoru neřeš.** Skript nastaví klávesnici
> na **českou jako výchozí a anglickou (US) jako druhou** (přepínání Alt+Shift)
> a jazyk na **angličtinu s britským formátem data a času** (24 hodin) — bez
> ohledu na to, co se v instalátoru zvolilo.

Po instalaci **nezapomeň odpojit ISO** (Zařízení → Optické mechaniky →
Odstranit disk z jednotky), jinak se VM bude pořád bootovat z instalátoru.

---

## 3. Stavba prostředí

Stáhne se **jediný soubor**. Git ani repozitář předem mít nemusíš — skript
si je obstará sám:

```bash
curl -fsSL https://raw.githubusercontent.com/eduxo/os-lab/main/nastroje/priprava-stanice.sh -o priprava-stanice.sh
less priprava-stanice.sh      # podívej se, co pouštíš
bash priprava-stanice.sh
```

Celé to trvá desítky minut a stahuje stovky MB.

> Kdyby na stanici nebyl ani `curl`, jde totéž ručně:
> `sudo apt update && sudo apt install -y git && git clone https://github.com/eduxo/os-lab.git ~/os-lab && bash ~/os-lab/nastroje/priprava-stanice.sh`

Od druhého spuštění ho pouštěj rovnou z repozitáře
(`bash ~/os-lab/nastroje/priprava-stanice.sh`) — je tam vždy nejnovější verze
a skript si ho sám aktualizuje.

Skript se ptá jen na tři věci — jestli rozšířit kořenový svazek na celý disk,
jestli doinstalovat MATE a jaké má být heslo roota. Zbytek udělá sám: balíčky
ze `balicky.txt`, **vzhled eduxo** (pozadí plochy i přihlašovací obrazovky,
motiv Yaru-blue, domovská stránka Firefoxu), **doplňky hypervizoru** (pozná
VirtualBox sám, zapne multiverse a vezme `virtualbox-guest-utils`), LXD
s btrfs, síť `netlab`, obraz `ubuntu-26.04` do lokální cache a obrazy Dockeru.
Stažená kopie skriptu se na konci sama smaže.

Po doběhnutí stanici **vypni a exportuj** — nic dalšího v šabloně dělat
nemusíš. Všechno, co skript nastavil, se projeví při prvním startu.

> **Cvičení v šabloně nezkoušej.** První spuštění kteréhokoli cvičení uloží do
> stanice tvoje číslo žáka (`~/.os-lab-zak`) a to by pak měla celá třída.
> Zkoušej na **importované kopii** — tu po zkoušce klidně smaž.

Na té kopii pak:

```bash
bash ~/os-lab/nastroje/overeni-prostredi.sh
cd ~/os-lab/3-lin/16-web-server && ./start.sh && ./check.sh
cd ~/os-lab/3-lin/21-docker      && ./start.sh && ./check.sh
```

První příkaz ověří předpoklady (hlavně jestli v kontejneru funguje `ufw`, na
kterém stojí cvičení 13, 18 i souborná práce), druhý LXD, síť, SSH
a kontejnerový obraz, třetí Docker.

---

## 4. Export a rozdání

Na hostiteli, s vypnutou VM:

```powershell
VBoxManage export "os-lab-sablona" -o os-lab-sablona.ova --ovf20
```

Nebo v GUI: Soubor → Exportovat appliance.

Na každé stanici pak import:

```powershell
VBoxManage import os-lab-sablona.ova --vsys 0 --vmname "os-lab"
```

> **MAC adresy** řešit nemusíš, ani při importu s volbou „generovat nové MAC
> adresy". Instalátor Ubuntu zapisuje síťovku podle MAC adresy a po takovém
> importu by se nenašla — `priprava-stanice.sh` ji proto přepíše na jméno
> rozhraní (`enp0s3`).

**Hned po importu udělej snapshot `cista-sablona`.** Je to jediná záchrana,
když si žák VM rozbije — a u VM, která má vydržet celý rok, se to stane.

---

## 5. Rituál začátku hodiny

Žák po přihlášení do VM:

```bash
cd ~/os-lab && git pull
```

Číslo žáka se drží v `~/.os-lab-zak`, takže se na něj skripty zeptají jen
poprvé. Když si sedne k cizí stanici nebo dostane novou VM, soubor smaže a
skript se zeptá znovu.

---

## Co zbývá ověřit

Tenhle postup vznikl proti dokumentaci a proti skriptům, **ne na postavené VM**.
Až ho projdeš, oprav tady, co nesedělo:

1. ~~Jestli je v obrazu 26.04 multiverse zapnuté.~~ **Ověřeno 2026-09-16 na
   školní šabloně: NENÍ.** Skript ho teď zapíná sám. Ve VirtualBoxu je navíc
   potřeba ručně přepnout **Zařízení → Sdílená schránka → Obousměrná**.
1b. **Automatické přizpůsobení obrazovky — ověřeno 2026-09-16: samo nefunguje.**
   Hostitel VirtualBox 7.1.12, doplňky z Ubuntu 7.2.6. Nová velikost okna do
   stanice dorazí (`xrandr` ji ukáže s `+`), ale nepoužije se. Skript proto
   přidává hlídač `/usr/local/bin/eduxo-obrazovka`, který ji použije. **Po
   přechodu školy na VirtualBox 7.2.6** vyzkoušej, jestli to funguje i bez
   něj — hlídač pak nemá co dělat a klidně může zůstat.
1c. **Síť na šabloně s druhou síťovkou** — `networkctl` musí u `enp0s3`
   hlásit `configured` a u druhé síťovky (`enp0s8`) `unmanaged` bez adresy.
   A doslovný výstup `sudo netplan get` po úpravě skriptem: zadání 3/01
   ukazuje v Kroku 1 ukázku, u které pořadí řádků není ověřené.
2. **Jestli je modul `vboxguest` v jádře** (`modinfo vboxguest`). Skript to
   kontroluje a poradí `linux-modules-extra`, ale nevyzkoušeno to je.
3. **Kolik po stavbě zabírá soubor VDI** — a jestli se to vejde do žákovského
   profilu. Odhad 14–18 GB je počítaný, ne měřený.
4. **Jestli 4096 MB stačí** na lab 15 (dva kontejnery naráz) současně s MATE.
5. **Jak dlouho trvá celá příprava** — kvůli plánu, kdy ji stihneš udělat.
6. **Jestli `overeni-prostredi.sh` projde `ufw` v kontejneru.** Visí to jako
   otevřené od bloku D a stojí na tom tři cvičení.
