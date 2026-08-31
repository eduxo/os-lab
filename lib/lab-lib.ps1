# lab-lib.ps1 — sdílené funkce ověřovacích skriptů pro windowsová cvičení.
#
# Druhá kolej vedle lab-lib.sh. Windows VM nemá bash ani naklonovaný
# repozitář, takže se sem check.ps1 stahuje jednotlivě přes Invoke-WebRequest.
# Výstup i chování schválně kopíruje linuxovou knihovnu: [PASS]/[FAIL],
# průběžné kontroly přes -Krok N, na konci otisk k odevzdání.
#
# Používá se v check.ps1 každého cvičení:
#     . "$PSScriptRoot\lab-lib.ps1"
#     Krok 1 "Prostředí"
#     RequireUzivatel "novak05"
#     VypisSouhrn

$Global:LabPass = 0
$Global:LabFail = 0
$Global:LabKrokAktualni = 0
$Global:LabKrokFiltr = 0        # 0 = kontrolovat všechno

# ───────────────────────────────────────────── číslo žáka
# Ptáme se jednou a pamatujeme si — stejně jako na Linuxu. Soubor leží
# v profilu žáka, takže o něm ví a umí ho opravit.
function ZjistiZaka {
    $soubor = Join-Path $env:USERPROFILE '.os-lab-zak'
    $cislo = $null
    if (Test-Path $soubor) {
        $cislo = (Get-Content $soubor -First 1) -replace '\D', ''
    }
    while (-not $cislo -or [int]$cislo -lt 1 -or [int]$cislo -gt 40) {
        Write-Host ''
        $vstup = Read-Host '  Zadejte své číslo v třídním výkazu (1-40)'
        $cislo = $vstup -replace '\D', ''
        if ($cislo -and [int]$cislo -ge 1 -and [int]$cislo -le 40) {
            '{0:d2}' -f [int]$cislo | Set-Content $soubor
            Write-Host "  Uloženo do $soubor — příště se už ptát nebudu."
            Write-Host '  (Kdyby se číslo neshodovalo s výkazem, soubor smažte.)'
            Write-Host ''
        } else { $cislo = $null }
    }
    $Global:ZAK  = [int]$cislo
    $Global:ZAK2 = '{0:d2}' -f $Global:ZAK
    # Odvozené hodnoty. Pozor: účet se ZÁMĚRNĚ nejmenuje novakXX jako na
    # Linuxu — tam je novakXX firemní identita žáka (klíč GPG, výzva shellu),
    # kdežto tady je to obsluha skladu, tedy někdo jiný. Se stejným jménem
    # by si žák v cvičení o NTFS zakazoval přístup „sám sobě".
    $Global:ZakUzivatel = "obsluha$($Global:ZAK2)"
    $Global:ZakSpravce  = "sprava$($Global:ZAK2)"
    $Global:ZakSkupina  = "sklad$($Global:ZAK2)"
    $Global:ZakStanice  = "NETLAB-$($Global:ZAK2)"
}

# ───────────────────────────────────────────── výpis výsledků
function Zapis([string]$stav, [string]$text) {
    if ($Global:LabKrokFiltr -ne 0 -and $Global:LabKrokAktualni -ne $Global:LabKrokFiltr) { return }
    if ($stav -eq 'PASS') {
        $Global:LabPass++
        Write-Host '  [PASS] ' -ForegroundColor Green -NoNewline; Write-Host $text
    } else {
        $Global:LabFail++
        Write-Host '  [FAIL] ' -ForegroundColor Red -NoNewline; Write-Host $text
    }
}
# Náhrada za ternární operátor — ten umí až PowerShell 7, ale Windows 11
# má ve výchozím stavu Windows PowerShell 5.1. Skripty musí běžet i tam.
function Nebo($hodnota, $nahrada) { if ($hodnota) { $hodnota } else { $nahrada } }

function Uspech([string]$t) { Zapis 'PASS' $t }
function Chyba([string]$t)  { Zapis 'FAIL' $t }
function Poznamka([string]$t) {
    if ($Global:LabKrokFiltr -ne 0 -and $Global:LabKrokAktualni -ne $Global:LabKrokFiltr) { return }
    Write-Host "         $t" -ForegroundColor DarkYellow
}
function Krok([int]$cislo, [string]$nazev) {
    $Global:LabKrokAktualni = $cislo
    if ($Global:LabKrokFiltr -ne 0 -and $cislo -ne $Global:LabKrokFiltr) { return }
    Write-Host ''
    Write-Host "── Část $cislo — $nazev" -ForegroundColor White
}

# ═════════════════════════════════════════════ kontrolní funkce

function RequirePath([string]$cesta, [string]$popisPass, [string]$popisFail) {
    if (Test-Path -LiteralPath $cesta) { Uspech (Nebo $popisPass "existuje $cesta") }
    else { Chyba (Nebo $popisFail "chybí: $cesta") }
}

