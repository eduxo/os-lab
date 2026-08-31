# 2/W2 — Windows 11: oprávnění NTFS. Prostředí: windowsová VM.
# Postaví složky, oprávnění nechá výchozí — nastavit je je učivo.
. "$PSScriptRoot\..\..\lib\lab-lib.ps1"

$Koren = 'C:\NetLab'
$Form  = Join-Path $env:USERPROFILE 'netlab\ntfs.txt'

# Úroveň oprávnění pro sklad se u každého žáka liší.
$Urovne = @('Modify', 'ReadAndExecute')
$MojeUroven = $Urovne[($ZAK % 2)]

if (Test-Path -LiteralPath $Form) {
    Write-Host ''
    Write-Host '  Prostředí už existuje — pokračujte, kde jste skončili.'
    Write-Host "  Oprávnění pro sklad:  $MojeUroven"
    Write-Host ''
    exit 0
}

# Účty z předchozího windowsového cvičení jsou předpokladem.
$Chybi = @()
foreach ($u in @($ZakUzivatel, $ZakSpravce)) {
    if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) { $Chybi += $u }
}
if ($Chybi.Count -gt 0) {
    Write-Host ''
    Write-Host "  Na stanici chybí účty: $($Chybi -join ', ')"
    Write-Host '  Zakládaly se ve cvičení o prvním startu Windows a tohle cvičení'
    Write-Host '  na nich stojí. Doplňte je a spusťte znovu.'
    Write-Host ''
    exit 1
}

Write-Host '  Zakládám složky oddělení…'
foreach ($d in @('sklad', 'ucetni', 'verejne')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Koren $d) | Out-Null
    "Pracovní dokument oddělení $d." |
        Set-Content -LiteralPath (Join-Path $Koren "$d\dokument.txt") -Encoding UTF8
}
New-Item -ItemType Directory -Force -Path (Split-Path $Form) | Out-Null

@"
# Oprávnění NTFS — zadání a formulář.
#
# C:\NetLab\sklad     místní skupina $ZakSkupina má mít oprávnění $MojeUroven
#                     a $ZakUzivatel má být jejím členem.
#                     Složka NEDĚDÍ oprávnění z nadřazené složky a nemá mít
#                     přístup ani skupina Users, ani Authenticated Users.
#
# C:\NetLab\ucetni    $ZakSpravce má mít Full control,
#                     $ZakUzivatel k ní nemá mít přístup.
#
# C:\NetLab\verejne   skupina Users má mít ReadAndExecute.
#
# Do formuláře zapište hodnoty zjištěné na hotovém systému:
# vlastnik-sklad = vlastník složky sklad (Get-Acl … .Owner), celý zápis
#                  včetně jména stanice před zpětným lomítkem
# pravidel-sklad = kolik pravidel má složka sklad po vypnutí dědičnosti
vlastnik-sklad:
pravidel-sklad:
"@ | Set-Content -LiteralPath $Form -Encoding UTF8

Write-Host ''
Write-Host '  Prostředí je připravené.'
Write-Host ''
Write-Host "    Složky oddělení:      $Koren"
Write-Host "    Zadání a formulář:    $Form"
Write-Host "    Oprávnění pro sklad:  $MojeUroven"
Write-Host ''
Write-Host '  Průběžnou kontrolu spouštějte odsud:'
Write-Host '    powershell -ExecutionPolicy Bypass -File .\check.ps1 -Krok 1'
Write-Host ''
