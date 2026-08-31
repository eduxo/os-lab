# 2/W2 — ověření
param([int]$Krok = 0)
. "$PSScriptRoot\..\..\lib\lab-lib.ps1"
$Global:LabKrokFiltr = $Krok
VyzadujSpravce

$Koren = 'C:\NetLab'
$Form  = Join-Path $env:USERPROFILE 'netlab\ntfs.txt'
$Urovne = @('Modify', 'ReadAndExecute')
$MojeUroven = $Urovne[($ZAK % 2)]

Krok 1 'Prostředí'
RequirePath $Form 'zadání a formulář jsou na místě' 'chybí formulář — spusťte start.ps1'
foreach ($d in @('sklad','ucetni','verejne')) {
    RequirePath (Join-Path $Koren $d) "složka $d existuje" "chybí složka $d"
}
RequireUzivatel $ZakUzivatel
RequireUzivatel $ZakSpravce

Krok 2 'Složka sklad'
$sklad = Join-Path $Koren 'sklad'
RequireDedicnostVypnuta $sklad
# Práva dostává skupina, ne účet — stejně jako na Linuxu. Teprve tak jde
# obojí porovnat a teprve tak se dá do oddělení někdo přidat bez sahání
# na oprávnění složky.
if (Get-LocalGroup -Name $ZakSkupina -ErrorAction SilentlyContinue) {
    Uspech "místní skupina $ZakSkupina existuje"
    RequireClenSkupiny $ZakUzivatel $ZakSkupina "$ZakUzivatel je členem skupiny $ZakSkupina"
} else { Chyba "místní skupina $ZakSkupina neexistuje" }
RequireOpravneni $sklad $ZakSkupina $MojeUroven `
    "skupina $ZakSkupina má na složce sklad oprávnění $MojeUroven"
# Vestavěné skupiny podle SID, ne podle jména — na české instalaci se
# jmenují jinak a hledání podle řetězce by tiše selhalo.
$SkupinaUzivatele = SkupinaPodleSID 'S-1-5-32-545'
if ($SkupinaUzivatele) {
    RequireBezPristupu $sklad $SkupinaUzivatele "skupina $SkupinaUzivatele nemá na složku sklad přístup"
}
# Po vypnutí dědičnosti zůstane i „Ověření uživatelé" zděděné z C:\ —
# odebrat jen Users nestačí, obsluha by se do složky pořád dostala.
# Tahle skupina není lokální, hledá se překladem známého SID.
$Overeni = (New-Object Security.Principal.SecurityIdentifier 'S-1-5-11').Translate(
             [Security.Principal.NTAccount]).Value -split '\\' | Select-Object -Last 1
RequireBezPristupu $sklad $Overeni "skupina $Overeni nemá na složku sklad přístup"
RequireZadnyPlnyPristup $sklad

Krok 3 'Složky ucetni a verejne'
$ucetni = Join-Path $Koren 'ucetni'
RequireOpravneni $ucetni $ZakSpravce 'FullControl' "$ZakSpravce má na složce ucetni plný přístup"
RequireBezPristupu $ucetni $ZakUzivatel "$ZakUzivatel nemá na složku ucetni přístup"
RequireOpravneni (Join-Path $Koren 'verejne') 'Users' 'ReadAndExecute' `
    'skupina Users má na složce verejne čtení a spouštění'

Krok 4 'Doložení vlastního běhu'
try {
    $acl = Get-Acl -LiteralPath $sklad -ErrorAction Stop
    RequireZaznam $Form 'vlastnik-sklad' $acl.Owner 've formuláři je vlastník složky sklad'
    RequireZaznam $Form 'pravidel-sklad' ([string]@($acl.Access).Count) `
        've formuláři je počet pravidel složky sklad'
} catch {
    Chyba 'oprávnění složky sklad se nepodařilo přečíst'
}

VypisSouhrn