function RequireUzivatel([string]$jmeno, [string]$popis) {
    if (Get-LocalUser -Name $jmeno -ErrorAction SilentlyContinue) {
        Uspech (Nebo $popis "místní účet $jmeno existuje")
    } else { Chyba "místní účet $jmeno neexistuje" }
}

# Vestavěné skupiny se hledají podle SID, ne podle jména — na lokalizovaných
# Windows se jmenují jinak (Administrators → Správci, Users → Uživatelé)
# a hledání podle jména by tiše selhalo.
function SkupinaPodleSID([string]$sid) {
    try { (Get-LocalGroup -SID $sid -ErrorAction Stop).Name } catch { $null }
}

function RequireClenSkupiny([string]$jmeno, [string]$skupina, [string]$popis) {
    $clenove = @()
    try { $clenove = (Get-LocalGroupMember -Group $skupina -ErrorAction Stop).Name } catch { }
    # Členství se vypisuje jako STANICE\jmeno, porovnáváme jen část za zpětným lomítkem.
    if ($clenove | Where-Object { ($_ -split '\\')[-1] -eq $jmeno }) {
        Uspech (Nebo $popis "$jmeno je ve skupině $skupina")
    } else { Chyba "$jmeno není ve skupině $skupina" }
}

function RequireNeClenSkupiny([string]$jmeno, [string]$skupina, [string]$popis) {
    $clenove = @()
    try { $clenove = (Get-LocalGroupMember -Group $skupina -ErrorAction Stop).Name } catch { }
    if ($clenove | Where-Object { ($_ -split '\\')[-1] -eq $jmeno }) {
        Chyba "$jmeno je ve skupině $skupina — zadání to nechtělo"
    } else { Uspech (Nebo $popis "$jmeno není ve skupině $skupina") }
}

# Hodnota za klíčem ve formuláři „klic: hodnota" — stejný tvar jako na Linuxu.
function Zaznam([string]$soubor, [string]$klic) {
    if (-not (Test-Path -LiteralPath $soubor)) { return '' }
    $r = Select-String -LiteralPath $soubor -Pattern "^\s*$klic\s*:" -CaseSensitive:$false |
         Select-Object -First 1
    if (-not $r) { return '' }
    ($r.Line -replace '^[^:]*:\s*', '').Trim()
}

function RequireZaznam([string]$soubor, [string]$klic, [string]$hodnota, [string]$popis) {
    # Hláška [FAIL] nikdy nevypisuje očekávanou hodnotu — kontrola je
    # checkpoint, ne nápověda. Stejné pravidlo jako v linuxové knihovně.
    $m = Zaznam $soubor $klic
    if ($m -and $m -eq $hodnota) { Uspech (Nebo $popis "${klic}: $hodnota") }
    else { Chyba ("zatím nesedí — " + (Nebo $popis "řádek ${klic}:") + " (máte '" + (Nebo $m 'nic') + "')") }
}

function RequireZaznamTvar([string]$soubor, [string]$klic, [string]$vzor, [string]$popis) {
    $m = Zaznam $soubor $klic
    if ($m -and $m -match $vzor) { Uspech (Nebo $popis "${klic}: $m") }
    else { Chyba ("zatím nesedí — " + (Nebo $popis "řádek ${klic}:") + " (máte '" + (Nebo $m 'nic') + "')") }
}

# ── oprávnění NTFS ────────────────────────────────────────────────
# Windows nepracuje s trojicí ugo/rwx, ale se seznamem pravidel (ACL).
# Každé pravidlo říká: komu, co povolit nebo zakázat, a jestli se to dědí.
# Kontroly proto nesrovnávají číslo, ale hledají konkrétní pravidlo.

function PravidlaPro([string]$cesta, [string]$identita) {
    # Identita se vypisuje jako STANICE\jmeno nebo BUILTIN\Users —
    # porovnáváme jen část za zpětným lomítkem.
    try { $acl = Get-Acl -LiteralPath $cesta -ErrorAction Stop } catch { return @() }
    @($acl.Access | Where-Object {
        ($_.IdentityReference.Value -split '\\')[-1] -eq $identita
    })
}

function RequireOpravneni([string]$cesta, [string]$identita, [string]$prava, [string]$popis) {
    # `prava` je jméno z výčtu FileSystemRights: Modify, ReadAndExecute,
    # FullControl, Write… Ověřuje se, že VLASTNÍ (nezděděné) povolení pokrývá
    # aspoň je — zděděné pravidlo z C:\ by jinak dalo PASS zadarmo.
    # Zároveň: existuje-li pro tutéž identitu Deny, přístup fakticky není.
    $pozadovano = [System.Security.AccessControl.FileSystemRights]$prava
    $vsechna = PravidlaPro $cesta $identita
    $zakaz = @($vsechna | Where-Object { $_.AccessControlType -eq 'Deny' })
    $sedi  = @($vsechna | Where-Object {
        $_.AccessControlType -eq 'Allow' -and (-not $_.IsInherited) -and
        (($_.FileSystemRights -band $pozadovano) -eq $pozadovano)
    })
    if ($zakaz.Count -gt 0) {
        Chyba "$identita má na $cesta pravidlo Deny — přístup tím fakticky nemá"
    } elseif ($sedi.Count -gt 0) {
        Uspech (Nebo $popis "$identita má na $cesta oprávnění $prava")
    } else {
        Chyba "zatím nesedí — oprávnění $prava pro $identita na $cesta"
    }
}

