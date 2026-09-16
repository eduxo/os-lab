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
| Název | `os-lab-sablona` | |
| Typ | Linux / Ubuntu (64-bit) | |
| Paměť | **4096 MB** (6144, když má stanice 16 GB) | MATE ~800 MB + dva kontejnery + Docker |
| Procesory | **2** | |
| Disk | **60 GB, VDI, dynamicky alokovaný** | viz níže |
| Grafika | VMSVGA, **128 MB** videopaměti | MATE s 16 MB nenaběhne pořádně |
| 3D akcelerace | **vypnutá** | s MATE dělá artefakty, k ničemu tu není |
| Síť | **NAT** | vše se děje uvnitř VM; nezatěžuje školní síť třiceti adresami |
| Paravirtualizace | KVM | |

**Proč 60 GB:** samotné úložiště LXD je btrfs **v souboru o 25 GiB**
(`lxd init` ho zakládá s `size: 25GiB`), k tomu Ubuntu Server ~3 GB, MATE
~2,5 GB, obraz kontejnerů, obrazy Dockeru a místo na růst. Se 40 GB dojde
místo uprostřed roku.

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
| Rozložení klávesnice | **English (US)** — viz poznámka |
| Typ instalace | Ubuntu Server (ne minimized) |
| Síť | nechat na DHCP |
| Proxy, zrcadlo | nechat prázdné / výchozí |
| Disk | **Use an entire disk** + **Set up this disk as an LVM group** |
| Šifrování disku (LUKS) | **nezaškrtávat** — chtělo by heslo při každém startu |
| Jméno serveru | `os-lab` |
| Uživatel | `zak` (na jménu nic nezávisí, ale ať je všude stejné) |
| Upgrade to Ubuntu Pro | Skip |
| OpenSSH server | **nezaškrtávat** — doinstaluje ho `priprava-stanice.sh` ze `balicky.txt` |
| Featured snaps | nic |

> **Klávesnice:** volím US, protože se celý rok píše v terminálu a znaky
> `/ \ | ~ { }` jsou na české klávesnici přes `AltGr` nebo vůbec. Žáci za to
> zaplatí prohozeným `y`/`z`. Když to rozhodneš jinak, přepni v MATE
> (Systém → Předvolby → Klávesnice → Rozložení) a v tomhle souboru to oprav —
> jinak se to rozejde s tím, co uvidí ve třídě.

Po instalaci **nezapomeň odpojit ISO** (Zařízení → Optické mechaniky →
Odstranit disk z jednotky), jinak se VM bude pořád bootovat z instalátoru.

---

## 3. Stavba prostředí

Na čerstvém Serveru **není `git`** — instalátor ho nedává:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/eduxo/os-lab.git ~/os-lab
```

Pak samotná příprava. Trvá desítky minut a stahuje stovky MB:

```bash
bash ~/os-lab/nastroje/priprava-stanice.sh
```

Skript se ptá jen na dvě věci — jestli doinstalovat MATE a jaké má být heslo
roota. Zbytek udělá sám: rozšíří kořenový svazek na celý disk, doinstaluje
balíčky ze `balicky.txt`, **doplňky hypervizoru** (pozná VirtualBox sám a vezme
`virtualbox-guest-utils` z multiverse — nic se nepřekládá a přežije to
aktualizaci jádra), LXD s btrfs, síť `netlab`, obraz `ubuntu-26.04` do lokální
cache a obrazy Dockeru.

**Odhlas se a přihlas znovu** — jinak se neprojeví členství ve skupinách
`lxd` a `docker`.

```bash
bash ~/os-lab/nastroje/overeni-prostredi.sh
```

Tohle je ta část, kvůli které má každý blok labů v kartách seznam „Nutno ověřit
před odučením". Projdi jeho výstup řádek po řádku — hlavně jestli v
nepřivilegovaném kontejneru funguje `ufw`, protože na tom stojí cvičení 13, 18
i souborná práce.

### Rychlá zkouška, že to opravdu žije

```bash
cd ~/os-lab/3-lin/16-web-server && ./start.sh && ./check.sh
cd ~/os-lab/3-lin/21-docker      && ./start.sh && ./check.sh
```

První ověří LXD, síť, SSH a kontejnerový obraz; druhý Docker. Pak po sobě ukliď:

```bash
cd ~/os-lab/3-lin/16-web-server && ./reset.sh   # potvrdit
lxc list        # musí být prázdné
docker ps -a    # musí být prázdné
```

---

## 4. Úklid před exportem

**Tohle je nejdůležitější krok celého postupu.** Co zůstane v šabloně, to bude
mít třicet žáků stejné.

```bash
# 1. Číslo žáka — jinak je celá třída „žák 7" a všichni si sáhnou na týž kontejner
rm -f ~/.os-lab-zak

