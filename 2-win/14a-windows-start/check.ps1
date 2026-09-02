# 2/W1 — ověření
param([int]$Krok = 0)
. "$PSScriptRoot\..\..\lib\lab-lib.ps1"
$Global:LabKrokFiltr = $Krok
VyzadujSpravce

$Doku = Join-Path $env:USERPROFILE 'netlab'
$Form = Join-Path $Doku 'stanice.txt'
$Spravce = $ZakSpravce

Krok 1 'Prostředí'
RequirePath $Form 'formulář stanice.txt je na místě' `
                  'chybí formulář — spusťte start.ps1'

Krok 2 'Jméno stanice'
RequireStanice $ZakStanice

Krok 3 'Účty'
RequireUzivatel $ZakUzivatel
RequireUzivatel $Spravce
# Skupina správců se hledá podle SID — na české instalaci se jmenuje jinak.
$SkupinaSpravcu = SkupinaPodleSID 'S-1-5-32-544'
if ($SkupinaSpravcu) {
    RequireClenSkupiny $Spravce $SkupinaSpravcu "$Spravce má práva správce"
    # Negativní kontrola: běžný účet práva správce mít nesmí.
    RequireNeClenSkupiny $ZakUzivatel $SkupinaSpravcu "$ZakUzivatel nemá práva správce"
} else { Chyba 'skupinu správců se nepodařilo najít — řekněte o tom vyučujícímu' }

Krok 4 'UAC a přehled stanice'
# UAC se vypíná hodnotou EnableLUA v registru. Vypnout ho „aby to nevyskakovalo"
# je nejběžnější rada z internetu a nejhorší, co se dá udělat.
$uac = $null
try {
    $uac = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
            -Name 'EnableLUA' -ErrorAction Stop).EnableLUA
} catch { }
if ($uac -eq 1) { Uspech 'UAC je zapnuté' }
else {
    Chyba 'UAC je vypnuté — zapněte ho zpátky'
    Poznamka 'vypnout UAC není řešení otravných dotazů, je to odstranění pojistky'
}

# Hodnoty z vlastního běhu — na jiné stanici vyjdou jinak.
$os = Get-CimInstance Win32_OperatingSystem
# Caption vrací „Microsoft Windows 11 Pro"; zadání ukazuje kratší tvar,
# takže se porovnává jen jádro, ne celý řetězec.
RequireZaznamTvar $Form 'vydani' 'Windows\s+1[01]' 've formuláři je edice Windows'
RequireZaznam $Form 'sestaveni' $os.BuildNumber 've formuláři je číslo sestavení'
$u = Get-LocalUser -Name $ZakUzivatel -ErrorAction SilentlyContinue
if ($u) { RequireZaznam $Form 'sid' $u.SID.Value "ve formuláři je SID účtu $ZakUzivatel" }
else    { Chyba "SID nelze ověřit, dokud účet $ZakUzivatel neexistuje" }

VypisSouhrn