function RequireBezPristupu([string]$cesta, [string]$identita, [string]$popis) {
    $povoleni = @(PravidlaPro $cesta $identita | Where-Object { $_.AccessControlType -eq 'Allow' })
    if ($povoleni.Count -gt 0) { Chyba "zatím nesedí — $identita má na $cesta pořád přístup" }
    else { Uspech (Nebo $popis "$identita na $cesta přístup nemá") }
}

function RequireZadnyPlnyPristup([string]$cesta, [string]$popis) {
    # Windowsová obdoba negative_no_777: nikdo „všichni" nesmí mít plné řízení.
    try { $acl = Get-Acl -LiteralPath $cesta -ErrorAction Stop } catch {
        Chyba "oprávnění $cesta se nepodařilo přečíst"; return }
    $siroke = @('Everyone','Users','Authenticated Users','Ověření uživatelé','Všichni')
    $plne = [System.Security.AccessControl.FileSystemRights]::FullControl
    $nalez = @($acl.Access | Where-Object {
        $_.AccessControlType -eq 'Allow' -and
        ($siroke -contains ($_.IdentityReference.Value -split '\\')[-1]) -and
        (($_.FileSystemRights -band $plne) -eq $plne)
    })
    if ($nalez.Count -gt 0) {
        Chyba "$cesta má plné řízení pro všechny — to není řešení, to je díra"
    } else { Uspech (Nebo $popis "$cesta není otevřená pro všechny") }
}

function RequireDedicnostVypnuta([string]$cesta, [string]$popis) {
    try { $acl = Get-Acl -LiteralPath $cesta -ErrorAction Stop } catch {
        Chyba "oprávnění $cesta se nepodařilo přečíst"; return }
    if ($acl.AreAccessRulesProtected) { Uspech (Nebo $popis "$cesta nedědí oprávnění z nadřazené složky") }
    else {
        Chyba "zatím nesedí — $cesta pořád dědí oprávnění z nadřazené složky"
        Poznamka 'dokud dědičnost běží, zděděná pravidla se odebrat nedají'
    }
}

function RequireStanice([string]$ocekavane) {
    if ($env:COMPUTERNAME -eq $ocekavane) { Uspech "stanice se jmenuje $ocekavane" }
    else { Chyba "stanice se jmenuje '$env:COMPUTERNAME', očekáváno $ocekavane" }
}

# ═════════════════════════════════════════════ souhrn
function VypisSouhrn {
    $celkem = $Global:LabPass + $Global:LabFail
    if ($celkem -eq 0 -and $Global:LabKrokFiltr -ne 0) {
        Write-Host ''
        Write-Host "  Část $($Global:LabKrokFiltr) v tomto cvičení není."
        Write-Host ''
        return
    }
    Write-Host ''
    if ($Global:LabFail -eq 0 -and $celkem -gt 0) {
        Write-Host "  Hotovo — $($Global:LabPass) z $celkem." -ForegroundColor Green
    } elseif ($celkem -gt 0) {
        Write-Host "  Splněno $($Global:LabPass) z $celkem. Zbývá $($Global:LabFail) — řádky [FAIL] výše říkají co."
    }
    # Otisk: stejný smysl jako na Linuxu. Není to důkaz — žák má na svém
    # stroji práva správce. Pozná se podle něj přeposlaný cizí výsledek.
    $cas = Get-Date -Format 'yyyy-MM-ddTHH:mm'
    $podklad = "$env:COMPUTERNAME|$($Global:ZAK)|$cas|$($Global:LabPass)/$celkem"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bajty = [System.Text.Encoding]::UTF8.GetBytes($podklad)
    $otisk = (($sha.ComputeHash($bajty) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 12)
    Write-Host "  Žák: $($Global:ZAK2) · Stanice: $env:COMPUTERNAME · Čas: $cas · Otisk: $otisk" -ForegroundColor DarkYellow
    Write-Host ''
    # Návratový kód jako u bashové verze: 0 hotovo, 1 zbývá práce.
    if ($Global:LabFail -eq 0) { exit 0 } else { exit 1 }
}

# Kontrola zvýšených práv. Bez nich Get-Acl na složce, ze které žák odebral
# Users, skončí výjimkou a žák dostane sérii nesrozumitelných FAILů.
function VyzadujSpravce {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $role = New-Object Security.Principal.WindowsPrincipal $id
    if (-not $role.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host ''
        Write-Host '  Tenhle skript potřebuje PowerShell spuštěný jako správce.' -ForegroundColor Red
        Write-Host '  Zavřete okno a otevřete Terminál (správce).'
        Write-Host ''
        exit 1
    }
}

ZjistiZaka
