#!/usr/bin/env python3
"""
Rozseká 'Laboratorní cvičení OS.docx' na Markdown soubory.

Spouštět ze složky, kde leží .docx:
    python3 ~/os-lab/nastroje/rozsekej-docx.py

Co dělá:
  Title            → nový soubor
  Heading1-4       → ## až #####
  font Courier New → bloky ```bash
  obrázky          → assets/ + odkaz v textu
  následně roztřídí do Linux/, Windows Server/, Windows Server - řešení/, Linux Server/

Původní .docx zůstává nedotčený a je závazný — tohle je pracovní kopie.
"""
import zipfile, re, os, io, shutil

DOCX = "Laboratorní cvičení OS.docx"
OUT  = "Laboratorní cvičení OS"

z   = zipfile.ZipFile(DOCX)
xml = z.read("word/document.xml").decode("utf-8", "ignore")

# ── obrázky: rId → soubor ───────────────────────────────────────────
rels = z.read("word/_rels/document.xml.rels").decode("utf-8", "ignore")
OBRAZKY = {m.group(1): "word/" + m.group(2)
           for m in re.finditer(r'Id="([^"]+)"[^>]*Target="(media/[^"]+)"', rels)}

os.makedirs(os.path.join(OUT, "assets"), exist_ok=True)
for rid, cesta in OBRAZKY.items():
    try:
        io.open(os.path.join(OUT, "assets", os.path.basename(cesta)), "wb").write(z.read(cesta))
    except KeyError:
        pass
print(f"  obrázků: {len(OBRAZKY)}")

def odescapuj(t):
    for a, b in [("&amp;","&"),("&lt;","<"),("&gt;",">"),("&quot;",'"'),("&apos;","'")]:
        t = t.replace(a, b)
    return t

def text_runu(run):
    t = "".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", run, re.S))
    t = odescapuj(re.sub(r"<[^>]+>", "", t))
    return t, bool(re.search(r'w:ascii="(Courier New|Roboto Mono)"', run))

odstavce = []
for m in re.finditer(r'<w:p [^>]*>((?:(?!</w:p>).)*?)</w:p>|<w:p/>', xml, re.S):
    blok = m.group(1) or ""
    st   = re.search(r'<w:pStyle w:val="([^"]+)"', blok)
    styl = st.group(1) if st else "Normal"

    obr = re.search(r'<a:blip[^>]*r:embed="([^"]+)"', blok)
    if obr and obr.group(1) in OBRAZKY:
        odstavce.append(("Obrazek", os.path.basename(OBRAZKY[obr.group(1)]), False))
        continue

    casti = [text_runu(r) for r in re.findall(r"<w:r[ >](?:(?!</w:r>).)*?</w:r>", blok, re.S)]
    text  = "".join(c[0] for c in casti).strip()
    mono  = sum(len(c[0]) for c in casti if c[1]) / (sum(len(c[0]) for c in casti) or 1) > 0.5
    odstavce.append((styl, text, mono))

# ── rozdělení na soubory ────────────────────────────────────────────
SEKCE = {"Prostředí pro cvičení","Síťové služby OS","Web Server Linux",
         "Nástroje pro řízení projektů","ITSM - systém GLPI",
         "Provozní monitoring pomocí Zabbix","Linux Server","Windows Server"}

soubory, akt, nazev, minuly = [], [], None, None
for styl, text, mono in odstavce:
    if styl == "Title" and text:
        if minuly and (text == minuly or minuly.startswith(text)
                       or re.sub(r'^\d+\.\s*','',minuly) == text):
            minuly = text; continue
        minuly = text
        if re.match(r'^\d+\.\s', text) or text in SEKCE or "_řešení" in text:
            if akt and nazev: soubory.append((nazev, akt))
            nazev, akt = text, []
            continue
    if nazev is None: continue
    if styl == "Obrazek":
        akt += ["", f"![]({{P}}assets/{text})", ""]; continue
    if not text:
        if akt and akt[-1] != "": akt.append("")
        continue
    if styl.startswith("Heading"):
        akt += ["", "#"*min(int(styl[-1])+1, 6) + " " + text, ""]
    elif mono:
        akt.append("```\n" + text)
    else:
        akt.append(text)
if akt and nazev: soubory.append((nazev, akt))

def sluc_kod(radky):
    ven, blok = [], []
    for r in radky:
        if r.startswith("```\n"):
            blok.append(r[4:])
        else:
            if blok: ven += ["", "```bash"] + blok + ["```", ""]; blok = []
            ven.append(r)
    if blok: ven += ["", "```bash"] + blok + ["```", ""]
    return ven