# 2. SSH klíč — cvičení 3/04 si ho žák vyrábí sám; sdílený privátní klíč
#    v šabloně je nesmysl a to cvičení by nedávalo smysl
rm -f ~/.ssh/id_* ~/.ssh/known_hosts

# 3. Nic nesmí zůstat běžet
lxc list && docker ps -a          # obojí prázdné

# 4. Identita stroje — ať si ji každá kopie vygeneruje vlastní
sudo truncate -s0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# 5. Balíčkovou cache pryč a volné místo vynulovat — OVA se pak zabalí
#    na zlomek velikosti (disk se dočasně zaplní, to je v pořádku)
sudo apt-get clean
sudo dd if=/dev/zero of=/EMPTY bs=1M status=progress; sudo rm -f /EMPTY; sync

# 6. Historie příkazů AŽ NAKONEC a s vypnutým zápisem — jinak by ji
#    odhlášení zapsalo znovu i s celým tímhle úklidem
unset HISTFILE
cat /dev/null > ~/.bash_history && history -c

sudo poweroff
```

> Pořadí u posledního bodu není kosmetika: kdybys historii mazal dřív, bash by
> ji při odhlášení zapsal znovu — a byl by v ní i tenhle úklid.

---

## 5. Export a rozdání

Na hostiteli, s vypnutou VM:

```powershell
VBoxManage export "os-lab-sablona" -o os-lab-sablona.ova --ovf20
```

Nebo v GUI: Soubor → Exportovat appliance.

Na každé stanici pak import:

```powershell
VBoxManage import os-lab-sablona.ova --vsys 0 --vmname "os-lab"
```

> **MAC adresy** řešit nemusíš, dokud zůstaneš u NATu — každá VM má vlastní
> NAT engine a na sdílené L2 se nikdy nepotkají. Kdybys někdy přepnul na
> Bridged, pak ano: v dialogu importu zvol „Generovat nové MAC adresy pro
> všechny síťové karty".

**Hned po importu udělej snapshot `cista-sablona`.** Je to jediná záchrana,
když si žák VM rozbije — a u VM, která má vydržet celý rok, se to stane.

---

## 6. Rituál začátku hodiny

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

1. **Jestli je v obrazu 26.04 multiverse zapnuté.** Bez něj krok 4b jen varuje
   a schránka nefunguje. Ověřeno je, že `virtualbox-guest-utils` v 26.04
   (resolute) existuje — že je repozitář po instalaci zapnutý, ne.
2. **Jestli je modul `vboxguest` v jádře** (`modinfo vboxguest`). Skript to
   kontroluje a poradí `linux-modules-extra`, ale nevyzkoušeno to je.
3. **Kolik po stavbě zabírá soubor VDI** — a jestli se to vejde do žákovského
   profilu. Odhad 14–18 GB je počítaný, ne měřený.
4. **Jestli 4096 MB stačí** na lab 15 (dva kontejnery naráz) současně s MATE.
5. **Jak dlouho trvá celá příprava** — kvůli plánu, kdy ji stihneš udělat.
6. **Jestli `overeni-prostredi.sh` projde `ufw` v kontejneru.** Visí to jako
   otevřené od bloku D a stojí na tom tři cvičení.
