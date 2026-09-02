#!/bin/bash
# 2/18 — katalog závad v oprávněních. Sdílí ho start.sh i check.sh.
# Čitelný záměrně, ze stejného důvodu jako u cvičení 2/13: kód, který závadu
# zavádí, tu být musí, takže by šifra chránila popisky, ne podstatu. Odolnost
# dělá to, že závada je v žákově systému a najít se musí tam.

LAB_KOREN="${LAB_KOREN:-$HOME/netlab/porucha}"
LAB_ZALOHY="${LAB_ZALOHY:-/var/backups/netlab-lab18}"
# Účet žáka. Závady kategorie C se zavádějí pod rootem, takže `id -un` by
# vrátilo root — jméno se proto předává z start.sh.
LAB_UCET="${LAB_UCET:-$(id -un)}"

# ══ A — práva adresáře ════════════════════════════════════════════
zaved_A1() { chmod 660 "$LAB_KOREN/sklad"; }                       # chybí x
opraveno_A1() { [ -x "$LAB_KOREN/sklad" ]; }
popis_A1() { echo "adresář sklad neměl právo vstupu (x), takže se do něj nedalo přejít"; }

zaved_A2() { chmod 330 "$LAB_KOREN/ucetni"; }                      # chybí r
opraveno_A2() { [ -r "$LAB_KOREN/ucetni" ]; }
popis_A2() { echo "adresář ucetni nešel vypsat — chybělo právo čtení (r)"; }

zaved_A3() { chmod 000 "$LAB_KOREN/vedeni"; }
opraveno_A3() { [ -r "$LAB_KOREN/vedeni" ] && [ -x "$LAB_KOREN/vedeni" ]; }
popis_A3() { echo "adresář vedeni neměl žádná práva"; }

# ══ B — práva souboru ═════════════════════════════════════════════
zaved_B1() { chmod 000 "$LAB_KOREN/sklad/cenik.txt"; }
opraveno_B1() { [ -r "$LAB_KOREN/sklad/cenik.txt" ]; }
popis_B1() { echo "soubor cenik.txt neměl žádná práva, nešel ani přečíst"; }

zaved_B2() { chmod 444 "$LAB_KOREN/ucetni/faktury.txt"; }
opraveno_B2() { [ -w "$LAB_KOREN/ucetni/faktury.txt" ]; }
popis_B2() { echo "soubor faktury.txt byl jen ke čtení, nešlo do něj zapsat"; }

zaved_B3() { chmod 600 "$LAB_KOREN/verejne/oznameni.txt"; }
# Stejná volnost jako u B1 a B2: rozhoduje, že soubor přečtou ostatní,
# ne přesné číslo. Dřív se vyžadovalo doslova 644, takže třeba 664 neprošlo.
opraveno_B3() { local m; m="$(stat -c %a "$LAB_KOREN/verejne/oznameni.txt" 2>/dev/null)"
                [ -n "$m" ] && (( (${m: -1} & 4) != 0 )); }
popis_B3() { echo "veřejné oznámení mělo práva jen pro vlastníka, ostatní ho nepřečetli"; }

# ══ C — vlastnictví ═══════════════════════════════════════════════
zaved_C1() { chgrp vedeni "$LAB_KOREN/sklad" 2>/dev/null; }
opraveno_C1() { [ "$(stat -c %G "$LAB_KOREN/sklad" 2>/dev/null)" = "sklad" ]; }
popis_C1() { echo "adresář sklad patřil skupině vedeni místo skupině sklad"; }

zaved_C2() { chgrp "$LAB_UCET" "$LAB_KOREN/ucetni" 2>/dev/null; }
opraveno_C2() { [ "$(stat -c %G "$LAB_KOREN/ucetni" 2>/dev/null)" = "ucetni" ]; }
popis_C2() { echo "adresář ucetni ztratil skupinu oddělení"; }

zaved_C3() { chgrp "$LAB_UCET" "$LAB_KOREN/tym" 2>/dev/null; }
opraveno_C3() { [ "$(stat -c %G "$LAB_KOREN/tym" 2>/dev/null)" = "vedeni" ]; }
popis_C3() { echo "sdílený adresář tym patřil špatné skupině"; }

# ══ D — rozšířené bity ════════════════════════════════════════════
zaved_D1() { chmod 0770 "$LAB_KOREN/tym"; }                        # setgid pryč
opraveno_D1() { local m; m="$(stat -c %a "$LAB_KOREN/tym" 2>/dev/null)"
                [ "${#m}" -eq 4 ] && (( (${m:0:1} & 2) != 0 )); }
popis_D1() { echo "sdílenému adresáři tym chyběl setgid, nové soubory nedědily skupinu"; }

zaved_D2() { chmod 0777 "$LAB_KOREN/odkladiste"; }                 # sticky pryč
opraveno_D2() { local m; m="$(stat -c %a "$LAB_KOREN/odkladiste" 2>/dev/null)"
                [ "${#m}" -eq 4 ] && (( (${m:0:1} & 1) != 0 )); }
popis_D2() { echo "odkladiště přišlo o sticky bit, uživatelé si mazali cizí soubory"; }

zaved_D3() { chmod 2660 "$LAB_KOREN/tym"; }                        # setgid bez x
opraveno_D3() { [ -x "$LAB_KOREN/tym" ]; }
popis_D3() { echo "adresář tym měl setgid, ale chybělo mu právo vstupu — ve výpisu velké S"; }

# ── výběr tří závad, každá z jiné kategorie ───────────────────────
lab18_vyber() {
  local kategorie=(A B C D) k v
  for k in $(lab_vyber 4 3 191); do
    v=$(lab_vyber 3 1 $(( 200 + k )))
    printf '%s%s\n' "${kategorie[$((k-1))]}" "$v"
  done
}