def sluc_vystupy(t):
    """Řádek mezi kódovými bloky, který nezačíná velkým písmenem, je výstup příkazu."""
    r, ven, i = t.split("\n"), [], 0
    while i < len(r):
        if (r[i].strip() == "```" and i+4 < len(r) and r[i+1].strip() == ""
                and r[i+3].strip() == "" and r[i+4].strip() == "```bash"
                and r[i+2].strip() and not r[i+2][:1].isupper()
                and not r[i+2].startswith(("#","-","|","*",">","!"))):
            ven.append(r[i+2]); i += 5; continue
        ven.append(r[i]); i += 1
    return "\n".join(ven)

poradi = 0
for nazev, radky in soubory:
    poradi += 1
    text, prazdny = [], False
    for r in sluc_kod(radky):
        if r == "":
            if not prazdny: text.append(r)
            prazdny = True
        else:
            text.append(r); prazdny = False
    obsah = "\n".join(text).strip()
    for _ in range(8):
        n = sluc_vystupy(obsah)
        if n == obsah: break
        obsah = n
    jmeno = re.sub(r'[/\\:]', '-', nazev).strip()
    if not re.match(r'^\d+\.', jmeno): jmeno = f"{poradi:02d}. {jmeno}"
    io.open(os.path.join(OUT, jmeno + ".md"), "w", encoding="utf-8").write(
        f"# {nazev}\n\n" + obsah + "\n")

# ── roztřídění do podsložek ─────────────────────────────────────────
LINUX = {f"{i:02d}." for i in range(1, 20)}
WS    = {"01. Instalace Windows Server 2019 a novější","02. Instalace a konfigurace ADDS",
         "03. Připojení koncové stanice do domény","04. Návrh struktury Organizačních jednotek",
         "05. Vzdálená správa Windows Serveru","06. Správa datových úložišť Windows Server",
         "07. Správa sdílení a oprávnění","08. DNS služby na Windows Server",
         "09. Instalace a konfigurace DHCP služby","10. Internet Information Services (IIS)",
         "11. Group Policy Object"}
LINUX_NAZVY = {"01. Úvod do OS Linux","02. Instalace Linuxu","03. Grafické uživatelské rozhraní",
  "04. Základní softwarové vybavení","05. Příkazový řádek","06. Práce se soubory a adresáři",
  "07. Správa místních uživatelů a skupin","08. Řízení přístupu k souborům",
  "09. Archivace a zálohování","10. Základy skriptování v Bash","11. Vzdálená správa serveru Linux",
  "12. Zabezpečení serveru Linux","13. Instalace a aktualizace softwarových balíčků",
  "14. Monitorování a správa procesů","15. Řízení služeb","16. Analýza a ukládání logů",
  "17. Správa síťových připojení","18. Správa datových úložišť Linux","19. Kontejnery"}

for d in ["Linux","Windows Server","Windows Server - řešení","Linux Server"]:
    os.makedirs(os.path.join(OUT, d), exist_ok=True)

for f in sorted(os.listdir(OUT)):
    if not f.endswith(".md"): continue
    zaklad, cil = f[:-3], None
    if zaklad in LINUX_NAZVY:      cil = "Linux"
    elif zaklad in WS:             cil = "Windows Server"
    elif "_řešení" in zaklad:      cil = "Windows Server - řešení"
    elif re.search(r'Web Server Linux|Nástroje pro řízení|GLPI|Zabbix|^\d+\. Linux Server', zaklad):
        cil = "Linux Server"
    if cil:
        novy = re.sub(r'^\d+\.\s+(PLWS|Web Server|Nástroje|ITSM|Provozní|Linux Server)', r'\1', zaklad)
        # v podsložce vede cesta k obrázkům o úroveň výš
        p = os.path.join(OUT, f)
        s = io.open(p, encoding="utf-8").read().replace("{P}assets/", "../assets/")
        io.open(p, "w", encoding="utf-8").write(s)
        shutil.move(p, os.path.join(OUT, cil, novy + ".md"))

for f in os.listdir(OUT):                       # zbytek v kořeni
    if f.endswith(".md"):
        p = os.path.join(OUT, f)
        s = io.open(p, encoding="utf-8").read().replace("{P}assets/", "assets/")
        io.open(p, "w", encoding="utf-8").write(s)

for st, no in [("01. Prostředí pro cvičení.md","00. Prostředí pro cvičení.md"),
               ("21. Síťové služby OS.md","Síťové služby OS.md"),
               ("22. Windows Server.md","Windows Server/00. Teorie — Windows Server.md")]:
    zdroj = os.path.join(OUT, st)
    if not os.path.exists(zdroj): continue
    # když soubor míří do podsložky, musí se prohloubit i cesta k obrázkům
    if "/" in no:
        s = io.open(zdroj, encoding="utf-8").read().replace("](assets/", "](../assets/")
        io.open(zdroj, "w", encoding="utf-8").write(s)
    shutil.move(zdroj, os.path.join(OUT, no))

pocet = sum(1 for _, _, fs in os.walk(OUT) for f in fs if f.endswith(".md"))
print(f"  souborů: {pocet}")
